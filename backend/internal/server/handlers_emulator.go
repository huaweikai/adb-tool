package server

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"time"

	"adb-tool/backend/internal/emulator"
	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

// EmulatorEngine holds the current engine configuration state.
var EmulatorEngine = &emulator.Engine{}

// DownloadMgr handles emulator-related downloads.
var DownloadMgr = emulator.NewDownloadManager()

// SDKMgr handles Android SDK import and management.
var SDKMgr = emulator.NewSDKManager()

// handleEmulatorEngineStatus returns the current emulator engine status.
func (s *Server) handleEmulatorEngineStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		writeAPIError(w, http.StatusMethodNotAllowed, "GET required")
		return
	}

	// Refresh engine status
	EmulatorEngine, _ = emulator.DetectEmulatorEngine("", "")

	writeJSON(w, map[string]interface{}{
		"isValid":         EmulatorEngine.IsValid,
		"emulatorPath":    EmulatorEngine.EmulatorPath,
		"androidHome":     EmulatorEngine.AndroidHome,
		"emulatorVersion": EmulatorEngine.EmulatorVersion,
		"avdmanagerPath":  EmulatorEngine.AvdmanagerPath,
		"sdkmanagerPath":  EmulatorEngine.SdkmanagerPath,
		"javaPath":        EmulatorEngine.JavaPath,
		"javaVersion":     EmulatorEngine.JavaVersion,
		"toolchainReady":  EmulatorEngine.ToolchainReady,
		"lastVerified":    EmulatorEngine.LastVerified,
		"error":           EmulatorEngine.Error,
		"hasSDK":          SDKMgr.Exists(),
		"sdkPath":         SDKMgr.GetSDKPath(),
	})
}

// handleEmulatorSDKImport imports an Android SDK from a zip file.
func (s *Server) handleEmulatorSDKImport(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}

	// Parse multipart form
	if err := r.ParseMultipartForm(500 << 20); err != nil { // 500MB max
		writeAPIError(w, http.StatusBadRequest, "failed to parse form: "+err.Error())
		return
	}

	file, _, err := r.FormFile("sdk")
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "sdk file is required")
		return
	}
	defer file.Close()

	// Save to temp file
	tmpPath := filepath.Join(os.TempDir(), "sdk-import-"+uuid.New().String()+".zip")
	tmpFile, err := os.Create(tmpPath)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, "failed to create temp file")
		return
	}
	defer os.Remove(tmpPath)
	defer tmpFile.Close()

	if _, err := io.Copy(tmpFile, file); err != nil {
		writeAPIError(w, http.StatusInternalServerError, "failed to save temp file")
		return
	}
	tmpFile.Close()

	// Extract SDK
	if err := SDKMgr.ImportSDKFromZip(tmpPath); err != nil {
		writeAPIError(w, http.StatusInternalServerError, "failed to extract SDK: "+err.Error())
		return
	}

	// Re-detect engine
	EmulatorEngine, _ = emulator.DetectEmulatorEngine("", "")

	// Get SDK size
	size, _ := SDKMgr.GetSDKSize()

	writeJSON(w, map[string]interface{}{
		"success":         true,
		"sdkPath":         SDKMgr.GetSDKPath(),
		"emulatorPath":   EmulatorEngine.EmulatorPath,
		"sizeBytes":       size,
		"toolchainReady":  EmulatorEngine.ToolchainReady,
	})
}

// handleEmulatorSDKDelete deletes the imported SDK.
func (s *Server) handleEmulatorSDKDelete(w http.ResponseWriter, r *http.Request) {
	if r.Method != "DELETE" {
		writeAPIError(w, http.StatusMethodNotAllowed, "DELETE required")
		return
	}

	if err := SDKMgr.DeleteSDK(); err != nil {
		writeAPIError(w, http.StatusInternalServerError, "failed to delete SDK: "+err.Error())
		return
	}

	// Re-detect engine
	EmulatorEngine, _ = emulator.DetectEmulatorEngine("", "")

	writeJSON(w, map[string]interface{}{
		"success": true,
	})
}

// handleEmulatorSDKDetect scans the system for existing Android SDK installations.
func (s *Server) handleEmulatorSDKDetect(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		writeAPIError(w, http.StatusMethodNotAllowed, "GET required")
		return
	}

	// Scan common SDK locations
	sdks := emulator.ScanSystemSDKs()

	writeJSON(w, map[string]interface{}{
		"sdks": sdks,
	})
}

// handleEmulatorSDKDownload downloads Android SDK command-line tools from Google.
func (s *Server) handleEmulatorSDKDownload(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	defer r.Body.Close()

	var req struct {
		URL    string `json:"url"`
		ID     string `json:"id"`
		SHA256 string `json:"sha256"`
		Name   string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}

	if req.URL == "" || req.ID == "" {
		writeAPIError(w, http.StatusBadRequest, "url and id are required")
		return
	}

	home, err := os.UserHomeDir()
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, "failed to get home directory")
		return
	}

	platform := runtime.GOOS + "-" + runtime.GOARCH
	downloadID := req.ID + "-" + platform
	destPath := filepath.Join(home, ".adb-tool", "sdk", "downloads", downloadID, "cmdline-tools.zip")

	item := &emulator.DownloadItem{
		ID:       downloadID,
		Type:     emulator.DownloadTypeSDK,
		Name:     req.Name,
		URL:      req.URL,
		DestPath: destPath,
		SHA256:   req.SHA256,
	}

	download := DownloadMgr.StartDownload(item)

	writeJSON(w, map[string]interface{}{
		"id":       download.ID,
		"status":   download.Status,
		"progress": download.Progress,
	})
}

// handleEmulatorSDKUse selects a detected SDK path for use.
func (s *Server) handleEmulatorSDKUse(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	defer r.Body.Close()

	var req struct {
		SDKPath string `json:"sdkPath"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}

	if req.SDKPath == "" {
		writeAPIError(w, http.StatusBadRequest, "sdkPath is required")
		return
	}

	// Verify the path exists and contains emulator
	emulatorPath := filepath.Join(req.SDKPath, "emulator", "emulator")
	if runtime.GOOS == "windows" {
		emulatorPath += ".exe"
	}
	if _, err := os.Stat(emulatorPath); err != nil {
		writeAPIError(w, http.StatusBadRequest, "invalid SDK path: emulator not found")
		return
	}

	// Re-detect engine with this path
	engine, err := emulator.DetectEmulatorEngine(req.SDKPath, "")
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}

	// Update global state
	EmulatorEngine = engine

	writeJSON(w, map[string]interface{}{
		"isValid":         engine.IsValid,
		"emulatorPath":    engine.EmulatorPath,
		"androidHome":     engine.AndroidHome,
		"emulatorVersion": engine.EmulatorVersion,
		"avdmanagerPath":   engine.AvdmanagerPath,
		"sdkmanagerPath":   engine.SdkmanagerPath,
		"javaPath":        engine.JavaPath,
		"javaVersion":      engine.JavaVersion,
		"toolchainReady":  engine.ToolchainReady,
		"lastVerified":     engine.LastVerified,
		"error":           engine.Error,
	})
}

// handleEmulatorEngineValidate validates the given emulator path or Android home.
func (s *Server) handleEmulatorEngineValidate(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	defer r.Body.Close()

	var req struct {
		AndroidHome  string `json:"androidHome"`
		EmulatorPath string `json:"emulatorPath"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}

	engine, err := emulator.DetectEmulatorEngine(req.AndroidHome, req.EmulatorPath)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}

	// Update global state
	EmulatorEngine = engine

	writeJSON(w, map[string]interface{}{
		"isValid":         engine.IsValid,
		"emulatorPath":    engine.EmulatorPath,
		"androidHome":     engine.AndroidHome,
		"emulatorVersion": engine.EmulatorVersion,
		"avdmanagerPath":  engine.AvdmanagerPath,
		"sdkmanagerPath":  engine.SdkmanagerPath,
		"javaPath":        engine.JavaPath,
		"javaVersion":     engine.JavaVersion,
		"toolchainReady":  engine.ToolchainReady,
		"lastVerified":    engine.LastVerified,
		"error":          engine.Error,
	})
}

// handleEmulatorEngineConfig updates the emulator engine configuration.
func (s *Server) handleEmulatorEngineConfig(w http.ResponseWriter, r *http.Request) {
	if r.Method != "PUT" {
		writeAPIError(w, http.StatusMethodNotAllowed, "PUT required")
		return
	}
	defer r.Body.Close()

	var req struct {
		AndroidHome  string `json:"androidHome"`
		EmulatorPath string `json:"emulatorPath"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}

	engine, err := emulator.DetectEmulatorEngine(req.AndroidHome, req.EmulatorPath)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}

	// Update global state
	EmulatorEngine = engine

	writeJSON(w, map[string]interface{}{
		"isValid":         engine.IsValid,
		"emulatorPath":    engine.EmulatorPath,
		"androidHome":     engine.AndroidHome,
		"emulatorVersion": engine.EmulatorVersion,
		"avdmanagerPath":  engine.AvdmanagerPath,
		"sdkmanagerPath":  engine.SdkmanagerPath,
		"javaPath":        engine.JavaPath,
		"javaVersion":     engine.JavaVersion,
		"toolchainReady":  engine.ToolchainReady,
		"lastVerified":    engine.LastVerified,
		"error":          engine.Error,
	})
}

// handleEmulatorJavaStatus returns the current Java runtime status.
func (s *Server) handleEmulatorJavaStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		writeAPIError(w, http.StatusMethodNotAllowed, "GET required")
		return
	}

	// Detect current Java
	java := emulator.DetectJavaRuntime(EmulatorEngine.AndroidHome)

	// Scan all available Java runtimes
	runtimes := emulator.ScanJavaRuntimes(EmulatorEngine.AndroidHome)

	// Persisted user selection
	selectedPath := emulator.LoadSelectedJavaPath()

	// Get embedded runtimes
	embedded := emulator.GetEmbeddedJavaRuntimes()

	// Get Java downloads
	downloads := DownloadMgr.ListDownloadsByType(emulator.DownloadTypeJava)

	// Convert downloads to response format
	downloadsResp := make([]map[string]interface{}, len(downloads))
	for i, d := range downloads {
		downloadsResp[i] = map[string]interface{}{
			"id":        d.ID,
			"status":    d.Status,
			"progress":  d.Progress,
			"downloaded": d.Downloaded,
			"size":      d.Size,
		}
	}

	response := map[string]interface{}{
		"systemJava":   java,
		"runtimes":     runtimes,
		"selectedPath": selectedPath,
		"embedded":     embedded,
		"downloads":    downloadsResp,
	}

	if java != nil {
		response["status"] = "found"
		response["path"] = java.Path
		response["version"] = java.Version
	} else {
		response["status"] = "not_found"
	}

	writeJSON(w, response)
}

// handleEmulatorJavaValidate validates a specific Java path.
func (s *Server) handleEmulatorJavaValidate(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	defer r.Body.Close()

	var req struct {
		JavaPath string `json:"javaPath"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}

	if req.JavaPath == "" {
		writeAPIError(w, http.StatusBadRequest, "javaPath is required")
		return
	}

	// Test the Java path by running java -version
	rt := emulator.ValidateJavaPath(req.JavaPath)
	if rt == nil {
		writeJSON(w, map[string]interface{}{
			"valid": false,
			"error": "Not a usable Java executable",
		})
		return
	}

	writeJSON(w, map[string]interface{}{
		"valid":   true,
		"path":    rt.Path,
		"version": rt.Version,
		"vendor":  rt.Vendor,
	})
}

// handleEmulatorJavaList returns all detected Java runtimes plus the selection.
func (s *Server) handleEmulatorJavaList(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		writeAPIError(w, http.StatusMethodNotAllowed, "GET required")
		return
	}

	writeJSON(w, map[string]interface{}{
		"runtimes":     emulator.ScanJavaRuntimes(EmulatorEngine.AndroidHome),
		"selectedPath": emulator.LoadSelectedJavaPath(),
	})
}

// handleEmulatorJavaSelect persists the user-selected Java runtime.
func (s *Server) handleEmulatorJavaSelect(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	defer r.Body.Close()

	var req struct {
		JavaPath string `json:"javaPath"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}

	if req.JavaPath == "" {
		writeAPIError(w, http.StatusBadRequest, "javaPath is required")
		return
	}

	// Verify the selected path is a usable Java executable.
	rt := emulator.ValidateJavaPath(req.JavaPath)
	if rt == nil {
		writeJSON(w, map[string]interface{}{
			"selected": false,
			"error":    "Not a usable Java executable",
		})
		return
	}

	if err := emulator.SaveSelectedJavaPath(rt.Path); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}

	// Reflect the selection in the live engine so the toolchain uses it.
	EmulatorEngine.JavaPath = rt.Path
	EmulatorEngine.JavaVersion = rt.Version

	writeJSON(w, map[string]interface{}{
		"selected": true,
		"path":     rt.Path,
		"version":  rt.Version,
		"vendor":   rt.Vendor,
	})
}

// handleEmulatorJavaDownload starts a Java runtime download.
func (s *Server) handleEmulatorJavaDownload(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	defer r.Body.Close()

	var req struct {
		URL    string `json:"url"`
		ID     string `json:"id"`
		SHA256 string `json:"sha256"`
		Name   string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}

	if req.URL == "" || req.ID == "" {
		writeAPIError(w, http.StatusBadRequest, "url and id are required")
		return
	}

	// Build download item
	home, err := os.UserHomeDir()
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, "failed to get home directory")
		return
	}

	platform := runtime.GOOS + "-" + runtime.GOARCH
	downloadID := req.ID + "-" + platform
	destPath := filepath.Join(home, ".adb-tool", "emulator", "java-runtime", downloadID, "download.zip")

	item := &emulator.DownloadItem{
		ID:       downloadID,
		Type:     emulator.DownloadTypeJava,
		Name:     req.Name,
		URL:      req.URL,
		DestPath: destPath,
		SHA256:   req.SHA256,
	}

	download := DownloadMgr.StartDownload(item)

	writeJSON(w, map[string]interface{}{
		"id":       download.ID,
		"status":   download.Status,
		"progress": download.Progress,
	})
}

// handleEmulatorDownloadProgress returns the progress of a download (unified).
func (s *Server) handleEmulatorDownloadProgress(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		writeAPIError(w, http.StatusMethodNotAllowed, "GET required")
		return
	}

	id := r.URL.Query().Get("id")
	if id == "" {
		writeAPIError(w, http.StatusBadRequest, "id is required")
		return
	}

	download := DownloadMgr.GetDownload(id)
	if download == nil {
		writeJSON(w, map[string]interface{}{
			"id":       id,
			"status":   "not_found",
			"progress": 0,
		})
		return
	}

	writeJSON(w, map[string]interface{}{
		"id":         download.ID,
		"type":       download.Type,
		"name":       download.Name,
		"status":     download.Status,
		"progress":   download.Progress,
		"downloaded": download.Downloaded,
		"size":       download.Size,
		"error":      download.Error,
	})
}

// handleEmulatorDownloadCancel cancels a download (unified).
func (s *Server) handleEmulatorDownloadCancel(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}

	id := r.URL.Query().Get("id")
	if id == "" {
		writeAPIError(w, http.StatusBadRequest, "id is required")
		return
	}

	DownloadMgr.CancelDownload(id)

	writeJSON(w, map[string]interface{}{
		"status": "cancelled",
	})
}

// handleEmulatorDownloadPause pauses a download.
func (s *Server) handleEmulatorDownloadPause(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}

	id := r.URL.Query().Get("id")
	if id == "" {
		writeAPIError(w, http.StatusBadRequest, "id is required")
		return
	}

	DownloadMgr.PauseDownload(id)

	writeJSON(w, map[string]interface{}{
		"status": "paused",
	})
}

// handleEmulatorDownloadResume resumes a paused download.
func (s *Server) handleEmulatorDownloadResume(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}

	id := r.URL.Query().Get("id")
	if id == "" {
		writeAPIError(w, http.StatusBadRequest, "id is required")
		return
	}

	DownloadMgr.ResumeDownload(id)

	item := DownloadMgr.GetDownload(id)
	if item != nil {
		writeJSON(w, map[string]interface{}{
			"id":       item.ID,
			"status":   item.Status,
			"progress": item.Progress,
		})
	} else {
		writeJSON(w, map[string]interface{}{
			"status": "not_found",
		})
	}
}

// handleEmulatorDownloads returns all downloads (unified).
func (s *Server) handleEmulatorDownloads(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		writeAPIError(w, http.StatusMethodNotAllowed, "GET required")
		return
	}

	downloadType := r.URL.Query().Get("type")
	var downloads []*emulator.DownloadItem

	if downloadType != "" {
		downloads = DownloadMgr.ListDownloadsByType(emulator.DownloadType(downloadType))
	} else {
		downloads = DownloadMgr.ListDownloads()
	}

	result := make([]map[string]interface{}, len(downloads))
	for i, d := range downloads {
		result[i] = map[string]interface{}{
			"id":        d.ID,
			"type":      d.Type,
			"name":      d.Name,
			"status":    d.Status,
			"progress":  d.Progress,
			"downloaded": d.Downloaded,
			"size":      d.Size,
		}
	}

	writeJSON(w, map[string]interface{}{
		"downloads": result,
	})
}

// handleEmulatorImages returns the list of system images.
func (s *Server) handleEmulatorImages(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		writeAPIError(w, http.StatusMethodNotAllowed, "GET required")
		return
	}

	// Create image manager
	imageMgr := emulator.NewImageManager(EmulatorEngine.AndroidHome)

	// Get system images
	images := imageMgr.ListImages()

	// Get download status for each image
	downloads := DownloadMgr.ListDownloadsByType(emulator.DownloadTypeImage)
	downloadMap := make(map[string]*emulator.DownloadItem)
	for _, d := range downloads {
		downloadMap[d.ID] = d
	}

	// Build response
	result := make([]map[string]interface{}, len(images))
	for i, img := range images {
		// Check if image has an active download
		download := downloadMap[img.ID]
		status := img.Status
		progress := 0.0
		if download != nil {
			status = download.Status
			progress = download.Progress
		}

		result[i] = map[string]interface{}{
			"id":             img.ID,
			"name":           img.Name,
			"apiLevel":       img.APILevel,
			"androidVersion": img.AndroidVersion,
			"arch":           img.Arch,
			"variant":        img.Variant,
			"localPath":      img.LocalPath,
			"files":          img.Files,
			"fileSize":       img.FileSize,
			"status":         status,
			"progress":       progress,
		}
	}

	writeJSON(w, map[string]interface{}{
		"images": result,
	})
}

// handleEmulatorImageGet returns a specific system image.
func (s *Server) handleEmulatorImageGet(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		writeAPIError(w, http.StatusMethodNotAllowed, "GET required")
		return
	}

	id := r.URL.Query().Get("id")
	if id == "" {
		writeAPIError(w, http.StatusBadRequest, "id is required")
		return
	}

	imageMgr := emulator.NewImageManager(EmulatorEngine.AndroidHome)
	image := imageMgr.GetImage(id)

	if image == nil {
		writeAPIError(w, http.StatusNotFound, "image not found")
		return
	}

	// Check download status
	download := DownloadMgr.GetDownload(id)
	status := image.Status
	progress := 0.0
	if download != nil {
		status = download.Status
		progress = download.Progress
	}

	writeJSON(w, map[string]interface{}{
		"id":             image.ID,
		"name":           image.Name,
		"apiLevel":       image.APILevel,
		"androidVersion": image.AndroidVersion,
		"arch":           image.Arch,
		"variant":        image.Variant,
		"localPath":      image.LocalPath,
		"files":          image.Files,
		"fileSize":       image.FileSize,
		"status":         status,
		"progress":       progress,
	})
}

// handleEmulatorImageAdd adds a new system image for download.
func (s *Server) handleEmulatorImageAdd(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	defer r.Body.Close()

	var req struct {
		URL    string `json:"url"`
		ID     string `json:"id"`
		Name   string `json:"name"`
		SHA256 string `json:"sha256"`
		APILevel int `json:"apiLevel"`
		Arch   string `json:"arch"`
		Variant string `json:"variant"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}

	if req.URL == "" {
		writeAPIError(w, http.StatusBadRequest, "url is required")
		return
	}

	home, err := os.UserHomeDir()
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, "failed to get home directory")
		return
	}

	// Build download ID
	downloadID := fmt.Sprintf("image-%s-%s-%s", req.ID, req.Arch, req.Variant)
	destPath := filepath.Join(home, ".adb-tool", "emulator", "system-images", downloadID, "download.zip")

	item := &emulator.DownloadItem{
		ID:       downloadID,
		Type:     emulator.DownloadTypeImage,
		Name:     req.Name,
		URL:      req.URL,
		DestPath: destPath,
		SHA256:   req.SHA256,
	}

	download := DownloadMgr.StartDownload(item)

	writeJSON(w, map[string]interface{}{
		"id":       download.ID,
		"status":   download.Status,
		"progress": download.Progress,
	})
}

// handleEmulatorInstances returns the list of emulator instances.
func (s *Server) handleEmulatorInstances(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		writeAPIError(w, http.StatusMethodNotAllowed, "GET required")
		return
	}

	if s.instanceManager == nil {
		writeAPIError(w, http.StatusServiceUnavailable, "emulator not initialized")
		return
	}

	instances := s.instanceManager.List()

	result := make([]map[string]interface{}, len(instances))
	for i, inst := range instances {
		result[i] = map[string]interface{}{
			"id":           inst.ID,
			"imageId":      inst.ImageID,
			"name":         inst.Name,
			"avdPath":      inst.AVDPath,
			"config":       inst.Config,
			"status":       inst.Status,
			"consolePort":  inst.ConsolePort,
			"adbPort":      inst.ADBPort,
			"pid":          inst.PID,
			"serial":       inst.Serial,
			"snapshotId":   inst.SnapshotID,
			"createdAt":    inst.CreatedAt,
			"lastStartedAt": inst.LastStartedAt,
		}
	}

	writeJSON(w, map[string]interface{}{
		"instances": result,
	})
}

// handleEmulatorInstanceCreate creates a new emulator instance.
func (s *Server) handleEmulatorInstanceCreate(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	defer r.Body.Close()

	if s.instanceManager == nil {
		writeAPIError(w, http.StatusServiceUnavailable, "emulator not initialized")
		return
	}

	var req struct {
		ImageID    string `json:"imageId"`
		Name       string `json:"name"`
		Cores      int    `json:"cores"`
		MemoryMB   int    `json:"memoryMb"`
		Width      int    `json:"width"`
		Height     int    `json:"height"`
		Density    int    `json:"density"`
		SDCardSize string `json:"sdcardSize"`
		GPUMode    string `json:"gpuMode"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}

	if req.ImageID == "" || req.Name == "" {
		writeAPIError(w, http.StatusBadRequest, "imageId and name are required")
		return
	}

	// Build config
	config := emulator.InstanceConfig{
		Cores:      req.Cores,
		MemoryMB:   req.MemoryMB,
		Width:      req.Width,
		Height:     req.Height,
		Density:    req.Density,
		SDCardSize: req.SDCardSize,
		GPUMode:    req.GPUMode,
	}

	// Create instance
	instance, err := s.instanceManager.Create(emulator.CreateInstanceRequest{
		Name:    req.Name,
		ImageID: req.ImageID,
		Config:  config,
	})
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, map[string]interface{}{
		"id":           instance.ID,
		"name":         instance.Name,
		"status":       instance.Status,
		"consolePort":  instance.ConsolePort,
		"adbPort":      instance.ADBPort,
		"serial":       instance.Serial,
		"avdPath":      instance.AVDPath,
		"createdAt":    instance.CreatedAt,
	})
}

// handleEmulatorInstanceStart starts an emulator instance.
func (s *Server) handleEmulatorInstanceStart(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	defer r.Body.Close()

	if s.instanceManager == nil {
		writeAPIError(w, http.StatusServiceUnavailable, "emulator not initialized")
		return
	}

	id := r.URL.Query().Get("id")
	if id == "" {
		writeAPIError(w, http.StatusBadRequest, "id is required")
		return
	}

	instance, err := s.instanceManager.Start(id)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}

	// Broadcast status update
	if s.statusMonitor != nil {
		s.statusMonitor.BroadcastStatus(instance.ID, instance.Status)
	}

	writeJSON(w, map[string]interface{}{
		"id":          instance.ID,
		"status":      instance.Status,
		"pid":         instance.PID,
		"serial":      instance.Serial,
		"consolePort": instance.ConsolePort,
		"adbPort":     instance.ADBPort,
	})
}

// handleEmulatorInstanceStop stops an emulator instance.
func (s *Server) handleEmulatorInstanceStop(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	defer r.Body.Close()

	if s.instanceManager == nil {
		writeAPIError(w, http.StatusServiceUnavailable, "emulator not initialized")
		return
	}

	id := r.URL.Query().Get("id")
	if id == "" {
		writeAPIError(w, http.StatusBadRequest, "id is required")
		return
	}

	instance, err := s.instanceManager.Get(id)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, err.Error())
		return
	}

	if err := s.instanceManager.Stop(id); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}

	// Broadcast status update
	if s.statusMonitor != nil {
		s.statusMonitor.BroadcastStatus(instance.ID, emulator.StatusStopped)
	}

	writeJSON(w, map[string]interface{}{
		"id":     instance.ID,
		"status": emulator.StatusStopped,
	})
}

// handleEmulatorInstanceDelete deletes an emulator instance.
func (s *Server) handleEmulatorInstanceDelete(w http.ResponseWriter, r *http.Request) {
	if r.Method != "DELETE" {
		writeAPIError(w, http.StatusMethodNotAllowed, "DELETE required")
		return
	}
	defer r.Body.Close()

	if s.instanceManager == nil {
		writeAPIError(w, http.StatusServiceUnavailable, "emulator not initialized")
		return
	}

	id := r.URL.Query().Get("id")
	if id == "" {
		writeAPIError(w, http.StatusBadRequest, "id is required")
		return
	}

	if err := s.instanceManager.Delete(id); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, map[string]interface{}{
		"id":      id,
		"deleted": true,
	})
}

// handleEmulatorInstanceGet returns a specific instance.
func (s *Server) handleEmulatorInstanceGet(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		writeAPIError(w, http.StatusMethodNotAllowed, "GET required")
		return
	}

	if s.instanceManager == nil {
		writeAPIError(w, http.StatusServiceUnavailable, "emulator not initialized")
		return
	}

	id := r.URL.Query().Get("id")
	if id == "" {
		writeAPIError(w, http.StatusBadRequest, "id is required")
		return
	}

	instance, err := s.instanceManager.Get(id)
	if err != nil {
		writeAPIError(w, http.StatusNotFound, err.Error())
		return
	}

	writeJSON(w, map[string]interface{}{
		"id":            instance.ID,
		"imageId":       instance.ImageID,
		"name":          instance.Name,
		"avdPath":       instance.AVDPath,
		"config":        instance.Config,
		"status":        instance.Status,
		"consolePort":   instance.ConsolePort,
		"adbPort":       instance.ADBPort,
		"pid":           instance.PID,
		"serial":        instance.Serial,
		"snapshotId":    instance.SnapshotID,
		"createdAt":     instance.CreatedAt,
		"lastStartedAt": instance.LastStartedAt,
	})
}

// handleEmulatorStatusWS handles WebSocket connections for emulator status updates.
func (s *Server) handleEmulatorStatusWS(w http.ResponseWriter, r *http.Request) {
	if s.statusMonitor == nil {
		writeAPIError(w, http.StatusServiceUnavailable, "emulator not initialized")
		return
	}

	conn, err := s.upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	defer conn.Close()

	// Get instance IDs to watch (comma-separated)
	instanceIDs := r.URL.Query()["id"]

	// Register connection
	s.statusMonitor.Register(conn, instanceIDs)
	defer s.statusMonitor.Unregister(conn)

	// Send initial status for watched instances
	if len(instanceIDs) > 0 {
		for _, id := range instanceIDs {
			inst, err := s.instanceManager.Get(id)
			if err == nil {
				update := emulator.StatusUpdate{
					Type:       "status",
					InstanceID: inst.ID,
					Status:     inst.Status,
					Timestamp:  time.Now(),
				}
				conn.WriteJSON(update)
			}
		}
	}

	// Keep connection alive and handle incoming messages
	for {
		_, msg, err := conn.ReadMessage()
		if err != nil {
			break
		}

		// Handle ping/pong or commands
		if string(msg) == "ping" {
			conn.WriteMessage(websocket.PongMessage, nil)
		}
	}
}
