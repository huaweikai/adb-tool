// Windowless scrcpy recording — a separate scrcpy subprocess that runs
// with `--no-window --record=<path>` and writes the MP4 directly to
// the host. This is the recording path used when the user selects
// "scrcpy" as their recording method in the new recording settings
// page (vs. the legacy `adb screenrecord` path which is kept for
// devices that don't play nice with scrcpy).
//
// Why a separate scrcpyState rather than reusing the mirror one:
//   - Mirror wants `--no-window` off (it needs the SDL window).
//   - Recording wants `--no-window` on (no popping window, just write).
//   - They are mutually exclusive on the same device: scrcpy holds
//     the adb-server connection, and a second scrcpy would fail with
//     "device already in use" or steal the connection.
//   - Separating state makes the conflict visible at the type level
//     and lets the mirror UI cleanly say "scrcpy is busy recording,
//     can't start mirror" instead of having to peek at a mode field.
package server

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"time"
)

// ErrScrcpyBusy is returned by StartScrcpyRecording when another scrcpy
// subprocess is already running (mirror or recording). The handler
// surfaces it as 409 with the kind in the data field so the UI can
// decide whether to prompt the user to preempt.
var ErrScrcpyBusy = errors.New("scrcpy is in use")

// scrcpyRecordState holds the live windowless-recording scrcpy
// subprocess. One per recording device, stored in
// AdbManager.scrcpyRecordMap. Protected by AdbManager.scrcpyMu.
type scrcpyRecordState struct {
	cmd        *exec.Cmd
	serial     string
	outputPath string
	started    time.Time
	done       chan struct{} // closed when cmd.Wait returns
}

// scrcpyRecordBusyKind is the discriminator for the 409 response so
// the Flutter side can render a different message depending on
// whether the user has a mirror session or another recording in
// flight.
type scrcpyRecordBusyKind string

const (
	scrcpyRecordBusyMirror scrcpyRecordBusyKind = "mirror"
	scrcpyRecordBusyRecord scrcpyRecordBusyKind = "record"
)

// scrcpyRecordBusyError carries the kind alongside ErrScrcpyBusy so
// the handler can unpack it without string matching.
type scrcpyRecordBusyError struct {
	Kind   scrcpyRecordBusyKind
	Serial string
}

func (e *scrcpyRecordBusyError) Error() string {
	return fmt.Sprintf("scrcpy is in use by %s (serial=%s)", e.Kind, e.Serial)
}

func (e *scrcpyRecordBusyError) Unwrap() error { return ErrScrcpyBusy }

// ScrcpyRecordingSandboxDir returns the host directory where the
// backend writes in-progress scrcpy recordings. We use a fixed
// per-user path under the home directory so:
//   - the user can find the file later if the UI fails to clean up
//     (e.g. the app crashed mid-recording).
//   - the file lives across app restarts, unlike os.TempDir() which
//     is wiped by the OS on reboot.
//   - the path is portable between macOS, Windows, and Linux.
//
// Convention matches the rest of the backend's per-user data
// (~/.adb-tool/emulator for emulator state, ~/.adb-tool/scrcpy_recordings
// for in-flight recordings).
func ScrcpyRecordingSandboxDir() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("resolve home dir for scrcpy sandbox: %w", err)
	}
	return filepath.Join(home, ".adb-tool", "scrcpy_recordings"), nil
}

// StartScrcpyRecording spawns a windowless scrcpy that records to a
// per-call file under ScrcpyRecordingSandboxDir(). The path is
// computed by the backend (not the caller) so the Flutter side has
// nothing to validate or persist — the recording settings page no
// longer asks the user for a destination directory, and the file
// is gone after the user saves it through the system save dialog
// (file-browser flow) or moves it to the session dir
// (test-session flow).
//
// Behavior when something is already running:
//   - If a mirror session is running and force=false → returns
//     *scrcpyRecordBusyError with Kind=mirror so the UI can prompt.
//   - If a mirror session is running and force=true → graceful-kills
//     the mirror (reusing the same terminateScrcpyProcess path the
//     existing StartScrcpy uses to handle stale processes) and starts
//     the recording.
//   - If a previous recording is running → always kills it and
//     starts fresh. There's no "two recordings on one device" path
//     because the saved file would overwrite and the user clearly
//     asked for a new one.
//
// The file is opened by scrcpy itself, so we don't need to do any
// I/O on the host side. If scrcpy fails to start (binary missing,
// adb connection refused, etc.) we return the raw error and the
// caller surfaces it.
func (m *AdbManager) StartScrcpyRecording(serial string, force bool) (string, error) {
	if serial == "" {
		return "", fmt.Errorf("serial required")
	}

	dir, err := ScrcpyRecordingSandboxDir()
	if err != nil {
		return "", err
	}
	if err := os.MkdirAll(dir, 0755); err != nil {
		return "", fmt.Errorf("create scrcpy sandbox: %w", err)
	}
	probe, err := os.CreateTemp(dir, ".adb-tool-record-probe-*")
	if err != nil {
		return "", fmt.Errorf("scrcpy sandbox not writable: %w", err)
	}
	probe.Close()
	os.Remove(probe.Name())

	outputPath := filepath.Join(dir,
		fmt.Sprintf("adb-tool-record_%d.mp4", time.Now().UnixNano()))

	paths, err := FindScrcpy(m.scrcpyFS)
	if err != nil {
		return "", err
	}

	m.scrcpyMu.Lock()

	// Recording already running on this device? Kill and restart.
	if old, ok := m.scrcpyRecordMap[serial]; ok && old.cmd != nil && old.cmd.Process != nil && old.cmd.ProcessState == nil {
		m.killRecordingEntry(old, "replaced by new recording")
		delete(m.scrcpyRecordMap, serial)
	}

	// Same-device mirror conflict check.
	if mirror, ok := m.scrcpyMap[serial]; ok && mirror.cmd != nil && mirror.cmd.Process != nil {
		if !force {
			m.scrcpyMu.Unlock()
			return "", &scrcpyRecordBusyError{
				Kind:   scrcpyRecordBusyMirror,
				Serial: serial,
			}
		}
		m.killMirrorEntry(mirror, "preempted by recording")
	}

	args := []string{
		"-s", serial,
		"--no-window",
		"--no-playback",
		"--record=" + outputPath,
		"--video-bit-rate", "8M",
		"--max-size", "1024",
		"--max-fps", "30",
	}

	cmd := exec.Command(paths.Binary, args...)
	cmd.Dir = paths.Dir
	out := &syncBuffer{}
	cmd.Stdout = out
	cmd.Stderr = out
	configureScrcpySysProc(cmd)

	if err := cmd.Start(); err != nil {
		m.scrcpyMu.Unlock()
		return "", fmt.Errorf("start scrcpy recording: %w", err)
	}

	done := make(chan struct{})
	rec := &scrcpyRecordState{
		cmd:        cmd,
		serial:     serial,
		outputPath: outputPath,
		started:    time.Now(),
		done:       done,
	}
	m.scrcpyRecordMap[serial] = rec
	m.scrcpyMu.Unlock()

	Log.Add("scrcpy recording started",
		fmt.Sprintf("serial=%s arch=%s pid=%d output=%s",
			serial, paths.Arch, cmd.Process.Pid, outputPath),
		nil, 0)

	go func() {
		waitErr := cmd.Wait()
		close(done)

		m.scrcpyMu.Lock()
		if cur, ok := m.scrcpyRecordMap[serial]; ok && cur.cmd == cmd {
			elapsed := time.Since(cur.started)
			delete(m.scrcpyRecordMap, serial)
			result := fmt.Sprintf("serial=%s output=%s exit=%s",
				serial, outputPath, describeExit(waitErr))
			if tail := out.tail(800); tail != "" {
				result += " output=" + tail
			}
			Log.Add("scrcpy recording exited", result, nil, elapsed)
		}
		m.scrcpyMu.Unlock()
	}()

	return outputPath, nil
}

// killRecordingEntry sends a graceful shutdown to a recording entry
// and waits up to 10s. Caller must hold m.scrcpyMu.
func (m *AdbManager) killRecordingEntry(st *scrcpyRecordState, reason string) {
	cmd := st.cmd
	done := st.done
	if cmd == nil || cmd.Process == nil {
		return
	}
	m.killScrcpyServerOnDevice(st.serial)
	if err := terminateScrcpyProcess(cmd.Process); err != nil {
		Log.Add("scrcpy recording stop signal", "reason="+reason, err, 0)
	}
	select {
	case <-done:
		Log.Add("scrcpy recording stopped", "reason="+reason+" graceful", nil, 0)
	case <-time.After(10 * time.Second):
		Log.Add("scrcpy recording stop timeout",
			"reason="+reason+" forcing kill after 10s", nil, 10*time.Second)
		_ = cmd.Process.Kill()
	}
}

// killMirrorEntry sends a graceful shutdown to a mirror entry and
// waits up to 10s. The mirror's own exit goroutine will clean up the
// map entry. Caller must hold m.scrcpyMu.
func (m *AdbManager) killMirrorEntry(st *scrcpyState, reason string) {
	cmd := st.cmd
	done := st.done
	if cmd == nil || cmd.Process == nil {
		return
	}
	if err := terminateScrcpyProcess(cmd.Process); err != nil {
		Log.Add("scrcpy mirror stop signal", "reason="+reason, err, 0)
	}
	select {
	case <-done:
		Log.Add("scrcpy mirror stopped", "reason="+reason+" graceful", nil, 0)
	case <-time.After(10 * time.Second):
		Log.Add("scrcpy mirror stop timeout",
			"reason="+reason+" forcing kill after 10s", nil, 10*time.Second)
		_ = cmd.Process.Kill()
	}
}

// StopScrcpyRecording gracefully stops the recording subprocess for
// the given device. No-op if nothing is recording on that device.
func (m *AdbManager) StopScrcpyRecording(serial string) error {
	m.scrcpyMu.Lock()
	st, ok := m.scrcpyRecordMap[serial]
	if !ok || st.cmd == nil || st.cmd.Process == nil {
		m.scrcpyMu.Unlock()
		return nil
	}
	cmd := st.cmd
	done := st.done
	m.killScrcpyServerOnDevice(serial)
	m.scrcpyMu.Unlock()

	if err := terminateScrcpyProcess(cmd.Process); err != nil {
		Log.Add("scrcpy recording stop signal", "serial="+serial, err, 0)
	}
	select {
	case <-done:
		Log.Add("scrcpy recording stopped", "serial="+serial+" graceful", nil, 0)
	case <-time.After(10 * time.Second):
		Log.Add("scrcpy recording stop timeout",
			"serial="+serial+" forcing kill after 10s", nil, 10*time.Second)
		_ = cmd.Process.Kill()
	}
	return nil
}

// killScrcpyServerOnDevice terminates the scrcpy-server process running
// on the Android device. When scrcpy-server crashes, the local scrcpy
// client detects the adb stream EOF and triggers its normal cleanup —
// including flushing and closing any in-progress recording file.
//
// This is essential on Windows where the recording path uses
// --no-window: without an SDL window, taskkill /pid (no /F) cannot
// deliver WM_CLOSE, so the local process never receives a graceful
// shutdown signal. Killing the remote server side-steps this entirely.
//
// Errors are best-effort: the server may already have exited, or the
// device may be unreachable. Callers still fall back to
// terminateScrcpyProcess and hard-kill on timeout.
func (m *AdbManager) killScrcpyServerOnDevice(serial string) {
	if serial == "" {
		return
	}
	// pkill -9 for immediate death so the stream breaks cleanly.
	// The local scrcpy client handles the abrupt disconnect and
	// runs its own muxer finalization.
	out, err := m.run("-s", serial, "shell", "pkill", "-9", "-f", "scrcpy")
	if err != nil {
		Log.Add("scrcpy-server kill (device)", out, err, 0)
	}
}

// ScrcpyRecordingStatus returns the recording subprocess state for
// the given device. Pass serial="" to get the first running entry.
func (m *AdbManager) ScrcpyRecordingStatus(serial string) (running bool, outSerial, outputPath string, pid int, elapsed time.Duration) {
	m.scrcpyMu.Lock()
	defer m.scrcpyMu.Unlock()

	if serial != "" {
		if st, ok := m.scrcpyRecordMap[serial]; ok && st.cmd != nil && st.cmd.Process != nil {
			return true, st.serial, st.outputPath, st.cmd.Process.Pid, time.Since(st.started)
		}
		return false, "", "", 0, 0
	}
	for _, st := range m.scrcpyRecordMap {
		if st.cmd != nil && st.cmd.Process != nil {
			return true, st.serial, st.outputPath, st.cmd.Process.Pid, time.Since(st.started)
		}
	}
	return false, "", "", 0, 0
}
