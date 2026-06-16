package server

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestRecoverHTTPPanicWritesErrorAndLog(t *testing.T) {
	oldLog := Log
	Log = NewBackendLogger(20)
	defer func() { Log = oldLog }()

	handler := recoverHTTP(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		panic("boom")
	}))

	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/panic", nil))

	if recorder.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500, got %d", recorder.Code)
	}
	if !strings.Contains(recorder.Body.String(), "internal server error") {
		t.Fatalf("expected generic error body, got %q", recorder.Body.String())
	}
	entries := Log.Snapshot()
	if len(entries) == 0 {
		t.Fatal("expected panic to be logged")
	}
	last := entries[len(entries)-1]
	if last.Command != "panic http GET /panic" {
		t.Fatalf("unexpected log command: %+v", last)
	}
	if !strings.Contains(last.Err, "boom") {
		t.Fatalf("expected panic reason in log: %+v", last)
	}
	if !strings.Contains(last.Result, "goroutine") {
		t.Fatalf("expected stack trace in log result: %+v", last)
	}
}
