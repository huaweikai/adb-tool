package server

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/base64"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync"
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
	adbPath      string
	recordMu     sync.Mutex
	recordCmd    *exec.Cmd
	recordSerial string
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
	outStr, err := m.runRaw(args...)
	if err != nil {
		return "", err
	}
	return outStr, nil
}

func (m *AdbManager) runRaw(args ...string) (string, error) {
	return m.runRawContext(context.Background(), args...)
}

func (m *AdbManager) runRawContext(ctx context.Context, args ...string) (string, error) {
	start := time.Now()
	cmdStr := strings.Join(args, " ")
	cmd := exec.CommandContext(ctx, m.adbPath, args...)
	output, err := cmd.CombinedOutput()
	elapsed := time.Since(start)
	outStr := strings.TrimSpace(string(output))
	logOut := outStr
	if len(logOut) > 500 {
		logOut = logOut[:500] + fmt.Sprintf("... (%d bytes)", len(logOut))
	}
	if err != nil {
		if ctx.Err() != nil {
			Log.Add("adb "+cmdStr, logOut, ctx.Err(), elapsed)
			return outStr, ctx.Err()
		}
		errStr := fmt.Sprintf("adb %s: %v\n%s", cmdStr, err, string(output))
		Log.Add("adb "+cmdStr, logOut, err, elapsed)
		return outStr, fmt.Errorf("%s", errStr)
	}
	Log.Add("adb "+cmdStr, logOut, nil, elapsed)
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

func (m *AdbManager) PullFileToPath(serial, remotePath, localPath string) error {
	return m.PullFileToPathContext(context.Background(), serial, remotePath, localPath)
}

func (m *AdbManager) PullFileToPathContext(ctx context.Context, serial, remotePath, localPath string) error {
	_, err := m.runRawContext(ctx, "-s", serial, "pull", remotePath, localPath)
	return err
}

func (m *AdbManager) PushFile(serial string, data []byte, remotePath string) error {
	tmpFile := filepath.Join(os.TempDir(), fmt.Sprintf("adb-tool-push-%d", time.Now().UnixNano()))
	if err := os.WriteFile(tmpFile, data, 0644); err != nil {
		return err
	}
	defer os.Remove(tmpFile)
	return m.PushFileFromPath(serial, tmpFile, remotePath)
}

func (m *AdbManager) PushFileFromPath(serial, localPath, remotePath string) error {
	return m.PushFileFromPathContext(context.Background(), serial, localPath, remotePath)
}

func (m *AdbManager) PushFileFromPathContext(ctx context.Context, serial, localPath, remotePath string) error {
	_, err := m.runRawContext(ctx, "-s", serial, "push", localPath, remotePath)
	return err
}

func (m *AdbManager) UninstallPackage(serial, packageName string) error {
	_, err := m.run("-s", serial, "uninstall", packageName)
	return err
}

var installPkgRe = regexp.MustCompile(`Package\s+(\S+)`)

func (m *AdbManager) InstallPackage(serial, apkPath string) (string, error) {
	return m.InstallPackageContext(context.Background(), serial, apkPath)
}

func (m *AdbManager) InstallPackageContext(ctx context.Context, serial, apkPath string) (string, error) {
	output, err := m.runRawContext(ctx, "-s", serial, "install", "-r", "-d", apkPath)
	if err == nil {
		return output, nil
	}

	if ctx.Err() != nil || !strings.Contains(output, "INSTALL_FAILED_UPDATE_INCOMPATIBLE") {
		return output, err
	}

	pkg := extractPackageFromInstallError(output)
	if pkg == "" {
		return output, fmt.Errorf("签名不一致，但无法解析包名\n%s", output)
	}

	uninstallOut, uninstallErr := m.runRawContext(ctx, "-s", serial, "uninstall", pkg)
	if uninstallErr != nil {
		return output, fmt.Errorf("签名不一致，卸载旧版本(%s)也失败: %s\n原错误: %s", pkg, uninstallOut, output)
	}

	output, err = m.runRawContext(ctx, "-s", serial, "install", apkPath)
	if err != nil {
		return output, fmt.Errorf("已卸载旧版本(%s)，但安装新版本仍然失败: %s", pkg, output)
	}

	return "已卸载旧版本(" + pkg + ")并重新安装成功\n" + output, nil
}

func extractPackageFromInstallError(output string) string {
	m := installPkgRe.FindStringSubmatch(output)
	if len(m) > 1 {
		return m[1]
	}
	return ""
}

func (m *AdbManager) Shell(serial, command string) (string, error) {
	return m.run("-s", serial, "shell", command)
}

func (m *AdbManager) Execute(serial string, args []string) (string, error) {
	fullArgs := []string{"-s", serial}
	fullArgs = append(fullArgs, args...)
	return m.runRaw(fullArgs...)
}

func (m *AdbManager) WirelessPair(address, code string) (string, error) {
	return m.runRaw("pair", address, code)
}

func (m *AdbManager) WirelessConnect(address string) (string, error) {
	return m.runRaw("connect", address)
}

func (m *AdbManager) IsClipboardHelperInstalled(serial string) bool {
	out, err := m.run("-s", serial, "shell", "pm", "list", "packages", "com.adbtool.clipboard")
	if err != nil {
		return false
	}
	return strings.Contains(out, "com.adbtool.clipboard")
}

func (m *AdbManager) InstallClipboardHelper(serial string, apkBytes []byte) error {
	tmpFile := filepath.Join(os.TempDir(), "clipboard-helper.apk")
	if err := os.WriteFile(tmpFile, apkBytes, 0644); err != nil {
		return fmt.Errorf("write temp apk: %w", err)
	}
	defer os.Remove(tmpFile)
	_, err := m.run("-s", serial, "install", "-r", "-d", tmpFile)
	return err
}

func (m *AdbManager) SendClipboard(serial, text string) error {
	encoded := base64.StdEncoding.EncodeToString([]byte(text))
	_, err := m.run("-s", serial, "shell", "am", "start", "-n", "com.adbtool.clipboard/.SetClipboardActivity", "--es", "text", encoded)
	return err
}

func (m *AdbManager) UninstallClipboardHelper(serial string) error {
	_, err := m.run("-s", serial, "uninstall", "com.adbtool.clipboard")
	return err
}

func (m *AdbManager) StartScreenRecord(serial string) error {
	m.recordMu.Lock()
	defer m.recordMu.Unlock()

	if m.recordCmd != nil {
		return fmt.Errorf("screenrecord already active for %s", m.recordSerial)
	}

	stopMarker := "/sdcard/adb-tool-stop"
	m.run("-s", serial, "shell", "rm", "-f", "/sdcard/adb-tool-record.mp4", stopMarker)

	m.run("-s", serial, "shell", "settings", "put", "system", "show_touches", "1")

	script := fmt.Sprintf(
		`screenrecord --time-limit 1800 /sdcard/adb-tool-record.mp4 & SRPID=$!; while ! [ -f %s ]; do sleep 0.3; done; kill -2 $SRPID; wait $SRPID; sync; rm -f %s`,
		stopMarker, stopMarker,
	)
	cmd := exec.Command(m.adbPath, "-s", serial, "shell", script)
	if err := cmd.Start(); err != nil {
		return err
	}
	m.recordCmd = cmd
	m.recordSerial = serial
	return nil
}

func (m *AdbManager) StopScreenRecord(serial string) error {
	defer m.run("-s", serial, "shell", "settings", "put", "system", "show_touches", "0")

	stopMarker := "/sdcard/adb-tool-stop"
	m.run("-s", serial, "shell", "touch", stopMarker)

	cmd := m.getRecordCmd(serial)
	if cmd != nil {
		waitCommandExit(cmd, 60*time.Second)
		m.clearRecordCmd(serial, cmd)
	}

	if err := m.waitRemoteFileStable(serial, "/sdcard/adb-tool-record.mp4", 8, 500*time.Millisecond, 30*time.Second); err != nil {
		return err
	}

	return nil
}

func (m *AdbManager) PullRecordedVideo(serial string) ([]byte, error) {
	tmpFile := filepath.Join(os.TempDir(), fmt.Sprintf("adb-recording-%d.mp4", time.Now().UnixNano()))
	defer os.Remove(tmpFile)
	_, err := m.run("-s", serial, "pull", "/sdcard/adb-tool-record.mp4", tmpFile)
	if err != nil {
		return nil, err
	}
	return os.ReadFile(tmpFile)
}

func (m *AdbManager) CleanRecordedVideo(serial string) {
	m.run("-s", serial, "shell", "rm", "-f", "/sdcard/adb-tool-record.mp4")
}

func (m *AdbManager) getRecordCmd(serial string) *exec.Cmd {
	m.recordMu.Lock()
	defer m.recordMu.Unlock()
	if m.recordSerial != serial {
		return nil
	}
	return m.recordCmd
}

func (m *AdbManager) clearRecordCmd(serial string, cmd *exec.Cmd) {
	m.recordMu.Lock()
	defer m.recordMu.Unlock()
	if m.recordSerial == serial && m.recordCmd == cmd {
		m.recordCmd = nil
		m.recordSerial = ""
	}
}

func waitCommandExit(cmd *exec.Cmd, timeout time.Duration) (bool, error) {
	done := make(chan error, 1)
	go func() {
		done <- cmd.Wait()
	}()

	select {
	case err := <-done:
		return true, err
	case <-time.After(timeout):
		return false, fmt.Errorf("command did not exit after %s", timeout)
	}
}

func (m *AdbManager) remoteFileSize(serial, path string) (int64, error) {
	out, err := m.run(
		"-s", serial, "shell", "sh", "-c",
		"stat -c %s "+path+" 2>/dev/null || ls -l "+path+" 2>/dev/null | awk '{print $5}'",
	)
	if err != nil {
		return 0, err
	}
	out = strings.TrimSpace(out)
	if out == "" {
		return 0, fmt.Errorf("empty file size output")
	}
	n, err := strconv.ParseInt(out, 10, 64)
	if err != nil {
		return 0, err
	}
	return n, nil
}

func (m *AdbManager) waitRemoteFileStable(serial, path string, stableCount int, interval, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	var last int64 = -1
	stable := 0
	for time.Now().Before(deadline) {
		size, err := m.remoteFileSize(serial, path)
		if err != nil {
			stable = 0
			time.Sleep(interval)
			continue
		}
		if size > 0 && size == last {
			stable++
			if stable >= stableCount {
				return nil
			}
		} else {
			stable = 0
		}
		last = size
		time.Sleep(interval)
	}
	return fmt.Errorf("recorded video not stable after %s", timeout)
}
