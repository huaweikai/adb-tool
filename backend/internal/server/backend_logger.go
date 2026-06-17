package server

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"
)

const (
	backendLogFile    = "backend.log"
	maxLogFileSize    = 50 * 1024 * 1024 // 50 MB
	maxLogBackupFiles = 2
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

	file    *os.File
	fileMu  sync.Mutex
	rotated int // number of previous backup files
}

var Log = NewBackendLogger(500)

func NewBackendLogger(max int) *BackendLogger {
	l := &BackendLogger{
		buffer: make([]LogEntry, 0, max),
		max:    max,
	}
	l.openFile()
	return l
}

func (l *BackendLogger) openFile() {
	dir := backendLogDir()
	if dir == "" {
		return
	}
	_ = os.MkdirAll(dir, 0755)
	path := filepath.Join(dir, backendLogFile)
	f, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		return
	}
	l.file = f
	// Count existing backup files
	for i := 1; i <= maxLogBackupFiles; i++ {
		backup := filepath.Join(dir, fmt.Sprintf("backend.%d.log", i))
		if _, err := os.Stat(backup); err == nil {
			l.rotated = i
		}
	}
}

func (l *BackendLogger) writeToFile(entry LogEntry) {
	l.fileMu.Lock()
	defer l.fileMu.Unlock()

	if l.file == nil {
		return
	}

	// Rotate if too large
	info, err := l.file.Stat()
	if err == nil && info.Size() >= maxLogFileSize {
		l.rotateFileLocked()
	}

	data, err := json.Marshal(entry)
	if err != nil {
		return
	}
	l.file.Write(append(data, '\n'))
}

func (l *BackendLogger) rotateFileLocked() {
	if l.file != nil {
		l.file.Close()
	}

	dir := backendLogDir()
	// Remove the oldest backup if we're at the limit
	oldest := filepath.Join(dir, fmt.Sprintf("backend.%d.log", maxLogBackupFiles))
	os.Remove(oldest)

	// Shift backups
	for i := maxLogBackupFiles - 1; i >= 1; i-- {
		src := filepath.Join(dir, fmt.Sprintf("backend.%d.log", i))
		dst := filepath.Join(dir, fmt.Sprintf("backend.%d.log", i+1))
		os.Rename(src, dst)
	}

	// Rotate current log to .1
	src := filepath.Join(dir, backendLogFile)
	dst := filepath.Join(dir, "backend.1.log")
	os.Rename(src, dst)

	l.rotated++
	// Reopen
	f, err := os.OpenFile(src, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		l.file = nil
		return
	}
	l.file = f
}

func formatLogError(err error) string {
	if err == nil {
		return ""
	}
	switch err.Error() {
	case "context deadline exceeded":
		return "超时：ADB 命令执行超过时限（ADB 可能卡住或设备响应慢）"
	case "context canceled":
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

	go l.writeToFile(entry)
}

func (l *BackendLogger) Snapshot() []LogEntry {
	l.mu.Lock()
	defer l.mu.Unlock()

	out := make([]LogEntry, len(l.buffer))
	copy(out, l.buffer)
	return out
}

// FileTail returns the last n entries from the on-disk log file.
func (l *BackendLogger) FileTail(n int) []LogEntry {
	dir := backendLogDir()
	if dir == "" {
		return nil
	}
	path := filepath.Join(dir, backendLogFile)
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer f.Close()

	var entries []LogEntry
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Bytes()
		if len(line) == 0 {
			continue
		}
		var entry LogEntry
		if err := json.Unmarshal(line, &entry); err != nil {
			continue
		}
		entries = append(entries, entry)
	}

	if n <= 0 || n >= len(entries) {
		return entries
	}
	return entries[len(entries)-n:]
}

func (l *BackendLogger) Close() {
	l.fileMu.Lock()
	defer l.fileMu.Unlock()
	if l.file != nil {
		l.file.Close()
		l.file = nil
	}
}
