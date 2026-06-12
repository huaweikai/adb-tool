package server

import (
	"encoding/json"
	"io"
	"io/fs"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

type Server struct {
	adb      *AdbManager
	webFS    fs.FS
	upgrader websocket.Upgrader

	recordMu        sync.Mutex
	recordingSerial string
	recordStarted   time.Time

	startedAt time.Time
}

func New(adbPath string, webFS fs.FS) *Server {
	return &Server{
		adb:   NewAdbManager(adbPath),
		webFS: webFS,
		startedAt: time.Now(),
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool { return true },
		},
	}
}

func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("/api/devices", s.handleDevices)
	mux.HandleFunc("/api/clear", s.handleClear)
	mux.HandleFunc("/api/info", s.handleDeviceInfo)
	mux.HandleFunc("/api/package-pid", s.handlePackagePID)
	mux.HandleFunc("/api/running-packages", s.handleRunningPackages)
	mux.HandleFunc("/ws/logs", s.handleLogStream)
	mux.HandleFunc("/api/adb-path", s.handleAdbPath)

	// New APIs
	mux.HandleFunc("/api/files", s.handleFiles)
	mux.HandleFunc("/api/file-content", s.handleFileContent)
	mux.HandleFunc("/api/packages", s.handlePackages)
	mux.HandleFunc("/api/device-detail", s.handleDeviceDetail)
	mux.HandleFunc("/api/screenshot", s.handleScreenshot)
	mux.HandleFunc("/api/uninstall-package", s.handleUninstallPackage)
	mux.HandleFunc("/api/backend-logs", s.handleBackendLogs)
	mux.HandleFunc("/api/pull-file", s.handlePullFile)
	mux.HandleFunc("/api/push-file", s.handlePushFile)
	mux.HandleFunc("/api/screen-record", s.handleScreenRecord)
	mux.HandleFunc("/api/screen-record-video", s.handleScreenRecordVideo)
	mux.HandleFunc("/api/identify", s.handleIdentify)
	mux.HandleFunc("/api/shutdown", s.handleShutdown)

	webFS, err := fs.Sub(s.webFS, "web")
	if err != nil {
		panic("web directory not found in embedded FS: " + err.Error())
	}
	mux.Handle("/", http.FileServer(http.FS(webFS)))

	return mux
}

func (s *Server) handleDevices(w http.ResponseWriter, r *http.Request) {
	devices, err := s.adb.Devices()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if devices == nil {
		devices = []Device{}
	}
	writeJSON(w, devices)
}

func (s *Server) handleClear(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		http.Error(w, "serial required", http.StatusBadRequest)
		return
	}
	if err := s.adb.ClearLogcat(serial); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

func (s *Server) handleDeviceInfo(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		http.Error(w, "serial required", http.StatusBadRequest)
		return
	}
	output, err := s.adb.Shell(serial, "getprop")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]string{"props": output})
}

func (s *Server) handlePackagePID(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	packageName := r.URL.Query().Get("package")
	if serial == "" || packageName == "" {
		http.Error(w, "serial and package required", http.StatusBadRequest)
		return
	}
	pid, err := s.adb.GetPackagePID(serial, packageName)
	if err != nil {
		writeJSON(w, map[string]string{"error": err.Error(), "pid": ""})
		return
	}
	writeJSON(w, map[string]string{"pid": pid})
}

func (s *Server) handleRunningPackages(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		http.Error(w, "serial required", http.StatusBadRequest)
		return
	}
	pkgs, err := s.adb.GetRunningPackages(serial)
	if err != nil {
		writeJSON(w, map[string]interface{}{"error": err.Error(), "packages": []string{}})
		return
	}
	if pkgs == nil {
		pkgs = []string{}
	}
	writeJSON(w, map[string]interface{}{"packages": pkgs})
}

func (s *Server) handleAdbPath(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]string{"path": s.adb.AdbPath()})
}

func (s *Server) handleLogStream(w http.ResponseWriter, r *http.Request) {
	conn, err := s.upgrader.Upgrade(w, r, nil)
	if err != nil {
		http.Error(w, "websocket upgrade failed", http.StatusBadRequest)
		return
	}

	session := NewLogSession(conn, s.adb)
	session.Run()
}

func (s *Server) handleFiles(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	path := r.URL.Query().Get("path")
	if serial == "" || path == "" {
		http.Error(w, `{"error":"serial and path required"}`, http.StatusBadRequest)
		return
	}
	entries, err := s.adb.ListFiles(serial, path)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}
	if entries == nil {
		entries = []FileEntry{}
	}
	writeJSON(w, map[string]interface{}{"files": entries})
}

func (s *Server) handleFileContent(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	path := r.URL.Query().Get("path")
	if serial == "" || path == "" {
		http.Error(w, "serial and path required", http.StatusBadRequest)
		return
	}
	content, err := s.adb.ReadFile(serial, path)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]string{"content": content})
}

func (s *Server) handlePackages(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		http.Error(w, "serial required", http.StatusBadRequest)
		return
	}
	pkgs, err := s.adb.InstalledPackages(serial)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if pkgs == nil {
		pkgs = []PackageInfo{}
	}
	writeJSON(w, map[string]interface{}{"packages": pkgs})
}

func (s *Server) handleDeviceDetail(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		http.Error(w, "serial required", http.StatusBadRequest)
		return
	}
	props, err := s.adb.DeviceDetail(serial)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if props == nil {
		props = map[string]string{}
	}
	writeJSON(w, map[string]interface{}{"props": props})
}

func (s *Server) handleScreenshot(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		http.Error(w, "serial required", http.StatusBadRequest)
		return
	}
	data, err := s.adb.Screenshot(serial)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "image/png")
	w.Write(data)
}

func (s *Server) handleUninstallPackage(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}
	serial := r.URL.Query().Get("serial")
	packageName := r.URL.Query().Get("package")
	if serial == "" || packageName == "" {
		http.Error(w, "serial and package required", http.StatusBadRequest)
		return
	}
	if err := s.adb.UninstallPackage(serial, packageName); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

func (s *Server) handleBackendLogs(w http.ResponseWriter, r *http.Request) {
	entries := Log.Snapshot()
	if entries == nil {
		entries = []LogEntry{}
	}
	writeJSON(w, map[string]interface{}{"logs": entries})
}

func (s *Server) handlePullFile(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	path := r.URL.Query().Get("path")
	if serial == "" || path == "" {
		http.Error(w, "serial and path required", http.StatusBadRequest)
		return
	}
	data, err := s.adb.PullFile(serial, path)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Disposition", "attachment; filename=\""+filepath.Base(path)+"\"")
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Write(data)
}

func (s *Server) handlePushFile(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}
	serial := r.URL.Query().Get("serial")
	path := r.URL.Query().Get("path")
	if serial == "" || path == "" {
		http.Error(w, "serial and path required", http.StatusBadRequest)
		return
	}
	defer r.Body.Close()
	data, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if err := s.adb.PushFile(serial, data, path); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

func (s *Server) handleScreenRecordVideo(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		http.Error(w, "serial required", http.StatusBadRequest)
		return
	}
	data, err := s.adb.PullRecordedVideo(serial)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	go s.adb.CleanRecordedVideo(serial)
	w.Header().Set("Content-Type", "video/mp4")
	w.Header().Set("Content-Disposition", "attachment; filename=\"screen-record.mp4\"")
	w.Write(data)
}

func (s *Server) handleScreenRecord(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	action := r.URL.Query().Get("action")

	switch action {
	case "start":
		if serial == "" {
			http.Error(w, "serial required", http.StatusBadRequest)
			return
		}
		s.recordMu.Lock()
		defer s.recordMu.Unlock()
		if s.recordingSerial != "" {
			writeJSON(w, map[string]interface{}{"error": "already recording on " + s.recordingSerial})
			return
		}
		if err := s.adb.StartScreenRecord(serial); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		s.recordingSerial = serial
		s.recordStarted = time.Now()
		writeJSON(w, map[string]interface{}{"status": "recording", "serial": serial})

	case "stop":
		s.recordMu.Lock()
		if s.recordingSerial == "" {
			s.recordMu.Unlock()
			writeJSON(w, map[string]interface{}{"error": "not recording"})
			return
		}
		if err := s.adb.StopScreenRecord(s.recordingSerial); err != nil {
			s.recordMu.Unlock()
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		s.recordingSerial = ""
		started := s.recordStarted
		s.recordMu.Unlock()

		elapsed := time.Since(started).Seconds()
		writeJSON(w, map[string]interface{}{
			"status":  "stopped",
			"elapsed": elapsed,
		})

	case "status":
		s.recordMu.Lock()
		if s.recordingSerial == "" {
			s.recordMu.Unlock()
			writeJSON(w, map[string]interface{}{"recording": false})
			return
		}
		serial := s.recordingSerial
		elapsed := time.Since(s.recordStarted).Seconds()
		s.recordMu.Unlock()
		writeJSON(w, map[string]interface{}{
			"recording": true,
			"serial":    serial,
			"elapsed":   elapsed,
		})

	default:
		writeJSON(w, map[string]string{"error": "action must be start, stop, or status"})
	}
}

func (s *Server) handleIdentify(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]interface{}{
		"name":    "adb-tool",
		"pid":     os.Getpid(),
		"started": s.startedAt.Format(time.RFC3339),
	})
}

func (s *Server) handleShutdown(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}

	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		http.Error(w, "bad remote addr", http.StatusForbidden)
		return
	}
	ip := net.ParseIP(host)
	if ip == nil || !ip.IsLoopback() {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}

	writeJSON(w, map[string]string{"status": "shutting down"})
	go func() {
		time.Sleep(150 * time.Millisecond)
		os.Exit(0)
	}()
}

func writeJSON(w http.ResponseWriter, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(v)
}
