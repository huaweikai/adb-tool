package server

import (
	"archive/zip"
	"bytes"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"time"
)

type Device struct {
	Serial string `json:"serial"`
	State  string `json:"state"`
	Model  string `json:"model"`
	Brand  string `json:"brand"`
	SDK    string `json:"sdk"`
}

type LogFilter struct {
	Tag         string `json:"tag"`
	Priority    string `json:"priority"`
	Keyword     string `json:"keyword"`
	PackageName string `json:"packageName"`
	PackagePid  string `json:"packagePid"`
}

type AdbManager struct {
	adbPath string
}

func (m *AdbManager) AdbPath() string {
	return m.adbPath
}

func NewAdbManager(adbPath string) *AdbManager {
	return &AdbManager{adbPath: adbPath}
}

func FindOrExtractADB(zipData []byte) (string, error) {
	adbName := "adb"
	if runtime.GOOS == "windows" {
		adbName = "adb.exe"
	}

	cacheDir := filepath.Join(os.TempDir(), "adb-tool-cache")
	adbPath := filepath.Join(cacheDir, adbName)

	if _, err := os.Stat(adbPath); err == nil {
		os.Chmod(adbPath, 0755)
		return adbPath, nil
	}

	os.MkdirAll(cacheDir, 0755)

	reader, err := zip.NewReader(bytes.NewReader(zipData), int64(len(zipData)))
	if err != nil {
		return "", fmt.Errorf("failed to read zip: %w", err)
	}

	for _, f := range reader.File {
		name := filepath.Base(f.Name)
		if strings.EqualFold(name, adbName) || (runtime.GOOS == "windows" && strings.EqualFold(name, "adb.exe")) {
			rc, err := f.Open()
			if err != nil {
				return "", fmt.Errorf("failed to open adb in zip: %w", err)
			}
			defer rc.Close()

			dst, err := os.OpenFile(adbPath, os.O_CREATE|os.O_WRONLY, 0755)
			if err != nil {
				return "", fmt.Errorf("failed to create adb binary: %w", err)
			}
			defer dst.Close()

			_, err = io.Copy(dst, rc)
			if err != nil {
				return "", fmt.Errorf("failed to extract adb: %w", err)
			}

			os.Chmod(adbPath, 0755)
			return adbPath, nil
		}
	}

	return "", fmt.Errorf("adb binary not found in platform-tools zip")
}

func (m *AdbManager) run(args ...string) (string, error) {
	start := time.Now()
	cmdStr := strings.Join(args, " ")
	cmd := exec.Command(m.adbPath, args...)
	output, err := cmd.CombinedOutput()
	elapsed := time.Since(start)
	outStr := strings.TrimSpace(string(output))
	if err != nil {
		errStr := fmt.Sprintf("adb %s: %v\n%s", cmdStr, err, string(output))
		Log.Add("adb "+cmdStr, "", err, elapsed)
		return "", fmt.Errorf("%s", errStr)
	}
	if len(outStr) > 500 {
		Log.Add("adb "+cmdStr, outStr[:500]+fmt.Sprintf("... (%d bytes)", len(outStr)), nil, elapsed)
	} else {
		Log.Add("adb "+cmdStr, outStr, nil, elapsed)
	}
	return outStr, nil
}

func (m *AdbManager) runOut(args ...string) ([]byte, error) {
	start := time.Now()
	cmdStr := strings.Join(args, " ")
	cmd := exec.Command(m.adbPath, args...)
	output, err := cmd.Output()
	elapsed := time.Since(start)
	if err != nil {
		Log.Add("adb "+cmdStr, "", err, elapsed)
	} else {
		Log.Add("adb "+cmdStr, fmt.Sprintf("<%d bytes binary>", len(output)), nil, elapsed)
	}
	return output, err
}

func (m *AdbManager) Devices() ([]Device, error) {
	out, err := m.run("devices", "-l")
	if err != nil {
		return nil, err
	}

	var devices []Device
	lines := strings.Split(out, "\n")
	for _, line := range lines[1:] {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}
		serial := fields[0]
		state := fields[1]

		device := Device{Serial: serial, State: state}

		props, err := m.deviceProps(serial)
		if err == nil {
			device.Model = props["ro.product.model"]
			device.Brand = props["ro.product.brand"]
			device.SDK = props["ro.build.version.sdk"]
		}

		devices = append(devices, device)
	}

	return devices, nil
}

func (m *AdbManager) deviceProps(serial string) (map[string]string, error) {
	out, err := m.run("-s", serial, "shell", "getprop")
	if err != nil {
		return nil, err
	}
	props := make(map[string]string)
	for _, line := range strings.Split(out, "\n") {
		line = strings.TrimSpace(line)
		if !strings.HasPrefix(line, "[ro.product") && !strings.HasPrefix(line, "[ro.build.version.sdk") {
			continue
		}
		parts := strings.SplitN(line, "]: [", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimPrefix(parts[0], "[")
		val := strings.TrimSuffix(parts[1], "]")
		props[key] = val
	}
	return props, nil
}

func (m *AdbManager) StartLogcat(serial string, filter LogFilter) (*exec.Cmd, io.ReadCloser, error) {
	m.ClearLogcat(serial)

	args := []string{"-s", serial, "logcat", "-v", "threadtime"}

	if filter.Priority != "" {
		args = append(args, "*:"+filter.Priority)
	}

	if filter.PackagePid != "" {
		args = append(args, "--pid="+filter.PackagePid)
	}

	cmd := exec.Command(m.adbPath, args...)

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, nil, err
	}
	cmd.Stderr = cmd.Stdout

	if err := cmd.Start(); err != nil {
		return nil, nil, err
	}

	return cmd, stdout, nil
}

func (m *AdbManager) GetPackagePID(serial, packageName string) (string, error) {
	out, err := m.run("-s", serial, "shell", "pidof", packageName)
	if err != nil {
		return "", err
	}
	pid := strings.TrimSpace(out)
	if pid == "" {
		return "", fmt.Errorf("package %s not running", packageName)
	}
	return pid, nil
}

func (m *AdbManager) GetRunningPackages(serial string) ([]string, error) {
	out, err := m.run("-s", serial, "shell", "ps", "-A", "-o", "NAME")
	if err != nil {
		return nil, err
	}

	seen := make(map[string]bool)
	var packages []string
	for _, line := range strings.Split(out, "\n") {
		name := strings.TrimSpace(line)
		if name == "" || name == "NAME" {
			continue
		}
		if !strings.Contains(name, ".") {
			continue
		}
		if strings.HasPrefix(name, "[") {
			continue
		}
		if seen[name] {
			continue
		}
		seen[name] = true
		packages = append(packages, name)
	}
	sort.Strings(packages)
	return packages, nil
}

func (m *AdbManager) ClearLogcat(serial string) error {
	_, err := m.run("-s", serial, "logcat", "-c")
	return err
}

type FileEntry struct {
	Name        string `json:"name"`
	Path        string `json:"path"`
	Size        int64  `json:"size"`
	IsDir       bool   `json:"isDir"`
	Permissions string `json:"permissions"`
	Modified    string `json:"modified"`
}

type PackageInfo struct {
	PackageName string `json:"packageName"`
	SourceDir   string `json:"sourceDir"`
}

func (m *AdbManager) ListFiles(serial, path string) ([]FileEntry, error) {
	path = strings.TrimRight(path, "/")
	out, err := m.run("-s", serial, "shell", "ls", "-la", path)
	if err != nil {
		return nil, err
	}
	return parseLsOutput(out, path), nil
}

func parseLsOutput(out, basePath string) []FileEntry {
	lines := strings.Split(out, "\n")
	var entries []FileEntry
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "total ") {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) < 8 {
			continue
		}
		perms := fields[0]
		if len(perms) < 10 {
			continue
		}

		var size int64
		if s, err := strconv.ParseInt(fields[4], 10, 64); err == nil {
			size = s
		}
		name := strings.Join(fields[7:], " ")
		if name == "." || name == ".." {
			continue
		}
		// strip symlink target " -> /path" from name
		if idx := strings.Index(name, " -> "); idx > 0 {
			name = name[:idx]
		}

		fullPath := basePath + "/" + name

		entries = append(entries, FileEntry{
			Name:        name,
			Path:        fullPath,
			Size:        size,
			IsDir:       perms[0] == 'd' || perms[0] == 'l',
			Permissions: perms,
			Modified:    fields[5] + " " + fields[6],
		})
	}
	return entries
}

func (m *AdbManager) ReadFile(serial, path string) (string, error) {
	return m.run("-s", serial, "shell", "cat", path)
}

func (m *AdbManager) InstalledPackages(serial string) ([]PackageInfo, error) {
	out, err := m.run("-s", serial, "shell", "pm", "list", "packages", "-f")
	if err != nil {
		out, err = m.run("-s", serial, "shell", "pm", "list", "packages")
		if err != nil {
			return nil, err
		}
		// fallback: no -f flag, parse package names only
		lines := strings.Split(out, "\n")
		var packages []PackageInfo
		for _, line := range lines {
			line = strings.TrimSpace(line)
			if !strings.HasPrefix(line, "package:") {
				continue
			}
			pkgName := strings.TrimPrefix(line, "package:")
			packages = append(packages, PackageInfo{
				PackageName: pkgName,
				SourceDir:   "",
			})
		}
		return packages, nil
	}

	lines := strings.Split(out, "\n")
	var packages []PackageInfo
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if !strings.HasPrefix(line, "package:") {
			continue
		}
		content := strings.TrimPrefix(line, "package:")
		idx := strings.LastIndex(content, "=")
		if idx < 0 {
			continue
		}
		sourceDir := content[:idx]
		pkgName := content[idx+1:]
		packages = append(packages, PackageInfo{
			PackageName: pkgName,
			SourceDir:   sourceDir,
		})
	}
	return packages, nil
}

func (m *AdbManager) DeviceDetail(serial string) (map[string]string, error) {
	out, err := m.run("-s", serial, "shell", "getprop")
	if err != nil {
		return nil, err
	}

	props := make(map[string]string)
	for _, line := range strings.Split(out, "\n") {
		line = strings.TrimSpace(line)
		if line == "" || !strings.HasPrefix(line, "[") {
			continue
		}
		parts := strings.SplitN(line, "]: [", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimPrefix(parts[0], "[")
		val := strings.TrimSuffix(parts[1], "]")
		props[key] = val
	}
	return props, nil
}

func (m *AdbManager) Screenshot(serial string) ([]byte, error) {
	return m.runOut("-s", serial, "exec-out", "screencap", "-p")
}

func (m *AdbManager) PullFile(serial, remotePath string) ([]byte, error) {
	return m.runOut("-s", serial, "exec-out", "cat", remotePath)
}

func (m *AdbManager) PushFile(serial string, data []byte, remotePath string) error {
	tmpFile := filepath.Join(os.TempDir(), fmt.Sprintf("adb-tool-push-%d", time.Now().UnixNano()))
	if err := os.WriteFile(tmpFile, data, 0644); err != nil {
		return err
	}
	defer os.Remove(tmpFile)
	_, err := m.run("-s", serial, "push", tmpFile, remotePath)
	return err
}

func (m *AdbManager) UninstallPackage(serial, packageName string) error {
	_, err := m.run("-s", serial, "uninstall", packageName)
	return err
}

func (m *AdbManager) Shell(serial, command string) (string, error) {
	return m.run("-s", serial, "shell", command)
}

func (m *AdbManager) StartScreenRecord(serial string) error {
	// enable touch indicator so taps are visible in video
	m.run("-s", serial, "shell", "settings", "put", "system", "show_touches", "1")
	cmd := exec.Command(m.adbPath, "-s", serial, "shell",
		"screenrecord", "--time-limit", "1800", "/sdcard/adb-tool-record.mp4")
	return cmd.Start() // runs until stopped via pkill
}

func (m *AdbManager) StopScreenRecord(serial string) error {
	_, err := m.run("-s", serial, "shell", "pkill", "-INT", "screenrecord")
	// disable touch indicator
	m.run("-s", serial, "shell", "settings", "put", "system", "show_touches", "0")
	return err
}

func (m *AdbManager) PullRecordedVideo(serial string) ([]byte, error) {
	return m.runOut("-s", serial, "exec-out", "cat", "/sdcard/adb-tool-record.mp4")
}

func (m *AdbManager) CleanRecordedVideo(serial string) {
	m.run("-s", serial, "shell", "rm", "-f", "/sdcard/adb-tool-record.mp4")
}
