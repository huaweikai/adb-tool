package server

import (
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"unicode"
)

func validIOSCrashReportName(name string) bool {
	switch strings.ToLower(filepath.Ext(name)) {
	case ".ips", ".crash", ".panic":
	default:
		return false
	}
	return filepath.IsLocal(name) && !strings.ContainsAny(name, "/\\:\"*?<>|") &&
		strings.IndexFunc(name, unicode.IsControl) < 0
}

func parseIOSCrashReports(output []byte) []string {
	names := make([]string, 0)
	for line := range strings.SplitSeq(string(output), "\n") {
		name, ok := strings.CutPrefix(strings.TrimSuffix(line, "\r"), "/")
		if ok && validIOSCrashReportName(name) {
			names = append(names, name)
		}
	}
	slices.Sort(names)
	return slices.Compact(names)
}

func (s *Server) iosTarget(w http.ResponseWriter, r *http.Request, capability DeviceCapability) string {
	serial := r.URL.Query().Get("serial")
	if !strings.HasPrefix(serial, "ios:") || serial == "ios:" {
		writeAPIError(w, http.StatusBadRequest, "iOS device ID required")
		return ""
	}
	for _, device := range s.ios.snapshot() {
		if device.Serial == serial && slices.Contains(device.Capabilities, capability) {
			return strings.TrimPrefix(device.Serial, "ios:")
		}
	}
	writeAPIError(w, http.StatusNotFound, "iOS device is unavailable")
	return ""
}

func (s *Server) handleIOSCrashReports(w http.ResponseWriter, r *http.Request) {
	udid := s.iosTarget(w, r, capabilityCrashReports)
	if udid == "" {
		return
	}
	output, err := s.ios.command(r.Context(), "crash", "ls", "--udid", udid)
	if err != nil {
		Log.Add("iOS crash report list", err.Error(), err, 0)
		writeAPIError(w, http.StatusBadGateway, "Could not list iOS crash reports")
		return
	}
	writeJSON(w, parseIOSCrashReports(output))
}

func (s *Server) handleIOSCrashReport(w http.ResponseWriter, r *http.Request) {
	udid := s.iosTarget(w, r, capabilityCrashReports)
	if udid == "" {
		return
	}
	name := r.URL.Query().Get("name")
	if !validIOSCrashReportName(name) {
		writeAPIError(w, http.StatusBadRequest, "Invalid crash report filename")
		return
	}
	dir, err := os.MkdirTemp("", "adb-tool-crash-")
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, "Could not create crash report directory")
		return
	}
	defer os.RemoveAll(dir)
	if _, err := s.ios.command(r.Context(), "crash", "pull", "--udid", udid, dir, "/"+name); err != nil {
		Log.Add("iOS crash report download", err.Error(), err, 0)
		writeAPIError(w, http.StatusBadGateway, "Could not download iOS crash report")
		return
	}
	root, err := os.OpenRoot(dir)
	if err != nil {
		writeAPIError(w, http.StatusBadGateway, "Could not open downloaded crash report")
		return
	}
	defer root.Close()
	info, err := root.Lstat(name)
	if err != nil || !info.Mode().IsRegular() {
		writeAPIError(w, http.StatusBadGateway, "Downloaded crash report is missing")
		return
	}
	file, err := root.Open(name)
	if err != nil {
		writeAPIError(w, http.StatusBadGateway, "Could not open downloaded crash report")
		return
	}
	defer file.Close()
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Content-Disposition", mime.FormatMediaType("attachment", map[string]string{"filename": name}))
	http.ServeContent(w, r, name, info.ModTime(), file)
}
