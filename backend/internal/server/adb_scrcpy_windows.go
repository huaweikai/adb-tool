//go:build windows

package server

import (
	"os/exec"
	"syscall"
)

// CREATE_NO_WINDOW (0x08000000) tells Windows to launch the process
// without allocating a console. Without this, scrcpy pops up a black
// cmd.exe window alongside the SDL window — really annoying, especially
// when the user has our Flutter app fullscreen.
//
// Set on cmd.SysProcAttr.CreationFlags so CreateProcess honors it.
func configureScrcpySysProc(cmd *exec.Cmd) {
	if cmd.SysProcAttr == nil {
		cmd.SysProcAttr = &syscall.SysProcAttr{}
	}
	cmd.SysProcAttr.CreationFlags |= 0x08000000 // CREATE_NO_WINDOW
}