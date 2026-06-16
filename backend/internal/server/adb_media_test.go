package server

import (
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"
)

func TestScreenRecordStartsWithPlainAdbScreenrecord(t *testing.T) {
	adbPath := writePlainScreenRecordFakeAdb(t)
	logPath := filepath.Join(t.TempDir(), "adb.log")
	t.Setenv("ADB_FAKE_LOG", logPath)

	manager := NewAdbManager(adbPath)
	if err := manager.StartScreenRecord("serial-1"); err != nil {
		t.Fatalf("StartScreenRecord returned error: %v", err)
	}
	waitForLogContains(t, logPath, "-s serial-1 shell screenrecord /sdcard/adb-tool-record.mp4")
	if err := manager.StopScreenRecord("serial-1"); err != nil {
		t.Fatalf("StopScreenRecord returned error: %v", err)
	}

	logBytes, err := os.ReadFile(logPath)
	if err != nil {
		t.Fatalf("read fake adb log: %v", err)
	}
	log := string(logBytes)
	if !strings.Contains(log, "-s serial-1 shell screenrecord /sdcard/adb-tool-record.mp4") {
		t.Fatalf("expected plain screenrecord command, log:\n%s", log)
	}
	for _, unexpected := range []string{"adb-tool-stop", "adb-tool-record.pid", "SRPID", "while !", "pkill", "killall"} {
		if strings.Contains(log, unexpected) {
			t.Fatalf("unexpected %q in screenrecord flow, log:\n%s", unexpected, log)
		}
	}
}

func waitForLogContains(t *testing.T, path string, want string) {
	t.Helper()
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		data, _ := os.ReadFile(path)
		if strings.Contains(string(data), want) {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	data, _ := os.ReadFile(path)
	t.Fatalf("log did not contain %q, log:\n%s", want, data)
}

func writePlainScreenRecordFakeAdb(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	if runtime.GOOS == "windows" {
		path := filepath.Join(dir, "adb.bat")
		batch := strings.Join([]string{
			"@echo off",
			"echo %* >> \"%ADB_FAKE_LOG%\"",
			"if \"%3\"==\"shell\" if \"%4\"==\"rm\" exit /b 0",
			"if \"%3\"==\"shell\" if \"%4\"==\"settings\" exit /b 0",
			"if \"%3\"==\"shell\" if \"%4\"==\"screenrecord\" exit /b 0",
			"if \"%3\"==\"shell\" if \"%4\"==\"sh\" echo 1024& exit /b 0",
			"exit /b 1",
		}, "\r\n")
		if err := os.WriteFile(path, []byte(batch), 0o755); err != nil {
			t.Fatalf("write fake adb: %v", err)
		}
		return path
	}
	path := filepath.Join(dir, "adb")
	script := `#!/bin/sh
printf '%s ' "$@" >> "$ADB_FAKE_LOG"
printf '\n' >> "$ADB_FAKE_LOG"
if [ "$3" = "shell" ] && [ "$4" = "rm" ]; then
  exit 0
fi
if [ "$3" = "shell" ] && [ "$4" = "settings" ]; then
  exit 0
fi
if [ "$3" = "shell" ] && [ "$4" = "screenrecord" ]; then
  exit 0
fi
if echo "$*" | grep -q "stat -c %s"; then
  printf '1024\n'
  exit 0
fi
exit 1
`
	if err := os.WriteFile(path, []byte(script), 0o755); err != nil {
		t.Fatalf("write fake adb: %v", err)
	}
	return path
}
