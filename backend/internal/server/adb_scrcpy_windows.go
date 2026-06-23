//go:build windows

package server

import (
	"os"
	"os/exec"
	"strconv"
	"syscall"
)

// CREATE_NO_WINDOW (0x08000000) tells Windows to launch the process
// without allocating a console. Without this, scrcpy pops up a black
// cmd.exe window alongside the SDL window — really annoying, especially
// when our Flutter app is fullscreen.
//
// Set on cmd.SysProcAttr.CreationFlags so CreateProcess honors it.
func configureScrcpySysProc(cmd *exec.Cmd) {
	if cmd.SysProcAttr == nil {
		cmd.SysProcAttr = &syscall.SysProcAttr{}
	}
	cmd.SysProcAttr.CreationFlags |= 0x08000000 // CREATE_NO_WINDOW
}

// terminateScrcpyProcess asks scrcpy to shut down gracefully so it can
// finalize any in-progress recording file before exiting.
//
// Why taskkill and not os.Process.Signal / os.Process.Kill:
//   - os.Process.Signal only accepts os.Kill on Windows; any other signal
//     returns "not supported by windows".
//   - os.Process.Kill maps to TerminateProcess, which is a hard kill —
//     scrcpy exits without finalizing its MP4 muxer, so any active
//     recording is corrupted.
//
// `taskkill /pid <pid>` (no /F) sends WM_CLOSE to scrcpy's top-level
// window. scrcpy uses SDL2, which traps SDL_WINDOWEVENT_CLOSE and runs
// the same cleanup path as the user clicking the window close button —
// including flushing and closing the recording file before exiting.
//
// We don't pass /T: scrcpy does not fork local child processes (the
// on-device scrcpy-server runs over adb, not as a local fork), so a
// plain /pid is enough.
//
// The error from taskkill is best-effort: it returns non-zero when the
// process is already gone (e.g. user closed the window), which we don't
// want to surface. Callers handle the actual exit through cmd.Wait().
func terminateScrcpyProcess(p *os.Process) error {
	return exec.Command("taskkill", "/pid", strconv.Itoa(p.Pid)).Run()
}