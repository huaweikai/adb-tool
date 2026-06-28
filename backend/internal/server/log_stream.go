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
// "error" / "pong".
type WsMessage struct {
	Type  string   `json:"type"`
	Data  string   `json:"data,omitempty"`
	Lines []string `json:"lines,omitempty"`
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
	adb       *AdbManager // for ClearLogcat (device-side buffer) only
	writeMu   sync.Mutex
	mu        sync.Mutex

	serial  string
	paused  bool
	filters LogFilter

	// Active subscription; nil if not started.
	sub *LineSubscription

	// Reader goroutine lifecycle.
	readerCancel context.CancelFunc
	readerDone   chan struct{}

	// Lines accumulated while paused. Drop-old beyond 5000.
	pauseBuffer []string
}

// NewLogSession wires a WS connection to the shared logcat manager.
// adb is kept only for ClearLogcat (device-side logcat buffer reset);
// line streaming goes through the manager.
func NewLogSession(conn *websocket.Conn, mgr *LogcatStreamManager, adb *AdbManager) *LogSession {
	return &LogSession{
		conn:        conn,
		logcatMgr:   mgr,
		adb:         adb,
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

	s.mu.Lock()
	subCopy := sub
	s.sub = &subCopy
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
}

// stopSubscription cancels the reader goroutine and releases the
// manager subscription. Idempotent.
func (s *LogSession) stopSubscription() {
	s.mu.Lock()
	cancel := s.readerCancel
	done := s.readerDone
	s.readerCancel = nil
	s.readerDone = nil
	sub := s.sub
	s.sub = nil
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

// handleClear resets the local pause buffer and tells the device to
// clear its logcat buffer. Note: the manager's ring buffer is NOT
// cleared (that would affect other sessions), so the next subscribe
// from this session still replays recent lines from the ring.
func (s *LogSession) handleClear() {
	s.mu.Lock()
	s.pauseBuffer = s.pauseBuffer[:0]
	serial := s.serial
	s.mu.Unlock()

	if serial != "" && s.adb != nil {
		if err := s.adb.ClearLogcat(serial); err != nil {
			s.sendMsg("error", "failed to clear logcat: "+err.Error())
			return
		}
	}
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

// sendMsg / sendLogs / writeJSON — WS write plumbing. Concurrent
// callers (Run + readerLoop) are serialized by writeMu.

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
	if f.PackageName != "" && !strings.Contains(line, f.PackageName) {
		return false
	}
	if f.PackagePid != "" {
		// Match against the PID token in the logcat header. Use
		// space-padded match to avoid "12" matching "1234".
		if !strings.Contains(line, " "+f.PackagePid+" ") {
			return false
		}
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

// extractLogcatPriority returns the priority byte from a logcat
// line (the char immediately before the tag, after a space).
// Returns 0 if no priority could be parsed.
func extractLogcatPriority(line string) byte {
	if len(line) < 30 {
		return 0
	}
	// Walk forward to find the tag's leading uppercase letter.
	for i := 0; i < len(line) && i < 40; i++ {
		ch := line[i]
		if ch < 'A' || ch > 'Z' {
			continue
		}
		// Walk backward from i, skipping spaces.
		j := i - 1
		for j >= 0 && line[j] == ' ' {
			j--
		}
		if j < 0 {
			return 0
		}
		return line[j]
	}
	return 0
}