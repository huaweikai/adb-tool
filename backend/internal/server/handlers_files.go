package server

import (
	"archive/zip"
	"encoding/json"
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

// handlePullFile downloads a file (or directory as zip) from the device.
func (s *Server) handlePullFile(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	path := r.URL.Query().Get("path")
	if serial == "" || path == "" {
		writeAPIError(w, http.StatusBadRequest, "serial and path required")
		return
	}
	tmpPath := filepath.Join(os.TempDir(), "adb-tool-pull-"+time.Now().Format("20060102150405.000000000"))
	if err := s.adb.PullFileToPathContext(r.Context(), serial, path, tmpPath); err != nil {
		if r.Context().Err() != nil {
			writeAPIError(w, 499, "操作已取消")
			return
		}
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	localStat, localErr := os.Stat(tmpPath)
	if localErr == nil && localStat.IsDir() {
		dirName := deviceBaseName(path)
		renamed := filepath.Join(filepath.Dir(tmpPath), dirName)
		if err := os.Rename(tmpPath, renamed); err != nil {
			writeAPIError(w, http.StatusInternalServerError, err.Error())
			return
		}
		tmpPath = renamed
		zipPath := tmpPath + ".zip"
		if err := zipDirectory(tmpPath, zipPath); err != nil {
			writeAPIError(w, http.StatusInternalServerError, err.Error())
			return
		}
		defer os.RemoveAll(tmpPath)
		defer os.Remove(zipPath)
		w.Header().Set("Content-Disposition", "attachment; filename=\""+dirName+".zip\"")
		w.Header().Set("Content-Type", "application/zip")
		http.ServeFile(w, r, zipPath)
		return
	}
	defer os.Remove(tmpPath)
	w.Header().Set("Content-Disposition", "attachment; filename=\""+filepath.Base(path)+"\"")
	w.Header().Set("Content-Type", "application/octet-stream")
	http.ServeFile(w, r, tmpPath)
}

func copyDirectory(src, dst string) error {
	if err := os.MkdirAll(dst, 0755); err != nil {
		return err
	}
	entries, err := os.ReadDir(src)
	if err != nil {
		return err
	}
	for _, entry := range entries {
		srcPath := filepath.Join(src, entry.Name())
		dstPath := filepath.Join(dst, entry.Name())
		if entry.IsDir() {
			if err := copyDirectory(srcPath, dstPath); err != nil {
				return err
			}
		} else {
			srcFile, err := os.Open(srcPath)
			if err != nil {
				return err
			}
			dstFile, err := os.Create(dstPath)
			if err != nil {
				srcFile.Close()
				return err
			}
			_, err = io.Copy(dstFile, srcFile)
			srcFile.Close()
			dstFile.Close()
			if err != nil {
				return err
			}
		}
	}
	return nil
}

func zipDirectory(src, dst string) error {
	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer out.Close()
	zw := zip.NewWriter(out)
	defer zw.Close()
	parent := filepath.Dir(src)
	return filepath.Walk(src, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		rel, err := filepath.Rel(parent, path)
		if err != nil {
			return err
		}
		if rel == "." {
			return nil
		}
		rel = filepath.ToSlash(rel)
		if info.IsDir() {
			_, err := zw.Create(rel + "/")
			return err
		}
		f, err := os.Open(path)
		if err != nil {
			return err
		}
		defer f.Close()
		w, err := zw.Create(rel)
		if err != nil {
			return err
		}
		_, err = io.Copy(w, f)
		return err
	})
}

// handlePullDirectoryToPath pulls a device directory to a local directory.
func (s *Server) handlePullDirectoryToPath(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	var req struct {
		Serial     string `json:"serial"`
		RemotePath string `json:"remotePath"`
		DestDir    string `json:"destDir"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	if req.Serial == "" || req.RemotePath == "" || req.DestDir == "" {
		writeAPIError(w, http.StatusBadRequest, "serial, remotePath and destDir required")
		return
	}
	dirName := deviceBaseName(req.RemotePath)
	localTarget := filepath.Join(req.DestDir, dirName)
	if err := os.MkdirAll(req.DestDir, 0755); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	// Pull to a temp path first, then move to final destination
	tmpPull := filepath.Join(os.TempDir(), "adb-tool-pulldir-"+time.Now().Format("20060102150405.000000000"), dirName)
	if err := os.MkdirAll(filepath.Dir(tmpPull), 0755); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if err := s.adb.PullFileToPathContext(r.Context(), req.Serial, req.RemotePath, tmpPull); err != nil {
		os.RemoveAll(filepath.Dir(tmpPull))
		if r.Context().Err() != nil {
			writeAPIError(w, 499, "操作已取消")
			return
		}
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if err := os.RemoveAll(localTarget); err != nil {
		os.RemoveAll(filepath.Dir(tmpPull))
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if err := os.Rename(tmpPull, localTarget); err != nil {
		if copyErr := copyDirectory(tmpPull, localTarget); copyErr != nil {
			os.RemoveAll(filepath.Dir(tmpPull))
			writeAPIError(w, http.StatusInternalServerError, copyErr.Error())
			return
		}
	}
	os.RemoveAll(filepath.Dir(tmpPull))
	writeJSON(w, map[string]string{"status": "ok"})
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
