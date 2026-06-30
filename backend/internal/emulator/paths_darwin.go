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
//
// Order matters — earlier entries are probed first. We deliberately list
// any real JDK installs under /Library/Java/JavaVirtualMachines/ BEFORE
// `/usr/bin/java`, because the Apple stub at /usr/bin/java hangs when
// invoked from a GUI-app subprocess (the stub does launchd IPC with
// java_helper that never completes outside an interactive Terminal).
//
// Sources for the JDK layout: Adoptium, Azul Zulu, Oracle — all install
// under `/Library/Java/JavaVirtualMachines/<name>/Contents/Home/bin/java`
// with `/Contents/Home` being JAVA_HOME.
func defaultJavaSystemPaths(home string) []string {
	paths := []string{
		"/Library/Internet Plug-Ins/JavaAppletPlugin.plugin/Contents/Home/bin/java",
		filepath.Join(home, ".jenv", "shims", "java"),
	}
	// Discover any installed real JDK at the standard Adoptium/Oracle
	// path. filepath.Glob expands the wildcard at probe time, so the
	// returned list always reflects what's actually on disk.
	if matches, err := filepath.Glob("/Library/Java/JavaVirtualMachines/*/Contents/Home/bin/java"); err == nil {
		paths = append(paths, matches...)
	}
	// Apple stub last — only used if nothing else is present. We deliberately
	// keep it in the list so users without a JDK (just Apple stub) still get
	// a JavaPath; they just have to install a real JDK before using
	// sdkmanager / emulator (the stub will hang regardless of how we spawn
	// it).
	paths = append(paths, "/usr/bin/java")
	return paths
}

// adoptiumOSName returns the Adoptium OS token for the current platform.
func adoptiumOSName() string {
	return "mac"
}
