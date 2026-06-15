package server

import (
	"bufio"
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

type SessionLogcat struct {
	mu     sync.Mutex
	cmd    *exec.Cmd
	cancel context.CancelFunc
	done   chan struct{}
	path   string
}

func (s *SessionLogcat) Start(adbPath, serial, sessionDir, packageName string) error {
	s.Stop()

	s.mu.Lock()
	defer s.mu.Unlock()

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

	args := []string{"-s", serial, "logcat", "-v", "threadtime", "-T", now.Format("01-02 15:04:05.000")}

	if packageName != "" {
		if pid := getPackagePID(adbPath, serial, packageName); pid != "" {
			args = append(args, "--pid="+pid)
		}
	}

	ctx, cancel := context.WithCancel(context.Background())
	cmd := exec.CommandContext(ctx, adbPath, args...)

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		cancel()
		file.Close()
		os.Remove(filePath)
		return err
	}
	cmd.Stderr = cmd.Stdout

	if err := cmd.Start(); err != nil {
		cancel()
		file.Close()
		os.Remove(filePath)
		return err
	}

	s.cmd = cmd
	s.cancel = cancel
	s.done = make(chan struct{})
	s.path = filePath

	go s.pump(bufio.NewReader(stdout), file, ctx, s.done)
	return nil
}

func (s *SessionLogcat) pump(reader *bufio.Reader, file *os.File, ctx context.Context, done chan struct{}) {
	writer := bufio.NewWriterSize(file, 128*1024)
	defer func() {
		writer.Flush()
		file.Close()
		close(done)
	}()

	lineCh := make(chan []byte, 256)
	errCh := make(chan error, 1)

	go func() {
		for {
			line, err := reader.ReadBytes('\n')
			if len(line) > 0 {
				lineCh <- line
			}
			if err != nil {
				errCh <- err
				return
			}
		}
	}()

	ticker := time.NewTicker(500 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			writer.Flush()
		case <-errCh:
			writer.Flush()
			return
		case line := <-lineCh:
			writer.Write(line)
			if writer.Buffered() >= 100*1024 {
				writer.Flush()
			}
		}
	}
}

func (s *SessionLogcat) Stop() string {
	s.mu.Lock()
	if s.cancel != nil {
		s.cancel()
	}
	if s.cmd != nil && s.cmd.Process != nil {
		s.cmd.Process.Kill()
		s.cmd.Wait()
	}
	done := s.done
	path := s.path
	s.cmd = nil
	s.cancel = nil
	s.done = nil
	s.path = ""
	s.mu.Unlock()

	if done != nil {
		<-done
	}
	return path
}

func getPackagePID(adbPath, serial, packageName string) string {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, adbPath, "-s", serial, "shell", "pidof", packageName)
	out, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}
