//go:build darwin

package emulator

import (
	"os"
	"path/filepath"
)

// executableName appends the platform-specific executable suffix (.exe on
// Windows, none on Darwin). Symmetric to the Windows and Unix variants so
// callers don't need a runtime.GOOS check.
func executableName(name string) string {
	return name
}

// findBinary returns path itself if it exists on disk. macOS shells don't
// have the Windows .exe / .bat wrapper resolution dance.
func findBinary(path string) string {
	if _, err := os.Stat(path); err == nil {
		return path
	}
	return ""
}

// defaultEmulatorSystemPaths returns macOS well-known paths where the
// emulator binary may live (Library/Android/sdk + Homebrew layout).
func defaultEmulatorSystemPaths(home string) []string {
	return []string{
		filepath.Join(home, "Library", "Android", "sdk", "emulator", "emulator"),
		"/usr/local/share/android-sdk/emulator/emulator",
	}
}

// defaultSDKSystemPaths returns macOS well-known SDK root paths.
func defaultSDKSystemPaths(home string) []string {
	return []string{
		filepath.Join(home, "Library", "Android", "sdk"),
		"/usr/local/share/android-sdk",
	}
}

// defaultJavaSystemPaths returns macOS well-known Java binary paths.
func defaultJavaSystemPaths(home string) []string {
	return []string{
		"/Library/Internet Plug-Ins/JavaAppletPlugin.plugin/Contents/Home/bin/java",
		"/usr/bin/java",
		filepath.Join(home, ".jenv", "shims", "java"),
	}
}

// adoptiumOSName returns the Adoptium OS token for the current platform.
func adoptiumOSName() string {
	return "mac"
}