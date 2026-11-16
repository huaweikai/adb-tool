package server

import (
	"context"
	"fmt"
	"io"
	"os/exec"
	"regexp"
	"sort"
	"strings"
)

// A timestamp cursor lets the client resume from the device ring after a
// transport reconnect. A fresh stream starts at the most recent 1,000 records.
var logcatCursor = regexp.MustCompile(`^(\d{4}-)?\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3,6}$`)

func (m *AdbManager) StartLogcat(ctx context.Context, serial string, filter LogFilter, since string) (*exec.Cmd, io.ReadCloser, error) {
	tail := "1000"
	if since != "" {
		if !logcatCursor.MatchString(since) {
			return nil, nil, fmt.Errorf("invalid logcat cursor")
		}
		tail = since
	}
	args := []string{"-s", serial, "logcat", "-v", "threadtime", "-v", "usec", "-v", "year", "-T", tail}

	if filter.Priority != "" {
		args = append(args, "*:"+filter.Priority)
	}

	if filter.PackagePid != "" {
		args = append(args, "--pid="+filter.PackagePid)
	}

	cmd := exec.CommandContext(ctx, m.adbPath, args...)

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
