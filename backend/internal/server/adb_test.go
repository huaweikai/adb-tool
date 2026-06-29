package server

import (
	"embed"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

func TestParseDeviceLineWithMdnsSuffix(t *testing.T) {
	line := "adb-499d1b6e-KhoFQX (2)._adb-tls-connect._tcp device product:annibale model:2510DRK44C device:annibale transport_id:3"
	serial, state, ok := parseDeviceLine(line)
	if !ok {
		t.Fatal("expected device line to parse")
	}
	if serial != "adb-499d1b6e-KhoFQX (2)._adb-tls-connect._tcp" {
		t.Fatalf("unexpected serial: %q", serial)
	}
	if state != "device" {
		t.Fatalf("unexpected state: %q", state)
	}
}

func TestParseDeviceLineWithUsbSerial(t *testing.T) {
	line := "0123456789ABCDEF device product:test model:Pixel device:raven transport_id:1"
	serial, state, ok := parseDeviceLine(line)
	if !ok {
		t.Fatal("expected device line to parse")
	}
	if serial != "0123456789ABCDEF" {
		t.Fatalf("unexpected serial: %q", serial)
	}
	if state != "device" {
		t.Fatalf("unexpected state: %q", state)
	}
}

func TestParseDeviceLineDoesNotTreatDevicePropertyAsState(t *testing.T) {
	line := "0123456789ABCDEF\toffline product:test model:Pixel device:raven transport_id:1"
	serial, state, ok := parseDeviceLine(line)
	if !ok {
		t.Fatal("expected device line to parse")
	}
	if serial != "0123456789ABCDEF" {
		t.Fatalf("unexpected serial: %q", serial)
	}
	if state != "offline" {
		t.Fatalf("unexpected state: %q", state)
	}
}

func TestShellCommandQuotesSpecialPathCharacters(t *testing.T) {
	command := shellCommand(
		"mv --",
		"/storage/emulated/0/Download/HZ55A55E(1012).zip",
		"/storage/emulated/0/Download/H).zip",
	)
	expected := "mv -- '/storage/emulated/0/Download/HZ55A55E(1012).zip' '/storage/emulated/0/Download/H).zip'"
	if command != expected {
		t.Fatalf("unexpected command: %q", command)
	}
}

func TestShellQuoteEscapesSingleQuote(t *testing.T) {
	quoted := shellQuote("/sdcard/Download/a'b.txt")
	expected := "'/sdcard/Download/a'\\''b.txt'"
	if quoted != expected {
		t.Fatalf("unexpected quote: %q", quoted)
	}
}

func TestNewServerLogsAdbStartupDiagnostics(t *testing.T) {
	oldLog := Log
	Log = NewBackendLogger(20)
	defer func() { Log = oldLog }()

	adbPath := writeFakeAdb(t, `#!/bin/sh
printf '%s ' "$@" >> "$ADB_FAKE_LOG"
printf '\n' >> "$ADB_FAKE_LOG"
if [ "$1" = "version" ]; then
  printf 'Android Debug Bridge version 1.0.41\n'
  exit 0
fi
if [ "$1" = "start-server" ]; then
  printf '* daemon started successfully *\n'
  exit 0
fi
exit 0
`)
	logPath := filepath.Join(t.TempDir(), "adb.log")
	t.Setenv("ADB_FAKE_LOG", logPath)

	New(adbPath, os.DirFS(t.TempDir()), nil, embed.FS{})

	entries := Log.Snapshot()
	if !hasLogCommand(entries, "adb diagnostic path") {
		t.Fatalf("expected adb path diagnostic log, entries: %+v", entries)
	}
	if !hasLogCommand(entries, "adb version") {
		t.Fatalf("expected adb version diagnostic log, entries: %+v", entries)
	}
	if !hasLogCommand(entries, "adb start-server") {
		t.Fatalf("expected adb start-server diagnostic log, entries: %+v", entries)
	}
}

func TestDevicesSkipsPropsForDisconnectedStates(t *testing.T) {
	adbPath := writeFakeAdb(t, `#!/bin/sh
printf '%s ' "$@" >> "$ADB_FAKE_LOG"
printf '\n' >> "$ADB_FAKE_LOG"
if [ "$1" = "devices" ]; then
  printf 'List of devices attached\n'
  printf 'offline-serial\toffline product:test model:Offline device:test\n'
  printf 'unauth-serial\tunauthorized product:test model:Unauthorized device:test\n'
  printf 'ready-serial\tdevice product:test model:Ready device:test\n'
  exit 0
fi
if [ "$3" = "shell" ] && echo "$4" | grep -q "getprop"; then
  printf 'Ready\n'
  printf 'TestBrand\n'
  printf '35\n'
  printf 'ROSN-12345\n'
  exit 0
fi
exit 1
`)
	logPath := filepath.Join(t.TempDir(), "adb.log")
	t.Setenv("ADB_FAKE_LOG", logPath)

	devices, err := NewAdbManager(adbPath, embed.FS{}).Devices()
	if err != nil {
		t.Fatalf("Devices returned error: %v", err)
	}
	if len(devices) != 3 {
		t.Fatalf("expected 3 devices, got %d", len(devices))
	}
	if devices[0].Model != "" || devices[1].Model != "" {
		t.Fatalf("disconnected devices should not load props: %+v", devices[:2])
	}
	if devices[2].Model != "Ready" {
		t.Fatalf("connected device should load props: %+v", devices[2])
	}
	if devices[2].HardwareSerial != "ROSN-12345" {
		t.Fatalf("connected device should populate hardwareSerial: %+v", devices[2])
	}

	logBytes, err := os.ReadFile(logPath)
	if err != nil {
		t.Fatalf("read fake adb log: %v", err)
	}
	log := string(logBytes)
	if strings.Contains(log, "-s offline-serial shell getprop") {
		t.Fatalf("offline device should not run getprop, log:\n%s", log)
	}
	if strings.Contains(log, "-s unauth-serial shell getprop") {
		t.Fatalf("unauthorized device should not run getprop, log:\n%s", log)
	}
	if !strings.Contains(log, "-s ready-serial shell") || !strings.Contains(log, "getprop ro.product.model") {
		t.Fatalf("connected device should run getprop, log:\n%s", log)
	}
}

func hasLogCommand(entries []LogEntry, command string) bool {
	for _, entry := range entries {
		if entry.Command == command {
			return true
		}
	}
	return false
}

func writeFakeAdb(t *testing.T, script string) string {
	t.Helper()
	dir := t.TempDir()
	if runtime.GOOS == "windows" {
		path := filepath.Join(dir, "adb.bat")
		batch := strings.Join([]string{
			"@echo off",
			"echo %* >> \"%ADB_FAKE_LOG%\"",
			"if \"%1\"==\"version\" echo Android Debug Bridge version 1.0.41& exit /b 0",
			"if \"%1\"==\"start-server\" echo * daemon started successfully *& exit /b 0",
			"if \"%1\"==\"devices\" echo List of devices attached& echo offline-serial	offline product:test model:Offline device:test& echo unauth-serial	unauthorized product:test model:Unauthorized device:test& echo ready-serial	device product:test model:Ready device:test& exit /b 0",
			"if \"%3\"==\"shell\" echo %4 | findstr getprop >nul && echo Ready& echo TestBrand& echo 35& echo ROSN-12345& exit /b 0",
			"exit /b 1",
		}, "\r\n")
		if err := os.WriteFile(path, []byte(batch), 0o755); err != nil {
			t.Fatalf("write fake adb: %v", err)
		}
		return path
	}
	path := filepath.Join(dir, "adb")
	if err := os.WriteFile(path, []byte(script), 0o755); err != nil {
		t.Fatalf("write fake adb: %v", err)
	}
	return path
}
