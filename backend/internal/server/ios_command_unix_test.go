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
