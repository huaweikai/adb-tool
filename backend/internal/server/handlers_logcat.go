package server

import (
	"encoding/json"
	"net/http"
	"strconv"
)

// handleLogStream upgrades the request to a WebSocket for live logcat streaming.
func (s *Server) handleLogStream(w http.ResponseWriter, r *http.Request) {
	conn, err := s.upgrader.Upgrade(w, r, nil)
	if err != nil {
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
