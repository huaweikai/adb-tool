package server

import (
	"os/exec"
	"sync"
	"time"
)

type AdbManager struct {
	adbPath      string
	recordMu     sync.Mutex
	recordCmd    *exec.Cmd
	recordSerial string
}

func NewAdbManager(adbPath string) *AdbManager {
	return &AdbManager{adbPath: adbPath}
}

func (m *AdbManager) AdbPath() string {
	return m.adbPath
}

func (m *AdbManager) Close() {
	m.recordMu.Lock()
	cmd := m.recordCmd
	m.recordCmd = nil
	m.recordSerial = ""
	m.recordMu.Unlock()
	if cmd != nil && cmd.Process != nil {
		if err := cmd.Process.Kill(); err != nil {
			Log.Add("screenrecord kill", "", err, 0)
		}
		if _, err := waitCommandExit(cmd, 2*time.Second); err != nil {
			Log.Add("screenrecord wait", "", err, 0)
		}
	}
	if _, err := m.runRaw("kill-server"); err != nil {
		Log.Add("adb kill-server", "", err, 0)
	}
}
