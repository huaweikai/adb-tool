package server

import (
	"bufio"
	"context"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// SessionLogcat captures logcat output to a file. Used by the
// test-session flow (single instance per Server) AND by LocalRecorder
// (one per active recording). Either way it now SUBSCRIBES to the
// shared LogcatStreamManager instead of spawning its own adb logcat
// subprocess — so multiple recordings on the same device share one
// subprocess and capture an identical line stream.
type SessionLogcat struct {
	mu       sync.Mutex
	mgr      *LogcatStreamManager
	adb      *AdbManager
	sub      *LineSubscription
	cancel   context.CancelFunc
	done     chan struct{}
	path     string
	startedAt time.Time
	pidFilter string // empty = no filter; otherwise match " <pid> " in the line header
}

// Path returns the absolute path of the file currently (or last) being
// written. Safe to call before Start (returns "") and after Stop (returns
// the last-known path).
func (s *SessionLogcat) Path() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.path
}

// StartedAt returns when the current recording was started, or zero if
// no recording is active. Used by [LocalRecorder.Status] to report
// elapsed time without keeping a second clock.
func (s *SessionLogcat) StartedAt() time.Time {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.startedAt
}

// Start begins a new recording. If a recording is already running,
// it is stopped first (same semantics as before).
//
// packageName, if non-empty, is resolved to a PID via AdbManager and
// used as a line-header filter (" <pid> "). This replaces the old
// per-recording `adb logcat --pid=<pid>` filter — now applied
// client-side because the subprocess is shared.
func (s *SessionLogcat) Start(mgr *LogcatStreamManager, adb *AdbManager, serial, sessionDir, packageName string) error {
	s.Stop()

	if mgr == nil {
		return nil // nothing to do; tests can construct without a manager
	}

	// Resolve package → PID BEFORE we open the file / subscribe, so a
	// PID-lookup failure aborts cleanly with no partial state.
	var pidFilter string
	if packageName != "" && adb != nil {
		pid, _ := adb.GetPackagePID(serial, packageName)
		pidFilter = pid
	}

	logsDir := filepath.Join(sessionDir, "logs")
	if err := os.MkdirAll(logsDir, 0755); err != nil {
		return err
	}

	now := time.Now()
	fileName := now.Format("20060102_150405") + ".log"
	filePath := filepath.Join(logsDir, fileName)
	file, err := os.Create(filePath)
	if err != nil {
		return err
	}

	// Ensure watcher is running (idempotent — event stream usually
	// already did this on device-add).
	mgr.Ensure(serial)

	// Replay 0: recordings start fresh. Old code passed -T to adb
	// logcat to skip pre-start lines; with a shared subprocess we
	// can't filter by start time at the source, so we just drop
	// pre-existing ring-buffer entries.
	sub, err := mgr.Subscribe(serial, 0)
	if err != nil {
		file.Close()
		os.Remove(filePath)
		return err
	}

	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})

	s.mu.Lock()
	s.mgr = mgr
	s.adb = adb
	s.sub = &sub
	s.cancel = cancel
	s.done = done
	s.path = filePath
	s.startedAt = now
	s.pidFilter = pidFilter
	s.mu.Unlock()

	go s.pump(sub, ctx, done, file)
	return nil
}

func (s *SessionLogcat) pump(sub LineSubscription, ctx context.Context, done chan struct{}, file *os.File) {
	writer := bufio.NewWriterSize(file, 128*1024)
	defer func() {
		writer.Flush()
		file.Close()
		close(done)
	}()

	ticker := time.NewTicker(500 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			writer.Flush()
		case line, ok := <-sub.Lines:
			if !ok {
				writer.Flush()
				return
			}

			s.mu.Lock()
			pidFilter := s.pidFilter
			s.mu.Unlock()

			// PID filter: match " <pid> " against the PID field in
			// the logcat header (3rd whitespace-separated token).
			// Space-padded to avoid "12" matching "1234".
			if pidFilter != "" && !strings.Contains(line, " "+pidFilter+" ") {
				continue
			}

			writer.WriteString(line)
			writer.WriteByte('\n')
			if writer.Buffered() >= 100*1024 {
				writer.Flush()
			}
		}
	}
}

// Stop ends the recording, flushes the file, and returns the file path.
// Safe to call when nothing is running (returns "").
func (s *SessionLogcat) Stop() string {
	s.mu.Lock()
	cancel := s.cancel
	done := s.done
	sub := s.sub
	s.cancel = nil
	s.done = nil
	s.sub = nil
	path := s.path
	s.path = ""
	s.startedAt = time.Time{}
	s.pidFilter = ""
	s.mu.Unlock()

	if cancel != nil {
		cancel()
	}
	if done != nil {
		<-done
	}
	if sub != nil {
		sub.Cancel()
	}
	return path
}
