//go:build darwin

package server

import "os/exec"

// configureScrcpySysProc is a no-op on macOS — scrcpy is a Cocoa app,
// no console window to suppress. The function exists so adb_scrcpy.go
// doesn't need build tags.
func configureScrcpySysProc(_ *exec.Cmd) {}