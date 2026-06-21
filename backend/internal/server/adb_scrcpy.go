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
	scrcpyActionHome      scrcpyAction = "home"
	scrcpyActionBack      scrcpyAction = "back"
	scrcpyActionRecents   scrcpyAction = "recents"
	scrcpyActionPower     scrcpyAction = "power"
	scrcpyActionVolumeUp  scrcpyAction = "volume_up"
	scrcpyActionVolumeDown scrcpyAction = "volume_down"
	scrcpyActionMenu      scrcpyAction = "menu"
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
// attached to. Scrcpy itself is a single-instance desktop app — one
// SDL window per host — so we keep one cmd rather than a per-device map.
type scrcpyState struct {
	mu      sync.Mutex
	cmd     *exec.Cmd
	serial  string
	started time.Time
	done    chan struct{} // closed when cmd.Wait returns
}

// reset clears state after a process exits. Safe to call multiple times.
func (s *scrcpyState) reset() {
	s.cmd = nil
	s.serial = ""
	s.started = time.Time{}
	s.done = nil
}

// StartScrcpy spawns the bundled scrcpy binary attached to the given
// serial. If a previous scrcpy instance is still running it's killed
// first — only one scrcpy window per host makes sense.
//
// The cwd of the subprocess is set to the scrcpy distribution directory
// so scrcpy can locate scrcpy-server (and, on Windows, its sibling
// DLLs) without needing SCRCPY_SERVER_PATH or PATH tricks.
func (m *AdbManager) StartScrcpy(serial string) error {
	paths, err := FindScrcpy(m.scrcpyFS)
	if err != nil {
		return err
	}

	m.scrcpy.mu.Lock()
	defer m.scrcpy.mu.Unlock()

	// If a previous run is still alive, kill it first. We don't surface
	// that failure to the caller — the user asked for a fresh start and
	// the stale process is in the way.
	if m.scrcpy.cmd != nil && m.scrcpy.cmd.Process != nil {
		if killErr := m.scrcpy.cmd.Process.Kill(); killErr != nil {
			Log.Add("scrcpy stale kill", "", killErr, 0)
		}
		// Best-effort drain so cmd.Process isn't reused.
		select {
		case <-m.scrcpy.done:
		case <-time.After(2 * time.Second):
			Log.Add("scrcpy stale wait", "timed out after 2s", nil, 2*time.Second)
		}
		m.scrcpy.reset()
	}

	args := []string{
		"-s", serial,
		"--no-window-decoration",
		"--stay-awake",
		// --max-size keeps the SDL window manageable on phones that
		// ship 1440p+ panels. 1024 is a sane cap for the user to
		// glance at while doing other things in the Flutter shell.
		"--max-size", "1024",
		"--bit-rate", "8M",
	}

	cmd := exec.Command(paths.Binary, args...)
	cmd.Dir = paths.Dir
	// Capture scrcpy's stdout/stderr into an in-memory buffer instead
	// of inheriting them. On Windows we set CREATE_NO_WINDOW (no
	// console at all), so inherited streams would go nowhere and any
	// "could not connect" / "server push failed" message scrcpy prints
	// right before it exits would be lost. Buffering lets us attach the
	// output tail to the "scrcpy exited" log entry for diagnosis.
	out := &syncBuffer{}
	cmd.Stdout = out
	cmd.Stderr = out
	// The platform-specific configureScrcpySysProc sets CREATE_NO_WINDOW
	// on Windows so no console box pops up alongside the SDL window.
	configureScrcpySysProc(cmd)

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("start scrcpy: %w", err)
	}

	done := make(chan struct{})
	m.scrcpy.cmd = cmd
	m.scrcpy.serial = serial
	m.scrcpy.started = time.Now()
	m.scrcpy.done = done

	Log.Add("scrcpy started", fmt.Sprintf("serial=%s arch=%s pid=%d", serial, paths.Arch, cmd.Process.Pid), nil, 0)

	// Background goroutine: when scrcpy exits, clear state. This is the
	// only way we notice a user closes the SDL window directly.
	go func() {
		waitErr := cmd.Wait()
		close(done)

		m.scrcpy.mu.Lock()
		// Only clear if this is still the same instance (a fresh
		// StartScrcpy may have replaced it by now).
		if m.scrcpy.cmd == cmd {
			elapsed := time.Since(m.scrcpy.started)
			m.scrcpy.reset()
			// Surface the exit code and the captured output tail so an
			// unexpected early exit (auth denied, encoder unsupported,
			// missing DLL, etc.) is visible in the backend log rather
			// than appearing as a bare "scrcpy exited".
			result := fmt.Sprintf("serial=%s exit=%s", serial, describeExit(waitErr))
			if tail := out.tail(800); tail != "" {
				result += " output=" + tail
			}
			Log.Add("scrcpy exited", result, nil, elapsed)
		}
		m.scrcpy.mu.Unlock()
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

// StopScrcpy kills the running scrcpy subprocess (if any). Safe to call
// when nothing is running — returns nil in that case.
func (m *AdbManager) StopScrcpy() error {
	m.scrcpy.mu.Lock()
	cmd := m.scrcpy.cmd
	done := m.scrcpy.done
	m.scrcpy.mu.Unlock()

	if cmd == nil || cmd.Process == nil {
		return nil
	}

	if err := cmd.Process.Kill(); err != nil {
		// Process already gone — that's fine, treat as success.
		Log.Add("scrcpy stop kill", "", err, 0)
		return nil
	}

	select {
	case <-done:
	case <-time.After(3 * time.Second):
		// Force-kill if graceful stop is too slow.
		Log.Add("scrcpy stop timeout", "forcing kill after 3s", nil, 3*time.Second)
		_ = cmd.Process.Kill()
	}

	return nil
}

// ScrcpyStatus returns a snapshot of the current scrcpy process.
func (m *AdbManager) ScrcpyStatus() (running bool, serial string, pid int, elapsed time.Duration) {
	m.scrcpy.mu.Lock()
	defer m.scrcpy.mu.Unlock()

	if m.scrcpy.cmd == nil || m.scrcpy.cmd.Process == nil {
		return false, "", 0, 0
	}
	return true, m.scrcpy.serial, m.scrcpy.cmd.Process.Pid, time.Since(m.scrcpy.started)
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