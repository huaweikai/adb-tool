//go:build windows

package emulator

import (
	"os"
	"path/filepath"
	"strings"
)

// executableName appends .exe when name doesn't already have a Windows
// executable suffix (.exe or .bat). Centralizes what used to be a
// per-callsite `if runtime.GOOS == "windows" { path += ".exe" }`.
func executableName(name string) string {
	if strings.HasSuffix(name, ".exe") || strings.HasSuffix(name, ".bat") {
		return name
	}
	return name + ".exe"
}

// findBinary resolves a Windows binary by trying common wrapper suffixes.
//
// Resolution order: <path>.exe → <path>.bat → <path>. Modern Android
// cmdline-tools (>= 8.0) only ship .bat wrappers + .jar files under
// cmdline-tools/latest/bin/ (no .exe), so .bat is a required fallback.
// Go's exec.Command handles .bat natively on Windows (it shells out via
// cmd.exe internally), so downstream callers can pass the returned path
// straight to exec.CommandContext without any extra massaging.
func findBinary(path string) string {
	if !strings.HasSuffix(path, ".exe") {
		if _, err := os.Stat(path + ".exe"); err == nil {
			return path + ".exe"
		}
	}
	if !strings.HasSuffix(path, ".bat") {
		if _, err := os.Stat(path + ".bat"); err == nil {
			return path + ".bat"
		}
	}
	if _, err := os.Stat(path); err == nil {
		return path
	}
	return ""
}

// defaultEmulatorSystemPaths returns Windows well-known paths where the
// emulator binary may live (AppData/Local/Android/Sdk).
func defaultEmulatorSystemPaths(home string) []string {
	return []string{
		filepath.Join(home, "AppData", "Local", "Android", "Sdk", "emulator", "emulator.exe"),
	}
}

// defaultSDKSystemPaths returns Windows well-known SDK root paths.
func defaultSDKSystemPaths(home string) []string {
	return []string{
		filepath.Join(home, "AppData", "Local", "Android", "Sdk"),
	}
}

// defaultJavaSystemPaths returns Windows well-known Java binary paths.
// Windows doesn't have a system-wide Java, so we leave this empty and let
// the caller fall back to PATH discovery.
func defaultJavaSystemPaths(home string) []string {
	return nil
}

// adoptiumOSName returns the Adoptium OS token for the current platform.
func adoptiumOSName() string {
	return "windows"
}