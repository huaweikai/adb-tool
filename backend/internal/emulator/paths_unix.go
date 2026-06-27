//go:build !darwin && !windows

package emulator

import (
	"os"
	"path/filepath"
)

// executableName appends the platform-specific executable suffix (.exe on
// Windows, none on Unix). Symmetric to the Windows and Darwin variants so
// callers don't need a runtime.GOOS check.
func executableName(name string) string {
	return name
}

// findBinary returns path itself if it exists on disk. Unix shells don't
// have the Windows .exe / .bat wrapper resolution dance.
func findBinary(path string) string {
	if _, err := os.Stat(path); err == nil {
		return path
	}
	return ""
}

// defaultEmulatorSystemPaths returns Linux well-known paths where the
// emulator binary may live (XDG + opt + /usr/local layouts).
func defaultEmulatorSystemPaths(home string) []string {
	return []string{
		filepath.Join(home, "Android", "Sdk", "emulator", "emulator"),
		"/opt/android-sdk/emulator/emulator",
	}
}

// defaultSDKSystemPaths returns Linux well-known SDK root paths.
func defaultSDKSystemPaths(home string) []string {
	return []string{
		filepath.Join(home, "Android", "Sdk"),
		"/opt/android-sdk",
		"/usr/local/android-sdk",
	}
}

// defaultJavaSystemPaths returns Linux well-known Java binary paths.
// Linux doesn't ship a system Java; users usually install via apt and end
// up on $PATH, which findOnPath already handles. Keep this empty so callers
// know to fall back to PATH discovery.
func defaultJavaSystemPaths(home string) []string {
	return nil
}

// adoptiumOSName returns the Adoptium OS token for the current platform.
func adoptiumOSName() string {
	return "linux"
}