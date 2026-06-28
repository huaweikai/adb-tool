package server

import (
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"
)

// LocalRecorder owns zero or more per-device [SessionLogcat] instances used
// by the "save logcat to local file" UI flow (vs. the test-session flow,
// which uses [Server.sessionLogcat] as a singleton).
//
// Each device serial maps to at most one active recording at a time;
// calling [LocalRecorder.Start] for a serial that already has one running
// tears the existing recording down first (same semantics as
// [SessionLogcat.Start] for the test-session singleton).
//
// This type is intentionally thin: the heavy lifting (subprocess, pump,
// 500ms flush) is all in [SessionLogcat]. We just multiplex.
type LocalRecorder struct {
	mu        sync.Mutex
	instances map[string]*SessionLogcat
}

func NewLocalRecorder() *LocalRecorder {
	return &LocalRecorder{instances: make(map[string]*SessionLogcat)}
}

// Start begins a new adb logcat subprocess for the given device, writing
// to <saveDir>/<YYYYMMDD_HHMMSS>.log. If a recording is already running
// for this serial it is replaced.
//
// saveDir is NOT validated as a session dir — the caller (typically the
// handler) controls where the file lands. Use os.TempDir() / a per-process
// scratch dir for the save-to-local flow; use [validateSessionDir] for
// the test-session flow.
func (l *LocalRecorder) Start(adbPath, serial, saveDir, packageName string) (string, error) {
	if serial == "" {
		return "", fmt.Errorf("serial required")
	}
	if saveDir == "" {
		return "", fmt.Errorf("saveDir required")
	}
	if err := os.MkdirAll(saveDir, 0755); err != nil {
		return "", err
	}

	// Tear down any existing recording for this serial. SessionLogcat.Start
	// also does this internally, but doing it here means we can guarantee
	// the map entry is fresh before we publish it under the lock.
	l.mu.Lock()
	if prev, ok := l.instances[serial]; ok {
		l.mu.Unlock()
		prev.Stop()
		l.mu.Lock()
	}

	rec := &SessionLogcat{}
	l.instances[serial] = rec
	l.mu.Unlock()

	if err := rec.Start(adbPath, serial, saveDir, packageName); err != nil {
		l.mu.Lock()
		// Only drop the map entry if it's still ours (avoid racing a
		// concurrent Start for a different session dir).
		if l.instances[serial] == rec {
			delete(l.instances, serial)
		}
		l.mu.Unlock()
		return "", err
	}

	// Return the file path the recorder actually wrote to — slightly
	// more honest than reconstructing it from saveDir+time on the client.
	return rec.Path(), nil
}

// Stop tears down the recording for serial and returns the absolute path
// of the log file that was being written. Returns ("", nil) if no
// recording is active for the serial.
func (l *LocalRecorder) Stop(serial string) (string, error) {
	l.mu.Lock()
	rec, ok := l.instances[serial]
	if ok {
		delete(l.instances, serial)
	}
	l.mu.Unlock()
	if !ok {
		return "", nil
	}
	return rec.Stop(), nil
}

// Status reports whether serial is currently recording and, if so, how
// long it has been. Used by the UI to render the elapsed-time pill.
func (l *LocalRecorder) Status(serial string) (recording bool, elapsed time.Duration) {
	l.mu.Lock()
	rec, ok := l.instances[serial]
	l.mu.Unlock()
	if !ok {
		return false, 0
	}
	return true, time.Since(rec.StartedAt())
}

// StopAll tears down every active recording. Used at server shutdown so
// we don't leak subprocesses.
func (l *LocalRecorder) StopAll() {
	l.mu.Lock()
	snapshot := make([]*SessionLogcat, 0, len(l.instances))
	for _, rec := range l.instances {
		snapshot = append(snapshot, rec)
	}
	l.instances = make(map[string]*SessionLogcat)
	l.mu.Unlock()
	for _, rec := range snapshot {
		rec.Stop()
	}
}

// localRecordingSaveDir builds a per-device scratch dir under os.TempDir().
// Kept here (not in the handler) so unit tests can target a stable path
// scheme.
func localRecordingSaveDir(serial string) string {
	ts := time.Now().Format("20060102_150405")
	return filepath.Join(os.TempDir(), "adb_tool_logcat", serial+"_"+ts)
}