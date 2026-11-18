package server

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"os"
	"os/exec"
	"strings"
	"sync"
	"time"
)

type iosDaemon struct {
	mu          sync.Mutex
	shutdownCtx context.Context
	cli         string
	cmd         *exec.Cmd
	stdin       io.WriteCloser
	reader      *bufio.Reader
	tempDir     string
	nextID      int64
	disabled    bool
}

type iosDaemonReq struct {
	ID   int64    `json:"id"`
	Args []string `json:"args"`
}

type iosDaemonResp struct {
	ID     int64  `json:"id"`
	OK     bool   `json:"ok"`
	Output string `json:"output"`
	Error  string `json:"error"`
}

func newIOSDaemon(shutdownCtx context.Context, cli string) *iosDaemon {
	d := &iosDaemon{shutdownCtx: shutdownCtx, cli: cli}
	context.AfterFunc(shutdownCtx, func() {
		d.mu.Lock()
		defer d.mu.Unlock()
		d.resetLocked()
	})
	return d
}

func (d *iosDaemon) startLocked() error {
	if d.cmd != nil {
		return nil
	}
	if err := d.shutdownCtx.Err(); err != nil {
		return err
	}
	temp, err := os.MkdirTemp("", "adb-tool-ios-daemon-")
	if err != nil {
		return err
	}
	cmd := exec.CommandContext(d.shutdownCtx, d.cli, "--daemon")
	configureIOSProcess(cmd)
	cmd.WaitDelay = 5 * time.Second
	cmd.Env = append(cmd.Environ(), "PYTHONIOENCODING=utf-8", "NO_COLOR=1",
		"TEMP="+temp, "TMP="+temp, "TMPDIR="+temp)
	stdin, err := cmd.StdinPipe()
	if err != nil {
		_ = os.RemoveAll(temp)
		return err
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		_ = stdin.Close()
		_ = os.RemoveAll(temp)
		return err
	}
	if err := cmd.Start(); err != nil {
		_ = stdin.Close()
		_ = os.RemoveAll(temp)
		return err
	}
	d.cmd = cmd
	d.stdin = stdin
	d.reader = bufio.NewReaderSize(stdout, 256*1024)
	d.tempDir = temp
	return nil
}

func (d *iosDaemon) resetLocked() {
	if d.stdin != nil {
		_ = d.stdin.Close()
		d.stdin = nil
	}
	if d.cmd != nil {
		if d.cmd.Process != nil {
			// PyInstaller's bootloader and Python child must stop together.
			_ = d.cmd.Cancel()
		}
		_ = d.cmd.Wait()
		d.cmd = nil
	}
	d.reader = nil
	if d.tempDir != "" {
		_ = os.RemoveAll(d.tempDir)
		d.tempDir = ""
	}
}

func (d *iosDaemon) Call(ctx context.Context, args ...string) ([]byte, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	d.mu.Lock()
	// A queued request may have expired while another command was running.
	if err := ctx.Err(); err != nil {
		d.mu.Unlock()
		return nil, err
	}
	if d.disabled {
		d.mu.Unlock()
		var out bytes.Buffer
		err := runIOSCLI(ctx, d.cli, &out, args...)
		return out.Bytes(), err
	}
	if err := d.startLocked(); err != nil {
		d.mu.Unlock()
		return nil, err
	}
	d.nextID++
	reqID := d.nextID
	payload, err := json.Marshal(iosDaemonReq{ID: reqID, Args: args})
	if err != nil {
		d.mu.Unlock()
		return nil, err
	}
	payload = append(payload, '\n')
	if _, err := d.stdin.Write(payload); err != nil {
		d.resetLocked()
		d.mu.Unlock()
		var out bytes.Buffer
		err2 := runIOSCLI(ctx, d.cli, &out, args...)
		return out.Bytes(), err2
	}

	type readResult struct {
		line []byte
		err  error
	}
	reader := d.reader
	ch := make(chan readResult, 1)
	go func() {
		line, rErr := reader.ReadBytes('\n')
		ch <- readResult{line: line, err: rErr}
	}()

	var res readResult
	select {
	case <-ctx.Done():
		d.resetLocked()
		d.mu.Unlock()
		return nil, ctx.Err()
	case res = <-ch:
	}

	if res.err != nil {
		d.resetLocked()
		if strings.Contains(string(res.line), "No such option: --daemon") {
			d.disabled = true
		}
		d.mu.Unlock()
		var out bytes.Buffer
		err2 := runIOSCLI(ctx, d.cli, &out, args...)
		return out.Bytes(), err2
	}
	defer d.mu.Unlock()
	var resp iosDaemonResp
	if err := json.Unmarshal(bytes.TrimSpace(res.line), &resp); err != nil {
		d.resetLocked()
		return nil, err
	}
	if resp.ID != reqID {
		d.resetLocked()
		return nil, errors.New("unexpected iOS daemon response ID")
	}
	if !resp.OK {
		return []byte(resp.Output), errors.New(resp.Error)
	}
	return []byte(resp.Output), nil
}

func runIOSCLI(ctx context.Context, cli string, output io.Writer, args ...string) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	// PyInstaller can leave its extracted files behind after a forced stop.
	temp, err := os.MkdirTemp("", "adb-tool-ios-")
	if err != nil {
		return err
	}
	defer func() {
		if err := os.RemoveAll(temp); err != nil {
			Log.Add("iOS CLI temp directory cleanup", err.Error(), err, 0)
		}
	}()

	cmd := exec.CommandContext(ctx, cli, args...)
	configureIOSProcess(cmd)
	cmd.Stdout = output
	cmd.Env = append(cmd.Environ(), "PYTHONIOENCODING=utf-8", "NO_COLOR=1",
		"TEMP="+temp, "TMP="+temp, "TMPDIR="+temp)
	cmd.WaitDelay = 5 * time.Second
	err = cmd.Run()
	if err != nil && ctx.Err() != nil {
		return ctx.Err()
	}
	return err
}
