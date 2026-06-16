package server

import (
	"encoding/json"
	"net"
	"net/http"
	"os"
	"strings"
	"time"
)

// handleBackendLogs returns the in-memory ring buffer of recent backend operations.
func (s *Server) handleBackendLogs(w http.ResponseWriter, r *http.Request) {
	entries := Log.Snapshot()
	if entries == nil {
		entries = []LogEntry{}
	}
	writeJSON(w, map[string]interface{}{"logs": entries})
}

// handleAdbExec runs a generic adb command against a device. Args are passed
// straight to `adb -s <serial> <args...>`. Use with care — see C.3 in the
// optimization proposal for a future dangerous-command guard.
func (s *Server) handleAdbExec(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	defer r.Body.Close()
	var req struct {
		Args []string `json:"args"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	if len(req.Args) == 0 {
		writeAPIError(w, http.StatusBadRequest, "args required")
		return
	}
	for _, arg := range req.Args {
		if strings.TrimSpace(arg) == "" {
			writeAPIError(w, http.StatusBadRequest, "empty argument not allowed")
			return
		}
	}
	output, err := s.adb.Execute(serial, req.Args)
	if err != nil {
		writeAPIErrorData(w, http.StatusBadRequest, err.Error(), map[string]interface{}{"ok": false, "output": output})
		return
	}
	writeJSON(w, map[string]interface{}{"ok": true, "output": output})
}

// handleIdentify returns identifying info about this backend process.
func (s *Server) handleIdentify(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]interface{}{
		"name":    "adb-tool",
		"pid":     os.Getpid(),
		"started": s.startedAt.Format(time.RFC3339),
	})
}

// handleShutdown gracefully shuts down the backend. Only loopback callers
// (enforced by requireLoopback middleware) may invoke it.
func (s *Server) handleShutdown(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}

	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		writeAPIError(w, http.StatusForbidden, "bad remote addr")
		return
	}
	ip := net.ParseIP(host)
	if ip == nil || !ip.IsLoopback() {
		writeAPIError(w, http.StatusForbidden, "forbidden")
		return
	}

	writeJSON(w, map[string]string{"status": "shutting down"})
	go func() {
		time.Sleep(150 * time.Millisecond)
		if s.onShutdown != nil {
			s.onShutdown()
			return
		}
		s.Close()
	}()
}
