package server

import (
	"bytes"
	"context"
	"fmt"
	"os/exec"
	"strings"
	"sync"
	"time"
)

// syncBuffer is a goroutine-safe bytes.Buffer. scrcpy writes to stdout
// and stderr from its own threads while our Wait goroutine reads the
// captured tail on exit, so the writes and the final read must be
// serialized.
type syncBuffer struct {
	mu  sync.Mutex
	buf bytes.Buffer
}

func (b *syncBuffer) Write(p []byte) (int, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.buf.Write(p)
}

// tail returns at most the last n bytes written, trimmed, with inner
// blank lines collapsed so the log entry stays readable.
func (b *syncBuffer) tail(n int) string {
	b.mu.Lock()
	defer b.mu.Unlock()
	s := strings.TrimSpace(b.buf.String())
	if len(s) > n {
		s = "..." + s[len(s)-n:]
	}
	return strings.ReplaceAll(s, "\n", " | ")
}

// scrcpyAction is the set of system-level shortcuts we expose over the
// scrcpy UI. Each value maps to an `adb shell input keyevent` code.
// We deliberately keep this list small — it's the actions that are
// tedious to reach while scrcpy is focused on the device window but
// cheap to fire as a button click from our Flutter shell.
type scrcpyAction string

const (
	scrcpyActionHome       scrcpyAction = "home"
	scrcpyActionBack       scrcpyAction = "back"
	scrcpyActionRecents    scrcpyAction = "recents"
	scrcpyActionPower      scrcpyAction = "power"
	scrcpyActionVolumeUp   scrcpyAction = "volume_up"
	scrcpyActionVolumeDown scrcpyAction = "volume_down"
	scrcpyActionMenu       scrcpyAction = "menu"
)

// androidKeyCode maps scrcpyAction to the Android `input keyevent`
// constant (KEYCODE_* from android.view.KeyEvent). Unknown actions
// return an error so the handler can return 400 instead of silently
// firing a no-op.
func (a scrcpyAction) androidKeyCode() (int, error) {
	switch a {
	case scrcpyActionHome:
		return 3, nil // KEYCODE_HOME
	case scrcpyActionBack:
		return 4, nil // KEYCODE_BACK
	case scrcpyActionRecents:
		return 187, nil // KEYCODE_APP_SWITCH
	case scrcpyActionPower:
		return 26, nil // KEYCODE_POWER
	case scrcpyActionVolumeUp:
		return 24, nil // KEYCODE_VOLUME_UP
	case scrcpyActionVolumeDown:
		return 25, nil // KEYCODE_VOLUME_DOWN
	case scrcpyActionMenu:
		return 82, nil // KEYCODE_MENU
	}
	return 0, fmt.Errorf("unknown scrcpy action: %q", a)
}

// scrcpyState holds the live scrcpy subprocess and the device it's
// attached to. One per mirrored device, stored in AdbManager.scrcpyMap.
// Protected by AdbManager.scrcpyMu (map-level lock, not per-entry).
type scrcpyState struct {
	cmd     *exec.Cmd
	serial  string
	started time.Time
	done    chan struct{} // closed when cmd.Wait returns
}

// StartScrcpy spawns the bundled scrcpy binary attached to the given
// serial, applying the user-supplied options. If a previous scrcpy
// instance for the same device is still running it's killed first.
// Different devices can run mirror concurrently.
//
// Refuses to start if the same device has an active recording (the
// two scrcpy invocations are mutually exclusive per device).
func (m *AdbManager) StartScrcpy(serial string, opts ScrcpyOptions) error {
	if err := opts.Validate(); err != nil {
		return fmt.Errorf("invalid scrcpy options: %w", err)
	}
	if isZeroOptions(opts) {
		opts = DefaultScrcpyOptions()
	}

	paths, err := FindScrcpy(m.scrcpyFS)
	if err != nil {
		return err
	}

	m.scrcpyMu.Lock()
	defer m.scrcpyMu.Unlock()

	// Same-device recording conflict check.
	if rec, ok := m.scrcpyRecordMap[serial]; ok && rec.cmd != nil && rec.cmd.Process != nil && rec.cmd.ProcessState == nil {
		return fmt.Errorf("scrcpy is busy recording (serial=%s)", serial)
	}

	// Kill stale mirror for this device if one exists.
	if old, ok := m.scrcpyMap[serial]; ok && old.cmd != nil && old.cmd.Process != nil {
		if killErr := terminateScrcpyProcess(old.cmd.Process); killErr != nil {
			Log.Add("scrcpy stale kill", "serial="+serial, killErr, 0)
		}
		select {
		case <-old.done:
		case <-time.After(2 * time.Second):
			Log.Add("scrcpy stale wait", "serial="+serial+" timed out after 2s", nil, 2*time.Second)
		}
		delete(m.scrcpyMap, serial)
	}

	args := []string{"-s", serial}
	args = append(args, opts.Args()...)

	cmd := exec.Command(paths.Binary, args...)
	cmd.Dir = paths.Dir
	out := &syncBuffer{}
	cmd.Stdout = out
	cmd.Stderr = out
	configureScrcpySysProc(cmd)

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("start scrcpy: %w", err)
	}

	done := make(chan struct{})
	m.scrcpyMap[serial] = &scrcpyState{
		cmd:     cmd,
		serial:  serial,
		started: time.Now(),
		done:    done,
	}

	Log.Add("scrcpy started",
		fmt.Sprintf("serial=%s arch=%s pid=%d args=%d", serial, paths.Arch, cmd.Process.Pid, len(args)),
		nil, 0)

	go func() {
		waitErr := cmd.Wait()
		close(done)

		m.scrcpyMu.Lock()
		// Only clear if this is still the same instance.
		if cur, ok := m.scrcpyMap[serial]; ok && cur.cmd == cmd {
			elapsed := time.Since(cur.started)
			delete(m.scrcpyMap, serial)
			result := fmt.Sprintf("serial=%s exit=%s", serial, describeExit(waitErr))
			if tail := out.tail(800); tail != "" {
				result += " output=" + tail
			}
			Log.Add("scrcpy exited", result, nil, elapsed)
		}
		m.scrcpyMu.Unlock()
	}()

	return nil
}

// describeExit renders cmd.Wait's error as a short human-readable exit
// status. nil means a clean exit(0) — typically the user closing the
// scrcpy window. A non-zero code usually means scrcpy bailed on its own.
func describeExit(err error) string {
	if err == nil {
		return "0 (clean)"
	}
	if exitErr, ok := err.(*exec.ExitError); ok {
		return fmt.Sprintf("%d", exitErr.ExitCode())
	}
	return err.Error()
}

// StopScrcpy gracefully stops the mirror subprocess for the given
// device. No-op if nothing is running for that serial.
func (m *AdbManager) StopScrcpy(serial string) error {
	m.scrcpyMu.Lock()
	st, ok := m.scrcpyMap[serial]
	if !ok || st.cmd == nil || st.cmd.Process == nil {
		m.scrcpyMu.Unlock()
		return nil
	}
	cmd := st.cmd
	done := st.done
	m.scrcpyMu.Unlock()

	if err := terminateScrcpyProcess(cmd.Process); err != nil {
		Log.Add("scrcpy stop signal", "serial="+serial, err, 0)
		return nil
	}

	select {
	case <-done:
		Log.Add("scrcpy stopped", "serial="+serial+" graceful", nil, 0)
	case <-time.After(10 * time.Second):
		Log.Add("scrcpy stop timeout", "serial="+serial+" forcing kill after 10s", nil, 10*time.Second)
		_ = cmd.Process.Kill()
	}

	return nil
}

// ScrcpyStatus returns the mirror subprocess state for the given
// device. Pass serial="" to get the first running entry (for
// backwards-compatible callers that don't care which device).
func (m *AdbManager) ScrcpyStatus(serial string) (running bool, outSerial string, pid int, elapsed time.Duration) {
	m.scrcpyMu.Lock()
	defer m.scrcpyMu.Unlock()

	if serial != "" {
		if st, ok := m.scrcpyMap[serial]; ok && st.cmd != nil && st.cmd.Process != nil {
			return true, st.serial, st.cmd.Process.Pid, time.Since(st.started)
		}
		return false, "", 0, 0
	}
	// No serial filter — return the first running entry.
	for _, st := range m.scrcpyMap {
		if st.cmd != nil && st.cmd.Process != nil {
			return true, st.serial, st.cmd.Process.Pid, time.Since(st.started)
		}
	}
	return false, "", 0, 0
}

// ScrcpyShortcut fires a system-level shortcut (home/back/recents/etc.)
// against the given device. The serial param exists so the caller can
// target a specific device — the action itself doesn't care which
// device is currently being mirrored, but if you have multiple devices
// and call ScrcpyShortcut on the wrong one the button "feels broken".
//
// Uses an explicit context so a hung adb can't wedge the handler.
// 5s is more than enough for `input keyevent` to round-trip.
func (m *AdbManager) ScrcpyShortcut(serial string, action scrcpyAction) error {
	code, err := action.androidKeyCode()
	if err != nil {
		return err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// `input keyevent N` is the canonical path — works on all Android
	// versions we target, no permissions required for shell uid.
	if _, err := m.runRawContext(ctx, "-s", serial, "shell", "input", "keyevent", fmt.Sprintf("%d", code)); err != nil {
		return fmt.Errorf("keyevent %s: %w", action, err)
	}
	return nil
}
