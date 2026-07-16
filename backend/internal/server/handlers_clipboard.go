package server

import (
	"encoding/json"
	"net/http"
	"strings"
)

// handleClipboardCheck reports whether the clipboard helper APK is installed on the device.
func (s *Server) handleClipboardCheck(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	installed := s.adb.IsClipboardHelperInstalled(serial)
	writeJSON(w, map[string]interface{}{"installed": installed})
}

// handleClipboardInstall installs the embedded clipboard helper APK onto the device.
func (s *Server) handleClipboardInstall(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	if err := s.adb.ensureHelperInstalled(serial, s.clipboardApk); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

// handleClipboardSend writes the given text to the device clipboard via the helper APK.
func (s *Server) handleClipboardSend(w http.ResponseWriter, r *http.Request) {
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
		Text string `json:"text"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<20)).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, "text required")
		return
	}
	text := strings.TrimSpace(req.Text)
	if text == "" {
		writeAPIError(w, http.StatusBadRequest, "text required")
		return
	}
	if err := s.adb.SendClipboard(serial, text); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

// handleClipboardUninstall removes the clipboard helper APK from the device.
func (s *Server) handleClipboardUninstall(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	if err := s.adb.UninstallClipboardHelper(serial); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}
