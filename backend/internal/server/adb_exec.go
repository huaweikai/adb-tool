package server

import (
	"context"
	"fmt"
	"os/exec"
	"strings"
	"time"
)

func (m *AdbManager) run(args ...string) (string, error) {
	outStr, err := m.runRaw(args...)
	if err != nil {
		return "", err
	}
	return outStr, nil
}

func (m *AdbManager) runRaw(args ...string) (string, error) {
	return m.runRawContext(context.Background(), args...)
}

func (m *AdbManager) runRawContext(ctx context.Context, args ...string) (string, error) {
	start := time.Now()
	cmdStr := strings.Join(args, " ")
	cmd := exec.CommandContext(ctx, m.adbPath, args...)
	output, err := cmd.CombinedOutput()
	elapsed := time.Since(start)
	outStr := strings.TrimSpace(string(output))
	logOut := outStr
	if len(logOut) > 500 {
		logOut = logOut[:500] + fmt.Sprintf("... (%d bytes)", len(logOut))
	}
	if err != nil {
		if ctx.Err() != nil {
			Log.Add("adb "+cmdStr, logOut, ctx.Err(), elapsed)
			return outStr, ctx.Err()
		}
		errStr := fmt.Sprintf("adb %s: %v\n%s", cmdStr, err, string(output))
		Log.Add("adb "+cmdStr, logOut, err, elapsed)
		return outStr, fmt.Errorf("%s", errStr)
	}
	Log.Add("adb "+cmdStr, logOut, nil, elapsed)
	return outStr, nil
}

func (m *AdbManager) runOut(args ...string) ([]byte, error) {
	start := time.Now()
	cmdStr := strings.Join(args, " ")
	cmd := exec.Command(m.adbPath, args...)
	output, err := cmd.Output()
	elapsed := time.Since(start)
	if err != nil {
		Log.Add("adb "+cmdStr, "", err, elapsed)
	} else {
		Log.Add("adb "+cmdStr, fmt.Sprintf("<%d bytes binary>", len(output)), nil, elapsed)
	}
	return output, err
}

func shellQuote(value string) string {
	if value == "" {
		return "''"
	}
	return "'" + strings.ReplaceAll(value, "'", "'\\''") + "'"
}

func shellCommand(command string, args ...string) string {
	quoted := make([]string, 0, len(args)+1)
	quoted = append(quoted, command)
	for _, arg := range args {
		quoted = append(quoted, shellQuote(arg))
	}
	return strings.Join(quoted, " ")
}

func (m *AdbManager) runShell(serial, command string) (string, error) {
	return m.run("-s", serial, "shell", command)
}

func (m *AdbManager) Shell(serial, command string) (string, error) {
	return m.run("-s", serial, "shell", command)
}

func (m *AdbManager) Execute(serial string, args []string) (string, error) {
	fullArgs := []string{"-s", serial}
	fullArgs = append(fullArgs, args...)
	return m.runRaw(fullArgs...)
}

func (m *AdbManager) WirelessPair(address, code string) (string, error) {
	return m.runRaw("pair", address, code)
}

func (m *AdbManager) WirelessConnect(address string) (string, error) {
	return m.runRaw("connect", address)
}

func (m *AdbManager) WirelessDisconnect(serial string) (string, error) {
	return m.runRaw("disconnect", serial)
}
