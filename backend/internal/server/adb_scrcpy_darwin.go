//go:build darwin

package server

import (
	"os"
	"os/exec"
	"syscall"
)

// configureScrcpySysProc is a no-op on macOS — scrcpy is a Cocoa app,
// no console window to suppress. The function exists so adb_scrcpy.go
// doesn't need build tags.
func configureScrcpySysProc(_ *exec.Cmd) {}

// terminateScrcpyProcess asks scrcpy to shut down gracefully so it can
// finalize any in-progress recording file before exiting. On macOS this
// is just SIGTERM — scrcpy's signal handler traps it and runs the same
// cleanup path as a window close.
//
// On Windows os.Process.Signal only accepts os.Kill (which is a hard
// TerminateProcess and would corrupt recordings), so the Windows build
// uses `taskkill /pid` (no /F) to send WM_CLOSE instead — see
// adb_scrcpy_windows.go.
func terminateScrcpyProcess(p *os.Process) error {
	return p.Signal(syscall.SIGTERM)
}