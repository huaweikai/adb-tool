package server

import (
	"embed"
	"fmt"
	"os/exec"
	"sync"
	"time"
)

const devicePropsCacheTTL = 60 * time.Second

type cachedDeviceProps struct {
	props map[string]string
	until time.Time
}

type AdbManager struct {
	adbPath      string
	recordMu     sync.Mutex
	recordCmd    *exec.Cmd
	recordSerial string
	recordDone   chan error

	// scrcpy per-device state — one mirror and one recording per
	// device, keyed by serial (ro.serialno). Different devices can
	// run concurrently; same-device mirror + recording are mutually
	// exclusive. scrcpyMu protects both maps.
	scrcpyMap       map[string]*scrcpyState
	scrcpyRecordMap map[string]*scrcpyRecordState
	scrcpyMu        sync.Mutex
	scrcpyFS        embed.FS // injected by NewAdbManager, sourced from main's embed_scrcpy_*.go

	propsMu        sync.Mutex
	propsCache     map[string]cachedDeviceProps
	restartMu      sync.Mutex
	lastAdbRestart time.Time
}

func NewAdbManager(adbPath string, scrcpyFS embed.FS) *AdbManager {
	return &AdbManager{
		adbPath:         adbPath,
		scrcpyMap:       make(map[string]*scrcpyState),
		scrcpyRecordMap: make(map[string]*scrcpyRecordState),
		scrcpyFS:        scrcpyFS,
		propsCache:      make(map[string]cachedDeviceProps),
	}
}
func (m *AdbManager) AdbPath() string {
	return m.adbPath
}

func (m *AdbManager) DiagnoseStartup() {
	start := time.Now()
	resolved, err := exec.LookPath(m.adbPath)
	result := fmt.Sprintf("configured=%s", m.adbPath)
	if resolved != "" {
		result += fmt.Sprintf(" resolved=%s", resolved)
	}
	Log.Add("adb diagnostic path", result, err, time.Since(start))
	m.runRaw("version")
	if _, err := m.runRaw("start-server"); err != nil {
		Log.Add("adb start-server retry", "", err, 0)
		m.restartAdbServer()
	}
}

func (m *AdbManager) restartAdbServer() {
	m.restartMu.Lock()
	defer m.restartMu.Unlock()
	if time.Since(m.lastAdbRestart) < 10*time.Second {
		return
	}
	m.lastAdbRestart = time.Now()
	Log.Add("adb recovery", "restarting adb server", nil, 0)
	m.runRaw("kill-server")
	m.runRaw("start-server")
}
func (m *AdbManager) Close() {
	m.recordMu.Lock()
	cmd := m.recordCmd
	done := m.recordDone
	m.recordCmd = nil
	m.recordSerial = ""
	m.recordDone = nil
	m.recordMu.Unlock()
	if cmd != nil && cmd.Process != nil {
		if err := cmd.Process.Kill(); err != nil {
			Log.Add("screenrecord kill", "", err, 0)
		}
		if err := waitRecordDone(done, 2*time.Second); err != nil {
			Log.Add("screenrecord wait", "", err, 0)
		}
	}
	// Kill all per-device scrcpy mirror and recording processes.
	m.scrcpyMu.Lock()
	for serial, st := range m.scrcpyMap {
		if st.cmd != nil && st.cmd.Process != nil {
			Log.Add("scrcpy mirror kill (close)", "serial="+serial, nil, 0)
			_ = st.cmd.Process.Kill()
		}
	}
	m.scrcpyMap = make(map[string]*scrcpyState)
	for serial, st := range m.scrcpyRecordMap {
		if st.cmd != nil && st.cmd.Process != nil {
			Log.Add("scrcpy recording kill (close)", "serial="+serial, nil, 0)
			_ = st.cmd.Process.Kill()
		}
	}
	m.scrcpyRecordMap = make(map[string]*scrcpyRecordState)
	m.scrcpyMu.Unlock()
	if _, err := m.runRaw("kill-server"); err != nil {
		Log.Add("adb kill-server", "", err, 0)
	}
}
