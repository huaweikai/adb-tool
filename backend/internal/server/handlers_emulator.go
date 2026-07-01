package server

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
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

// SDKInstaller handles sdkmanager-driven package installs.
var SDKInstaller = emulator.NewSDKInstaller()

// emulatorInstanceToMap converts an emulator.Instance into the canonical
// JSON shape returned by every endpoint that exposes an instance
// (list, get, create, start, stop). Keeping the shape in one place
// means the Flutter client can trust that every endpoint carries the
// full identity fields (avdName / imageId / config / createdAt / ...),
// not just the mutable runtime fields. Previously Start and Stop
// returned only {id, status, pid, serial, ...}, so the Flutter
// provider's "replace whole instance" code path silently zeroed out
// the name and config the moment the user pressed Start.
func emulatorInstanceToMap(inst *emulator.Instance) map[string]interface{} {
	return map[string]interface{}{
		"id":            inst.ID,
		"imageId":       inst.ImageID,
		"name":          inst.Name,
		"avdPath":       inst.AVDPath,
		"config":        inst.Config,
		"status":        inst.Status,
		"consolePort":   inst.ConsolePort,
		"adbPort":       inst.ADBPort,
		"pid":           inst.PID,
		"serial":        inst.Serial,
		"snapshotId":    inst.SnapshotID,
		"createdAt":     inst.CreatedAt,
		"lastStartedAt": inst.LastStartedAt,
		"lastError":     inst.LastError,
		"logPath":       inst.LogPath,
		"bootStage":     inst.BootStage,
		"bootProgress":  inst.BootProgress,
		"bootMessage":   inst.BootMessage,
	}
}

// handleEmulatorEngineStatus returns the current emulator engine status.
func (s *Server) handleEmulatorEngineStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		writeAPIError(w, http.StatusMethodNotAllowed, "GET required")
		return
	}

	// Refresh engine status
	EmulatorEngine, _ = emulator.DetectEmulatorEngine("", "")

	writeJSON(w, map[string]interface{}{
		"isValid":            EmulatorEngine.IsValid,
		"emulatorPath":       EmulatorEngine.EmulatorPath,
		"androidHome":        EmulatorEngine.AndroidHome,
		"emulatorVersion":    EmulatorEngine.EmulatorVersion,
		"avdmanagerPath":     EmulatorEngine.AvdmanagerPath,
		"sdkmanagerPath":     EmulatorEngine.SdkmanagerPath,
		"javaPath":           EmulatorEngine.JavaPath,
		"javaVersion":        EmulatorEngine.JavaVersion,
		"toolchainReady":     EmulatorEngine.ToolchainReady,
		"lastVerified":       EmulatorEngine.LastVerified,
		"error":              EmulatorEngine.Error,
		"hasSDK":             SDKMgr.Exists(),
		"sdkPath":            SDKMgr.GetSDKPath(),
		"selectedSDKPath":    EmulatorEngine.SelectedSDKPath,
		"selectedSDKInvalid": EmulatorEngine.SelectedSDKInvalid,
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
		"success":        true,
		"sdkPath":        SDKMgr.GetSDKPath(),
		"emulatorPath":   EmulatorEngine.EmulatorPath,
		"sizeBytes":      size,
		"toolchainReady": EmulatorEngine.ToolchainReady,
	})
}

// handleEmulatorSDKDelete deletes the imported SDK.
func (s *Server) handleEmulatorSDKDelete(w http.ResponseWriter, r *http.Request) {
	if r.Method != "DELETE" {
		writeAPIError(w, http.StatusMethodNotAllowed, "DELETE required")
		return
	}

	// Fix (code-review B2): destructive — wipes the entire managed SDK dir.
	// Require ?confirm=true so a stray curl / accidental UI click can't
	// blow away multi-GB downloads. Mirrors handleCacheCleanup.
	if r.URL.Query().Get("confirm") != "true" {
		writeAPIError(w, http.StatusBadRequest,
			"pass ?confirm=true to acknowledge this destructive SDK deletion")
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

	// Fix (code-review M3 + M7): validate the URL scheme/host and the
	// ID-derived path segment before building the destPath.
	if err := validateDownloadURL(req.URL); err != nil {
		writeAPIError(w, http.StatusBadRequest, "invalid url: "+err.Error())
		return
	}
	safeID, err := sanitizeDownloadIDComponent(req.ID)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "invalid id: "+err.Error())
		return
	}

	home, err := os.UserHomeDir()
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, "failed to get home directory")
		return
	}

	platform := runtime.GOOS + "-" + runtime.GOARCH
	downloadID := safeID + "-" + platform
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

	// ponytail: reuse the same scan-path validator from M2 — single helper,
	// one place to update if we ever tighten the rules (e.g. enforce a
	// path prefix). Rejects empty / non-absolute / '..' / filesystem roots.
	if _, err := validateScanPath(req.SDKPath); err != nil {
		writeAPIError(w, http.StatusBadRequest, "invalid sdkPath: "+err.Error())
		return
	}

	// Accept the path if it has EITHER the emulator binary already OR a
	// usable cmdline-tools toolchain (sdkmanager + avdmanager). The latter
	// case lets the user point us at a freshly-installed SDK that hasn't
	// pulled emulator yet — they'll install it through the SDK download UI
	// and we'll pick it up automatically.
	emulatorPath := filepath.Join(req.SDKPath, "emulator", "emulator")
	if runtime.GOOS == "windows" {
		emulatorPath += ".exe"
	}
	hasEmulator := false
	if _, err := os.Stat(emulatorPath); err == nil {
		hasEmulator = true
	}
	hasToolchain := emulator.SdkPathHasToolchain(req.SDKPath)
	if !hasEmulator && !hasToolchain {
		writeAPIError(w, http.StatusBadRequest,
			"invalid SDK path: neither emulator nor cmdline-tools sdkmanager/avdmanager found")
		return
	}

	// Re-detect engine with this path
	engine, err := emulator.DetectEmulatorEngine(req.SDKPath, "")
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}

	// Persist the selection so it survives restarts.
	if err := emulator.SaveSelectedSDKPath(req.SDKPath); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}

	// Update global state
	EmulatorEngine = engine

	// Sync the resolved paths into the running InstanceManager so a freshly
	// sdkmanager-installed emulator (which only becomes visible AFTER the
	// initial empty-path InitEmulator call) is picked up by the next start.
	// Without this the instance_manager keeps its original empty emulatorPath
	// and startEmulator fails with "emulator path not configured".
	if s.instanceManager != nil {
		s.instanceManager.UpdateToolchainPaths(engine.EmulatorPath, engine.AvdmanagerPath)
	}

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
		"error":           engine.Error,
		// emulatorMissing lets the UI show a "click here to install emulator
		// + system image" prompt instead of treating the path as broken.
		"emulatorMissing": !hasEmulator,
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
		"error":           engine.Error,
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
		"error":           engine.Error,
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

	// A persisted selection that no longer resolves to a usable Java is invalid.
	selectedInvalid := false
	if selectedPath != "" && emulator.ValidateJavaPath(selectedPath) == nil {
		selectedInvalid = true
	}

	// Get embedded runtimes
	embedded := emulator.GetEmbeddedJavaRuntimes()

	// Get Java downloads
	downloads := DownloadMgr.ListDownloadsByType(emulator.DownloadTypeJava)

	// Convert downloads to response format
	downloadsResp := make([]map[string]interface{}, len(downloads))
	for i, d := range downloads {
		downloadsResp[i] = map[string]interface{}{
			"id":         d.ID,
			"status":     d.Status,
			"progress":   d.Progress,
			"downloaded": d.Downloaded,
			"size":       d.Size,
		}
	}

	// Build the default download suggestion list (Adoptium Temurin) so the
	// frontend can render a one-click "Download" dialog without the user
	// having to paste a URL.
	defaults := make([]map[string]interface{}, 0, len(emulator.SupportedJavaVersions))
	for _, ver := range emulator.SupportedJavaVersions {
		url, err := emulator.DefaultJavaDownloadURL(ver)
		if err != nil {
			// Skip unsupported combinations silently — handler keeps
			// working; just no default URL for that version.
			continue
		}
		defaults = append(defaults, map[string]interface{}{
			"version": ver,
			"id":      "temurin-" + ver,
			"name":    "Eclipse Temurin " + ver,
			"url":     url,
		})
	}

	response := map[string]interface{}{
		"systemJava":       java,
		"runtimes":         runtimes,
		"selectedPath":     selectedPath,
		"selectedInvalid":  selectedInvalid,
		"embedded":         embedded,
		"downloads":        downloadsResp,
		"defaultDownloads": defaults,
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
		URL     string `json:"url"`
		ID      string `json:"id"`
		SHA256  string `json:"sha256"`
		Name    string `json:"name"`
		Version string `json:"version"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}

	if req.ID == "" {
		writeAPIError(w, http.StatusBadRequest, "id is required")
		return
	}

	// Fix (code-review M7): the ID flows into a filepath.Join'd destPath;
	// reject anything with path separators or '..'.
	safeID, err := sanitizeDownloadIDComponent(req.ID)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "invalid id: "+err.Error())
		return
	}

	// If the caller didn't provide a URL, fall back to the Adoptium
	// Temurin build for the requested Java version. Version may be empty,
	// in which case the frontend should have pre-resolved a default — but
	// we still try the latest 17 download as a last resort.
	if req.URL == "" {
		version := req.Version
		if version == "" {
			version = "17"
		}
		url, err := emulator.DefaultJavaDownloadURL(version)
		if err != nil {
			writeAPIError(w, http.StatusBadRequest, err.Error())
			return
		}
		req.URL = url
		if req.Name == "" {
			req.Name = "Eclipse Temurin " + version
		}
	}

	// Fix (code-review M3): after the default-URL fallback, validate the
	// resolved URL the same way the caller-supplied one is validated.
	if err := validateDownloadURL(req.URL); err != nil {
		writeAPIError(w, http.StatusBadRequest, "invalid url: "+err.Error())
		return
	}

	// Build download item
	home, err := os.UserHomeDir()
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, "failed to get home directory")
		return
	}

	platform := runtime.GOOS + "-" + runtime.GOARCH
	downloadID := safeID + "-" + platform
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
		"url":      req.URL,
	})
}

// handleEmulatorJavaImport imports a Java runtime from a local .zip upload.
// Expects a multipart/form-data POST with two fields:
//   - `id`   : runtime id, used as the managed directory name
//   - `file` : the .zip archive
//
// We originally tried to share the same `application/octet-stream` raw
// body pattern as `/api/install-package`, but dio 5.9.2's Stream body
// transport reliably aborts mid-upload on Windows with WSAECONNABORTED
// (10053) before the body fully drains. Multipart has a deterministic
// Content-Length on both ends and dodges the issue.
func (s *Server) handleEmulatorJavaImport(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}

	if err := r.ParseMultipartForm(500 << 20); err != nil { // 500MB ceiling
		writeAPIError(w, http.StatusBadRequest, "failed to parse form: "+err.Error())
		return
	}

	runtimeID := r.FormValue("id")
	if err := emulator.SanitizeJavaRuntimeID(runtimeID); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "java file is required: "+err.Error())
		return
	}
	defer file.Close()

	tmpPath := filepath.Join(os.TempDir(), "java-import-"+uuid.New().String()+".zip")
	tmpFile, err := os.Create(tmpPath)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, "failed to create temp file: "+err.Error())
		return
	}
	if _, err := io.Copy(tmpFile, file); err != nil {
		_ = tmpFile.Close()
		_ = os.Remove(tmpPath)
		writeAPIError(w, http.StatusInternalServerError, "failed to save temp file: "+err.Error())
		return
	}
	if err := tmpFile.Close(); err != nil {
		_ = os.Remove(tmpPath)
		writeAPIError(w, http.StatusInternalServerError, "failed to finalize temp file: "+err.Error())
		return
	}
	defer os.Remove(tmpPath)

	javaPath, err := emulator.ImportJavaFromZip(tmpPath, runtimeID)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "failed to import java: "+err.Error())
		return
	}

	rt := emulator.ValidateJavaPath(javaPath)
	if rt == nil {
		_ = emulator.DeleteJavaRuntime(runtimeID)
		writeAPIError(w, http.StatusBadRequest, "imported file is not a usable Java runtime")
		return
	}

	writeJSON(w, map[string]interface{}{
		"success":      true,
		"id":           runtimeID,
		"path":         rt.Path,
		"version":      rt.Version,
		"vendor":       rt.Vendor,
		"originalName": header.Filename,
	})
}

// handleEmulatorJavaDelete removes a managed (downloaded / imported) Java
// runtime by id. Does not affect system Java or other runtimes found on PATH.
func (s *Server) handleEmulatorJavaDelete(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	defer r.Body.Close()

	var req struct {
		ID string `json:"id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	if err := emulator.SanitizeJavaRuntimeID(req.ID); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}

	if req.ID == "" {
		writeAPIError(w, http.StatusBadRequest, "id is required")
		return
	}

	if err := emulator.DeleteJavaRuntime(req.ID); err != nil {
		writeAPIError(w, http.StatusInternalServerError, "failed to delete runtime: "+err.Error())
		return
	}

	// If the deleted runtime was the active selection, clear it.
	if selected := emulator.LoadSelectedJavaPath(); selected != "" {
		rt := emulator.ValidateJavaPath(selected)
		if rt == nil || !strings.HasPrefix(rt.Path, emulator.JavaRuntimeDir()) {
			_ = emulator.SaveSelectedJavaPath("")
		}
	}

	writeJSON(w, map[string]interface{}{
		"success": true,
		"id":      req.ID,
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
			"id":         d.ID,
			"type":       d.Type,
			"name":       d.Name,
			"status":     d.Status,
			"progress":   d.Progress,
			"downloaded": d.Downloaded,
			"size":       d.Size,
		}
	}

	writeJSON(w, map[string]interface{}{
		"downloads": result,
	})
}

// handleEmulatorImageScan scans a given path for system images and registers
// the discovered ones (real paths) into the persisted registry. After this,
// listing no longer needs to re-scan — it just validates stored paths.
func (s *Server) handleEmulatorImageScan(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	defer r.Body.Close()

	var req struct {
		Path string `json:"path"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	// Fix (code-review M2): reject "/" / "C:\" / ".." before handing to Walk.
	scanPath, err := validateScanPath(req.Path)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "invalid path: "+err.Error())
		return
	}
	if _, err := os.Stat(scanPath); err != nil {
		writeAPIError(w, http.StatusBadRequest, "path not accessible: "+err.Error())
		return
	}

	imageMgr := emulator.NewImageManager(EmulatorEngine.AndroidHome)
	count, err := imageMgr.ScanAndRegister(scanPath)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, map[string]interface{}{
		"success": true,
		"found":   count,
	})
}

// handleEmulatorImageDelete removes a system image from disk and from the
// persisted registry. Required query params: id, ?confirm=true.
//
// ponytail: destructive but explicit. The image id came from the registry
// that we just showed the user; the confirm gate matches handleEmulatorSDKDelete
// (B2) and handleEmulatorInstanceDelete (B3) — accidental curl or stray UI
// click can't wipe a multi-GB image dir. Refuses to delete an image still
// referenced by any AVD instance — that would break the instance's
// image.sysdir.1 path. Returns 409 with the instance names in that case.
func (s *Server) handleEmulatorImageDelete(w http.ResponseWriter, r *http.Request) {
	if r.Method != "DELETE" {
		writeAPIError(w, http.StatusMethodNotAllowed, "DELETE required")
		return
	}

	if r.URL.Query().Get("confirm") != "true" {
		writeAPIError(w, http.StatusBadRequest,
			"pass ?confirm=true to acknowledge this destructive image deletion")
		return
	}

	id := r.URL.Query().Get("id")
	if id == "" {
		writeAPIError(w, http.StatusBadRequest, "id is required")
		return
	}

	removed, err := emulator.DeleteRegisteredImage(id, func(imageID string) []string {
		if s.instanceManager == nil {
			return nil
		}
		var users []string
		for _, inst := range s.instanceManager.List() {
			if inst.ImageID == imageID {
				users = append(users, inst.Name)
			}
		}
		return users
	})
	if err != nil {
		var inUseErr *emulator.ImageInUseError
		if errors.As(err, &inUseErr) {
			writeAPIErrorData(w, http.StatusConflict, inUseErr.Error(), map[string]interface{}{
				"inUseBy": inUseErr.UsedBy,
			})
			return
		}
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, map[string]interface{}{
		"success":    true,
		"id":         removed.ID,
		"path":       removed.Path,
		"managed":    removed.Managed,
		"deleteMode": string(removed.DeleteMode),
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
	log.Printf("[image] GET /api/emulator/images: AndroidHome=%q", EmulatorEngine.AndroidHome)
	images := imageMgr.ListImages()
	log.Printf("[image] GET /api/emulator/images: returning %d image(s)", len(images))

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
			"managed":        emulator.IsManagedImagePath(img.LocalPath),
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
		URL      string `json:"url"`
		ID       string `json:"id"`
		Name     string `json:"name"`
		SHA256   string `json:"sha256"`
		APILevel int    `json:"apiLevel"`
		Arch     string `json:"arch"`
		Variant  string `json:"variant"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}

	if req.URL == "" {
		writeAPIError(w, http.StatusBadRequest, "url is required")
		return
	}

	// Fix (code-review M3 + M7): validate URL + sanitize every component
	// that flows into downloadID. A malicious "id" or "variant" containing
	// "../etc" would have escaped the managed download root before this.
	if err := validateDownloadURL(req.URL); err != nil {
		writeAPIError(w, http.StatusBadRequest, "invalid url: "+err.Error())
		return
	}
	safeID, err := sanitizeDownloadIDComponent(req.ID)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "invalid id: "+err.Error())
		return
	}
	safeArch, err := sanitizeDownloadIDComponent(req.Arch)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "invalid arch: "+err.Error())
		return
	}
	safeVariant, err := sanitizeDownloadIDComponent(req.Variant)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "invalid variant: "+err.Error())
		return
	}

	home, err := os.UserHomeDir()
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, "failed to get home directory")
		return
	}

	// Build download ID
	downloadID := fmt.Sprintf("image-%s-%s-%s", safeID, safeArch, safeVariant)
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

	// Remember this URL in the persisted address book (dedup by URL).
	_, _ = emulator.AddImageSource(emulator.ImageSource{
		URL:      req.URL,
		Name:     req.Name,
		APILevel: req.APILevel,
		Arch:     req.Arch,
		Variant:  req.Variant,
		SHA256:   req.SHA256,
	})

	writeJSON(w, map[string]interface{}{
		"id":       download.ID,
		"status":   download.Status,
		"progress": download.Progress,
	})
}

// handleEmulatorImageSources returns the persisted image source address book.
func (s *Server) handleEmulatorImageSources(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		writeAPIError(w, http.StatusMethodNotAllowed, "GET required")
		return
	}
	writeJSON(w, map[string]interface{}{
		"sources": emulator.LoadImageSources(),
	})
}

// handleEmulatorImageSourceAdd appends a new image source URL (dedup by URL).
func (s *Server) handleEmulatorImageSourceAdd(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	defer r.Body.Close()

	var req struct {
		URL      string `json:"url"`
		Name     string `json:"name"`
		APILevel int    `json:"apiLevel"`
		Arch     string `json:"arch"`
		Variant  string `json:"variant"`
		SHA256   string `json:"sha256"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}

	sources, err := emulator.AddImageSource(emulator.ImageSource{
		URL:      req.URL,
		Name:     req.Name,
		APILevel: req.APILevel,
		Arch:     req.Arch,
		Variant:  req.Variant,
		SHA256:   req.SHA256,
	})
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}

	writeJSON(w, map[string]interface{}{
		"success": true,
		"sources": sources,
	})
}

// handleEmulatorImageSourceRemove removes an image source URL.
func (s *Server) handleEmulatorImageSourceRemove(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	defer r.Body.Close()

	var req struct {
		URL string `json:"url"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	if req.URL == "" {
		writeAPIError(w, http.StatusBadRequest, "url is required")
		return
	}

	sources, err := emulator.RemoveImageSource(req.URL)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, map[string]interface{}{
		"success": true,
		"sources": sources,
	})
}

// handleEmulatorImageImportZip imports a system image uploaded as a zip file.
func (s *Server) handleEmulatorImageImportZip(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}

	if err := r.ParseMultipartForm(2 << 30); err != nil { // 2GB ceiling
		writeAPIError(w, http.StatusBadRequest, "failed to parse form: "+err.Error())
		return
	}

	file, _, err := r.FormFile("image")
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "image file is required: "+err.Error())
		return
	}
	defer file.Close()

	tmpPath := filepath.Join(os.TempDir(), "image-import-"+uuid.New().String()+".zip")
	tmpFile, err := os.Create(tmpPath)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, "failed to create temp file: "+err.Error())
		return
	}

	if _, err := io.Copy(tmpFile, file); err != nil {
		_ = tmpFile.Close()
		_ = os.Remove(tmpPath)
		writeAPIError(w, http.StatusInternalServerError, "failed to save temp file: "+err.Error())
		return
	}
	_ = tmpFile.Close()
	defer os.Remove(tmpPath)

	imageMgr := emulator.NewImageManager(EmulatorEngine.AndroidHome)
	images, err := imageMgr.ImportImageFromZip(tmpPath)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "failed to import zip: "+err.Error())
		return
	}

	result := make([]map[string]interface{}, 0, len(images))
	for _, img := range images {
		result = append(result, map[string]interface{}{
			"id":             img.ID,
			"name":           img.Name,
			"apiLevel":       img.APILevel,
			"androidVersion": img.AndroidVersion,
			"arch":           img.Arch,
			"variant":        img.Variant,
			"localPath":      img.LocalPath,
			"fileSize":       img.FileSize,
			"status":         img.Status,
		})
	}

	writeJSON(w, map[string]interface{}{
		"success": true,
		"count":   len(result),
		"images":  result,
		"image":   firstImageOrNil(result),
	})
}

// handleEmulatorImageImportPath imports a system image from a server-side
// local path. Accepts either a directory containing an extracted image or a
// .zip archive. The Go side scans the path, registers every image it finds
// in the persisted registry, and returns the freshly registered entries.
func (s *Server) handleEmulatorImageImportPath(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	defer r.Body.Close()

	var req struct {
		Path string `json:"path"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}

	// Fix (code-review M2): reject "/" / "C:\" / ".." before invoking the
	// walker. Without this, a user passing "/" pins the goroutine for
	// minutes walking every file on disk.
	scanPath, err := validateScanPath(req.Path)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "invalid path: "+err.Error())
		return
	}

	info, err := os.Stat(scanPath)
	if err != nil {
		writeAPIError(w, http.StatusBadRequest, "path not accessible: "+err.Error())
		return
	}

	imageMgr := emulator.NewImageManager(EmulatorEngine.AndroidHome)

	var images []*emulator.SystemImage
	if info.IsDir() {
		log.Printf("[image] import-path: directory import path=%s", scanPath)
		images, err = imageMgr.ImportImageFromDirectory(scanPath)
	} else {
		if !strings.HasSuffix(strings.ToLower(scanPath), ".zip") {
			writeAPIError(w, http.StatusBadRequest, "file is not a .zip archive")
			return
		}
		log.Printf("[image] import-path: zip import path=%s", scanPath)
		images, err = imageMgr.ImportImageFromZip(scanPath)
	}
	if err != nil {
		log.Printf("[image] import-path: failed: %v", err)
		writeAPIError(w, http.StatusBadRequest, "failed to import: "+err.Error())
		return
	}

	result := make([]map[string]interface{}, 0, len(images))
	for _, img := range images {
		log.Printf("[image] import-path:   registered id=%s path=%s", img.ID, img.LocalPath)
		result = append(result, map[string]interface{}{
			"id":             img.ID,
			"name":           img.Name,
			"apiLevel":       img.APILevel,
			"androidVersion": img.AndroidVersion,
			"arch":           img.Arch,
			"variant":        img.Variant,
			"localPath":      img.LocalPath,
			"fileSize":       img.FileSize,
			"status":         img.Status,
		})
	}

	writeJSON(w, map[string]interface{}{
		"success": true,
		"count":   len(result),
		"images":  result,
		// Legacy single-image field so older clients reading .image still
		// see something useful.
		"image": firstImageOrNil(result),
	})
}

// firstImageOrNil returns the first image in the list, or nil if the list
// is empty. Marshals to JSON null when the list is empty, which is the
// shape legacy callers expect.
func firstImageOrNil(images []map[string]interface{}) interface{} {
	if len(images) == 0 {
		return nil
	}
	return images[0]
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
		result[i] = emulatorInstanceToMap(inst)
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

	writeJSON(w, emulatorInstanceToMap(instance))
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

	// Broadcast status update (carries the initial boot-progress snapshot
	// so the UI has data to render before the first tracker tick lands).
	if s.statusMonitor != nil {
		s.statusMonitor.BroadcastStatus(instance.ID, instance.Status, instance.BootStage, instance.BootProgress, instance.BootMessage)
	}

	writeJSON(w, emulatorInstanceToMap(instance))
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

	if _, err := s.instanceManager.Get(id); err != nil {
		writeAPIError(w, http.StatusNotFound, err.Error())
		return
	}

	if err := s.instanceManager.Stop(id); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}

	// Re-read after Stop so the response reflects the post-stop state
	// (StatusStopped, PID=0, boot fields cleared) instead of the
	// pre-stop snapshot.
	instance, err := s.instanceManager.Get(id)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}

	// Broadcast status update (boot fields are cleared on Stop)
	if s.statusMonitor != nil {
		s.statusMonitor.BroadcastStatus(instance.ID, emulator.StatusStopped, "", 0, "")
	}

	writeJSON(w, emulatorInstanceToMap(instance))
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

	// Fix (code-review B3): destructive — recursively wipes the AVD dir
	// and releases the instance's allocated ports. Require ?confirm=true
	// to match the SDK delete guard (handleEmulatorSDKDelete).
	if r.URL.Query().Get("confirm") != "true" {
		writeAPIError(w, http.StatusBadRequest,
			"pass ?confirm=true to acknowledge this destructive AVD deletion")
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

// handleEmulatorInstanceLog returns the last N lines of the per-AVD
// emulator.log so the UI can show it without re-implementing file IO.
//
// Query params:
//   - id:    instance id (required)
//   - tail:  number of lines from the end (default 80, max 500)
//
// Returns {"logPath": "...", "tail": <N>, "lines": [...]} on success.
// 200 even when the log file is missing (with empty `lines`) so the UI
// can render a friendly "no log yet" placeholder instead of an error.
func (s *Server) handleEmulatorInstanceLog(w http.ResponseWriter, r *http.Request) {
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

	// Parse tail param. Default 80, clamp 1..500 so a misbehaving client
	// can't ask for megabytes of log in one request.
	tail := 80
	if raw := r.URL.Query().Get("tail"); raw != "" {
		if n, err := strconv.Atoi(raw); err == nil && n > 0 {
			tail = n
		}
	}
	if tail > 500 {
		tail = 500
	}

	logPath := instance.LogPath
	var lines []string
	if logPath != "" {
		if data, err := os.ReadFile(logPath); err == nil {
			// Reuse ReadLogTail's "drop trailing blanks" behavior so
			// the on-screen view doesn't end with a wall of empty
			// lines when the emulator process just exited.
			all := strings.Split(strings.TrimRight(string(data), "\n"), "\n")
			if len(all) > tail {
				all = all[len(all)-tail:]
			}
			for len(all) > 0 && strings.TrimSpace(all[len(all)-1]) == "" {
				all = all[:len(all)-1]
			}
			lines = all
		}
	}

	writeJSON(w, map[string]interface{}{
		"id":      instance.ID,
		"logPath": logPath,
		"tail":    tail,
		"lines":   lines,
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

	writeJSON(w, emulatorInstanceToMap(instance))
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

	// Fix (code-review B5): half-open sockets (laptop sleep / network drop
	// / NAT timeout) used to leak a goroutine forever because the read
	// loop never timed out and never saw the client die. Add a read
	// deadline refreshed by the PongHandler, and a periodic Ping from a
	// dedicated goroutine. Also serialize writes — gorilla/websocket
	// forbids concurrent WriteJSON on the same conn, and our previous
	// initial-snapshot loop + later broadcast both wrote without a lock.
	const (
		wsWriteDeadline = 10 * time.Second
		wsReadDeadline  = 60 * time.Second
		wsPingInterval  = 25 * time.Second
	)
	_ = conn.SetReadDeadline(time.Now().Add(wsReadDeadline))
	conn.SetPongHandler(func(string) error {
		return conn.SetReadDeadline(time.Now().Add(wsReadDeadline))
	})

	// Per-conn write mutex; broadcasts grab it before each write.
	var writeMu sync.Mutex
	safeWriteJSON := func(v interface{}) error {
		writeMu.Lock()
		defer writeMu.Unlock()
		_ = conn.SetWriteDeadline(time.Now().Add(wsWriteDeadline))
		return conn.WriteJSON(v)
	}

	// Ping ticker — keeps the connection warm and detects half-close
	// within one tick.
	stopPing := make(chan struct{})
	go func() {
		ticker := time.NewTicker(wsPingInterval)
		defer ticker.Stop()
		for {
			select {
			case <-stopPing:
				return
			case <-ticker.C:
				writeMu.Lock()
				_ = conn.SetWriteDeadline(time.Now().Add(wsWriteDeadline))
				err := conn.WriteMessage(websocket.PingMessage, nil)
				writeMu.Unlock()
				if err != nil {
					// Best effort: closing the conn will unblock the read loop.
					_ = conn.Close()
					return
				}
			}
		}
	}()
	defer close(stopPing)

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
				_ = safeWriteJSON(update)
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
			writeMu.Lock()
			_ = conn.SetWriteDeadline(time.Now().Add(wsWriteDeadline))
			err := conn.WriteMessage(websocket.PongMessage, nil)
			writeMu.Unlock()
			if err != nil {
				break
			}
		}
	}
}

// handleEmulatorSDKInstall starts an sdkmanager-driven install of one or more
// SDK packages (e.g. "emulator", "platform-tools",
// "system-images;android-33;google_apis_playstore;arm64-v8a"). The actual
// sdkmanager process runs asynchronously — poll /install/status?id=<id>
// for progress. Licenses must be accepted separately before this call.
func (s *Server) handleEmulatorSDKInstall(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	defer r.Body.Close()

	var req struct {
		Packages []string `json:"packages"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	if len(req.Packages) == 0 {
		writeAPIError(w, http.StatusBadRequest, "packages is required (e.g. [\"emulator\"])")
		return
	}

	sdkmanagerPath := EmulatorEngine.SdkmanagerPath
	sdkPath := EmulatorEngine.AndroidHome
	javaPath := EmulatorEngine.JavaPath
	if sdkmanagerPath == "" || sdkPath == "" {
		writeAPIError(w, http.StatusBadRequest,
			"SDK not selected or sdkmanager not available — pick an SDK first")
		return
	}

	mirrorURL := emulator.LoadMirrorConfig()
	job, err := SDKInstaller.Start(sdkmanagerPath, sdkPath, javaPath, req.Packages, mirrorURL)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, job)
}

// handleEmulatorSDKInstallStatus returns the current state of a previously
// started install job.
func (s *Server) handleEmulatorSDKInstallStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		writeAPIError(w, http.StatusMethodNotAllowed, "GET required")
		return
	}
	id := r.URL.Query().Get("id")
	if id == "" {
		writeAPIError(w, http.StatusBadRequest, "id is required")
		return
	}
	job := SDKInstaller.Get(id)
	if job == nil {
		writeAPIError(w, http.StatusNotFound, "install job not found")
		return
	}
	writeJSON(w, job)
}

// handleEmulatorMirror handles GET (read) and PUT (update) for SDK mirror config.
func (s *Server) handleEmulatorMirror(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		mirrorURL := emulator.LoadMirrorConfig()
		writeJSON(w, map[string]string{"mirrorURL": mirrorURL})
	case "PUT":
		defer r.Body.Close()
		var req struct {
			MirrorURL string `json:"mirrorURL"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeAPIError(w, http.StatusBadRequest, err.Error())
			return
		}
		// Empty URL is allowed (clears the mirror). Non-empty must parse and
		// resolve to a concrete http/https host so we don't silently accept
		// garbage that sdkmanager would later ignore.
		if req.MirrorURL != "" {
			parsed, err := url.Parse(req.MirrorURL)
			if err != nil {
				writeAPIError(w, http.StatusBadRequest, fmt.Sprintf("invalid mirror URL: %v", err))
				return
			}
			if parsed.Scheme != "http" && parsed.Scheme != "https" {
				writeAPIError(w, http.StatusBadRequest, "mirror URL must use http or https")
				return
			}
			if parsed.Host == "" {
				writeAPIError(w, http.StatusBadRequest, "mirror URL must include a host")
				return
			}
		}
		if err := emulator.SaveMirrorConfig(req.MirrorURL); err != nil {
			writeAPIError(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, map[string]string{"mirrorURL": req.MirrorURL})
	default:
		writeAPIError(w, http.StatusMethodNotAllowed, "GET or PUT required")
	}
}
