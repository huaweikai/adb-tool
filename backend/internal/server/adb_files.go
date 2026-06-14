package server

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

func (m *AdbManager) ListFiles(serial, path string) ([]FileEntry, error) {
	if path == "" {
		path = "/sdcard"
	} else if path != "/" {
		path = strings.TrimRight(path, "/")
	}
	out, err := m.runShell(serial, shellCommand("ls -la", path))
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
		if idx := strings.Index(name, " -> "); idx > 0 {
			name = name[:idx]
		}

		fullPath := joinDevicePath(basePath, name)

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

func joinDevicePath(basePath, name string) string {
	basePath = strings.TrimRight(basePath, "/")
	if basePath == "" {
		return "/" + name
	}
	return basePath + "/" + name
}

func deviceBaseName(path string) string {
	path = strings.TrimRight(path, "/")
	if path == "" {
		return "/"
	}
	if idx := strings.LastIndex(path, "/"); idx >= 0 {
		return path[idx+1:]
	}
	return path
}

func (m *AdbManager) ReadFile(serial, path string) (string, error) {
	return m.runShell(serial, shellCommand("cat", path))
}

func (m *AdbManager) DeleteFile(serial, path string, recursive bool) error {
	command := "rm -f --"
	if recursive {
		command = "rm -rf --"
	}
	_, err := m.runShell(serial, shellCommand(command, path))
	return err
}

func (m *AdbManager) RenameFile(serial, from, to string) error {
	_, err := m.runShell(serial, shellCommand("mv --", from, to))
	return err
}

func (m *AdbManager) MakeDir(serial, path string) error {
	_, err := m.runShell(serial, shellCommand("mkdir -p", path))
	return err
}

func (m *AdbManager) TouchFile(serial, path string) error {
	_, err := m.runShell(serial, shellCommand("touch", path))
	return err
}

func (m *AdbManager) FileStat(serial, path string) (FileStat, error) {
	out, err := m.runShell(serial, shellCommand("ls -ld", path))
	if err != nil {
		return FileStat{}, err
	}
	entry, ok := parseLsSingle(strings.TrimSpace(out), path)
	if !ok {
		return FileStat{Path: path, Name: deviceBaseName(path), Raw: strings.TrimSpace(out)}, nil
	}
	return FileStat{
		Name:        entry.Name,
		Path:        path,
		Size:        entry.Size,
		IsDir:       entry.IsDir,
		Permissions: entry.Permissions,
		Modified:    entry.Modified,
		Raw:         strings.TrimSpace(out),
	}, nil
}

func parseLsSingle(line, path string) (FileEntry, bool) {
	fields := strings.Fields(line)
	if len(fields) < 8 {
		return FileEntry{}, false
	}
	perms := fields[0]
	if len(perms) < 10 {
		return FileEntry{}, false
	}
	var size int64
	if s, err := strconv.ParseInt(fields[4], 10, 64); err == nil {
		size = s
	}
	name := deviceBaseName(path)
	return FileEntry{
		Name:        name,
		Path:        path,
		Size:        size,
		IsDir:       perms[0] == 'd' || perms[0] == 'l',
		Permissions: perms,
		Modified:    fields[5] + " " + fields[6],
	}, true
}

func (m *AdbManager) PullFile(serial, remotePath string) ([]byte, error) {
	return m.runOut("-s", serial, "exec-out", shellCommand("cat", remotePath))
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
