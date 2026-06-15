package server

import (
	"context"
	"errors"
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

func formatLogError(err error) string {
	if err == nil {
		return ""
	}
	switch {
	case errors.Is(err, context.DeadlineExceeded):
		return "超时：ADB 命令执行超过时限（ADB 可能卡住或设备响应慢）"
	case errors.Is(err, context.Canceled):
		return "已取消：请求被中断（切换页面、重启服务或取消传输时会触发）"
	default:
		return err.Error()
	}
}

func (l *BackendLogger) Add(cmd, result string, err error, elapsed time.Duration) {
	l.mu.Lock()
	defer l.mu.Unlock()

	l.seq++

	entry := LogEntry{
		Time:    time.Now().Format("15:04:05.000"),
		Command: cmd,
		Result:  result,
		Err:     formatLogError(err),
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
