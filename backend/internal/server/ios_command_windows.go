package server

import (
	"context"
	"os"
	"os/exec"
	"strconv"
	"time"
)

func configureIOSProcess(cmd *exec.Cmd) {
	configureScrcpySysProc(cmd)
	cmd.Cancel = func() error {
		// Stop both the PyInstaller bootloader and its Python child.
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		stop := exec.CommandContext(ctx, "taskkill.exe", "/PID", strconv.Itoa(cmd.Process.Pid), "/T", "/F")
		configureScrcpySysProc(stop)
		if err := stop.Run(); err != nil {
			return cmd.Process.Kill()
		}
		return os.ErrProcessDone
	}
}
