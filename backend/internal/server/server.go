package server

import (
	"encoding/json"
	"io"
	"io/fs"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

type Server struct {
	adb      *AdbManager
	webFS    fs.FS
	upgrader websocket.Upgrader

	clipboardApk []byte

	recordMu        sync.Mutex
	recordingSerial string
	recordStarted   time.Time

	startedAt  time.Time
	onShutdown func()
	closeOnce  sync.Once
}

func New(adbPath string, webFS fs.FS, clipboardApk []byte) *Server {
	return &Server{
		adb:          NewAdbManager(adbPath),
		webFS:        webFS,
		clipboardApk: clipboardApk,
		startedAt:    time.Now(),
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool { return true },
		},
	}
}

func (s *Server) SetShutdownFunc(fn func()) {
	s.onShutdown = fn
}

func (s *Server) Close() {
	s.closeOnce.Do(func() {
		s.recordMu.Lock()
		s.recordingSerial = ""
		s.recordMu.Unlock()
		s.adb.Close()
	})
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
	mux.HandleFunc("/api/install-package", s.handleInstallPackage)
	mux.HandleFunc("/api/backend-logs", s.handleBackendLogs)
	mux.HandleFunc("/api/pull-file", s.handlePullFile)
	mux.HandleFunc("/api/push-file", s.handlePushFile)
	mux.HandleFunc("/api/screen-record", s.handleScreenRecord)
	mux.HandleFunc("/api/screen-record-video", s.handleScreenRecordVideo)
	mux.HandleFunc("/api/identify", s.handleIdentify)
	mux.HandleFunc("/api/shutdown", s.handleShutdown)
	mux.HandleFunc("/api/clipboard-check", s.handleClipboardCheck)
	mux.HandleFunc("/api/clipboard-install", s.handleClipboardInstall)
	mux.HandleFunc("/api/clipboard-send", s.handleClipboardSend)
	mux.HandleFunc("/api/clipboard-uninstall", s.handleClipboardUninstall)
	mux.HandleFunc("/api/adb-exec", s.handleAdbExec)
	mux.HandleFunc("/api/adb-wireless-pair", s.handleAdbWirelessPair)
	mux.HandleFunc("/api/adb-wireless-connect", s.handleAdbWirelessConnect)

	webFS, err := fs.Sub(s.webFS, "web")
	if err != nil {
		mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
			http.Error(w, "web assets unavailable: "+err.Error(), http.StatusInternalServerError)
		})
	} else {
		mux.Handle("/", http.FileServer(http.FS(webFS)))
	}

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
	if _, err := w.Write(data); err != nil {
		Log.Add("http screenshot response", "", err, 0)
	}
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

func (s *Server) handleInstallPackage(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		http.Error(w, "serial required", http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	tmpFile, err := os.CreateTemp("", "adb-tool-install-*.apk")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer os.Remove(tmpFile.Name())

	if _, err := io.Copy(tmpFile, r.Body); err != nil {
		if closeErr := tmpFile.Close(); closeErr != nil {
			Log.Add("install temp close", "", closeErr, 0)
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if err := tmpFile.Close(); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	output, err := s.adb.InstallPackageContext(r.Context(), serial, tmpFile.Name())
	if err != nil {
		if r.Context().Err() != nil {
			w.WriteHeader(499)
			writeJSON(w, map[string]string{"error": "操作已取消"})
			return
		}
		w.WriteHeader(http.StatusBadRequest)
		msg := parseInstallError(output)
		writeJSON(w, map[string]string{"error": msg, "raw": output})
		return
	}
	writeJSON(w, map[string]string{"status": "ok", "output": output})
}

func parseInstallError(output string) string {
	output = strings.TrimSpace(output)
	switch {
	case strings.Contains(output, "INSTALL_FAILED_VERSION_DOWNGRADE"):
		return "版本低于已安装版本，请先卸载原应用后再安装"
	case strings.Contains(output, "INSTALL_FAILED_ALREADY_EXISTS"):
		return "应用已存在，请先卸载后再安装"
	case strings.Contains(output, "INSTALL_FAILED_UPDATE_INCOMPATIBLE"):
		return "签名不一致，请先卸载原应用后再安装"
	case strings.Contains(output, "INSTALL_FAILED_INSUFFICIENT_STORAGE"):
		return "存储空间不足"
	case strings.Contains(output, "INSTALL_FAILED_INVALID_APK"):
		return "APK 文件无效或已损坏"
	case strings.Contains(output, "INSTALL_PARSE_FAILED"):
		return "APK 解析失败，文件可能已损坏"
	default:
		if output != "" {
			return "安装失败: " + output
		}
		return "安装失败"
	}
}

func (s *Server) handleBackendLogs(w http.ResponseWriter, r *http.Request) {
	entries := Log.Snapshot()
	if entries == nil {
		entries = []LogEntry{}
	}
	writeJSON(w, map[string]interface{}{"logs": entries})
}

func (s *Server) handleAdbExec(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		http.Error(w, "serial required", http.StatusBadRequest)
		return
	}
	defer r.Body.Close()
	var req struct {
		Args []string `json:"args"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	if len(req.Args) == 0 {
		http.Error(w, "args required", http.StatusBadRequest)
		return
	}
	for _, arg := range req.Args {
		if strings.TrimSpace(arg) == "" {
			http.Error(w, "empty argument not allowed", http.StatusBadRequest)
			return
		}
	}
	output, err := s.adb.Execute(serial, req.Args)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		writeJSON(w, map[string]interface{}{"ok": false, "output": output, "error": err.Error()})
		return
	}
	writeJSON(w, map[string]interface{}{"ok": true, "output": output})
}

func (s *Server) handleAdbWirelessPair(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}
	defer r.Body.Close()
	var req struct {
		Address string `json:"address"`
		Code    string `json:"code"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	req.Address = strings.TrimSpace(req.Address)
	req.Code = strings.TrimSpace(req.Code)
	if req.Address == "" || req.Code == "" {
		http.Error(w, "address and code required", http.StatusBadRequest)
		return
	}
	output, err := s.adb.WirelessPair(req.Address, req.Code)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		writeJSON(w, map[string]interface{}{"ok": false, "output": output, "error": err.Error()})
		return
	}
	writeJSON(w, map[string]interface{}{"ok": true, "output": output})
}

func (s *Server) handleAdbWirelessConnect(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}
	defer r.Body.Close()
	var req struct {
		Address string `json:"address"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	req.Address = strings.TrimSpace(req.Address)
	if req.Address == "" {
		http.Error(w, "address required", http.StatusBadRequest)
		return
	}
	output, err := s.adb.WirelessConnect(req.Address)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		writeJSON(w, map[string]interface{}{"ok": false, "output": output, "error": err.Error()})
		return
	}
	writeJSON(w, map[string]interface{}{"ok": true, "output": output})
}

func (s *Server) handlePullFile(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	path := r.URL.Query().Get("path")
	if serial == "" || path == "" {
		http.Error(w, "serial and path required", http.StatusBadRequest)
		return
	}
	tmpFile := filepath.Join(os.TempDir(), "adb-tool-pull-"+time.Now().Format("20060102150405.000000000"))
	defer os.Remove(tmpFile)
	if err := s.adb.PullFileToPathContext(r.Context(), serial, path, tmpFile); err != nil {
		if r.Context().Err() != nil {
			http.Error(w, "操作已取消", 499)
			return
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Disposition", "attachment; filename=\""+filepath.Base(path)+"\"")
	w.Header().Set("Content-Type", "application/octet-stream")
	http.ServeFile(w, r, tmpFile)
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
	tmpFile := filepath.Join(os.TempDir(), "adb-tool-push-"+time.Now().Format("20060102150405.000000000"))
	defer os.Remove(tmpFile)
	out, err := os.Create(tmpFile)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if _, err := io.Copy(out, r.Body); err != nil {
		if closeErr := out.Close(); closeErr != nil {
			Log.Add("push temp close", "", closeErr, 0)
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if err := out.Close(); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if err := s.adb.PushFileFromPathContext(r.Context(), serial, tmpFile, path); err != nil {
		if r.Context().Err() != nil {
			http.Error(w, "操作已取消", 499)
			return
		}
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
	if _, err := w.Write(data); err != nil {
		Log.Add("http screen-record response", "", err, 0)
	}
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
		if s.onShutdown != nil {
			s.onShutdown()
			return
		}
		s.Close()
	}()
}

func writeJSON(w http.ResponseWriter, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(v); err != nil {
		Log.Add("http json response", "", err, 0)
	}
}

func (s *Server) handleClipboardCheck(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		http.Error(w, "serial required", http.StatusBadRequest)
		return
	}
	installed := s.adb.IsClipboardHelperInstalled(serial)
	writeJSON(w, map[string]interface{}{"installed": installed})
}

func (s *Server) handleClipboardInstall(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		http.Error(w, "serial required", http.StatusBadRequest)
		return
	}
	if err := s.adb.InstallClipboardHelper(serial, s.clipboardApk); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

func (s *Server) handleClipboardSend(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}
	serial := r.URL.Query().Get("serial")
	text := r.URL.Query().Get("text")
	if serial == "" || text == "" {
		http.Error(w, "serial and text required", http.StatusBadRequest)
		return
	}
	if err := s.adb.SendClipboard(serial, text); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

func (s *Server) handleClipboardUninstall(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		http.Error(w, "serial required", http.StatusBadRequest)
		return
	}
	if err := s.adb.UninstallClipboardHelper(serial); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}
