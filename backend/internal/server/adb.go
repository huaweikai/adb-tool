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
	"strings"
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

func FindOrExtractADB(darwinZip, windowsZip []byte) (string, error) {
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

	var zipData []byte
	if runtime.GOOS == "windows" {
		zipData = windowsZip
	} else {
		zipData = darwinZip
	}

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
	cmd := exec.Command(m.adbPath, args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("adb %s: %w\n%s", strings.Join(args, " "), err, string(output))
	}
	return strings.TrimSpace(string(output)), nil
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

func (m *AdbManager) Shell(serial, command string) (string, error) {
	return m.run("-s", serial, "shell", command)
}
