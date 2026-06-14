package server

import "testing"

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
