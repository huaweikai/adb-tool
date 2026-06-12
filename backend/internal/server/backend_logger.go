package server

import (
	"fmt"
	"sync"
	"time"
)

type LogEntry struct {
	Time    string `json:"time"`
	Command string `json:"command"`
	Result  string `json:"result"`
	Err     string `json:"err"`
	Elapsed string `json:"elapsed"`
}

type BackendLogger struct {
	mu     sync.Mutex
	buffer []LogEntry
	max    int
	seq    int
}

var Log = NewBackendLogger(500)

func NewBackendLogger(max int) *BackendLogger {
	return &BackendLogger{
		buffer: make([]LogEntry, 0, max),
		max:    max,
	}
}

func (l *BackendLogger) Add(cmd, result string, err error, elapsed time.Duration) {
	l.mu.Lock()
	defer l.mu.Unlock()

	l.seq++
	errStr := ""
	if err != nil {
		errStr = err.Error()
	}

	entry := LogEntry{
		Time:    time.Now().Format("15:04:05.000"),
		Command: cmd,
		Result:  result,
		Err:     errStr,
		Elapsed: fmt.Sprintf("%dms", elapsed.Milliseconds()),
	}

	if len(l.buffer) >= l.max {
		l.buffer = append(l.buffer[1:], entry)
	} else {
		l.buffer = append(l.buffer, entry)
	}
}

func (l *BackendLogger) Snapshot() []LogEntry {
	l.mu.Lock()
	defer l.mu.Unlock()

	out := make([]LogEntry, len(l.buffer))
	copy(out, l.buffer)
	return out
}
