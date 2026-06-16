package server

import (
	"context"
	"encoding/json"
	"io"
	"io/fs"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
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

	sessionLogcat *SessionLogcat

	startedAt  time.Time
	onShutdown func()
	closeOnce  sync.Once
}

func New(adbPath string, webFS fs.FS, clipboardApk []byte) *Server {
	adb := NewAdbManager(adbPath)
	adb.DiagnoseStartup()
	return &Server{
		adb:           adb,
		webFS:         webFS,
		clipboardApk:  clipboardApk,
		sessionLogcat: &SessionLogcat{},
		startedAt:     time.Now(),
		upgrader: websocket.Upgrader{
			CheckOrigin: isAllowedWebSocketOrigin,
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
	mux.HandleFunc("/api/device-status", s.handleDeviceStatus)
	mux.HandleFunc("/api/screenshot", s.handleScreenshot)
	mux.HandleFunc("/api/uninstall-package", s.handleUninstallPackage)
	mux.HandleFunc("/api/install-package", s.handleInstallPackage)
	mux.HandleFunc("/api/backend-logs", s.handleBackendLogs)
	mux.HandleFunc("/api/pull-file", s.handlePullFile)
	mux.HandleFunc("/api/push-file", s.handlePushFile)
	mux.HandleFunc("/api/file-delete", s.handleFileDelete)
	mux.HandleFunc("/api/file-rename", s.handleFileRename)
	mux.HandleFunc("/api/file-mkdir", s.handleFileMkdir)
	mux.HandleFunc("/api/file-touch", s.handleFileTouch)
	mux.HandleFunc("/api/file-stat", s.handleFileStat)
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
	mux.HandleFunc("/api/adb-wireless-disconnect", s.handleAdbWirelessDisconnect)
	mux.HandleFunc("/api/adb-wireless-scan", s.handleAdbWirelessScan)
	mux.HandleFunc("/api/session-logcat", s.handleSessionLogcat)
	mux.HandleFunc("/api/logcat-recent", s.handleRecentLogcat)

	webFS, err := fs.Sub(s.webFS, "web")
	if err != nil {
		mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
			http.Error(w, "web assets unavailable: "+err.Error(), http.StatusInternalServerError)
		})
	} else {
		mux.Handle("/", http.FileServer(http.FS(webFS)))
	}

	return recoverHTTP(requireLoopback(mux))
}

func (s *Server) handleDevices(w http.ResponseWriter, r *http.Request) {
	devices, err := s.adb.DevicesContext(r.Context())
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
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
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	if err := s.adb.ClearLogcat(serial); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

func (s *Server) handleDeviceInfo(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	output, err := s.adb.Shell(serial, "getprop")
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]string{"props": output})
}

func (s *Server) handlePackagePID(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	packageName := r.URL.Query().Get("package")
	if serial == "" || packageName == "" {
		writeAPIError(w, http.StatusBadRequest, "serial and package required")
		return
	}
	pid, err := s.adb.GetPackagePID(serial, packageName)
	if err != nil {
		writeAPIErrorData(w, http.StatusInternalServerError, err.Error(), map[string]string{"pid": ""})
		return
	}
	writeJSON(w, map[string]string{"pid": pid})
}

func (s *Server) handleRunningPackages(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	pkgs, err := s.adb.GetRunningPackages(serial)
	if err != nil {
		writeAPIErrorData(w, http.StatusInternalServerError, err.Error(), map[string]interface{}{"packages": []string{}})
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
		writeAPIError(w, http.StatusBadRequest, "websocket upgrade failed")
		return
	}

	session := NewLogSession(conn, s.adb)
	session.Run()
}

func (s *Server) handleFiles(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	path := r.URL.Query().Get("path")
	if serial == "" || path == "" {
		writeAPIError(w, http.StatusBadRequest, "serial and path required")
		return
	}
	entries, err := s.adb.ListFiles(serial, path)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
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
		writeAPIError(w, http.StatusBadRequest, "serial and path required")
		return
	}
	content, err := s.adb.ReadFile(serial, path)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]string{"content": content})
}

func (s *Server) handlePackages(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	pkgs, err := s.adb.InstalledPackages(serial)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
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
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	props, err := s.adb.DeviceDetail(serial)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if props == nil {
		props = map[string]string{}
	}
	writeJSON(w, map[string]interface{}{"props": props})
}

func (s *Server) handleDeviceStatus(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	status, err := s.adb.DeviceStatus(r.Context(), serial)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]interface{}{"status": status})
}

func (s *Server) handleScreenshot(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	data, err := s.adb.Screenshot(serial)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	w.Header().Set("Content-Type", "image/png")
	if _, err := w.Write(data); err != nil {
		Log.Add("http screenshot response", "", err, 0)
	}
}

func (s *Server) handleUninstallPackage(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	serial := r.URL.Query().Get("serial")
	packageName := r.URL.Query().Get("package")
	if serial == "" || packageName == "" {
		writeAPIError(w, http.StatusBadRequest, "serial and package required")
		return
	}
	if err := s.adb.UninstallPackage(serial, packageName); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

func (s *Server) handleInstallPackage(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	defer r.Body.Close()

	tmpFile, err := os.CreateTemp("", "adb-tool-install-*.apk")
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	defer os.Remove(tmpFile.Name())

	if _, err := io.Copy(tmpFile, r.Body); err != nil {
		if closeErr := tmpFile.Close(); closeErr != nil {
			Log.Add("install temp close", "", closeErr, 0)
		}
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if err := tmpFile.Close(); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}

	output, err := s.adb.InstallPackageContext(r.Context(), serial, tmpFile.Name())
	if err != nil {
		if r.Context().Err() != nil {
			writeAPIError(w, 499, "操作已取消")
			return
		}
		msg := parseInstallError(output)
		writeAPIErrorData(w, http.StatusBadRequest, msg, map[string]string{"raw": output})
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
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	defer r.Body.Close()
	var req struct {
		Args []string `json:"args"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	if len(req.Args) == 0 {
		writeAPIError(w, http.StatusBadRequest, "args required")
		return
	}
	for _, arg := range req.Args {
		if strings.TrimSpace(arg) == "" {
			writeAPIError(w, http.StatusBadRequest, "empty argument not allowed")
			return
		}
	}
	output, err := s.adb.Execute(serial, req.Args)
	if err != nil {
		writeAPIErrorData(w, http.StatusBadRequest, err.Error(), map[string]interface{}{"ok": false, "output": output})
		return
	}
	writeJSON(w, map[string]interface{}{"ok": true, "output": output})
}

func (s *Server) handleAdbWirelessPair(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	defer r.Body.Close()
	var req struct {
		Address string `json:"address"`
		Code    string `json:"code"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	req.Address = strings.TrimSpace(req.Address)
	req.Code = strings.TrimSpace(req.Code)
	if req.Address == "" || req.Code == "" {
		writeAPIError(w, http.StatusBadRequest, "address and code required")
		return
	}
	output, err := s.adb.WirelessPairContext(r.Context(), req.Address, req.Code)
	if err != nil {
		writeAPIErrorData(w, http.StatusBadRequest, err.Error(), map[string]interface{}{"ok": false, "output": output})
		return
	}
	writeJSON(w, map[string]interface{}{"ok": true, "output": output})
}

func (s *Server) handleAdbWirelessConnect(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	defer r.Body.Close()
	var req struct {
		Address string `json:"address"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	req.Address = strings.TrimSpace(req.Address)
	if req.Address == "" {
		writeAPIError(w, http.StatusBadRequest, "address required")
		return
	}
	output, err := s.adb.WirelessConnectContext(r.Context(), req.Address)
	if err != nil {
		writeAPIErrorData(w, http.StatusBadRequest, err.Error(), map[string]interface{}{"ok": false, "output": output})
		return
	}
	writeJSON(w, map[string]interface{}{"ok": true, "output": output})
}

func (s *Server) handleAdbWirelessDisconnect(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	defer r.Body.Close()
	var req struct {
		Serial string `json:"serial"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	req.Serial = strings.TrimSpace(req.Serial)
	if req.Serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	output, err := s.adb.WirelessDisconnectContext(r.Context(), req.Serial)
	if err != nil {
		writeAPIErrorData(w, http.StatusBadRequest, err.Error(), map[string]interface{}{"ok": false, "output": output})
		return
	}
	writeJSON(w, map[string]interface{}{"ok": true, "output": output})
}

func (s *Server) handleAdbWirelessScan(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		writeAPIError(w, http.StatusMethodNotAllowed, "GET required")
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
	defer cancel()
	devices, output, err := s.adb.ScanWirelessAdb(ctx)
	data := map[string]interface{}{"devices": devices, "output": output}
	if err != nil {
		if ctx.Err() == context.DeadlineExceeded {
			writeJSON(w, data)
			return
		}
		writeAPIErrorData(w, http.StatusBadRequest, err.Error(), data)
		return
	}
	writeJSON(w, data)
}

func (s *Server) handleRecentLogcat(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		writeAPIError(w, http.StatusMethodNotAllowed, "GET required")
		return
	}
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	lines := 1000
	if raw := r.URL.Query().Get("lines"); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil || parsed <= 0 {
			writeAPIError(w, http.StatusBadRequest, "lines must be a positive integer")
			return
		}
		lines = parsed
	}
	content, err := s.adb.GetRecentLogcat(serial, lines)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]any{"content": content, "lines": lines})
}

func (s *Server) handleSessionLogcat(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	var req struct {
		Action      string `json:"action"`
		Serial      string `json:"serial"`
		SessionDir  string `json:"sessionDir"`
		PackageName string `json:"packageName"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}

	switch req.Action {
	case "start":
		if req.Serial == "" || req.SessionDir == "" {
			writeAPIError(w, http.StatusBadRequest, "serial and sessionDir required")
			return
		}
		sessionDir, err := validateSessionDir(req.SessionDir)
		if err != nil {
			writeAPIError(w, http.StatusBadRequest, err.Error())
			return
		}
		if err := s.sessionLogcat.Start(s.adb.AdbPath(), req.Serial, sessionDir, req.PackageName); err != nil {
			writeAPIError(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, map[string]string{"status": "ok"})
	case "stop":
		path := s.sessionLogcat.Stop()
		writeJSON(w, map[string]string{"path": path})
	default:
		writeAPIError(w, http.StatusBadRequest, "invalid action, use start or stop")
	}
}

func (s *Server) handlePullFile(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	path := r.URL.Query().Get("path")
	if serial == "" || path == "" {
		writeAPIError(w, http.StatusBadRequest, "serial and path required")
		return
	}
	tmpFile := filepath.Join(os.TempDir(), "adb-tool-pull-"+time.Now().Format("20060102150405.000000000"))
	defer os.Remove(tmpFile)
	if err := s.adb.PullFileToPathContext(r.Context(), serial, path, tmpFile); err != nil {
		if r.Context().Err() != nil {
			writeAPIError(w, 499, "操作已取消")
			return
		}
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	w.Header().Set("Content-Disposition", "attachment; filename=\""+filepath.Base(path)+"\"")
	w.Header().Set("Content-Type", "application/octet-stream")
	http.ServeFile(w, r, tmpFile)
}

func (s *Server) handlePushFile(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	serial := r.URL.Query().Get("serial")
	path := r.URL.Query().Get("path")
	if serial == "" || path == "" {
		writeAPIError(w, http.StatusBadRequest, "serial and path required")
		return
	}
	defer r.Body.Close()
	tmpFile := filepath.Join(os.TempDir(), "adb-tool-push-"+time.Now().Format("20060102150405.000000000"))
	defer os.Remove(tmpFile)
	out, err := os.Create(tmpFile)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if _, err := io.Copy(out, r.Body); err != nil {
		if closeErr := out.Close(); closeErr != nil {
			Log.Add("push temp close", "", closeErr, 0)
		}
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if err := out.Close(); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if err := s.adb.PushFileFromPathContext(r.Context(), serial, tmpFile, path); err != nil {
		if r.Context().Err() != nil {
			writeAPIError(w, 499, "操作已取消")
			return
		}
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

func (s *Server) handleFileDelete(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	serial := r.URL.Query().Get("serial")
	path := r.URL.Query().Get("path")
	recursive := r.URL.Query().Get("recursive") == "true"
	if serial == "" || path == "" {
		writeAPIError(w, http.StatusBadRequest, "serial and path required")
		return
	}
	if err := s.adb.DeleteFile(serial, path, recursive); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

func (s *Server) handleFileRename(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	serial := r.URL.Query().Get("serial")
	from := r.URL.Query().Get("from")
	to := r.URL.Query().Get("to")
	if serial == "" || from == "" || to == "" {
		writeAPIError(w, http.StatusBadRequest, "serial, from and to required")
		return
	}
	if err := s.adb.RenameFile(serial, from, to); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

func (s *Server) handleFileMkdir(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	serial := r.URL.Query().Get("serial")
	path := r.URL.Query().Get("path")
	if serial == "" || path == "" {
		writeAPIError(w, http.StatusBadRequest, "serial and path required")
		return
	}
	if err := s.adb.MakeDir(serial, path); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

func (s *Server) handleFileTouch(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	serial := r.URL.Query().Get("serial")
	path := r.URL.Query().Get("path")
	if serial == "" || path == "" {
		writeAPIError(w, http.StatusBadRequest, "serial and path required")
		return
	}
	if err := s.adb.TouchFile(serial, path); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

func (s *Server) handleFileStat(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	path := r.URL.Query().Get("path")
	if serial == "" || path == "" {
		writeAPIError(w, http.StatusBadRequest, "serial and path required")
		return
	}
	stat, err := s.adb.FileStat(serial, path)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]interface{}{"stat": stat})
}

func (s *Server) handleScreenRecordVideo(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	data, err := s.adb.PullRecordedVideo(serial)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
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
			writeAPIError(w, http.StatusBadRequest, "serial required")
			return
		}
		s.recordMu.Lock()
		defer s.recordMu.Unlock()
		if s.recordingSerial != "" {
			writeAPIError(w, http.StatusConflict, "already recording on "+s.recordingSerial)
			return
		}
		if err := s.adb.StartScreenRecord(serial); err != nil {
			writeAPIError(w, http.StatusInternalServerError, err.Error())
			return
		}
		s.recordingSerial = serial
		s.recordStarted = time.Now()
		writeJSON(w, map[string]interface{}{"status": "recording", "serial": serial})

	case "stop":
		s.recordMu.Lock()
		if s.recordingSerial == "" {
			s.recordMu.Unlock()
			writeAPIError(w, http.StatusConflict, "not recording")
			return
		}
		serial := s.recordingSerial
		started := s.recordStarted
		s.recordMu.Unlock()

		err := s.adb.StopScreenRecord(serial)

		s.recordMu.Lock()
		if s.recordingSerial == serial {
			s.recordingSerial = ""
			s.recordStarted = time.Time{}
		}
		s.recordMu.Unlock()

		if err != nil {
			writeAPIError(w, http.StatusInternalServerError, err.Error())
			return
		}

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
		started := s.recordStarted
		s.recordMu.Unlock()

		if !s.adb.IsScreenRecording(serial) {
			s.recordMu.Lock()
			if s.recordingSerial == serial {
				s.recordingSerial = ""
				s.recordStarted = time.Time{}
			}
			s.recordMu.Unlock()
			writeJSON(w, map[string]interface{}{"recording": false})
			return
		}

		elapsed := time.Since(started).Seconds()
		writeJSON(w, map[string]interface{}{
			"recording": true,
			"serial":    serial,
			"elapsed":   elapsed,
		})

	default:
		writeAPIError(w, http.StatusBadRequest, "action must be start, stop, or status")
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
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}

	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		writeAPIError(w, http.StatusForbidden, "bad remote addr")
		return
	}
	ip := net.ParseIP(host)
	if ip == nil || !ip.IsLoopback() {
		writeAPIError(w, http.StatusForbidden, "forbidden")
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

func (s *Server) handleClipboardCheck(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	installed := s.adb.IsClipboardHelperInstalled(serial)
	writeJSON(w, map[string]interface{}{"installed": installed})
}

func (s *Server) handleClipboardInstall(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	if err := s.adb.InstallClipboardHelper(serial, s.clipboardApk); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

func (s *Server) handleClipboardSend(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	defer r.Body.Close()
	var req struct {
		Text string `json:"text"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<20)).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, "text required")
		return
	}
	text := strings.TrimSpace(req.Text)
	if text == "" {
		writeAPIError(w, http.StatusBadRequest, "text required")
		return
	}
	if err := s.adb.SendClipboard(serial, text); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

func (s *Server) handleClipboardUninstall(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	if err := s.adb.UninstallClipboardHelper(serial); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}
