//go:build unix

package server

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"
)

func TestIOSShortCommandStopsChildAndClearsExtractionOnShutdown(t *testing.T) {
	ready := filepath.Join(t.TempDir(), "ready")
	t.Setenv("IOS_CLI_TEST_READY", ready)
	shutdown, cancel := context.WithCancel(context.Background())
	defer cancel()
	discovery := newIOSDiscovery(shutdown, "/bin/sh")
	result := make(chan error, 1)
	go func() {
		_, err := discovery.command(context.Background(), "-c", `
set -e
extracted=$(mktemp -d "$TMPDIR/_MEI.XXXXXX")
sleep 30 &
printf '%s\n%s\n' "$!" "$extracted" > "$IOS_CLI_TEST_READY.tmp"
mv "$IOS_CLI_TEST_READY.tmp" "$IOS_CLI_TEST_READY"
wait
`)
		result <- err
	}()

	var data []byte
	deadline := time.After(5 * time.Second)
	ticker := time.NewTicker(10 * time.Millisecond)
	defer ticker.Stop()
	for len(data) == 0 {
		select {
		case err := <-result:
			t.Fatalf("helper exited before starting its child: %v", err)
		case <-deadline:
			t.Fatal("helper did not start its child")
		case <-ticker.C:
			data, _ = os.ReadFile(ready)
		}
	}
	pidText, extraction, _ := strings.Cut(strings.TrimSpace(string(data)), "\n")
	pid, err := strconv.Atoi(pidText)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.RemoveAll(extraction) })

	cancel()
	select {
	case err := <-result:
		if !errors.Is(err, context.Canceled) {
			t.Fatalf("command returned %v, want context cancellation", err)
		}
	case <-time.After(3 * time.Second):
		_ = syscall.Kill(pid, syscall.SIGKILL)
		t.Fatal("child kept the CLI output pipe open after cancellation")
	}
	if _, err := os.Stat(extraction); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("extraction directory survived cancellation: %v", err)
	}
}

func TestIOSDaemonTimeoutStopsChildAndClearsExtraction(t *testing.T) {
	ready := filepath.Join(t.TempDir(), "ready")
	t.Setenv("IOS_CLI_TEST_READY", ready)
	cli := filepath.Join(t.TempDir(), "fake-cli")
	if err := os.WriteFile(cli, []byte(`#!/bin/sh
set -e
extracted=$(mktemp -d "$TMPDIR/_MEI.XXXXXX")
sleep 30 &
printf '%s\n%s\n' "$!" "$extracted" > "$IOS_CLI_TEST_READY"
wait
`), 0700); err != nil {
		t.Fatal(err)
	}
	shutdown, stop := context.WithCancel(context.Background())
	defer stop()
	daemon := newIOSDaemon(shutdown, cli)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	result := make(chan error, 1)
	go func() {
		_, err := daemon.Call(ctx, "usbmux", "list")
		result <- err
	}()
	var data []byte
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		data, _ = os.ReadFile(ready)
		if strings.Count(string(data), "\n") == 2 {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	pidText, extraction, _ := strings.Cut(strings.TrimSpace(string(data)), "\n")
	pid, err := strconv.Atoi(pidText)
	if err != nil {
		t.Fatalf("helper did not start its child: %q, %v", data, err)
	}
	t.Cleanup(func() { _ = syscall.Kill(pid, syscall.SIGKILL) })
	cancel()
	select {
	case err := <-result:
		if !errors.Is(err, context.Canceled) {
			t.Fatalf("call returned %v", err)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("daemon cancellation did not finish")
	}
	deadline = time.Now().Add(2 * time.Second)
	for syscall.Kill(pid, 0) == nil && time.Now().Before(deadline) {
		time.Sleep(10 * time.Millisecond)
	}
	if err := syscall.Kill(pid, 0); !errors.Is(err, syscall.ESRCH) {
		t.Fatalf("daemon child survived cancellation: %v", err)
	}
	if _, err := os.Stat(extraction); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("extraction directory survived cancellation: %v", err)
	}
}
