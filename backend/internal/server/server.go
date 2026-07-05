package server

import (
	"context"
	"embed"
	"fmt"
	"io/fs"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
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

	// localRecorder owns the per-device recordings used by the
	// save-to-local-file UI flow (vs. the test-session singleton above).
	localRecorder *LocalRecorder

	// logcatMgr owns one persistent logcat subprocess per device.
	// Driven by eventStream below via Ensure/Close.
	logcatMgr *LogcatStreamManager

	// eventStream subscribes to adb server's host:track-devices and
	// drives logcatMgr.Ensure/Close on device add/remove. streamCancel
	// terminates eventStream.Run on shutdown.
	eventStream  *AdbEventStream
	streamCancel context.CancelFunc

	// Emulator components
	instanceManager *emulator.InstanceManager
	statusMonitor   *emulator.StatusMonitor
	imageValidator  chan struct{}

	startedAt  time.Time
	onShutdown func()
	closeOnce  sync.Once
}

func New(adbPath string, webFS fs.FS, clipboardApk []byte, scrcpyFS embed.FS) *Server {
	adb := NewAdbManager(adbPath, scrcpyFS)
	adb.DiagnoseStartup()

	logcatMgr := NewLogcatStreamManager(adb)

	// Wire device add/remove → logcat watcher start/stop. The
	// callback runs on the event-stream's read-loop goroutine;
	// Ensure/Close are non-blocking (acquire a mutex, return), so
	// a slow consumer here can't stall the stream.
	eventStream := NewAdbEventStream(0, func(change trackDeviceChange) {
		for _, serial := range change.Added {
			logcatMgr.Ensure(serial)
		}
		for _, serial := range change.Removed {
			logcatMgr.Close(serial)
		}
	})

	streamCtx, streamCancel := context.WithCancel(context.Background())

	s := &Server{
		adb:           adb,
		webFS:         webFS,
		clipboardApk:  clipboardApk,
		sessionLogcat: &SessionLogcat{},
		localRecorder: NewLocalRecorder(),
		logcatMgr:     logcatMgr,
		eventStream:   eventStream,
		streamCancel:  streamCancel,
		startedAt:     time.Now(),
		upgrader: websocket.Upgrader{
			CheckOrigin: isAllowedWebSocketOrigin,
		},
	}

	go eventStream.Run(streamCtx)
	return s
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

	// Wire the same ImageManager into the SDK installer so successful
	// sdkmanager installs (e.g. a fresh system-image package) get
	// registered into the image list without a manual rescan.
	SDKInstaller.SetImageManager(imageManager)

	// Create instance manager
	s.instanceManager, err = emulator.NewInstanceManager(emulatorPath, avdManagerPath, javaPath, androidHome, dataDir, imageManager)
	if err != nil {
		return err
	}

	// Resolve emulator + avdmanager paths if the caller left them blank
	// (which is what main.go does — it expects us to auto-detect). Without
	// this, InstanceManager keeps an empty emulatorPath and every
	// startEmulator call returns "emulator path not configured".
	resolvedEmulator, resolvedAvdmanager := emulatorPath, avdManagerPath
	var resolvedSDK string
	if resolvedEmulator == "" || resolvedAvdmanager == "" {
		if engine, derr := emulator.DetectEmulatorEngine(androidHome, ""); derr == nil {
			if resolvedEmulator == "" {
				resolvedEmulator = engine.EmulatorPath
			}
			if resolvedAvdmanager == "" {
				resolvedAvdmanager = engine.AvdmanagerPath
			}
			// DetectEmulatorEngine also resolves the SDK root (via the
			// persisted selection, ANDROID_HOME, etc.). Push it down
			// to the instance manager so ANDROID_SDK_ROOT is non-empty
			// when we spawn the emulator subprocess — otherwise
			// emulator 36.x on macOS silently exits before the boot
			// because it can't resolve system image paths.
			resolvedSDK = engine.AndroidHome
			EmulatorEngine = engine
		}
	}
	if resolvedEmulator != "" || resolvedAvdmanager != "" {
		s.instanceManager.UpdateToolchainPaths(resolvedEmulator, resolvedAvdmanager)
	}
	if resolvedSDK != "" {
		s.instanceManager.UpdateAndroidSdkPath(resolvedSDK)

		// Create a platform-tools symlink under the SDK root so the
		// emulator launcher validates the path on macOS (it refuses
		// to continue without a platform-tools subdirectory). The
		// actual adb binary lives in /tmp/adb-tool-cache/adb, so we
		// symlink to it. This is safe because FindOrExtractADB is
		// guaranteed to have run before InitEmulator.
		ptDir := filepath.Join(resolvedSDK, "platform-tools")
		if _, statErr := os.Stat(ptDir); os.IsNotExist(statErr) {
			// FindOrExtractADB puts adb at <tmpdir>/adb-tool-cache/adb
			adbInCache := filepath.Join(os.TempDir(), "adb-tool-cache", "adb")
			if runtime.GOOS == "windows" {
				adbInCache = filepath.Join(os.TempDir(), "adb-tool-cache", "adb.exe")
			}
			if _, err := os.Stat(adbInCache); err == nil {
				if mkErr := os.MkdirAll(ptDir, 0755); mkErr == nil {
					symlinkTarget := filepath.Join(ptDir, "adb")
					// Remove stale file/dir at symlink target path
					os.Remove(symlinkTarget)
					if lnkErr := os.Symlink(adbInCache, symlinkTarget); lnkErr == nil {
						fmt.Printf("       platform-tools symlink: %s -> %s\n", symlinkTarget, adbInCache)
					}
				}
			}
		}
	}

	// Create status monitor and wire it back into the instance manager
	// so boot-progress updates can be broadcast to WebSocket clients.
	s.statusMonitor = emulator.NewStatusMonitor(s.instanceManager)
	s.instanceManager.SetStatusMonitor(s.statusMonitor)

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
		if androidHome != "" {
			// Also scan the selected SDK's own system-images dir so freshly
			// sdkmanager-installed images (which live under <androidHome>/
			// system-images, not under .adb-tool/emulator/system-images) get
			// picked up on next launch.
			if m2, err := imageManager.ScanAndRegister(
				filepath.Join(androidHome, "system-images")); err == nil {
				n += m2
			} else {
				log.Printf("[emulator] startup SDK system-images scan: %v", err)
			}
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

		// Tear down device-driven logcat: cancel the stream ctx so
		// Run exits on its next check, Stop the stream (belt &
		// suspenders if Run is mid-reconnect), then drain every
		// per-device watcher. Must happen BEFORE adb.Close() —
		// logcatMgr uses adb internally for spawn/seed.
		if s.streamCancel != nil {
			s.streamCancel()
		}
		if s.eventStream != nil {
			s.eventStream.Stop()
		}
		if s.logcatMgr != nil {
			s.logcatMgr.CloseAll()
		}

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
//     /api/clear, /api/package-pid, /api/running-packages, /api/adb-path
//   - handlers_files.go     /api/files, /api/file-content, /api/pull-file, /api/push-file,
//     /api/file-delete, /api/file-rename, /api/file-mkdir,
//     /api/file-touch, /api/file-stat
//   - handlers_packages.go  /api/packages, /api/install-package, /api/uninstall-package
//   - handlers_logcat.go    /ws/logs, /api/logcat-recent, /api/session-logcat
//   - handlers_screen.go    /api/screenshot, /api/screen-record, /api/screen-record-video
//   - handlers_scrcpy.go    /api/scrcpy/{start,stop,action,status}
//   - handlers_scrcpy_record.go /api/scrcpy/record/{start,stop,status}
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
	mux.HandleFunc("/api/local-recording", s.handleLocalRecording)

	// Screen capture & record
	mux.HandleFunc("/api/screenshot", s.handleScreenshot)
	mux.HandleFunc("/api/screen-record", s.handleScreenRecord)
	mux.HandleFunc("/api/screen-record-video", s.handleScreenRecordVideo)

	// Scrcpy (bundled binary) screen mirror
	mux.HandleFunc("/api/scrcpy/start", s.handleScrcpyStart)
	mux.HandleFunc("/api/scrcpy/stop", s.handleScrcpyStop)
	mux.HandleFunc("/api/scrcpy/action", s.handleScrcpyAction)
	mux.HandleFunc("/api/scrcpy/status", s.handleScrcpyStatus)

	// Scrcpy windowless recording (--no-window --record=<path>). Used
	// when the user picks "scrcpy" as their screen-recording method in
	// the new recording settings page. Mutually exclusive with the
	// mirror session — see adb_scrcpy_record.go for the conflict rules.
	mux.HandleFunc("/api/scrcpy/record/start", s.handleScrcpyRecordingStart)
	mux.HandleFunc("/api/scrcpy/record/stop", s.handleScrcpyRecordingStop)
	mux.HandleFunc("/api/scrcpy/record/status", s.handleScrcpyRecordingStatus)

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
	mux.HandleFunc("/api/emulator/java/import", s.handleEmulatorJavaImport)
	mux.HandleFunc("/api/emulator/java/delete", s.handleEmulatorJavaDelete)

	// SDK mirror config
	mux.HandleFunc("/api/emulator/mirror", s.handleEmulatorMirror)

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
	mux.HandleFunc("/api/emulator/image/delete", s.handleEmulatorImageDelete)
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
	mux.HandleFunc("/api/emulator/instance/log", s.handleEmulatorInstanceLog)
	mux.HandleFunc("/ws/emulator/status", s.handleEmulatorStatusWS)

	// SDK installer (sdkmanager-driven package install with progress)
	mux.HandleFunc("/api/emulator/sdk/install", s.handleEmulatorSDKInstall)
	mux.HandleFunc("/api/emulator/sdk/install/status", s.handleEmulatorSDKInstallStatus)

	mux.HandleFunc("/api/identify", s.handleIdentify)
	mux.HandleFunc("/api/shutdown", s.handleShutdown)
	mux.HandleFunc("/api/adb-exec", s.handleAdbExec)
	mux.HandleFunc("/api/debug/env", s.handleEnvDebug) // 诊断环境变量

	// One-shot "wipe all adb-tool caches" — UI entry in
	// Emulator Settings. Destructive, requires ?confirm=true.
	mux.HandleFunc("/api/cache/cleanup", s.handleCacheCleanup)

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
