// One-shot "clean all adb-tool caches" endpoint.
//
// Most of the app's state lives under ~/.adb-tool/ (cache + emulator
// tree + SDK), but a handful of one-off side directories leak out:
// system TempDir for adb/scrcpy binaries and short-lived scratch
// files, the Flutter desktop SQLite at
// %APPDATA%\com.example.ADB Tool\, the backend log under
// ~/Library/Application Support/ADBTool (macOS) or %APPDATA%\ADBTool
// (Windows), and the Flutter engine's ADBToolData cache. This
// handler whitelists a small set of paths and only ever touches
// those, so a stray install location outside the list is left alone.
//
// The Android SDK under ~/.adb-tool/sdk/ is the one thing we
// specifically do NOT touch (the user installed it). The
// `keepSDK` body field defaults to true for that reason.
package server

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strings"
)

// cacheCleanupRequest is the optional JSON body.
type cacheCleanupRequest struct {
	KeepSDK *bool `json:"keepSDK"`
}

// cacheCleanupEntry describes one path the handler tried to wipe.
type cacheCleanupEntry struct {
	Path        string `json:"path"`
	Description string `json:"description,omitempty"`
	Existed     bool   `json:"existed"`
	SizeBytes   int64  `json:"sizeBytes"`
	Error       string `json:"error,omitempty"`
}

// cacheCleanupResult is the JSON response.
type cacheCleanupResult struct {
	Success    bool                `json:"success"`
	KeptSDK    bool                `json:"keptSDK"`
	TotalBytes int64               `json:"totalBytes"`
	Cleaned    []cacheCleanupEntry `json:"cleaned"`
	Skipped    []cacheCleanupEntry `json:"skipped"`
}

func (s *Server) handleCacheCleanup(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	// Destructive action — require an explicit ack.
	if r.URL.Query().Get("confirm") != "true" {
		writeAPIError(w, http.StatusBadRequest,
			"pass ?confirm=true to acknowledge this destructive cleanup")
		return
	}

	var req cacheCleanupRequest
	if r.Body != nil {
		_ = json.NewDecoder(r.Body).Decode(&req)
	}
	keepSDK := true
	if req.KeepSDK != nil {
		keepSDK = *req.KeepSDK
	}

	result := cacheCleanupResult{
		Success: true,
		KeptSDK: keepSDK,
	}

	for _, c := range cacheCleanupCandidates(keepSDK) {
		entry := wipeCacheCandidate(c)
		if entry.Error == "" {
			result.Cleaned = append(result.Cleaned, entry)
			result.TotalBytes += entry.SizeBytes
		} else {
			result.Skipped = append(result.Skipped, entry)
		}
	}

	writeJSON(w, result)
}

// cacheCandidate describes one path to wipe and how to wipe it.
type cacheCandidate struct {
	Path        string // absolute path, may contain a single * glob segment
	Description string
	// SpecialMode lets us distinguish "wipe the directory wholesale"
	// (the default) from "wipe just the *.log files inside" (for
	// emulator instance dirs, where we want to keep the AVD).
	SpecialMode string
}

const (
	modeInstanceLogs = "instance-logs"
)

// cacheCleanupCandidates returns the whitelisted set of paths we
// know how to safely wipe. The list is intentionally narrow — if a
// future feature starts writing to a new place, it must be added
// here AND documented.
//
// IMPORTANT: we do NOT add the adb / scrcpy binary cache under
// os.TempDir()/adb-tool-cache to this list. The backend process
// holds the cached adb.exe open across the whole session, and
// scrcpy.exe is launched on demand. Wiping those paths while the
// backend is running makes the app immediately unable to talk to
// devices (fork/exec returns "file not found") and the user has
// to fully quit and relaunch the app to recover. Those binaries
// are re-extracted from the embedded zip on next startup anyway,
// so they're not real long-term disk usage.
func cacheCleanupCandidates(keepSDK bool) []cacheCandidate {
	home, _ := os.UserHomeDir()
	tempDir := os.TempDir()
	var out []cacheCandidate

	// 1. Scratch files dropped into TempDir by various handlers. We
	// use globbing so we can match the timestamped suffixes each
	// handler appends.

	// 2. Scratch files dropped into TempDir by various handlers. We
	// use globbing so we can match the timestamped suffixes each
	// handler appends.
	out = append(out, cacheCandidate{
		Path:        filepath.Join(tempDir, "adb-tool-pull-*"),
		Description: "scratch files for ADB pull",
	})
	out = append(out, cacheCandidate{
		Path:        filepath.Join(tempDir, "adb-tool-push-*"),
		Description: "scratch files for ADB push",
	})
	out = append(out, cacheCandidate{
		Path:        filepath.Join(tempDir, "adb-recording-*.mp4"),
		Description: "scratch screen-recording files",
	})
	out = append(out, cacheCandidate{
		Path:        filepath.Join(tempDir, "clipboard-helper.apk"),
		Description: "clipboard helper scratch APK",
	})
	out = append(out, cacheCandidate{
		Path:        filepath.Join(tempDir, "sdk-import-*.zip"),
		Description: "scratch SDK import zips",
	})
	out = append(out, cacheCandidate{
		Path:        filepath.Join(tempDir, "image-import-*.zip"),
		Description: "scratch system-image import zips",
	})
	out = append(out, cacheCandidate{
		Path:        filepath.Join(tempDir, "java-import-*.zip"),
		Description: "scratch Java runtime import zips",
	})

	if home != "" {
		// 3. Emulator instance logs (under each instance/logs/*.log) —
		// we keep the AVD itself (config.ini, *.img, *.avd) and just
		// drop the boot/runtime log files.
		out = append(out, cacheCandidate{
			Path:        filepath.Join(home, ".adb-tool", "emulator", "instances"),
			Description: "emulator instance logs (AVD files kept)",
			SpecialMode: modeInstanceLogs,
		})

		// 4. flutter engine cache on Windows / macOS. Best-effort:
		// if it doesn't exist or is locked, we just record a skip.
		if runtime.GOOS == "windows" {
			out = append(out, cacheCandidate{
				Path:        filepath.Join(home, "ADBToolData"),
				Description: "Flutter engine cache (Windows release)",
			})
		} else if runtime.GOOS == "darwin" {
			out = append(out, cacheCandidate{
				Path:        filepath.Join(home, "ADBToolData"),
				Description: "Flutter engine cache (macOS release)",
			})
		}
	}

	// 5. Flutter desktop app data (SQLite + session artifacts).
	if p := flutterAppDataDir(); p != "" {
		out = append(out, cacheCandidate{
			Path:        p,
			Description: "Flutter app SQLite db + session artifacts",
		})
	}

	// 6. Backend log.
	if p := backendLogDir(); p != "" {
		out = append(out, cacheCandidate{
			Path:        p,
			Description: "backend log (50MB cap, 2 backups)",
		})
	}

	// keepSDK is honored by leaving ~/.adb-tool/sdk/ out of the list
	// unconditionally (it's never added). This branch only exists so
	// we can document the contract in logs / response.
	_ = keepSDK

	return out
}

// flutterAppDataDir returns the platform-specific path the Flutter
// desktop app uses for its SQLite db, session artifacts, and
// exports — i.e. the value path_provider returns for
// getApplicationSupportDirectory().
//
// We hardcode the bundle id ("com.example.ADB Tool") to match what
// Flutter resolves from the Windows/macOS runner's PRODUCT_BUNDLE_IDENTIFIER.
func flutterAppDataDir() string {
	if runtime.GOOS == "windows" {
		appdata := os.Getenv("APPDATA")
		if appdata == "" {
			return ""
		}
		return filepath.Join(appdata, "com.example.ADB Tool")
	}
	home, _ := os.UserHomeDir()
	if home == "" {
		return ""
	}
	if runtime.GOOS == "darwin" {
		return filepath.Join(home, "Library", "Application Support", "com.example.ADB Tool")
	}
	return filepath.Join(home, ".local", "share", "com.example.ADB Tool")
}

func wipeCacheCandidate(c cacheCandidate) cacheCleanupEntry {
	entry := cacheCleanupEntry{Path: c.Path, Description: c.Description}
	if c.Path == "" {
		entry.Error = "path empty (env var unset?)"
		return entry
	}

	switch c.SpecialMode {
	case modeInstanceLogs:
		size, existed, err := wipeInstanceLogs(c.Path)
		if err != nil {
			entry.Error = err.Error()
		}
		entry.Existed = existed
		entry.SizeBytes = size
		return entry
	}

	// Glob path: the candidate's Path contains a *.
	if strings.Contains(c.Path, "*") {
		matches, err := filepath.Glob(c.Path)
		if err != nil {
			entry.Error = fmt.Sprintf("glob: %v", err)
			return entry
		}
		if len(matches) == 0 {
			entry.Existed = false
			return entry
		}
		var total int64
		anyExisted := false
		for _, m := range matches {
			size, existed, err := wipePath(m)
			if err != nil {
				entry.Error = err.Error()
				return entry
			}
			total += size
			anyExisted = anyExisted || existed
		}
		entry.Existed = anyExisted
		entry.SizeBytes = total
		return entry
	}

	size, existed, err := wipePath(c.Path)
	if err != nil {
		entry.Error = err.Error()
	}
	entry.Existed = existed
	entry.SizeBytes = size
	return entry
}

func wipePath(p string) (int64, bool, error) {
	info, err := os.Stat(p)
	if os.IsNotExist(err) {
		return 0, false, nil
	}
	if err != nil {
		return 0, false, err
	}
	var size int64
	if info.IsDir() {
		_ = filepath.Walk(p, func(_ string, fi os.FileInfo, err error) error {
			if err == nil && !fi.IsDir() {
				size += fi.Size()
			}
			return nil
		})
	} else {
		size = info.Size()
	}
	if err := os.RemoveAll(p); err != nil {
		return size, true, err
	}
	return size, true, nil
}

// wipeInstanceLogs walks <root>/<id>/logs/*.log and removes the log
// files. The AVD itself (config.ini, *.img, *.avd, *.lock) is left
// alone so the user does not have to recreate their emulator.
func wipeInstanceLogs(root string) (int64, bool, error) {
	info, err := os.Stat(root)
	if os.IsNotExist(err) {
		return 0, false, nil
	}
	if err != nil {
		return 0, false, err
	}
	if !info.IsDir() {
		return wipePath(root)
	}
	var total int64
	existed := false
	err = filepath.Walk(root, func(path string, fi os.FileInfo, walkErr error) error {
		if walkErr != nil || fi.IsDir() {
			return nil
		}
		name := fi.Name()
		isLog := strings.HasSuffix(name, ".log") ||
			strings.HasSuffix(name, ".log.txt") ||
			strings.HasSuffix(name, ".log.old")
		if !isLog {
			return nil
		}
		existed = true
		total += fi.Size()
		_ = os.Remove(path)
		return nil
	})
	return total, existed, err
}
