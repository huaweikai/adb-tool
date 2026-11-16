package server

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

type WsCommand struct {
	Action  string    `json:"action"`
	Serial  string    `json:"serial"`
	Filters LogFilter `json:"filters"`
	Since   string    `json:"since,omitempty"`
}

type WsMessage struct {
	Type  string   `json:"type"`
	Data  string   `json:"data,omitempty"`
	Lines []string `json:"lines,omitempty"`
}

type LogSession struct {
	conn    *websocket.Conn
	adb     *AdbManager
	mu      sync.Mutex
	writeMu sync.Mutex
	cancel  context.CancelFunc
	done    chan struct{}
	paused  bool
	buffer  []string
	filters LogFilter
	serial  string
}

func NewLogSession(conn *websocket.Conn, adb *AdbManager) *LogSession {
	return &LogSession{
		conn:   conn,
		adb:    adb,
		paused: false,
		buffer: make([]string, 0, 1000),
	}
}

func (s *LogSession) Run() {
	defer s.cancelLogcat()
	defer s.conn.Close()

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
			s.startLogcat(cmd)
		case "stop":
			s.cancelLogcat()
			s.sendMsg("status", "stopped")
		case "pause":
			s.mu.Lock()
			s.paused = true
			s.mu.Unlock()
			s.sendMsg("status", "paused")
		case "resume":
			s.mu.Lock()
			s.paused = false
			s.mu.Unlock()
			s.flushBuffer()
			s.sendMsg("status", "running")
		case "clear":
			s.clearLogcat()
		case "filter":
			s.mu.Lock()
			s.filters = cmd.Filters
			s.mu.Unlock()
			s.sendMsg("status", "filter_updated")
		case "ping":
			s.sendMsg("pong", "")
		}
	}
}

const (
	logBatchMaxLines = 120
	logBatchInterval = 50 * time.Millisecond
)

func (s *LogSession) startLogcat(cmd WsCommand) {
	if cmd.Serial == "" {
		s.sendMsg("error", "no device selected")
		return
	}
	s.cancelLogcat()
	s.runLogcat(cmd, false)
}

func (s *LogSession) clearLogcat() {
	if s.serial != "" {
		if err := s.adb.ClearLogcat(s.serial); err != nil {
			s.sendMsg("error", "failed to clear logcat: "+err.Error())
			return
		}
	}
	// Finish any in-flight write before acknowledging the clear. A fresh
	// reader can replay records written to the device since the clear.
	s.mu.Lock()
	wasRunning := s.cancel != nil
	paused := s.paused
	cmd := WsCommand{Serial: s.serial, Filters: s.filters}
	s.mu.Unlock()
	s.cancelLogcat()
	s.mu.Lock()
	s.buffer = s.buffer[:0]
	s.mu.Unlock()
	s.sendMsg("status", "cleared")
	if wasRunning {
		s.runLogcat(cmd, paused)
	}
}

func (s *LogSession) runLogcat(cmd WsCommand, paused bool) {
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	s.mu.Lock()
	s.cancel = cancel
	s.done = done
	s.filters = cmd.Filters
	s.serial = cmd.Serial
	s.paused = paused
	s.buffer = s.buffer[:0]
	s.mu.Unlock()

	go func() {
		defer close(done)
		defer cancel()
		process, stdout, err := s.adb.StartLogcat(ctx, cmd.Serial, cmd.Filters, cmd.Since)
		if err != nil {
			if ctx.Err() == nil {
				s.sendMsg("error", "failed to start logcat: "+err.Error())
				s.conn.Close()
			}
			return
		}
		defer func() {
			stdout.Close()
			process.Wait()
		}()

		if ctx.Err() == nil {
			s.sendMsg("status", "running")
		}
		err = s.forwardLogcat(ctx, stdout, s.sendLogs)
		if ctx.Err() == nil {
			if err != nil {
				s.sendMsg("error", "logcat read error: "+err.Error())
			}
			s.conn.Close()
		}
	}()
}

type logcatRead struct {
	line string
	err  error
}

func readLogcatLines(ctx context.Context, stdout io.Reader) <-chan logcatRead {
	lines := make(chan logcatRead, 256)
	go func() {
		defer close(lines)
		reader := bufio.NewReader(stdout)
		for ctx.Err() == nil {
			line, err := reader.ReadString('\n')
			// Preserve order when the sender is busy. The pipe provides
			// backpressure while this bounded queue is full.
			select {
			case lines <- logcatRead{line: line, err: err}:
			case <-ctx.Done():
				return
			}
			if err != nil {
				return
			}
		}
	}()
	return lines
}

func (s *LogSession) forwardLogcat(ctx context.Context, stdout io.Reader, sendBatch func([]string)) error {
	lines := readLogcatLines(ctx, stdout)
	ticker := time.NewTicker(logBatchInterval)
	defer ticker.Stop()
	batch := make([]string, 0, logBatchMaxLines)
	flush := func() {
		if len(batch) > 0 && ctx.Err() == nil {
			sendBatch(batch)
			batch = batch[:0]
		}
	}

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
			flush()
		case result, ok := <-lines:
			if !ok || ctx.Err() != nil {
				return ctx.Err()
			}
			// ReadString can return data and a terminal error together.
			if result.line != "" {
				line := strings.TrimRight(result.line, "\r\n")
				if s.allowLiveLine(ctx, line) {
					batch = append(batch, line)
					if len(batch) >= logBatchMaxLines {
						flush()
					}
				}
			}
			if result.err != nil {
				flush()
				if errors.Is(result.err, io.EOF) {
					return nil
				}
				return result.err
			}
		}
	}
}

func (s *LogSession) allowLiveLine(ctx context.Context, line string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	if ctx.Err() != nil || !s.matchFiltersLine(line, s.filters) {
		return false
	}
	if !s.paused {
		return true
	}
	s.buffer = append(s.buffer, line)
	if len(s.buffer) > 5000 {
		s.buffer = s.buffer[len(s.buffer)-2500:]
	}
	return false
}

func (s *LogSession) cancelLogcat() {
	s.mu.Lock()
	cancel, done := s.cancel, s.done
	s.cancel, s.done = nil, nil
	s.mu.Unlock()
	if cancel != nil {
		cancel()
		<-done
	}
}

func (s *LogSession) flushBuffer() {
	s.mu.Lock()
	buf := make([]string, len(s.buffer))
	copy(buf, s.buffer)
	s.buffer = s.buffer[:0]
	s.mu.Unlock()

	batch := make([]string, 0, logBatchMaxLines)
	for _, line := range buf {
		s.mu.Lock()
		f := s.filters
		s.mu.Unlock()
		if !s.matchFiltersLine(line, f) {
			continue
		}
		batch = append(batch, line)
		if len(batch) >= logBatchMaxLines {
			s.sendLogs(batch)
			batch = batch[:0]
		}
	}
	s.sendLogs(batch)
}

func (s *LogSession) matchFiltersLine(line string, f LogFilter) bool {
	if f.Keyword != "" && !strings.Contains(strings.ToLower(line), strings.ToLower(f.Keyword)) {
		return false
	}
	if f.Tag != "" {
		tagInLine := extractTag(line)
		if tagInLine != "" && !strings.Contains(strings.ToLower(tagInLine), strings.ToLower(f.Tag)) {
			return false
		}
	}
	return true
}

func extractTag(line string) string {
	if len(line) < 30 {
		return ""
	}
	for i, ch := range line {
		if i > 40 {
			break
		}
		if ch >= 'A' && ch <= 'Z' {
			end := strings.IndexByte(line[i+1:], ':')
			if end > 0 && end < 50 {
				return line[i : i+1+end]
			}
			break
		}
	}
	return ""
}

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
		s.conn.Close()
		return
	}
	if err := s.conn.WriteMessage(websocket.TextMessage, payload); err != nil {
		log.Printf("websocket write error: %v", err)
		s.conn.Close()
	}
}
