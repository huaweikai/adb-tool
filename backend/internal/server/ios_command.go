package server

import (
	"context"
	"io"
	"os"
	"os/exec"
	"time"
)

func runIOSCLI(ctx context.Context, cli string, output io.Writer, args ...string) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	// PyInstaller can leave its extracted files behind after a forced stop.
	temp, err := os.MkdirTemp("", "adb-tool-ios-")
	if err != nil {
		return err
	}
	defer func() {
		if err := os.RemoveAll(temp); err != nil {
			Log.Add("iOS CLI temp directory cleanup", err.Error(), err, 0)
		}
	}()

	cmd := exec.CommandContext(ctx, cli, args...)
	configureIOSProcess(cmd)
	cmd.Stdout = output
	cmd.Env = append(cmd.Environ(), "PYTHONIOENCODING=utf-8", "NO_COLOR=1",
		"TEMP="+temp, "TMP="+temp, "TMPDIR="+temp)
	cmd.WaitDelay = 5 * time.Second
	err = cmd.Run()
	if err != nil && ctx.Err() != nil {
		return ctx.Err()
	}
	return err
}
