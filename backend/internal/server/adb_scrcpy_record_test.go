package server

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
)

// TestIsScrcpyRecordOutputPathAcceptsGoodAndRejectsBad checks the path
// validator used by the handler. We don't need the real scrcpy binary
// for this — the validator is pure filesystem I/O.
func TestIsScrcpyRecordOutputPathAcceptsGoodAndRejectsBad(t *testing.T) {
	dir := t.TempDir()
	good := filepath.Join(dir, "recording.mp4")
	// Also try with a subdirectory that doesn't exist — that should fail.
	missing := filepath.Join(dir, "nope", "recording.mp4")

	m := &AdbManager{}

	if err := m.isScrcpyRecordOutputPath(good); err != nil {
		t.Fatalf("expected good path to be accepted, got %v", err)
	}
	if err := m.isScrcpyRecordOutputPath(missing); err == nil {
		t.Fatal("expected missing directory to be rejected, got nil")
	}
	if err := m.isScrcpyRecordOutputPath(""); err == nil {
		t.Fatal("expected empty path to be rejected, got nil")
	}
	if err := m.isScrcpyRecordOutputPath("relative/path.mp4"); err == nil {
		t.Fatal("expected relative path to be rejected, got nil")
	}
	// Make a file (not a dir) and try to use it as a directory
	// basename — that should also fail.
	notADir := filepath.Join(dir, "notadir")
	if err := os.WriteFile(notADir, []byte("x"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := m.isScrcpyRecordOutputPath(filepath.Join(notADir, "x.mp4")); err == nil {
		t.Fatal("expected file-as-dir to be rejected, got nil")
	}
}

// TestScrcpyRecordBusyErrorIsAsErrScrcpyBusy exercises the errors.As
// path the handler uses to decide between 409 and 500. The wrap
// contract: *scrcpyRecordBusyError must satisfy errors.As(ErrScrcpyBusy).
func TestScrcpyRecordBusyErrorIsAsErrScrcpyBusy(t *testing.T) {
	inner := &scrcpyRecordBusyError{Kind: scrcpyRecordBusyMirror, Serial: "abc"}
	if !errors.Is(inner, ErrScrcpyBusy) {
		t.Fatal("expected scrcpyRecordBusyError to be Is ErrScrcpyBusy")
	}
	var target *scrcpyRecordBusyError
	if !errors.As(inner, &target) {
		t.Fatal("expected errors.As to unwrap to *scrcpyRecordBusyError")
	}
	if target.Kind != scrcpyRecordBusyMirror {
		t.Fatalf("expected kind=mirror, got %q", target.Kind)
	}
}

// TestIsScrcpyRecordOutputPathAcceptsAbsolute checks that a freshly
// created absolute path is accepted — covers the success branch and
// the writability probe. We use a real file under t.TempDir() to
// avoid platform-specific path quirks.
func TestIsScrcpyRecordOutputPathAcceptsAbsolute(t *testing.T) {
	dir := t.TempDir()
	target := filepath.Join(dir, "adb-tool-record_test.mp4")

	m := &AdbManager{}
	if err := m.isScrcpyRecordOutputPath(target); err != nil {
		t.Fatalf("expected absolute path to be accepted, got %v", err)
	}
	// Output should be a real, non-empty string.
	if target == "" {
		t.Fatal("test path construction failed")
	}
}
