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

// Minimum viable video size: 1KB. Short recordings (sub-2s) often produce
// sub-10KB files while Android's buffer cache is still flushing — accept
// anything at least 1KB rather than failing. Caller-side handles the
// "too short" UX.
const minViableVideoSize = 1 * 1024

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
		// Another goroutine won the race; clean up this one.
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

	// Stop screenrecord by sending SIGINT from the DEVICE side.
	// This avoids cross-platform signal forwarding issues:
	//   - Windows os.Interrupt = CTRL_C_EVENT, adb may not forward it reliably
	//   - Unix SIGINT is forwarded fine, but device-side kill is cleaner
	// Using "kill -INT $(pgrep screenrecord)" sends SIGINT to the screenrecord
	// process, which causes it to flush buffers and finalize the MP4 muxer —
	// exactly what Ctrl+C does.
	m.killScreenRecordOnDevice(serial)

	// Wait for the local adb subprocess to exit.
	// The subprocess exits automatically once the remote screenrecord exits,
	// so we don't need a separate "wait for remote" step.
	if err := waitRecordDone(done, 8*time.Second); err != nil {
		Log.Add("screenrecord local wait", "", err, 0)
		// Fallback: kill the local adb process if it didn't exit.
		// This can happen if the device-side kill failed.
		if cmd.Process != nil {
			if killErr := cmd.Process.Kill(); killErr != nil {
				Log.Add("screenrecord local kill", "", killErr, 0)
			}
		}
		if waitErr := waitRecordDone(done, 2*time.Second); waitErr != nil {
			Log.Add("screenrecord wait after local kill", "", waitErr, 0)
		}
	}

	m.clearRecord(serial, cmd)

	// KEY FIX: Force Android filesystem sync before waiting for the file.
	// screenrecord exits, but Android's buffer cache may not have flushed
	// the MP4 data to storage yet. Run sync multiple times — some slow
	// storage controllers need more than one round to actually flush.
	// Errors are best-effort: sync may not be available on all devices.
	for i := 0; i < 3; i++ {
		if _, err := m.run("-s", serial, "shell", "sync"); err != nil {
			Log.Add(fmt.Sprintf("screenrecord sync round %d", i+1), "", err, 0)
		}
	}

	return m.waitRecordedVideo(serial, 20*time.Second)
}

// killScreenRecordOnDevice sends SIGINT to the running screenrecord process
// on the Android device. This is more reliable than sending os.Interrupt
// from the host, because it avoids cross-platform signal forwarding issues
// (Windows CTRL_C_EVENT vs Unix SIGINT).
func (m *AdbManager) killScreenRecordOnDevice(serial string) {
	// Try pgrep first (most Android devices have it via toybox).
	// pgrep returns the PID; -o = oldest match if multiple.
	// Fallback to pidof for devices without pgrep.
	// The $! shell trick captures the PID of the last background job,
	// but screenrecord runs in the foreground so we need pgrep/pidof.
	pidCmd := "(pgrep -o screenrecord 2>/dev/null || pidof screenrecord 2>/dev/null || ps -o pid,NAME 2>/dev/null | grep '[s]creenrecord' | awk '{print $1}')"
	out, err := m.run("-s", serial, "shell", "sh", "-c", pidCmd)
	if err != nil || strings.TrimSpace(out) == "" {
		Log.Add("screenrecord find pid", out, err, 0)
		return
	}
	pid := strings.TrimSpace(out)
	// Send SIGINT (equivalent to Ctrl+C) for graceful shutdown.
	_, err = m.run("-s", serial, "shell", "sh", "-c",
		fmt.Sprintf("kill -INT %s 2>/dev/null; kill -0 %s 2>/dev/null && sleep 1 && kill -INT %s 2>/dev/null", pid, pid, pid))
	if err != nil {
		Log.Add("screenrecord device kill -INT", "", err, 0)
	}
	// Give screenrecord a moment to flush and exit.
	time.Sleep(500 * time.Millisecond)
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
	// Capture the file size before deleting so the log entry has a
	// concrete number to grep for. Use Log.Add for both success (with
	// size) and failure (with stderr) so the user can see in the
	// backend log whether the rm actually went through.
	size, _ := m.remoteFileSize(serial, recordedVideoPath)
	out, err := m.run("-s", serial, "shell", "rm", "-f", recordedVideoPath)
	if err != nil {
		Log.Add(
			fmt.Sprintf("screenrecord clean remote video (size=%d before delete)", size),
			out, err, 0)
	} else {
		Log.Add(
			fmt.Sprintf("screenrecord clean remote video (size=%d deleted)", size),
			out, nil, 0)
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
	// Give the filesystem a moment to flush buffers after screenrecord exits.
	// Without this, Android's buffer cache may delay writing the MP4 data
	// to storage, causing false "file not available" errors.
	// 2s is a safe default for most devices.
	const fsFlushDelay = 2 * time.Second

	// Wait for the initial flush window first.
	time.Sleep(fsFlushDelay)

	// Remaining time for polling.
	remaining := timeout - fsFlushDelay
	if remaining <= 0 {
		size, err := m.remoteFileSize(serial, recordedVideoPath)
		if err == nil && size >= minViableVideoSize {
			return nil
		}
		return fmt.Errorf("recorded video not available after %s (timeout too short)", timeout)
	}

	deadline := time.Now().Add(remaining)

	// Poll for file availability with size stability check.
	// A file is "ready" when: it exists, has ≥ minViableVideoSize bytes,
	// and its size hasn't changed across two consecutive polls.
	var lastSize int64 = -1
	stableCount := 0
	const minStablePolls = 2

	for time.Now().Before(deadline) {
		size, err := m.remoteFileSize(serial, recordedVideoPath)
		if err == nil && size >= minViableVideoSize {
			if size == lastSize {
				stableCount++
				if stableCount >= minStablePolls {
					return nil
				}
			} else {
				lastSize = size
				stableCount = 0
			}
		} else {
			lastSize = -1
			stableCount = 0
		}
		time.Sleep(400 * time.Millisecond)
	}

	// Last-ditch check at the deadline.
	size, err := m.remoteFileSize(serial, recordedVideoPath)
	if err == nil && size >= minViableVideoSize {
		return nil
	}

	return fmt.Errorf("recorded video not available after %s", timeout)
}

func (m *AdbManager) remoteFileSize(serial, path string) (int64, error) {
	// Try multiple methods, in order of reliability:
	//  1. stat -c %s  — GNU stat (most Android devices)
	//  2. stat -f %z  — BSD stat (some devices)
	//  3. ls -l        — parse 5th column
	//  4. wc -c        — read byte count directly
	commands := []string{
		"stat -c %s " + path + " 2>/dev/null",
		"stat -f %z " + path + " 2>/dev/null",
		"ls -l " + path + " 2>/dev/null | awk '{print $5}'",
		"wc -c < " + path + " 2>/dev/null",
	}

	for _, cmd := range commands {
		out, err := m.run("-s", serial, "shell", "sh", "-c", cmd)
		if err != nil {
			continue
		}
		out = strings.TrimSpace(out)
		if out == "" {
			continue
		}
		// Extract first valid positive integer from output.
		for _, field := range strings.Fields(out) {
			if size, err := strconv.ParseInt(field, 10, 64); err == nil && size > 0 {
				return size, nil
			}
		}
	}
	return 0, fmt.Errorf("could not determine file size for %s", path)
}
