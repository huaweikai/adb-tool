package server

import (
	"context"
	"encoding/json"
	"log"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// WsCommand is the inbound command frame from the Flutter logcat
// screen.
type WsCommand struct {
	Action  string    `json:"action"`
	Serial  string    `json:"serial"`
	Filters LogFilter `json:"filters"`
}

// WsMessage is the outbound frame. Type is "logs" / "status" /
// "error" / "pong" / "crash".
type WsMessage struct {
	Type  string      `json:"type"`
	Data  string      `json:"data,omitempty"`
	Lines []string    `json:"lines,omitempty"`
	Crash *CrashEvent `json:"crash,omitempty"`
}

// LogSession is the per-WebSocket-connection state for the logcat
// screen. It does NOT own a logcat subprocess — that lives in the
// shared LogcatStreamManager (one per device). The session simply
// subscribes to the manager and forwards lines to the frontend.
//
// This replaces the old design where every WS connection spawned
// its own `adb logcat` subprocess, which meant N sessions on the
// same device = N subprocesses, each restarting on filter change
// (lost context, churn).
type LogSession struct {
	conn      *websocket.Conn
	logcatMgr *LogcatStreamManager
	writeMu   sync.Mutex
	mu        sync.Mutex

	serial  string
	paused  bool
	filters LogFilter

	// Active line subscription; nil if not started.
	sub *LineSubscription

	// Active crash subscription; nil if not started.
	crashSub *CrashSubscription

	// Reader goroutine lifecycle.
	readerCancel  context.CancelFunc
	readerDone    chan struct{}
	crashCancel   context.CancelFunc
	crashReaderDone chan struct{}

	// Lines accumulated while paused. Drop-old beyond 5000.
	pauseBuffer []string
}

// NewLogSession wires a WS connection to the shared logcat manager.
func NewLogSession(conn *websocket.Conn, mgr *LogcatStreamManager) *LogSession {
	return &LogSession{
		conn:        conn,
		logcatMgr:   mgr,
		pauseBuffer: make([]string, 0, 1000),
	}
}

// Run reads WS commands until the client disconnects. The actual
// line streaming is driven by a reader goroutine spawned in
// startSubscription.
func (s *LogSession) Run() {
	defer s.conn.Close()
	defer s.stopSubscription() // releases reader + manager subscription

	for {
		_, msgBytes, err := s.conn.ReadMessage()
		if err != nil {
			return
		}

		var cmd WsCommand
		if err := json.Unmarshal(msgBytes, &cmd); err != nil {
			s.sendMsg("error", "invalid command: "+err.Error())
			continue
		}

		switch cmd.Action {
		case "start":
			s.startSubscription(cmd.Serial, cmd.Filters)
		case "stop":
			s.stopSubscription()
		case "pause":
			s.setPaused(true)
			s.sendMsg("status", "paused")
		case "resume":
			s.flushPauseBuffer()
			s.setPaused(false)
			s.sendMsg("status", "running")
		case "clear":
			s.handleClear()
		case "filter":
			s.setFilters(cmd.Filters)
			s.sendMsg("status", "filter_updated")
		case "ping":
			s.sendMsg("pong", "")
		}
	}
}

const (
	logBatchMaxLines = 120
	logBatchInterval = 50 * time.Millisecond
	logReplayLines   = 200 // how many recent ring-buffer lines to deliver on subscribe
	pauseBufferCap   = 5000
	pauseBufferKeep  = 2500 // when overflow, keep this many tail
)

// startSubscription swaps to a new device stream. Cancels any
// prior subscription first; the manager's per-device watcher keeps
// running for other sessions.
func (s *LogSession) startSubscription(serial string, filters LogFilter) {
	s.stopSubscription()

	if serial == "" {
		s.sendMsg("error", "no device selected")
		return
	}

	// Idempotent. If the device event stream already started the
	// watcher, this is a no-op. If not (race: WS opened before the
	// first track-devices snapshot landed), it kicks off spawn now.
	s.logcatMgr.Ensure(serial)

	sub, err := s.logcatMgr.Subscribe(serial, logReplayLines)
	if err != nil {
		s.sendMsg("error", "subscribe failed: "+err.Error())
		return
	}

	crashSub, err := s.logcatMgr.SubscribeCrash(serial)
	if err != nil {
		s.sendMsg("error", "crash subscribe failed: "+err.Error())
		sub.Cancel()
		return
	}

	s.mu.Lock()
	subCopy := sub
	s.sub = &subCopy
	crashSubCopy := crashSub
	s.crashSub = &crashSubCopy
	s.serial = serial
	s.filters = filters
	s.pauseBuffer = s.pauseBuffer[:0]
	s.paused = false
	s.mu.Unlock()

	s.sendMsg("status", "running")

	ctx, cancel := context.WithCancel(context.Background())
	s.mu.Lock()
	s.readerCancel = cancel
	done := make(chan struct{})
	s.readerDone = done
	s.mu.Unlock()

	go s.readerLoop(ctx, subCopy, done)

	crashCtx, crashCancel := context.WithCancel(context.Background())
	s.mu.Lock()
	s.crashCancel = crashCancel
	crashDone := make(chan struct{})
	s.crashReaderDone = crashDone
	s.mu.Unlock()

	go s.crashReaderLoop(crashCtx, crashSubCopy, crashDone)
}

// stopSubscription cancels the reader goroutines and releases the
// manager subscriptions. Idempotent.
func (s *LogSession) stopSubscription() {
	s.mu.Lock()
	cancel := s.readerCancel
	done := s.readerDone
	s.readerCancel = nil
	s.readerDone = nil
	crashCancel := s.crashCancel
	crashDone := s.crashReaderDone
	s.crashCancel = nil
	s.crashReaderDone = nil
	sub := s.sub
	s.sub = nil
	crashSub := s.crashSub
	s.crashSub = nil
	s.serial = ""
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
	if crashCancel != nil {
		crashCancel()
	}
	if crashDone != nil {
		<-crashDone
	}
	if crashSub != nil {
		crashSub.Cancel()
	}
	s.sendMsg("status", "stopped")
}

// readerLoop pulls lines from the subscription channel and forwards
// them to the WS in batches. Pauses buffer locally; resumes flush
// the buffer first, then resume live streaming.
func (s *LogSession) readerLoop(ctx context.Context, sub LineSubscription, done chan struct{}) {
	defer close(done)

	ticker := time.NewTicker(logBatchInterval)
	defer ticker.Stop()
	batch := make([]string, 0, logBatchMaxLines)

	flush := func() {
		if len(batch) == 0 {
			return
		}
		s.sendLogs(batch)
		batch = batch[:0]
	}

	for {
		select {
		case <-ctx.Done():
			flush()
			return
		case <-ticker.C:
			flush()
		case line, ok := <-sub.Lines:
			if !ok {
				flush()
				return
			}

			line = strings.TrimRight(line, "\r\n")

			s.mu.Lock()
			f := s.filters
			paused := s.paused
			s.mu.Unlock()

			if !matchFiltersLine(line, f) {
				continue
			}

			if paused {
				s.mu.Lock()
				s.pauseBuffer = append(s.pauseBuffer, line)
				if len(s.pauseBuffer) > pauseBufferCap {
					// Drop oldest half so resume doesn't dump a
					// flood onto the WS.
					s.pauseBuffer = s.pauseBuffer[len(s.pauseBuffer)-pauseBufferKeep:]
				}
				s.mu.Unlock()
				continue
			}

			batch = append(batch, line)
			if len(batch) >= logBatchMaxLines {
				flush()
			}
		}
	}
}

// crashReaderLoop pulls crash events from the subscription channel
// and forwards them to the WS client. Crash events are rare, so this
// loop just blocks on the channel and sends each event individually.
func (s *LogSession) crashReaderLoop(ctx context.Context, sub CrashSubscription, done chan struct{}) {
	defer close(done)

	for {
		select {
		case <-ctx.Done():
			return
		case ev, ok := <-sub.Events:
			if !ok {
				return
			}
			s.sendCrash(ev)
		}
	}
}

// flushPauseBuffer drains the pause buffer into a single batch and
// sends it. Called on resume.
func (s *LogSession) flushPauseBuffer() {
	s.mu.Lock()
	if len(s.pauseBuffer) == 0 {
		s.mu.Unlock()
		return
	}
	buf := make([]string, len(s.pauseBuffer))
	copy(buf, s.pauseBuffer)
	s.pauseBuffer = s.pauseBuffer[:0]
	s.mu.Unlock()
	s.sendLogs(buf)
}

// handleClear resets the local pause buffer only. The device-side
// logcat buffer is NOT cleared — the shared manager process is
// always reading it, and a `logcat -c` would tear out lines from
// under other sessions. The manager's ring buffer is also NOT
// cleared, so the next subscribe still replays recent lines.
func (s *LogSession) handleClear() {
	s.mu.Lock()
	s.pauseBuffer = s.pauseBuffer[:0]
	s.mu.Unlock()

	s.sendMsg("status", "cleared")
}

func (s *LogSession) setPaused(v bool) {
	s.mu.Lock()
	s.paused = v
	s.mu.Unlock()
}

func (s *LogSession) setFilters(f LogFilter) {
	s.mu.Lock()
	s.filters = f
	s.mu.Unlock()
}

// sendMsg / sendLogs / sendCrash / writeJSON — WS write plumbing. Concurrent
// callers (Run + readerLoop + crashReaderLoop) are serialized by writeMu.

func (s *LogSession) sendMsg(msgType, data string) {
	s.writeJSON(WsMessage{Type: msgType, Data: data})
}

func (s *LogSession) sendLogs(lines []string) {
	if len(lines) == 0 {
		return
	}
	copied := make([]string, len(lines))
	copy(copied, lines)
	s.writeJSON(WsMessage{Type: "logs", Lines: copied})
}

func (s *LogSession) sendCrash(ev CrashEvent) {
	s.writeJSON(WsMessage{Type: "crash", Crash: &ev})
}

func (s *LogSession) writeJSON(msg WsMessage) {
	payload, err := json.Marshal(msg)
	if err != nil {
		log.Printf("json marshal error: %v", err)
		return
	}

	s.writeMu.Lock()
	defer s.writeMu.Unlock()

	if err := s.conn.SetWriteDeadline(time.Now().Add(5 * time.Second)); err != nil {
		log.Printf("websocket deadline error: %v", err)
		return
	}
	if err := s.conn.WriteMessage(websocket.TextMessage, payload); err != nil {
		log.Printf("websocket write error: %v", err)
	}
}

// =====================================================================
// filter helpers (package-level — stateless, used by readerLoop)
// =====================================================================

// priorityRank: logcat priorities in ascending visibility.
// V = verbose (lowest), F = fatal (highest, except S=silent which
// shouldn't appear in output).
var priorityRank = map[byte]int{
	'V': 0, 'D': 1, 'I': 2, 'W': 3, 'E': 4, 'F': 5,
}

// matchFiltersLine returns true if the line passes the filter.
// Filters: Tag (substring on extracted tag), Keyword (substring on
// full line), Priority (line priority >= filter priority), and
// PackageName / PackagePid (substring). All fields are AND-combined;
// an empty filter field is "no constraint".
//
// This replaces the old design where Priority/PackageName/PackagePid
// were passed to adb logcat as command-line arguments. With a shared
// subprocess, we filter client-side. Trade-off: subprocess emits all
// priorities, so volume may be higher; in practice logcat rates are
// modest and the manager's drop-old + ring buffer cap the cost.
func matchFiltersLine(line string, f LogFilter) bool {
	if f.Keyword != "" && !strings.Contains(strings.ToLower(line), strings.ToLower(f.Keyword)) {
		return false
	}
	if f.Tag != "" {
		tagInLine := extractLogcatTag(line)
		if tagInLine != "" && !strings.Contains(strings.ToLower(tagInLine), strings.ToLower(f.Tag)) {
			return false
		}
	}
	if f.Priority != "" {
		linePrio := extractLogcatPriority(line)
		if linePrio != 0 {
			filterRank, ok := priorityRank[f.Priority[0]]
			if !ok {
				filterRank = 0 // unknown filter priority → match all
			}
			if priorityRank[linePrio] < filterRank {
				return false
			}
		}
	}
	// PackagePid is the precise filter (exact PID-column match). When it
	// is set, skip the PackageName substring check — logcat lines rarely
	// contain the full package name as literal text, so the substring
	// check would reject all lines and make the PID filter useless.
	if f.PackagePid != "" {
		if extractLogcatPID(line) != f.PackagePid {
			return false
		}
		return true
	}
	if f.PackageName != "" && !strings.Contains(line, f.PackageName) {
		return false
	}
	return true
}

// extractLogcatTag pulls the tag from a standard threadtime logcat
// line:
//
//	MM-DD HH:MM:SS.mmm  PID TID PRIO TAG: message
//
// Implemented as a regex in logcat_stream_manager.go (used by both
// crash matching and filter matching). Re-declared here was a bug;
// just call the package-level one.