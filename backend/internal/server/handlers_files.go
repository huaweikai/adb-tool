package server

import (
	"io"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

// handleFiles lists the files in a directory on the device.
func (s *Server) handleFiles(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	path := r.URL.Query().Get("path")
	if serial == "" || path == "" {
		writeAPIError(w, http.StatusBadRequest, "serial and path required")
		return
	}
	entries, err := s.adb.ListFiles(serial, path)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if entries == nil {
		entries = []FileEntry{}
	}
	writeJSON(w, map[string]interface{}{"files": entries})
}

// handleFileContent returns the text content of a file on the device.
func (s *Server) handleFileContent(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	path := r.URL.Query().Get("path")
	if serial == "" || path == "" {
		writeAPIError(w, http.StatusBadRequest, "serial and path required")
		return
	}
	content, err := s.adb.ReadFile(serial, path)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]string{"content": content})
}

// handlePullFile downloads a file from the device.
func (s *Server) handlePullFile(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	path := r.URL.Query().Get("path")
	if serial == "" || path == "" {
		writeAPIError(w, http.StatusBadRequest, "serial and path required")
		return
	}
	tmpFile := filepath.Join(os.TempDir(), "adb-tool-pull-"+time.Now().Format("20060102150405.000000000"))
	defer os.Remove(tmpFile)
	if err := s.adb.PullFileToPathContext(r.Context(), serial, path, tmpFile); err != nil {
		if r.Context().Err() != nil {
			writeAPIError(w, 499, "操作已取消")
			return
		}
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	w.Header().Set("Content-Disposition", "attachment; filename=\""+filepath.Base(path)+"\"")
	w.Header().Set("Content-Type", "application/octet-stream")
	http.ServeFile(w, r, tmpFile)
}

// handlePushFile uploads a file to the device.
func (s *Server) handlePushFile(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	serial := r.URL.Query().Get("serial")
	path := r.URL.Query().Get("path")
	if serial == "" || path == "" {
		writeAPIError(w, http.StatusBadRequest, "serial and path required")
		return
	}
	defer r.Body.Close()
	tmpFile := filepath.Join(os.TempDir(), "adb-tool-push-"+time.Now().Format("20060102150405.000000000"))
	defer os.Remove(tmpFile)
	out, err := os.Create(tmpFile)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if _, err := io.Copy(out, r.Body); err != nil {
		if closeErr := out.Close(); closeErr != nil {
			Log.Add("push temp close", "", closeErr, 0)
		}
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if err := out.Close(); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if err := s.adb.PushFileFromPathContext(r.Context(), serial, tmpFile, path); err != nil {
		if r.Context().Err() != nil {
			writeAPIError(w, 499, "操作已取消")
			return
		}
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

// handleFileDelete deletes a file or (optionally) directory on the device.
func (s *Server) handleFileDelete(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	serial := r.URL.Query().Get("serial")
	path := r.URL.Query().Get("path")
	recursive := r.URL.Query().Get("recursive") == "true"
	if serial == "" || path == "" {
		writeAPIError(w, http.StatusBadRequest, "serial and path required")
		return
	}
	if err := s.adb.DeleteFile(serial, path, recursive); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

// handleFileRename renames (or moves) a file on the device.
func (s *Server) handleFileRename(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	serial := r.URL.Query().Get("serial")
	from := r.URL.Query().Get("from")
	to := r.URL.Query().Get("to")
	if serial == "" || from == "" || to == "" {
		writeAPIError(w, http.StatusBadRequest, "serial, from and to required")
		return
	}
	if err := s.adb.RenameFile(serial, from, to); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

// handleFileMkdir creates a directory on the device.
func (s *Server) handleFileMkdir(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	serial := r.URL.Query().Get("serial")
	path := r.URL.Query().Get("path")
	if serial == "" || path == "" {
		writeAPIError(w, http.StatusBadRequest, "serial and path required")
		return
	}
	if err := s.adb.MakeDir(serial, path); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

// handleFileTouch creates an empty file on the device.
func (s *Server) handleFileTouch(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	serial := r.URL.Query().Get("serial")
	path := r.URL.Query().Get("path")
	if serial == "" || path == "" {
		writeAPIError(w, http.StatusBadRequest, "serial and path required")
		return
	}
	if err := s.adb.TouchFile(serial, path); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

// handleFileStat returns metadata about a file on the device.
func (s *Server) handleFileStat(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	path := r.URL.Query().Get("path")
	if serial == "" || path == "" {
		writeAPIError(w, http.StatusBadRequest, "serial and path required")
		return
	}
	stat, err := s.adb.FileStat(serial, path)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]interface{}{"stat": stat})
}
