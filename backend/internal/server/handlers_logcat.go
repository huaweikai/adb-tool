package server

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"time"
)

// handleLogStream upgrades the request to a WebSocket for live logcat streaming.
func (s *Server) handleLogStream(w http.ResponseWriter, r *http.Request) {
	conn, err := s.upgrader.Upgrade(w, r, nil)
	if err != nil {
		Log.Add("ws upgrade failed", fmt.Sprintf("remote=%s ua=%q", r.RemoteAddr, r.Header.Get("User-Agent")), err, 0)
		writeAPIError(w, http.StatusBadRequest, "websocket upgrade failed")
		return
	}

	session := NewLogSession(conn, s.adb)
	session.Run()
}

// handleRecentLogcat returns the last N lines of logcat for a device.
func (s *Server) handleRecentLogcat(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		writeAPIError(w, http.StatusMethodNotAllowed, "GET required")
		return
	}
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	lines := 1000
	if raw := r.URL.Query().Get("lines"); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil || parsed <= 0 {
			writeAPIError(w, http.StatusBadRequest, "lines must be a positive integer")
			return
		}
		lines = parsed
	}
	content, err := s.adb.GetRecentLogcat(serial, lines)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]any{"content": content, "lines": lines})
}

// handleSessionLogcat starts/stops a logcat recording session bound to a test session dir.
func (s *Server) handleSessionLogcat(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	var req struct {
		Action      string `json:"action"`
		Serial      string `json:"serial"`
		SessionDir  string `json:"sessionDir"`
		PackageName string `json:"packageName"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}

	switch req.Action {
	case "start":
		if req.Serial == "" || req.SessionDir == "" {
			writeAPIError(w, http.StatusBadRequest, "serial and sessionDir required")
			return
		}
		sessionDir, err := validateSessionDir(req.SessionDir)
		if err != nil {
			writeAPIError(w, http.StatusBadRequest, err.Error())
			return
		}
		if err := s.sessionLogcat.Start(s.adb.AdbPath(), req.Serial, sessionDir, req.PackageName); err != nil {
			writeAPIError(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, map[string]string{"status": "ok"})
	case "stop":
		path := s.sessionLogcat.Stop()
		writeJSON(w, map[string]string{"path": path})
	default:
		writeAPIError(w, http.StatusBadRequest, "invalid action, use start or stop")
	}
}

// handleLocalRecording starts/stops a per-device logcat recording whose
// output goes to a temp dir (NOT a test session dir). The frontend uses
// this for the "Save to local file" UI flow on the logcat screen.
//
//   - POST {action:"start", serial, packageName} →
//     {ok, path, startedAt}    path is the file being written.
//   - POST {action:"stop",  serial}              →
//     {ok, path, bytes}        path is the same file, now closed.
//   - POST {action:"status", serial}             →
//     {ok, recording, elapsedMs}
//
// Each device serial maps to at most one active recording; calling start
// twice replaces the first. The temp dir is owned by the OS — on macOS
// /tmp gets pruned periodically, on Windows %TEMP% is per-user. The
// frontend is expected to copy the file to a user-chosen location via
// the file_selector save dialog after stop.
func (s *Server) handleLocalRecording(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	var req struct {
		Action      string `json:"action"`
		Serial      string `json:"serial"`
		PackageName string `json:"packageName"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	if req.Serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}

	switch req.Action {
	case "start":
		saveDir := localRecordingSaveDir(req.Serial)
		path, err := s.localRecorder.Start(s.adb.AdbPath(), req.Serial, saveDir, req.PackageName)
		if err != nil {
			writeAPIError(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, map[string]any{
			"ok":        true,
			"path":      path,
			"startedAt": time.Now().UTC().Format(time.RFC3339Nano),
		})
	case "stop":
		path, err := s.localRecorder.Stop(req.Serial)
		if err != nil {
			writeAPIError(w, http.StatusInternalServerError, err.Error())
			return
		}
		var bytes int64
		if path != "" {
			if info, statErr := os.Stat(path); statErr == nil {
				bytes = info.Size()
			}
		}
		writeJSON(w, map[string]any{
			"ok":    true,
			"path":  path,
			"bytes": bytes,
		})
	case "status":
		recording, elapsed := s.localRecorder.Status(req.Serial)
		writeJSON(w, map[string]any{
			"ok":        true,
			"recording": recording,
			"elapsedMs": elapsed.Milliseconds(),
		})
	default:
		writeAPIError(w, http.StatusBadRequest, "invalid action, use start, stop or status")
	}
}
