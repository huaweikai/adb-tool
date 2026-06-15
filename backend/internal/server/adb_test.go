package server

import (
	"os"
	"path/filepath"
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
if [ "$3" = "shell" ] && [ "$4" = "getprop" ]; then
  printf '[ro.product.model]: [Ready]\n'
  printf '[ro.product.brand]: [TestBrand]\n'
  printf '[ro.build.version.sdk]: [35]\n'
  exit 0
fi
exit 1
`)
	logPath := filepath.Join(t.TempDir(), "adb.log")
	t.Setenv("ADB_FAKE_LOG", logPath)

	devices, err := NewAdbManager(adbPath).Devices()
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
	if !strings.Contains(log, "-s ready-serial shell getprop") {
		t.Fatalf("connected device should run getprop, log:\n%s", log)
	}
}

func writeFakeAdb(t *testing.T, script string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "adb")
	if err := os.WriteFile(path, []byte(script), 0o755); err != nil {
		t.Fatalf("write fake adb: %v", err)
	}
	return path
}
