package server

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

func (m *AdbManager) Screenshot(serial string) ([]byte, error) {
	return m.runOut("-s", serial, "exec-out", "screencap", "-p")
}

func (m *AdbManager) StartScreenRecord(serial string) error {
	m.recordMu.Lock()
	defer m.recordMu.Unlock()

	if m.recordCmd != nil {
		return fmt.Errorf("screenrecord already active for %s", m.recordSerial)
	}

	stopMarker := "/sdcard/adb-tool-stop"
	if _, err := m.run("-s", serial, "shell", "rm", "-f", "/sdcard/adb-tool-record.mp4", stopMarker); err != nil {
		Log.Add("screenrecord cleanup", "", err, 0)
	}

	if _, err := m.run("-s", serial, "shell", "settings", "put", "system", "show_touches", "1"); err != nil {
		Log.Add("screenrecord show_touches on", "", err, 0)
	}

	script := fmt.Sprintf(
		`screenrecord --time-limit 1800 /sdcard/adb-tool-record.mp4 & SRPID=$!; while ! [ -f %s ]; do sleep 0.3; done; kill -2 $SRPID; wait $SRPID; sync; rm -f %s`,
		stopMarker, stopMarker,
	)
	cmd := exec.Command(m.adbPath, "-s", serial, "shell", script)
	if err := cmd.Start(); err != nil {
		return err
	}
	m.recordCmd = cmd
	m.recordSerial = serial
	return nil
}

func (m *AdbManager) StopScreenRecord(serial string) error {
	defer func() {
		if _, err := m.run("-s", serial, "shell", "settings", "put", "system", "show_touches", "0"); err != nil {
			Log.Add("screenrecord show_touches off", "", err, 0)
		}
	}()

	stopMarker := "/sdcard/adb-tool-stop"
	if _, err := m.run("-s", serial, "shell", "touch", stopMarker); err != nil {
		Log.Add("screenrecord touch marker", "", err, 0)
	}

	cmd := m.getRecordCmd(serial)
	if cmd != nil {
		waitCommandExit(cmd, 60*time.Second)
		m.clearRecordCmd(serial, cmd)
	}

	if err := m.waitRemoteFileStable(serial, "/sdcard/adb-tool-record.mp4", 8, 500*time.Millisecond, 30*time.Second); err != nil {
		return err
	}

	return nil
}

func (m *AdbManager) PullRecordedVideo(serial string) ([]byte, error) {
	tmpFile := filepath.Join(os.TempDir(), fmt.Sprintf("adb-recording-%d.mp4", time.Now().UnixNano()))
	defer os.Remove(tmpFile)
	_, err := m.run("-s", serial, "pull", "/sdcard/adb-tool-record.mp4", tmpFile)
	if err != nil {
		return nil, err
	}
	return os.ReadFile(tmpFile)
}

func (m *AdbManager) CleanRecordedVideo(serial string) {
	if _, err := m.run("-s", serial, "shell", "rm", "-f", "/sdcard/adb-tool-record.mp4"); err != nil {
		Log.Add("screenrecord clean remote video", "", err, 0)
	}
}

func (m *AdbManager) getRecordCmd(serial string) *exec.Cmd {
	m.recordMu.Lock()
	defer m.recordMu.Unlock()
	if m.recordSerial != serial {
		return nil
	}
	return m.recordCmd
}

func (m *AdbManager) clearRecordCmd(serial string, cmd *exec.Cmd) {
	m.recordMu.Lock()
	defer m.recordMu.Unlock()
	if m.recordSerial == serial && m.recordCmd == cmd {
		m.recordCmd = nil
		m.recordSerial = ""
	}
}

func waitCommandExit(cmd *exec.Cmd, timeout time.Duration) (bool, error) {
	done := make(chan error, 1)
	go func() {
		done <- cmd.Wait()
	}()

	select {
	case err := <-done:
		return true, err
	case <-time.After(timeout):
		return false, fmt.Errorf("command did not exit after %s", timeout)
	}
}

func (m *AdbManager) remoteFileSize(serial, path string) (int64, error) {
	out, err := m.run(
		"-s", serial, "shell", "sh", "-c",
		"stat -c %s "+path+" 2>/dev/null || ls -l "+path+" 2>/dev/null | awk '{print $5}'",
	)
	if err != nil {
		return 0, err
	}
	out = strings.TrimSpace(out)
	if out == "" {
		return 0, fmt.Errorf("empty file size output")
	}
	n, err := strconv.ParseInt(out, 10, 64)
	if err != nil {
		return 0, err
	}
	return n, nil
}

func (m *AdbManager) waitRemoteFileStable(serial, path string, stableCount int, interval, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	var last int64 = -1
	stable := 0
	for time.Now().Before(deadline) {
		size, err := m.remoteFileSize(serial, path)
		if err != nil {
			stable = 0
			time.Sleep(interval)
			continue
		}
		if size > 0 && size == last {
			stable++
			if stable >= stableCount {
				return nil
			}
		} else {
			stable = 0
		}
		last = size
		time.Sleep(interval)
	}
	return fmt.Errorf("recorded video not stable after %s", timeout)
}
