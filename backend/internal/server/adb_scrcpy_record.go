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
	"strings"
	"sync"
	"time"
)

// ErrScrcpyBusy is returned by StartScrcpyRecording when another scrcpy
// subprocess is already running (mirror or recording). The handler
// surfaces it as 409 with the kind in the data field so the UI can
// decide whether to prompt the user to preempt.
var ErrScrcpyBusy = errors.New("scrcpy is in use")

// scrcpyRecordState holds the live windowless-recording scrcpy
// subprocess. Like the mirror state, there's only one such process
// per host (one scrcpy at a time). The output path is final — scrcpy
// appends its own timestamp/extension suffix internally when
// `--record` is given as a directory, so we pass a fully-qualified
// file path here and trust scrcpy to write to it as-is.
type scrcpyRecordState struct {
	mu         sync.Mutex
	cmd        *exec.Cmd
	serial     string
	outputPath string
	started    time.Time
	done       chan struct{} // closed when cmd.Wait returns
}

func (s *scrcpyRecordState) reset() {
	s.cmd = nil
	s.serial = ""
	s.outputPath = ""
	s.started = time.Time{}
	s.done = nil
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

// StartScrcpyRecording spawns a windowless scrcpy that records to
// outputPath. The outputPath is a host file path; we expect the
// caller (Flutter) to have already verified the directory exists and
// is writable.
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
// The outputPath is fully-qualified and the file is opened by scrcpy
// itself, so we don't need to do any I/O on the host side. If scrcpy
// fails to start (binary missing, adb connection refused, etc.) we
// return the raw error and the caller surfaces it.
func (m *AdbManager) StartScrcpyRecording(serial, outputPath string, force bool) error {
	if serial == "" {
		return fmt.Errorf("serial required")
	}
	if outputPath == "" {
		return fmt.Errorf("outputPath required")
	}

	// Reject obviously bad paths before spawning. The handler also
	// checks this, but defending here keeps the engine from holding
	// the lock while doing filesystem I/O.
	dir := filepath.Dir(outputPath)
	if info, err := os.Stat(dir); err != nil {
		return fmt.Errorf("output directory: %w", err)
	} else if !info.IsDir() {
		return fmt.Errorf("output directory is not a directory: %s", dir)
	}

	// Probe writability by creating and immediately closing a temp
	// file. Cheap; fails fast on read-only mounts.
	probe, err := os.CreateTemp(dir, ".adb-tool-record-probe-*")
	if err != nil {
		return fmt.Errorf("output directory not writable: %w", err)
	}
	probe.Close()
	os.Remove(probe.Name())

	paths, err := FindScrcpy(m.scrcpyFS)
	if err != nil {
		return err
	}

	m.scrcpyRecord.mu.Lock()
	defer m.scpyRecordUnlock() // see below — keeps the per-state unlock DRY

	// Recording already running? Kill and restart. No "force" knob
	// here — a second recording click is unambiguously "I want a
	// new one, replace the old".
	if m.scrcpyRecord.cmd != nil && m.scpyRecordProcessAlive() {
		m.killRecordingLocked("replaced by new recording")
	}

	// Mirror running? Refuse (force=false) or graceful-kill
	// (force=true). The kill uses the same terminateScrcpyProcess
	// helper the existing StartScrcpy uses, so it finalizes any
	// in-progress mirror recording gracefully — but the mirror
	// record path is a different code path anyway, so this is
	// mostly about clean SDL shutdown.
	if m.scrcpy.cmd != nil && m.scrcpy.cmd.Process != nil {
		if !force {
			return &scrcpyRecordBusyError{
				Kind:   scrcpyRecordBusyMirror,
				Serial: m.scrcpy.serial,
			}
		}
		m.killMirrorForRecordLocked("preempted by recording")
	}

	args := []string{
		"-s", serial,
		"--no-window", // windowless — the whole point of this path
		"--no-playback",
		"--record=" + outputPath,
		// Sensible defaults; users can tweak via the recording
		// settings page if we ever expose them.
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
		return fmt.Errorf("start scrcpy recording: %w", err)
	}

	done := make(chan struct{})
	m.scrcpyRecord.cmd = cmd
	m.scrcpyRecord.serial = serial
	m.scrcpyRecord.outputPath = outputPath
	m.scrcpyRecord.started = time.Now()
	m.scrcpyRecord.done = done

	Log.Add("scrcpy recording started",
		fmt.Sprintf("serial=%s arch=%s pid=%d output=%s",
			serial, paths.Arch, cmd.Process.Pid, outputPath),
		nil, 0)

	// Same "exited → clear state" goroutine as the mirror, but
	// isolated to its own state slot. We use a local cmd closure to
	// avoid a race where this goroutine references a *exec.Cmd that
	// a later StartScrcpyRecording has already replaced.
	go func() {
		waitErr := cmd.Wait()
		close(done)

		m.scrcpyRecord.mu.Lock()
		if m.scrcpyRecord.cmd == cmd {
			elapsed := time.Since(m.scrcpyRecord.started)
			m.scrcpyRecord.reset()
			result := fmt.Sprintf("serial=%s output=%s exit=%s",
				serial, outputPath, describeExit(waitErr))
			if tail := out.tail(800); tail != "" {
				result += " output=" + tail
			}
			Log.Add("scrcpy recording exited", result, nil, elapsed)
		}
		m.scrcpyRecord.mu.Unlock()
	}()

	return nil
}

// scpyRecordUnlock / scpyRecordProcessAlive / killRecordingLocked /
// killMirrorForRecordLocked — small helpers that keep the lock-handling
// conventions visible inline. We use the same locking scheme as the
// mirror code (single mutex per state slot, never touch fields without
// holding it) so a future refactor can keep both code paths in sync.

// scpyRecordUnlock defers correctly: the recorder takes one lock at a
// time, so defer-friendly wrapper is just Unlock. Kept as a separate
// name so any future expansion (e.g. ordered mirror + record locks)
// is a single search-and-replace.
func (m *AdbManager) scpyRecordUnlock() { m.scrcpyRecord.mu.Unlock() }

func (m *AdbManager) scpyRecordProcessAlive() bool {
	cmd := m.scrcpyRecord.cmd
	if cmd == nil || cmd.Process == nil {
		return false
	}
	// cmd.ProcessState is non-nil iff the process has already been
	// reaped. We don't call Wait here (that would block the mutex
	// holder on a slow exit); instead rely on the goroutine above
	// to set state via reset() and trust that a non-nil Process
	// implies "alive" until then.
	return cmd.ProcessState == nil
}

// killRecordingLocked sends a graceful shutdown to the recording
// subprocess and waits up to 10s for it to finalize the MP4 muxer.
// Caller must hold m.scrcpyRecord.mu.
func (m *AdbManager) killRecordingLocked(reason string) {
	cmd := m.scrcpyRecord.cmd
	done := m.scrcpyRecord.done
	if cmd == nil || cmd.Process == nil {
		m.scrcpyRecord.reset()
		return
	}
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
	m.scrcpyRecord.reset()
}

// killMirrorForRecordLocked graceful-kills the mirror subprocess to
// free the adb connection for a recording. Used only when force=true
// on StartScrcpyRecording. The mirror's own state (scrcpy.cmd etc.)
// is reset by the mirror's exit goroutine — we don't reach across
// and clear it from here.
//
// We hold BOTH the mirror and record locks during this call. Order
// is consistent (record first, then mirror) to avoid deadlock with
// any future mirror-side code that also needs to coordinate with
// recording. (None exists today, but cheap to get right.)
func (m *AdbManager) killMirrorForRecordLocked(reason string) {
	// We already hold scrcpyRecord.mu. Take scrcpy.mu (record-then-
	// mirror order) so a future caller doing mirror-then-record sees
	// the same order.
	m.scrcpy.mu.Lock()
	defer m.scrcpy.mu.Unlock()

	cmd := m.scrcpy.cmd
	done := m.scrcpy.done
	if cmd == nil || cmd.Process == nil {
		return
	}
	if err := terminateScrcpyProcess(cmd.Process); err != nil {
		Log.Add("scrcpy mirror stop signal (preempted by recording)", reason, err, 0)
	}
	select {
	case <-done:
		Log.Add("scrcpy mirror stopped", "reason="+reason+" graceful", nil, 0)
	case <-time.After(10 * time.Second):
		Log.Add("scrcpy mirror stop timeout",
			"reason="+reason+" forcing kill after 10s", nil, 10*time.Second)
		_ = cmd.Process.Kill()
	}
	// Don't reset scrcpy state here — the mirror's own exit
	// goroutine owns that field. We only need the process gone.
}

// StopScrcpyRecording gracefully stops the recording subprocess. No-op
// if nothing is recording. Returns nil even if there was nothing to
// stop (matches StopScrcpy semantics: stopping a non-running
// subprocess is a no-op from the user's perspective).
func (m *AdbManager) StopScrcpyRecording() error {
	m.scrcpyRecord.mu.Lock()
	defer m.scrcpyRecord.mu.Unlock()

	cmd := m.scrcpyRecord.cmd
	if cmd == nil || cmd.Process == nil {
		return nil
	}
	if err := terminateScrcpyProcess(cmd.Process); err != nil {
		Log.Add("scrcpy recording stop signal", "", err, 0)
		// Don't return — still wait for done so the state clears.
	}
	done := m.scrcpyRecord.done
	select {
	case <-done:
		Log.Add("scrcpy recording stopped", "graceful", nil, 0)
	case <-time.After(10 * time.Second):
		Log.Add("scrcpy recording stop timeout",
			"forcing kill after 10s", nil, 10*time.Second)
		_ = cmd.Process.Kill()
	}
	m.scrcpyRecord.reset()
	return nil
}

// ScrcpyRecordingStatus returns a snapshot of the windowless recording
// subprocess.
func (m *AdbManager) ScrcpyRecordingStatus() (running bool, serial, outputPath string, pid int, elapsed time.Duration) {
	m.scrcpyRecord.mu.Lock()
	defer m.scrcpyRecord.mu.Unlock()

	if m.scrcpyRecord.cmd == nil || m.scrcpyRecord.cmd.Process == nil {
		return false, "", "", 0, 0
	}
	return true,
		m.scrcpyRecord.serial,
		m.scrcpyRecord.outputPath,
		m.scrcpyRecord.cmd.Process.Pid,
		time.Since(m.scrcpyRecord.started)
}

// isScrcpyRecordBusy is a single-call probe used by tests and by
// future endpoints that want to gate on "any scrcpy is recording".
func (m *AdbManager) isScrcpyRecordBusy() bool {
	m.scrcpyRecord.mu.Lock()
	defer m.scrcpyRecord.mu.Unlock()
	return m.scpyRecordProcessAlive()
}

// isScrcpyRecordOutputPath is a path validation helper exposed for
// the handler. Returns the cleaned absolute path plus a nil error if
// the path is acceptable.
func (m *AdbManager) isScrcpyRecordOutputPath(p string) error {
	if p == "" {
		return errors.New("outputPath required")
	}
	cleaned := filepath.Clean(p)
	if !filepath.IsAbs(cleaned) {
		return errors.New("outputPath must be absolute")
	}
	dir := filepath.Dir(cleaned)
	info, err := os.Stat(dir)
	if err != nil {
		return fmt.Errorf("output directory: %w", err)
	}
	if !info.IsDir() {
		return fmt.Errorf("output directory is not a directory: %s", dir)
	}
	// basename sanity: scrcpy will write to this path verbatim, so an
	// empty basename would be a bug. Filename with NUL is always a
	// bug.
	base := filepath.Base(cleaned)
	if base == "" || base == "." || base == ".." {
		return errors.New("outputPath has invalid basename")
	}
	if strings.ContainsRune(base, 0) {
		return errors.New("outputPath contains NUL")
	}
	return nil
}
