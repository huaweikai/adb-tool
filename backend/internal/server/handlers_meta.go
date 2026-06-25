package server

import (
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"os"
	"strings"
	"time"
)

// handleBackendLogs returns the in-memory ring buffer by default, or the
// last N entries from the on-disk log file when ?tail=N is specified.
func (s *Server) handleBackendLogs(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	var entries []LogEntry
	if n := q.Get("tail"); n != "" {
		var count int
		fmt.Sscanf(n, "%d", &count)
		entries = Log.FileTail(count)
	} else {
		entries = Log.Snapshot()
	}
	if entries == nil {
		entries = []LogEntry{}
	}
	writeJSON(w, map[string]interface{}{"logs": entries})
}

// handleAdbExec runs a generic adb command against a device. Args are passed
// straight to `adb -s <serial> <args...>`.
//
// A dangerous-command guard is applied when the user sends a shell command
// that matches a known destructive pattern (see isDangerousCommand).
// To bypass the guard, pass ?confirm=true — intended for automated / scripted
// callers that understand the risk.
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
	confirm := r.URL.Query().Get("confirm") == "true"
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

	// Dangerous command guard
	if !confirm {
		if warning, ok := isDangerousCommand(req.Args); ok {
			writeJSON(w, map[string]interface{}{
				"ok":      false,
				"blocked": true,
				"warning": warning,
				"confirm": "pass ?confirm=true to execute anyway",
			})
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

// handleEnvDebug returns the environment variables of this backend process.
// Useful for debugging why ANDROID_HOME is not available.
func (s *Server) handleEnvDebug(w http.ResponseWriter, r *http.Request) {
	envVars := []map[string]string{
		{"ANDROID_HOME": os.Getenv("ANDROID_HOME")},
		{"ANDROID_SDK_ROOT": os.Getenv("ANDROID_SDK_ROOT")},
		{"HOME": os.Getenv("HOME")},
		{"PATH": os.Getenv("PATH")},
		{"USER": os.Getenv("USER")},
		{"PWD": os.Getenv("PWD")},
	}

	// Check some common SDK paths
	home, _ := os.UserHomeDir()
	paths := map[string]bool{}
	if home != "" {
		paths["~/Library/Android/sdk"] = directoryExists(home + "/Library/Android/sdk")
		paths["~/.adb-tool/sdk"] = directoryExists(home + "/.adb-tool/sdk")
	}

	writeJSON(w, map[string]interface{}{
		"pid": os.Getpid(),
		"env": envVars,
		"paths": paths,
	})
}

func directoryExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
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
