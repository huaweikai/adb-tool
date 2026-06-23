package server

import (
	"bufio"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

type hijackableResponseWriter struct {
	http.ResponseWriter
}

func (w hijackableResponseWriter) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	return nil, nil, http.ErrNotSupported
}

func TestLoggingResponseWriterPreservesHijacker(t *testing.T) {
	wrapped := &loggingResponseWriter{
		ResponseWriter: hijackableResponseWriter{},
		status:         http.StatusOK,
	}

	if _, ok := any(wrapped).(http.Hijacker); !ok {
		t.Fatal("loggingResponseWriter must implement http.Hijacker for websocket upgrades")
	}
}

func TestLoggingMiddlewareRecordsStatusAndBytes(t *testing.T) {
	oldLog := Log
	Log = NewBackendLogger(20)
	defer func() { Log = oldLog }()

	handler := loggingMiddleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusAccepted)
		_, _ = w.Write([]byte("hello"))
	}))

	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, httptest.NewRequest(http.MethodPost, "/api/example", nil))

	if recorder.Code != http.StatusAccepted {
		t.Fatalf("expected status %d, got %d", http.StatusAccepted, recorder.Code)
	}
	entries := Log.Snapshot()
	if len(entries) == 0 {
		t.Fatal("expected request to be logged")
	}
	last := entries[len(entries)-1]
	if last.Command != "HTTP POST /api/example" {
		t.Fatalf("unexpected log command: %+v", last)
	}
	if !strings.Contains(last.Result, "status=202 bytes=5") {
		t.Fatalf("unexpected log result: %+v", last)
	}
}
