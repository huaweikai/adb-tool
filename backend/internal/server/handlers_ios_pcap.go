package server

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

type pcapStatusData struct {
	Status    string  `json:"status"`
	Active    bool    `json:"active"`
	FilePath  string  `json:"filePath"`
	Packets   int64   `json:"packets"`
	Bytes     int64   `json:"bytes"`
	Duration  float64 `json:"duration"`
	StartTime string  `json:"startTime"`
	Process   *string `json:"process,omitempty"`
	Interface *string `json:"interface,omitempty"`
	Error     *string `json:"error,omitempty"`
}

func sanitizeUDID(udid string) string {
	var b strings.Builder
	for _, r := range udid {
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r == '-' || r == '_' {
			b.WriteRune(r)
		}
	}
	return b.String()
}

func iosPcapDir() (string, error) {
	dir := filepath.Join(os.TempDir(), "adb_tool_pcap")
	if err := os.MkdirAll(dir, 0755); err != nil {
		return "", fmt.Errorf("create pcap directory: %w", err)
	}
	return dir, nil
}

func isAllowedPcapPath(baseDir, targetPath string) bool {
	base, err1 := filepath.EvalSymlinks(baseDir)
	if err1 != nil {
		base = baseDir
	}
	targetDir := filepath.Dir(filepath.Clean(targetPath))
	tDir, err2 := filepath.EvalSymlinks(targetDir)
	if err2 != nil {
		tDir = targetDir
	}
	base = strings.ToLower(filepath.Clean(base))
	tDir = strings.ToLower(filepath.Clean(tDir))
	rel, err := filepath.Rel(base, tDir)
	if err != nil {
		return false
	}
	return !strings.HasPrefix(rel, "..") && !filepath.IsAbs(rel)
}

func (s *Server) handleIOSPcapStart(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	udid := s.iosTarget(w, r, capabilityIOSPcap)
	if udid == "" {
		return
	}

	var transport string
	for _, d := range s.ios.snapshot() {
		if d.Serial == serial {
			transport = d.Transport
			break
		}
	}
	if transport == "wifi" && s.ios != nil {
		s.ios.refresh(r.Context(), nil)
		for _, d := range s.ios.snapshot() {
			if d.Serial == serial {
				transport = d.Transport
				break
			}
		}
	}
	if transport == "wifi" {
		Log.Add("iOS pcap start rejected", "iOS packet capture requires USB connection (Apple security restriction: Wi-Fi pairing prohibited)", nil, 0)
		writeAPIError(w, http.StatusBadRequest, "iOS 网络抓包服务受苹果系统安全策略限制：必须使用 USB 数据线连接电脑，禁止通过 Wi-Fi 抓包。请插入数据线并将设备切换至 USB 连接后再试。")
		return
	}

	process := strings.TrimSpace(r.URL.Query().Get("process"))
	iface := strings.TrimSpace(r.URL.Query().Get("interface"))

	dir, err := iosPcapDir()
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	ts := time.Now().Format("20060102_150405")
	filename := fmt.Sprintf("ios_capture_%s_%s.pcapng", sanitizeUDID(udid), ts)
	outPath := filepath.Join(dir, filename)

	out, err := s.ios.StartPcap(r.Context(), serial, outPath, process, iface)
	if err != nil {
		Log.Add("iOS pcap start error", err.Error(), err, 0)
		writeAPIError(w, http.StatusBadGateway, "Could not start iOS packet capture: "+err.Error())
		return
	}

	Log.Add("iOS pcap start", fmt.Sprintf("serial=%s udid=%s process=%s iface=%s out=%s", serial, udid, process, iface, outPath), nil, 0)

	var status pcapStatusData
	if err := json.Unmarshal(out, &status); err != nil {
		writeJSON(w, map[string]interface{}{
			"status":   "capturing",
			"active":   true,
			"filePath": outPath,
		})
		return
	}
	writeJSON(w, status)
}

func (s *Server) handleIOSPcapStop(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	udid := s.iosTarget(w, r, capabilityIOSPcap)
	if udid == "" {
		return
	}
	out, err := s.ios.StopPcap(r.Context(), serial)
	if err != nil {
		Log.Add("iOS pcap stop error", err.Error(), err, 0)
		writeAPIError(w, http.StatusBadGateway, "Could not stop iOS packet capture: "+err.Error())
		return
	}
	var status pcapStatusData
	if err := json.Unmarshal(out, &status); err != nil {
		Log.Add("iOS pcap stop", fmt.Sprintf("serial=%s udid=%s", serial, udid), nil, 0)
		writeJSON(w, map[string]interface{}{"status": "stopped", "active": false})
		return
	}
	Log.Add("iOS pcap stop", fmt.Sprintf("serial=%s udid=%s packets=%d bytes=%d duration=%.1fs file=%s", serial, udid, status.Packets, status.Bytes, status.Duration, status.FilePath), nil, 0)
	writeJSON(w, status)
}

func (s *Server) handleIOSPcapStatus(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	udid := s.iosTarget(w, r, capabilityIOSPcap)
	if udid == "" {
		return
	}
	out, err := s.ios.PcapStatus(r.Context(), serial)
	if err != nil {
		Log.Add("iOS pcap status error", err.Error(), err, 0)
		writeAPIError(w, http.StatusBadGateway, "Could not query iOS packet capture status: "+err.Error())
		return
	}
	var status pcapStatusData
	if err := json.Unmarshal(out, &status); err != nil {
		writeAPIError(w, http.StatusBadGateway, "Invalid packet capture status response")
		return
	}
	if status.Error != nil && *status.Error != "" {
		Log.Add("iOS pcap daemon error", fmt.Sprintf("serial=%s error=%s", serial, *status.Error), nil, 0)
	}
	writeJSON(w, status)
}

func (s *Server) handleIOSPcapDownload(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	udid := s.iosTarget(w, r, capabilityIOSPcap)
	if udid == "" {
		return
	}

	reqPath := r.URL.Query().Get("path")
	if reqPath == "" {
		out, err := s.ios.PcapStatus(r.Context(), serial)
		if err == nil {
			var status pcapStatusData
			if json.Unmarshal(out, &status) == nil && status.FilePath != "" {
				reqPath = status.FilePath
			}
		}
	}

	if reqPath == "" {
		writeAPIError(w, http.StatusNotFound, "No packet capture file found")
		return
	}

	cleaned := filepath.Clean(reqPath)
	pcapDir, err := iosPcapDir()
	if err != nil || !isAllowedPcapPath(pcapDir, cleaned) {
		writeAPIError(w, http.StatusForbidden, "Access to capture file denied")
		return
	}

	info, err := os.Stat(cleaned)
	if err != nil || info.IsDir() {
		writeAPIError(w, http.StatusNotFound, "Packet capture file does not exist")
		return
	}

	file, err := os.Open(cleaned)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, "Could not open packet capture file")
		return
	}
	defer file.Close()

	Log.Add("iOS pcap download", fmt.Sprintf("serial=%s file=%s size=%d", serial, filepath.Base(cleaned), info.Size()), nil, 0)

	w.Header().Set("Content-Type", "application/vnd.tcpdump.pcap")
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=%q", filepath.Base(cleaned)))
	http.ServeContent(w, r, filepath.Base(cleaned), info.ModTime(), file)
}

func findWireshark() (string, error) {
	switch runtime.GOOS {
	case "windows":
		candidates := []string{
			`C:\Program Files\Wireshark\Wireshark.exe`,
			`C:\Program Files (x86)\Wireshark\Wireshark.exe`,
		}
		for _, c := range candidates {
			if info, err := os.Stat(c); err == nil && !info.IsDir() {
				return c, nil
			}
		}
		if path, err := exec.LookPath("Wireshark.exe"); err == nil {
			return path, nil
		}
		if path, err := exec.LookPath("wireshark"); err == nil {
			return path, nil
		}
	case "darwin":
		candidates := []string{
			"/Applications/Wireshark.app/Contents/MacOS/Wireshark",
			filepath.Join(os.Getenv("HOME"), "Applications/Wireshark.app/Contents/MacOS/Wireshark"),
		}
		for _, c := range candidates {
			if info, err := os.Stat(c); err == nil && !info.IsDir() {
				return c, nil
			}
		}
		if path, err := exec.LookPath("wireshark"); err == nil {
			return path, nil
		}
	default:
		if path, err := exec.LookPath("wireshark"); err == nil {
			return path, nil
		}
	}
	return "", fmt.Errorf("Wireshark was not found. Please install Wireshark or open the saved pcapng file manually.")
}

func (s *Server) handleIOSPcapWireshark(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	udid := s.iosTarget(w, r, capabilityIOSPcap)
	if udid == "" {
		return
	}

	reqPath := r.URL.Query().Get("path")
	if reqPath == "" {
		out, err := s.ios.PcapStatus(r.Context(), serial)
		if err == nil {
			var status pcapStatusData
			if json.Unmarshal(out, &status) == nil && status.FilePath != "" {
				reqPath = status.FilePath
			}
		}
	}

	if reqPath == "" {
		writeAPIError(w, http.StatusNotFound, "No packet capture file found")
		return
	}

	cleaned := filepath.Clean(reqPath)
	pcapDir, err := iosPcapDir()
	if err != nil || !isAllowedPcapPath(pcapDir, cleaned) {
		writeAPIError(w, http.StatusForbidden, "Access to capture file denied")
		return
	}

	if _, err := os.Stat(cleaned); err != nil {
		writeAPIError(w, http.StatusNotFound, "Packet capture file does not exist")
		return
	}

	wsBin, err := findWireshark()
	if err != nil {
		writeAPIError(w, http.StatusNotFound, err.Error())
		return
	}

	cmd := exec.Command(wsBin, cleaned)
	if err := cmd.Start(); err != nil {
		Log.Add("Wireshark launch error", err.Error(), err, 0)
		writeAPIError(w, http.StatusInternalServerError, "Failed to launch Wireshark: "+err.Error())
		return
	}

	Log.Add("iOS pcap wireshark", fmt.Sprintf("serial=%s wsBin=%s file=%s", serial, wsBin, cleaned), nil, 0)

	writeJSON(w, map[string]interface{}{
		"launched":      true,
		"wiresharkPath": wsBin,
		"filePath":      cleaned,
	})
}
