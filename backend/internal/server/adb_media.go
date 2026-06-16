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

const recordedVideoPath = "/sdcard/adb-tool-record.mp4"

func (m *AdbManager) Screenshot(serial string) ([]byte, error) {
	return m.runOut("-s", serial, "exec-out", "screencap", "-p")
}

func (m *AdbManager) StartScreenRecord(serial string) error {
	m.recordMu.Lock()
	if m.recordCmd != nil {
		if m.recordFinishedLocked() {
			m.clearRecordLocked()
		} else {
			recordSerial := m.recordSerial
			m.recordMu.Unlock()
			return fmt.Errorf("screenrecord already active for %s", recordSerial)
		}
	}
	m.recordMu.Unlock()

	if _, err := m.run("-s", serial, "shell", "rm", "-f", recordedVideoPath); err != nil {
		Log.Add("screenrecord cleanup", "", err, 0)
	}
	if _, err := m.run("-s", serial, "shell", "settings", "put", "system", "show_touches", "1"); err != nil {
		Log.Add("screenrecord show_touches on", "", err, 0)
	}

	cmd := exec.Command(m.adbPath, "-s", serial, "shell", "screenrecord", recordedVideoPath)
	if err := cmd.Start(); err != nil {
		return err
	}
	done := make(chan error, 1)
	go func() {
		done <- cmd.Wait()
	}()

	m.recordMu.Lock()
	defer m.recordMu.Unlock()
	if m.recordCmd != nil {
		if cmd.Process != nil {
			if err := cmd.Process.Kill(); err != nil {
				Log.Add("screenrecord duplicate kill", "", err, 0)
			}
		}
		waitRecordDone(done, 2*time.Second)
		return fmt.Errorf("screenrecord already active for %s", m.recordSerial)
	}
	m.recordCmd = cmd
	m.recordSerial = serial
	m.recordDone = done
	return nil
}

func (m *AdbManager) StopScreenRecord(serial string) error {
	defer func() {
		if _, err := m.run("-s", serial, "shell", "settings", "put", "system", "show_touches", "0"); err != nil {
			Log.Add("screenrecord show_touches off", "", err, 0)
		}
	}()

	cmd, done := m.recordProcess(serial)
	if cmd == nil {
		return m.waitRecordedVideo(serial, 2*time.Second)
	}

	if cmd.Process != nil {
		if err := cmd.Process.Signal(os.Interrupt); err != nil {
			Log.Add("screenrecord interrupt", "", err, 0)
			if err := cmd.Process.Kill(); err != nil {
				Log.Add("screenrecord kill", "", err, 0)
			}
		}
	}

	if err := waitRecordDone(done, 8*time.Second); err != nil {
		Log.Add("screenrecord wait", "", err, 0)
		if cmd.Process != nil {
			if killErr := cmd.Process.Kill(); killErr != nil {
				Log.Add("screenrecord kill after wait", "", killErr, 0)
			}
		}
		if waitErr := waitRecordDone(done, 2*time.Second); waitErr != nil {
			Log.Add("screenrecord wait after kill", "", waitErr, 0)
		}
	}

	m.clearRecord(serial, cmd)
	return m.waitRecordedVideo(serial, 5*time.Second)
}

func (m *AdbManager) PullRecordedVideo(serial string) ([]byte, error) {
	tmpFile := filepath.Join(os.TempDir(), fmt.Sprintf("adb-recording-%d.mp4", time.Now().UnixNano()))
	defer os.Remove(tmpFile)
	if _, err := m.run("-s", serial, "pull", recordedVideoPath, tmpFile); err != nil {
		return nil, err
	}
	return os.ReadFile(tmpFile)
}

func (m *AdbManager) CleanRecordedVideo(serial string) {
	if _, err := m.run("-s", serial, "shell", "rm", "-f", recordedVideoPath); err != nil {
		Log.Add("screenrecord clean remote video", "", err, 0)
	}
}

func (m *AdbManager) IsScreenRecording(serial string) bool {
	m.recordMu.Lock()
	defer m.recordMu.Unlock()
	if m.recordSerial != serial || m.recordCmd == nil {
		return false
	}
	if m.recordFinishedLocked() {
		m.clearRecordLocked()
		return false
	}
	return true
}

func (m *AdbManager) recordProcess(serial string) (*exec.Cmd, chan error) {
	m.recordMu.Lock()
	defer m.recordMu.Unlock()
	if m.recordSerial != serial || m.recordCmd == nil {
		return nil, nil
	}
	return m.recordCmd, m.recordDone
}

func (m *AdbManager) clearRecord(serial string, cmd *exec.Cmd) {
	m.recordMu.Lock()
	defer m.recordMu.Unlock()
	if m.recordSerial == serial && m.recordCmd == cmd {
		m.clearRecordLocked()
	}
}

func (m *AdbManager) clearRecordLocked() {
	m.recordCmd = nil
	m.recordSerial = ""
	m.recordDone = nil
}

func (m *AdbManager) recordFinishedLocked() bool {
	select {
	case err := <-m.recordDone:
		if err != nil {
			Log.Add("screenrecord exited", "", err, 0)
		}
		return true
	default:
		return false
	}
}

func waitRecordDone(done <-chan error, timeout time.Duration) error {
	if done == nil {
		return nil
	}
	select {
	case err := <-done:
		return err
	case <-time.After(timeout):
		return fmt.Errorf("screenrecord did not exit after %s", timeout)
	}
}

func (m *AdbManager) waitRecordedVideo(serial string, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		size, err := m.remoteFileSize(serial, recordedVideoPath)
		if err == nil && size > 0 {
			return nil
		}
		time.Sleep(250 * time.Millisecond)
	}
	return fmt.Errorf("recorded video not available after %s", timeout)
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
	return strconv.ParseInt(out, 10, 64)
}
