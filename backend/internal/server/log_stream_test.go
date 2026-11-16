package server

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"testing/synctest"
	"time"

	"github.com/gorilla/websocket"
)

func TestForwardLogcatPreservesBurstAndFinalLine(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		const count = 1000
		want := make([]string, count)
		for i := range want {
			want[i] = fmt.Sprintf("11-16 12:00:00.000 1234 1234 I HttpTrace: %04d %s", i, strings.Repeat("数据", 500))
		}
		// The pipe ends immediately after the last message.
		source := strings.NewReader(strings.Join(want, "\n"))
		firstBatch := make(chan struct{})
		resumeSending := make(chan struct{})
		done := make(chan error, 1)
		var got []string
		session := &LogSession{}
		go func() {
			done <- session.forwardLogcat(context.Background(), source, func(lines []string) {
				if len(got) == 0 {
					close(firstBatch)
					<-resumeSending
				}
				got = append(got, lines...)
			})
		}()

		<-firstBatch
		// Model a temporarily busy WebSocket while ADB can keep reading.
		synctest.Wait()
		close(resumeSending)

		if err := <-done; err != nil {
			t.Fatal(err)
		}
		if len(got) != count {
			t.Fatalf("forwarded %d of %d lines", len(got), count)
		}
		if !slices.Equal(got, want) {
			t.Fatal("the forwarded lines changed content or order")
		}
	})
}

func TestLogcatReaderCanCancelWhileQueueIsFull(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		ctx, cancel := context.WithCancel(context.Background())
		defer cancel()
		lines := readLogcatLines(ctx, strings.NewReader(strings.Repeat("log\n", 1000)))
		synctest.Wait()

		if len(lines) != cap(lines) {
			t.Fatalf("reader should be blocked on a full queue, got %d of %d", len(lines), cap(lines))
		}
		cancel()
		synctest.Wait()

		count := 0
		for range lines {
			count++
		}
		if count != cap(lines) {
			t.Fatalf("expected %d lines already queued at cancellation, got %d", cap(lines), count)
		}
	})
}

func TestStartLogcatRetainsDeviceHistory(t *testing.T) {
	calls := filepath.Join(t.TempDir(), "calls")
	t.Setenv("LOGCAT_TEST_CALLS", calls)
	adb := &AdbManager{adbPath: buildLogcatTestAdb(t)}
	for _, tt := range []struct {
		since string
		tail  string
	}{
		{tail: "1000"},
		{since: "2026-11-16 12:00:00.123456", tail: "2026-11-16 12:00:00.123456"},
	} {
		cmd, stdout, err := adb.StartLogcat(t.Context(), "device", LogFilter{Priority: "V"}, tt.since)
		if err != nil {
			t.Fatal(err)
		}
		output, err := io.ReadAll(stdout)
		if err != nil {
			t.Fatal(err)
		}
		if err := cmd.Wait(); err != nil {
			t.Fatal(err)
		}
		want := []string{"-s", "device", "logcat", "-v", "threadtime", "-v", "usec", "-v", "year", "-T", tt.tail, "*:V"}
		if got := strings.Split(strings.TrimSuffix(string(output), "\n"), "\n"); !slices.Equal(got, want) {
			t.Fatalf("logcat args = %q, want %q", got, want)
		}
	}
	if _, _, err := adb.StartLogcat(t.Context(), "device", LogFilter{}, "-c"); err == nil {
		t.Fatal("expected an invalid cursor to be rejected")
	}
	invocations, err := os.ReadFile(calls)
	if err != nil {
		t.Fatal(err)
	}
	if count := strings.Count(string(invocations), "\n"); count != 2 {
		t.Fatalf("expected only the two live commands, got %q", invocations)
	}
}

func TestLogcatClearRestartsFollowingFromClearedBuffer(t *testing.T) {
	t.Setenv("LOGCAT_CLEARED_FILE", filepath.Join(t.TempDir(), "cleared"))
	adb := &AdbManager{adbPath: buildLogcatTestAdb(t)}
	upgrader := websocket.Upgrader{}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := upgrader.Upgrade(w, r, nil)
		if err == nil {
			NewLogSession(conn, adb).Run()
		}
	}))
	defer srv.Close()
	conn, _, err := websocket.DefaultDialer.Dial("ws"+strings.TrimPrefix(srv.URL, "http"), nil)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	if err := conn.SetReadDeadline(time.Now().Add(5 * time.Second)); err != nil {
		t.Fatal(err)
	}
	if err := conn.WriteJSON(WsCommand{Action: "start", Serial: "device"}); err != nil {
		t.Fatal(err)
	}
	read := func() WsMessage {
		t.Helper()
		var msg WsMessage
		if err := conn.ReadJSON(&msg); err != nil {
			t.Fatal(err)
		}
		return msg
	}
	if msg := read(); msg.Type != "status" || msg.Data != "running" {
		t.Fatalf("expected running status, got %+v", msg)
	}
	if msg := read(); msg.Type != "logs" || !slices.Equal(msg.Lines, []string{"old log"}) {
		t.Fatalf("expected the original buffer, got %+v", msg)
	}
	if err := conn.WriteJSON(WsCommand{Action: "clear"}); err != nil {
		t.Fatal(err)
	}
	if msg := read(); msg.Type != "status" || msg.Data != "cleared" {
		t.Fatalf("expected clear acknowledgement, got %+v", msg)
	}
	if msg := read(); msg.Type != "status" || msg.Data != "running" {
		t.Fatalf("expected the new stream to follow the acknowledgement, got %+v", msg)
	}
	if msg := read(); msg.Type != "logs" || !slices.Equal(msg.Lines, []string{"new log"}) {
		t.Fatalf("expected only post-clear logs, got %+v", msg)
	}
}

func buildLogcatTestAdb(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	source := filepath.Join(dir, "adb.go")
	const program = `package main
import (
	"fmt"
	"os"
	"strings"
	"time"
)
func main() {
	args := os.Args[1:]
	if path := os.Getenv("LOGCAT_TEST_CALLS"); path != "" {
		file, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
		if err != nil { panic(err) }
		fmt.Fprintln(file, strings.Join(args, " "))
		file.Close()
		fmt.Println(strings.Join(args, "\n"))
		return
	}
	cleared := os.Getenv("LOGCAT_CLEARED_FILE")
	if args[len(args)-1] == "-c" {
		if err := os.WriteFile(cleared, nil, 0600); err != nil { panic(err) }
		return
	}
	if _, err := os.Stat(cleared); err == nil {
		fmt.Println("new log")
	} else {
		fmt.Println("old log")
	}
	time.Sleep(30 * time.Second)
}
`
	if err := os.WriteFile(source, []byte(program), 0o600); err != nil {
		t.Fatal(err)
	}
	binary := filepath.Join(dir, "adb.exe")
	if output, err := exec.CommandContext(t.Context(), "go", "build", "-o", binary, source).CombinedOutput(); err != nil {
		t.Fatalf("build fake adb: %v\n%s", err, output)
	}
	return binary
}
