package server

import (
	"embed"
	"io/fs"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/gorilla/websocket"

	"adb-tool/backend/internal/emulator"
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

	// Emulator components
	instanceManager *emulator.InstanceManager
	statusMonitor  *emulator.StatusMonitor
	imageValidator chan struct{}

	startedAt  time.Time
	onShutdown func()
	closeOnce  sync.Once
}

func New(adbPath string, webFS fs.FS, clipboardApk []byte, scrcpyFS embed.FS) *Server {
	adb := NewAdbManager(adbPath, scrcpyFS)
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

// InitEmulator initializes the emulator components.
func (s *Server) InitEmulator(emulatorPath, avdManagerPath, javaPath, androidHome string) error {
	// Get data directory
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	dataDir := filepath.Join(home, ".adb-tool", "emulator")

	// Create data directory if needed
	if err := os.MkdirAll(dataDir, 0755); err != nil {
		return err
	}

	// Build one shared ImageManager and hand it to the InstanceManager so
	// AVD config.ini can be written with the *real* on-disk image path
	// (instead of guessing from the imageID, which has the wrong layout).
	imageManager := emulator.NewImageManager(androidHome)

	// Create instance manager
	s.instanceManager, err = emulator.NewInstanceManager(emulatorPath, avdManagerPath, javaPath, androidHome, dataDir, imageManager)
	if err != nil {
		return err
	}

	// Create status monitor
	s.statusMonitor = emulator.NewStatusMonitor(s.instanceManager)

	// Start a background goroutine that periodically validates the persisted
	// image registry paths (marks missing images as invalid).
	if s.imageValidator == nil {
		s.imageValidator = emulator.StartImageRegistryValidator(60 * time.Second)
	}

	// Auto-discover images that already live in the cache (from before the
	// registry existed, or copied there by an earlier build). Runs once at
	// boot in a goroutine so the server doesn't block on it.
	go func() {
		n, err := imageManager.ScanAndRegisterStorage()
		if err != nil {
			log.Printf("[emulator] startup storage scan: %v", err)
			return
		}
		if n > 0 {
			log.Printf("[emulator] startup storage scan: registered %d image(s)", n)
		}
	}()

	return nil
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
		if s.statusMonitor != nil {
			s.statusMonitor.Stop()
		}
		if s.imageValidator != nil {
			close(s.imageValidator)
			s.imageValidator = nil
		}
	})
}

// Handler returns the HTTP handler for the server. Route registration is split
// into logical groups — each handlers_*.go file owns the routes for its domain.
//
// Layout:
//   - handlers_devices.go   /api/devices, /api/info, /api/device-detail, /api/device-status,
//                            /api/clear, /api/package-pid, /api/running-packages, /api/adb-path
//   - handlers_files.go     /api/files, /api/file-content, /api/pull-file, /api/push-file,
//                            /api/file-delete, /api/file-rename, /api/file-mkdir,
//                            /api/file-touch, /api/file-stat
//   - handlers_packages.go  /api/packages, /api/install-package, /api/uninstall-package
//   - handlers_logcat.go    /ws/logs, /api/logcat-recent, /api/session-logcat
//   - handlers_screen.go    /api/screenshot, /api/screen-record, /api/screen-record-video
//   - handlers_scrcpy.go    /api/scrcpy/{start,stop,action,status}
//   - handlers_wireless.go  /api/adb-wireless-{pair,connect,disconnect,scan}
//   - handlers_clipboard.go /api/clipboard-{check,install,send,uninstall}
//   - handlers_meta.go      /api/backend-logs, /api/identify, /api/shutdown, /api/adb-exec
//   - handlers_emulator.go  /api/emulator/engine/{status,validate,config}
func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()

	// Devices & system
	mux.HandleFunc("/api/devices", s.handleDevices)
	mux.HandleFunc("/api/clear", s.handleClear)
	mux.HandleFunc("/api/info", s.handleDeviceInfo)
	mux.HandleFunc("/api/package-pid", s.handlePackagePID)
	mux.HandleFunc("/api/running-packages", s.handleRunningPackages)
	mux.HandleFunc("/api/adb-path", s.handleAdbPath)
	mux.HandleFunc("/api/device-detail", s.handleDeviceDetail)
	mux.HandleFunc("/api/device-status", s.handleDeviceStatus)

	// Files
	mux.HandleFunc("/api/files", s.handleFiles)
	mux.HandleFunc("/api/file-content", s.handleFileContent)
	mux.HandleFunc("/api/pull-file", s.handlePullFile)
	mux.HandleFunc("/api/push-file", s.handlePushFile)
	mux.HandleFunc("/api/file-delete", s.handleFileDelete)
	mux.HandleFunc("/api/file-rename", s.handleFileRename)
	mux.HandleFunc("/api/file-mkdir", s.handleFileMkdir)
	mux.HandleFunc("/api/file-touch", s.handleFileTouch)
	mux.HandleFunc("/api/file-stat", s.handleFileStat)

	// Packages
	mux.HandleFunc("/api/packages", s.handlePackages)
	mux.HandleFunc("/api/install-package", s.handleInstallPackage)
	mux.HandleFunc("/api/uninstall-package", s.handleUninstallPackage)

	// Logcat
	mux.HandleFunc("/ws/logs", s.handleLogStream)
	mux.HandleFunc("/api/logcat-recent", s.handleRecentLogcat)
	mux.HandleFunc("/api/session-logcat", s.handleSessionLogcat)

	// Screen capture & record
	mux.HandleFunc("/api/screenshot", s.handleScreenshot)
	mux.HandleFunc("/api/screen-record", s.handleScreenRecord)
	mux.HandleFunc("/api/screen-record-video", s.handleScreenRecordVideo)

	// Scrcpy (bundled binary) screen mirror
	mux.HandleFunc("/api/scrcpy/start", s.handleScrcpyStart)
	mux.HandleFunc("/api/scrcpy/stop", s.handleScrcpyStop)
	mux.HandleFunc("/api/scrcpy/action", s.handleScrcpyAction)
	mux.HandleFunc("/api/scrcpy/status", s.handleScrcpyStatus)

	// Wireless ADB
	mux.HandleFunc("/api/adb-wireless-pair", s.handleAdbWirelessPair)
	mux.HandleFunc("/api/adb-wireless-connect", s.handleAdbWirelessConnect)
	mux.HandleFunc("/api/adb-wireless-disconnect", s.handleAdbWirelessDisconnect)
	mux.HandleFunc("/api/adb-wireless-scan", s.handleAdbWirelessScan)

	// Clipboard
	mux.HandleFunc("/api/clipboard-check", s.handleClipboardCheck)
	mux.HandleFunc("/api/clipboard-install", s.handleClipboardInstall)
	mux.HandleFunc("/api/clipboard-send", s.handleClipboardSend)
	mux.HandleFunc("/api/clipboard-uninstall", s.handleClipboardUninstall)

	// Meta & diagnostics
	mux.HandleFunc("/api/backend-logs", s.handleBackendLogs)

	// Emulator engine & SDK
	mux.HandleFunc("/api/emulator/engine/status", s.handleEmulatorEngineStatus)
	mux.HandleFunc("/api/emulator/engine/validate", s.handleEmulatorEngineValidate)
	mux.HandleFunc("/api/emulator/engine/config", s.handleEmulatorEngineConfig)
	mux.HandleFunc("/api/emulator/sdk/import", s.handleEmulatorSDKImport)
	mux.HandleFunc("/api/emulator/sdk/delete", s.handleEmulatorSDKDelete)
	mux.HandleFunc("/api/emulator/sdk/detect", s.handleEmulatorSDKDetect)
	mux.HandleFunc("/api/emulator/sdk/download", s.handleEmulatorSDKDownload)
	mux.HandleFunc("/api/emulator/sdk/use", s.handleEmulatorSDKUse)

	// Emulator Java runtime
	mux.HandleFunc("/api/emulator/java/status", s.handleEmulatorJavaStatus)
	mux.HandleFunc("/api/emulator/java/list", s.handleEmulatorJavaList)
	mux.HandleFunc("/api/emulator/java/select", s.handleEmulatorJavaSelect)
	mux.HandleFunc("/api/emulator/java/validate", s.handleEmulatorJavaValidate)
	mux.HandleFunc("/api/emulator/java/download", s.handleEmulatorJavaDownload)

	// Unified download API (replaces Java-specific and image-specific download APIs)
	mux.HandleFunc("/api/emulator/downloads", s.handleEmulatorDownloads)
	mux.HandleFunc("/api/emulator/download/progress", s.handleEmulatorDownloadProgress)
	mux.HandleFunc("/api/emulator/download/cancel", s.handleEmulatorDownloadCancel)
	mux.HandleFunc("/api/emulator/download/pause", s.handleEmulatorDownloadPause)
	mux.HandleFunc("/api/emulator/download/resume", s.handleEmulatorDownloadResume)

	// Emulator system images
	mux.HandleFunc("/api/emulator/images", s.handleEmulatorImages)
	mux.HandleFunc("/api/emulator/image/get", s.handleEmulatorImageGet)
	mux.HandleFunc("/api/emulator/image/add", s.handleEmulatorImageAdd)
	mux.HandleFunc("/api/emulator/image/import", s.handleEmulatorImageImportZip)
	mux.HandleFunc("/api/emulator/image/import-path", s.handleEmulatorImageImportPath)
	mux.HandleFunc("/api/emulator/image/scan", s.handleEmulatorImageScan)
	mux.HandleFunc("/api/emulator/image/sources", s.handleEmulatorImageSources)
	mux.HandleFunc("/api/emulator/image/source/add", s.handleEmulatorImageSourceAdd)
	mux.HandleFunc("/api/emulator/image/source/remove", s.handleEmulatorImageSourceRemove)

	// Emulator instances
	mux.HandleFunc("/api/emulator/instances", s.handleEmulatorInstances)
	mux.HandleFunc("/api/emulator/instance/get", s.handleEmulatorInstanceGet)
	mux.HandleFunc("/api/emulator/instance/create", s.handleEmulatorInstanceCreate)
	mux.HandleFunc("/api/emulator/instance/start", s.handleEmulatorInstanceStart)
	mux.HandleFunc("/api/emulator/instance/stop", s.handleEmulatorInstanceStop)
	mux.HandleFunc("/api/emulator/instance/delete", s.handleEmulatorInstanceDelete)
	mux.HandleFunc("/ws/emulator/status", s.handleEmulatorStatusWS)

	mux.HandleFunc("/api/identify", s.handleIdentify)
	mux.HandleFunc("/api/shutdown", s.handleShutdown)
	mux.HandleFunc("/api/adb-exec", s.handleAdbExec)
	mux.HandleFunc("/api/debug/env", s.handleEnvDebug) // 诊断环境变量

	// Static web assets
	webFS, err := fs.Sub(s.webFS, "web")
	if err != nil {
		mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
			http.Error(w, "web assets unavailable: "+err.Error(), http.StatusInternalServerError)
		})
	} else {
		mux.Handle("/", http.FileServer(http.FS(webFS)))
	}

	// Order matters: loggingMiddleware sits outside everything else so
	// it sees the final status code even when recover/observe wrap the
	// response. requireLoopback is inside so non-loopback requests are
	// short-circuited before we'd bother logging them — though they
	// still appear in the log for completeness (shows up as 403).
	return recoverHTTP(observeHTTP(loggingMiddleware(requireLoopback(mux))))
}
