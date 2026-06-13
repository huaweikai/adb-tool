package server

import (
	"bufio"
	"context"
	"encoding/json"
	"io"
	"log"
	"os/exec"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

type WsCommand struct {
	Action  string    `json:"action"`
	Serial  string    `json:"serial"`
	Filters LogFilter `json:"filters"`
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
	ctx     context.Context
	cancel  context.CancelFunc
	paused  bool
	buffer  []string
	filters LogFilter
	serial  string
	cmd     *exec.Cmd
	stdout  io.ReadCloser
}

func NewLogSession(conn *websocket.Conn, adb *AdbManager) *LogSession {
	ctx, cancel := context.WithCancel(context.Background())
	return &LogSession{
		conn:   conn,
		adb:    adb,
		ctx:    ctx,
		cancel: cancel,
		paused: false,
		buffer: make([]string, 0, 1000),
	}
}

func (s *LogSession) Run() {
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
			go s.startLogcat(cmd)
		case "stop":
			s.stopLogcat()
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
			s.mu.Lock()
			s.buffer = s.buffer[:0]
			s.mu.Unlock()
			if s.serial != "" {
				if err := s.adb.ClearLogcat(s.serial); err != nil {
					s.sendMsg("error", "failed to clear logcat: "+err.Error())
					continue
				}
			}
			s.sendMsg("status", "cleared")
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
	s.mu.Lock()
	if s.cancel != nil {
		s.cancel()
	}
	if s.cmd != nil && s.cmd.Process != nil {
		if err := s.cmd.Process.Kill(); err != nil {
			Log.Add("logcat kill", "", err, 0)
		}
	}
	if s.stdout != nil {
		if err := s.stdout.Close(); err != nil {
			Log.Add("logcat stdout close", "", err, 0)
		}
	}
	ctx, cancel := context.WithCancel(context.Background())
	s.ctx = ctx
	s.cancel = cancel
	s.filters = cmd.Filters
	s.serial = cmd.Serial
	s.paused = false
	s.buffer = s.buffer[:0]
	s.mu.Unlock()

	if cmd.Serial == "" {
		s.sendMsg("error", "no device selected")
		return
	}

	execCmd, stdout, err := s.adb.StartLogcat(cmd.Serial, cmd.Filters)
	if err != nil {
		s.sendMsg("error", "failed to start logcat: "+err.Error())
		return
	}

	s.mu.Lock()
	s.cmd = execCmd
	s.stdout = stdout
	s.mu.Unlock()

	s.sendMsg("status", "running")

	reader := bufio.NewReader(stdout)
	lineCh := make(chan string, 256)
	doneCh := make(chan error, 1)

	go func() {
		for {
			line, err := reader.ReadString('\n')
			if err != nil {
				if err != io.EOF {
					doneCh <- err
				} else {
					doneCh <- nil
				}
				return
			}
			select {
			case lineCh <- line:
			default:
			}
		}
	}()

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
		case <-s.ctx.Done():
			flush()
			return
		case <-ticker.C:
			flush()
		case err := <-doneCh:
			flush()
			if err != nil {
				s.sendMsg("error", "logcat read error: "+err.Error())
			}
			return
		case line := <-lineCh:
			line = strings.TrimRight(line, "\r\n")

			s.mu.Lock()
			f := s.filters
			paused := s.paused
			s.mu.Unlock()

			if !s.matchFiltersLine(line, f) {
				continue
			}

			if paused {
				s.mu.Lock()
				s.buffer = append(s.buffer, line)
				if len(s.buffer) > 5000 {
					s.buffer = s.buffer[len(s.buffer)-2500:]
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

func (s *LogSession) stopLogcat() {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.cancel != nil {
		s.cancel()
	}
	if s.cmd != nil && s.cmd.Process != nil {
		if err := s.cmd.Process.Kill(); err != nil {
			Log.Add("logcat kill", "", err, 0)
		}
		s.cmd = nil
	}
	if s.stdout != nil {
		if err := s.stdout.Close(); err != nil {
			Log.Add("logcat stdout close", "", err, 0)
		}
		s.stdout = nil
	}
	s.sendMsg("status", "stopped")
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
		return
	}
	if err := s.conn.WriteMessage(websocket.TextMessage, payload); err != nil {
		log.Printf("websocket write error: %v", err)
	}
}
