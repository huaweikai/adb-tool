package server

import (
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

func TestValidateSessionDirRejectsTraversal(t *testing.T) {
	_, err := validateSessionDir("/tmp/sessions/../escape")
	if err == nil {
		t.Fatal("expected traversal to be rejected")
	}
}

func TestValidateSessionDirAllowsDoubleDotInDirectoryName(t *testing.T) {
	root := t.TempDir()
	sessionDir := filepath.Join(root, "foo..bar", "sessions", "case")
	got, err := validateSessionDir(sessionDir)
	if err != nil {
		t.Fatalf("expected directory name containing .. to be allowed: %v", err)
	}
	if got != filepath.Clean(sessionDir) {
		t.Fatalf("unexpected cleaned path: %q", got)
	}
}

func TestValidateSessionDirRequiresAbsolutePath(t *testing.T) {
	_, err := validateSessionDir("sessions/foo")
	if err == nil {
		t.Fatal("expected relative path to be rejected")
	}
}

func TestValidateSessionDirAcceptsAbsolutePath(t *testing.T) {
	root := t.TempDir()
	sessionDir := filepath.Join(root, "sessions", "20260101_test")
	got, err := validateSessionDir(sessionDir)
	if err != nil {
		t.Fatalf("validateSessionDir returned error: %v", err)
	}
	if got != filepath.Clean(sessionDir) {
		t.Fatalf("unexpected cleaned path: %q", got)
	}
}

func TestIsAllowedWebSocketOrigin(t *testing.T) {
	cases := []struct {
		origin string
		want   bool
	}{
		{"", true},
		{"http://localhost:9876", true},
		{"http://127.0.0.1:9876", true},
		{"http://[::1]:9876", true},
		{"http://evil.example", false},
	}
	for _, tc := range cases {
		req := httptest.NewRequest(http.MethodGet, "/ws/logs", nil)
		if tc.origin != "" {
			req.Header.Set("Origin", tc.origin)
		}
		if got := isAllowedWebSocketOrigin(req); got != tc.want {
			t.Fatalf("origin %q: got %v want %v", tc.origin, got, tc.want)
		}
	}
}

func TestRequireLoopbackAllowsLocalClient(t *testing.T) {
	called := false
	handler := requireLoopback(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/api/devices", nil)
	req.RemoteAddr = "127.0.0.1:12345"
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if !called {
		t.Fatal("handler was not called")
	}
}

func TestRequireLoopbackRejectsRemoteClient(t *testing.T) {
	handler := requireLoopback(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Fatal("handler should not be called")
	}))

	req := httptest.NewRequest(http.MethodGet, "/api/devices", nil)
	req.RemoteAddr = "192.168.1.10:12345"
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403, got %d", rec.Code)
	}
	if !strings.Contains(rec.Body.String(), "forbidden") {
		t.Fatalf("unexpected body: %s", rec.Body.String())
	}
}

func TestValidateSessionDirWindowsAbsolutePath(t *testing.T) {
	if runtime.GOOS != "windows" {
		t.Skip("windows-only path check")
	}
	root := t.TempDir()
	sessionDir := filepath.Join(root, "sessions", "case")
	got, err := validateSessionDir(sessionDir)
	if err != nil {
		t.Fatalf("validateSessionDir returned error: %v", err)
	}
	if got != filepath.Clean(sessionDir) {
		t.Fatalf("unexpected cleaned path: %q", got)
	}
}
