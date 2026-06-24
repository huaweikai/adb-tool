package emulator

import (
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

// DetectJavaRuntime attempts to find a suitable Java installation.
func DetectJavaRuntime(androidHome string) *JavaRuntime {
	javaCandidates := []string{}

	// Check JAVA_HOME
	if javaHome := os.Getenv("JAVA_HOME"); javaHome != "" {
		javaCandidates = append(javaCandidates, filepath.Join(javaHome, "bin", "java"))
	}

	// Check Android SDK bundled Java runtime
	if androidHome != "" {
		paths := []string{
			filepath.Join(androidHome, "jre", "bin", "java"),
			filepath.Join(androidHome, "java-runtime", "bin", "java"),
			filepath.Join(androidHome, "jbr", "bin", "java"),
		}
		javaCandidates = append(javaCandidates, paths...)
	}

	// Check common locations on macOS
	if runtime.GOOS == "darwin" {
		home, _ := os.UserHomeDir()
		javaCandidates = append(javaCandidates,
			"/Library/Internet Plug-Ins/JavaAppletPlugin.plugin/Contents/Home/bin/java",
			"/usr/bin/java",
			filepath.Join(home, ".jenv", "shims", "java"),
		)
	}

	// Check system PATH
	javaCandidates = append(javaCandidates, "java")

	for _, javaPath := range javaCandidates {
		path := findBinary(javaPath)
		if path == "" {
			continue
		}

		cmd := exec.Command(path, "-version")
		output, err := cmd.Output()
		if err != nil {
			continue
		}

		versionInfo := parseJavaVersionInfo(string(output))
		if versionInfo.Version != "" {
			return &JavaRuntime{
				Path:    path,
				Version: versionInfo.Version,
				Vendor:  versionInfo.Vendor,
				Arch:    runtime.GOARCH,
			}
		}
	}

	return nil
}

// JavaRuntime represents a detected or installed Java runtime.
type JavaRuntime struct {
	ID    string `json:"id"`
	Path  string `json:"path"`
	Version string `json:"version"`
	Vendor string `json:"vendor"`
	Arch  string `json:"arch"`
}

// GetEmbeddedJavaRuntimes returns list of embedded JREs in the app data directory.
func GetEmbeddedJavaRuntimes() []*JavaRuntime {
	home, _ := os.UserHomeDir()
	javaCacheDir := filepath.Join(home, ".adb-tool", "emulator", "java-runtime")

	runtimes := []*JavaRuntime{}
	entries, err := os.ReadDir(javaCacheDir)
	if err != nil {
		return runtimes
	}

	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		javaBin := filepath.Join(javaCacheDir, entry.Name(), "bin", "java")
		if _, err := os.Stat(javaBin); err == nil {
			runtimes = append(runtimes, &JavaRuntime{
				ID:   entry.Name(),
				Path: javaBin,
			})
		}
	}

	return runtimes
}

// JavaVersionInfo holds parsed Java version details.
type JavaVersionInfo struct {
	Version string
	Vendor  string
	Full    string
}

// parseJavaVersionInfo extracts version info from java -version output.
func parseJavaVersionInfo(output string) JavaVersionInfo {
	info := JavaVersionInfo{Full: output}
	lines := strings.Split(output, "\n")

	for _, line := range lines {
		// Look for version line like "openjdk version "21.0.2" 2024-01-15"
		if strings.Contains(line, "version") {
			// Extract version between quotes
			start := strings.Index(line, "\"")
			if start >= 0 {
				end := strings.Index(line[start+1:], "\"")
				if end > 0 {
					info.Version = line[start+1 : start+1+end]
				}
			}
		}
		if strings.Contains(line, "JetBrains") || strings.Contains(line, "JBR") {
			info.Vendor = "JetBrains Runtime"
		} else if strings.Contains(line, "Eclipse") {
			info.Vendor = "Eclipse Temurin"
		} else if strings.Contains(line, "Oracle") {
			info.Vendor = "Oracle"
		} else if strings.Contains(line, "OpenJDK") {
			info.Vendor = "OpenJDK"
		}
	}

	// Fallback: use first line
	if info.Version == "" && len(lines) > 0 {
		info.Version = strings.TrimSpace(lines[0])
		info.Full = info.Version
	}

	return info
}
