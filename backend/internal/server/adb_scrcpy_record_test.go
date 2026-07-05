package server

import (
	"errors"
	"path/filepath"
	"testing"
)

// TestScrcpyRecordingBusyErrorIsAsErrScrcpyBusy exercises the errors.As
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

// TestScrcpyRecordingSandboxDirReturnsExpectedLayout verifies the
// sandbox path is rooted at the user's home directory under a
// fixed ~/.adb-tool/scrcpy_recordings subfolder. The Flutter side
// doesn't read this path directly (the backend fills it into the
// status response), but the convention matters for users who want
// to find leftover files after a crash.
func TestScrcpyRecordingSandboxDirReturnsExpectedLayout(t *testing.T) {
	dir, err := ScrcpyRecordingSandboxDir()
	if err != nil {
		t.Fatalf("ScrcpyRecordingSandboxDir failed: %v", err)
	}
	// Path must end with .adb-tool/scrcpy_recordings.
	suffix := filepath.Join(".adb-tool", "scrcpy_recordings")
	if filepath.Base(dir) != "scrcpy_recordings" {
		t.Fatalf("unexpected dir basename: got %q want scrcpy_recordings", dir)
	}
	if filepath.Base(filepath.Dir(dir)) != ".adb-tool" {
		t.Fatalf("expected parent to be .adb-tool, got %q", filepath.Dir(dir))
	}
	_ = suffix // silence unused warning if compiler folds the test
}
