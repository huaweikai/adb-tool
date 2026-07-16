package server

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

func adbToolDir() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return filepath.Join(os.TempDir(), ".adb-tool")
	}
	return filepath.Join(home, ".adb-tool")
}

func iconCachePath() string {
	return filepath.Join(adbToolDir(), "app_icon")
}

func iconFileName(pkg string) string {
	return strings.ReplaceAll(pkg, "/", "_") + ".png"
}

func (s *Server) handleRefreshIcons(w http.ResponseWriter, r *http.Request) {
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
		writeAPIError(w, http.StatusInternalServerError, fmt.Sprintf("install helper: %v", err))
		return
	}

	_, err := s.adb.run("-s", serial, "shell", "am", "start",
		"-n", "com.adbtool.clipboard/.icon.IconDumpActivity")
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, fmt.Sprintf("launch icon dump: %v", err))
		return
	}

	donePath := "/sdcard/Android/data/com.adbtool.clipboard/files/adb-tool-icons/.done"
	deadline := time.Now().Add(60 * time.Second)
	polled := false
	for time.Now().Before(deadline) {
		out, _ := s.adb.run("-s", serial, "shell", "test", "-f", donePath, "&&", "echo", "done")
		if strings.TrimSpace(out) == "done" {
			polled = true
			break
		}
		time.Sleep(800 * time.Millisecond)
	}
	if !polled {
		writeAPIError(w, http.StatusGatewayTimeout, "icon dump timed out")
		return
	}

	remoteIconsDir := "/sdcard/Android/data/com.adbtool.clipboard/files/adb-tool-icons"
	localCacheDir := iconCachePath()

	tmpDir := filepath.Join(os.TempDir(), "adb-tool-cache",
		"icons-pull-"+time.Now().Format("20060102150405.000000000"))
	os.RemoveAll(tmpDir)
	os.MkdirAll(tmpDir, 0755)

	out, err := s.adb.runRaw("-s", serial, "pull", remoteIconsDir, tmpDir)
	if err != nil {
		os.RemoveAll(tmpDir)
		writeAPIError(w, http.StatusInternalServerError, fmt.Sprintf("pull icons: %v\n%s", err, out))
		return
	}

	pulledDir := filepath.Join(tmpDir, "adb-tool-icons")
	os.RemoveAll(localCacheDir)
	if err := os.Rename(pulledDir, localCacheDir); err != nil {
		os.MkdirAll(localCacheDir, 0755)
		entries, _ := os.ReadDir(pulledDir)
		for _, entry := range entries {
			if !entry.IsDir() {
				data, readErr := os.ReadFile(filepath.Join(pulledDir, entry.Name()))
				if readErr == nil {
					os.WriteFile(filepath.Join(localCacheDir, entry.Name()), data, 0644)
				}
			}
		}
	}
	os.RemoveAll(tmpDir)

	type iconEntry struct {
		Name    string `json:"name"`
		IconURL string `json:"iconUrl"`
	}
	packages := make([]iconEntry, 0)
	entries, err := os.ReadDir(localCacheDir)
	if err == nil {
		for _, entry := range entries {
			if entry.IsDir() || entry.Name() == ".done" {
				continue
			}
			pkg := strings.TrimSuffix(entry.Name(), ".png")
			packages = append(packages, iconEntry{
				Name:    pkg,
				IconURL: "/api/icons/" + iconFileName(pkg),
			})
		}
	}

	writeJSON(w, map[string]interface{}{"packages": packages})
}

func (s *Server) handleCachedIcon(w http.ResponseWriter, r *http.Request) {
	// Path: /api/icons/<filename>.png
	pkg := r.URL.Query().Get("package")
	name := strings.TrimPrefix(r.URL.Path, "/api/icons/")
	if pkg != "" {
		name = iconFileName(pkg)
	}
	if name == "" {
		writeAPIError(w, http.StatusBadRequest, "missing icon name")
		return
	}
	iconPath := filepath.Join(iconCachePath(), filepath.Base(name))
	if _, err := os.Stat(iconPath); err != nil {
		writeAPIError(w, http.StatusNotFound, "icon not found")
		return
	}
	w.Header().Set("Content-Type", "image/png")
	http.ServeFile(w, r, iconPath)
}
