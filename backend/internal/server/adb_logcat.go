package server

import (
	"fmt"
	"io"
	"os/exec"
	"sort"
	"strings"
)

func (m *AdbManager) StartLogcat(serial string, filter LogFilter) (*exec.Cmd, io.ReadCloser, error) {
	if err := m.ClearLogcat(serial); err != nil {
		Log.Add("adb logcat -c", "", err, 0)
	}

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

func (m *AdbManager) GetRecentLogcat(serial string, lines int) (string, error) {
	if lines <= 0 {
		lines = 1000
	}
	return m.run("-s", serial, "logcat", "-d", "-v", "threadtime", "-t", fmt.Sprintf("%d", lines))
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
