package server

import (
	"context"
	"fmt"
	"net"
	"os/exec"
	"regexp"
	"strings"
	"time"
)

// dangerousCmdPatterns matches dangerous shell commands.
// A match returns a human-readable warning.
var dangerousCmdPatterns = []struct {
	pattern *regexp.Regexp
	msg     string
}{
	// Destructive file operations
	{regexp.MustCompile(`(?i)^\s*(rm|rmdir|del)\s+(-[rfv]+\s+)*[/*]`), "删除系统根目录或通配符递归删除：可能永久丢失数据"},
	{regexp.MustCompile(`(?i)^\s*dd\s+.*of=/`), "直接写入设备文件：可能导致磁盘数据丢失"},
	// Device-level destructive commands
	{regexp.MustCompile(`(?i)\breboot\s+(bootloader|recovery|sideload\b)`), "重启到 Bootloader / Recovery / Sideload：可能中断正在运行的测试"},
	{regexp.MustCompile(`(?i)\bfastboot\b`), "Fastboot 模式：设备将脱离 ADB 连接"},
	// Package removal
	{regexp.MustCompile(`(?i)\bpm\s+(uninstall|clear)\b.* --user 0`), "卸载或清除系统用户 0 的应用：可能破坏系统组件"},
	{regexp.MustCompile(`(?i)\bpm\s+hide\b`), "禁用系统组件：可能导致系统异常"},
	{regexp.MustCompile(`(?i)\bpm\s+disable-user\b.* --user 0`), "禁用系统应用：可能影响设备正常运行"},
	// ADB daemon control
	{regexp.MustCompile(`(?i)\badb\s+kill-server\b`), "停止 ADB 服务：会导致当前所有 ADB 连接中断"},
	{regexp.MustCompile(`(?i)\badb\s+start-server\b`), "重启 ADB 服务：可能导致设备重新授权"},
}

// isDangerousCommand checks whether the shell command (the first non-flag arg after
// "shell") matches a known destructive pattern. It returns (warningMsg, isDangerous).
// Pass confirm=true to bypass the warning.
func isDangerousCommand(args []string) (string, bool) {
	if len(args) == 0 {
		return "", false
	}
	// Build the full command string for pattern matching
	fullCmd := strings.Join(args, " ")
	for _, entry := range dangerousCmdPatterns {
		if entry.pattern.MatchString(fullCmd) {
			return entry.msg, true
		}
	}
	return "", false
}

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

const defaultAdbCommandTimeout = 120 * time.Second

func withDefaultTimeout(ctx context.Context) (context.Context, context.CancelFunc) {
	if _, ok := ctx.Deadline(); ok {
		return ctx, func() {}
	}
	return context.WithTimeout(ctx, defaultAdbCommandTimeout)
}

func (m *AdbManager) runRawContext(ctx context.Context, args ...string) (string, error) {
	return m.runRawContextInner(ctx, true, args...)
}

func (m *AdbManager) runRawContextQuiet(ctx context.Context, args ...string) (string, error) {
	return m.runRawContextInner(ctx, false, args...)
}

func (m *AdbManager) runRawContextInner(ctx context.Context, logErrors bool, args ...string) (string, error) {
	ctx, cancel := withDefaultTimeout(ctx)
	defer cancel()

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
			if logErrors {
				Log.Add("adb "+cmdStr, logOut, ctx.Err(), elapsed)
			}
			return outStr, ctx.Err()
		}
		errStr := fmt.Sprintf("adb %s: %v\n%s", cmdStr, err, string(output))
		if logErrors {
			Log.Add("adb "+cmdStr, logOut, err, elapsed)
		}
		return outStr, fmt.Errorf("%s", errStr)
	}
	if logErrors {
		Log.Add("adb "+cmdStr, logOut, nil, elapsed)
	}
	return outStr, nil
}

func (m *AdbManager) runOut(args ...string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(context.Background(), defaultAdbCommandTimeout)
	defer cancel()

	start := time.Now()
	cmdStr := strings.Join(args, " ")
	cmd := exec.CommandContext(ctx, m.adbPath, args...)
	output, err := cmd.CombinedOutput()
	elapsed := time.Since(start)
	if err != nil {
		outStr := strings.TrimSpace(string(output))
		if len(outStr) > 500 {
			outStr = outStr[:500] + fmt.Sprintf("... (%d bytes)", len(outStr))
		}
		Log.Add("adb "+cmdStr, outStr, err, elapsed)
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

func (m *AdbManager) WirelessPairContext(ctx context.Context, address, code string) (string, error) {
	return m.runRawContext(ctx, "pair", address, code)
}

func (m *AdbManager) WirelessConnect(address string) (string, error) {
	return m.runRaw("connect", address)
}

func (m *AdbManager) WirelessConnectContext(ctx context.Context, address string) (string, error) {
	return m.runRawContext(ctx, "connect", address)
}

func (m *AdbManager) WirelessDisconnect(serial string) (string, error) {
	return m.runRaw("disconnect", serial)
}

func (m *AdbManager) WirelessDisconnectContext(ctx context.Context, serial string) (string, error) {
	return m.runRawContext(ctx, "disconnect", serial)
}

func (m *AdbManager) ScanWirelessAdb(ctx context.Context) ([]WirelessAdbDevice, string, error) {
	output, err := m.runRawContext(ctx, "mdns", "services")
	devices := parseWirelessAdbMdns(output)
	if err != nil {
		return devices, output, err
	}
	return devices, output, nil
}

var mdnsHostPortRe = regexp.MustCompile(`([0-9A-Fa-f:.]+):(\d+)`)

func parseWirelessAdbMdns(output string) []WirelessAdbDevice {
	items := map[string]*WirelessAdbDevice{}
	for _, line := range strings.Split(output, "\n") {
		line = strings.TrimSpace(line)
		if line == "" || !strings.Contains(line, "_adb-tls-") {
			continue
		}
		match := mdnsHostPortRe.FindStringSubmatch(line)
		if len(match) < 3 {
			continue
		}
		host := strings.Trim(match[1], "[]")
		port := match[2]
		if net.ParseIP(host) == nil {
			continue
		}
		device := items[host]
		if device == nil {
			device = &WirelessAdbDevice{
				Name:   mdnsDeviceName(line),
				Host:   host,
				Source: "mdns",
			}
			items[host] = device
		}
		if strings.Contains(line, "_adb-tls-pairing") {
			device.PairPort = port
			device.PairAddress = net.JoinHostPort(host, port)
		}
		if strings.Contains(line, "_adb-tls-connect") {
			device.ConnectPort = port
			device.Address = net.JoinHostPort(host, port)
		}
	}
	devices := make([]WirelessAdbDevice, 0, len(items))
	for _, device := range items {
		devices = append(devices, *device)
	}
	return devices
}

func mdnsDeviceName(line string) string {
	fields := strings.Fields(line)
	if len(fields) == 0 {
		return ""
	}
	name := strings.TrimSuffix(fields[0], ".")
	name = strings.TrimSuffix(name, "._adb-tls-connect._tcp")
	name = strings.TrimSuffix(name, "._adb-tls-pairing._tcp")
	return name
}
