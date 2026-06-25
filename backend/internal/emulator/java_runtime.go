package emulator

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

// javaCandidatePaths builds the ordered list of java executable paths to probe.
func javaCandidatePaths(androidHome string) []string {
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

	// Check our managed Java runtimes (one or more downloaded JREs)
	home, _ := os.UserHomeDir()
	javaCacheDir := filepath.Join(home, ".adb-tool", "emulator", "java-runtime")
	if entries, err := os.ReadDir(javaCacheDir); err == nil {
		for _, entry := range entries {
			if entry.IsDir() {
				javaCandidates = append(javaCandidates,
					filepath.Join(javaCacheDir, entry.Name(), "bin", "java"))
			}
		}
	}

	// Check common locations on macOS
	if runtime.GOOS == "darwin" {
		javaCandidates = append(javaCandidates,
			"/Library/Internet Plug-Ins/JavaAppletPlugin.plugin/Contents/Home/bin/java",
			"/usr/bin/java",
			filepath.Join(home, ".jenv", "shims", "java"),
		)
	}

	// Check system PATH
	javaCandidates = append(javaCandidates, "java")

	return javaCandidates
}

// probeJava runs `java -version` and parses the result. Returns nil if unusable.
func probeJava(javaPath string) *JavaRuntime {
	path := findBinary(javaPath)
	if path == "" {
		return nil
	}

	cmd := exec.Command(path, "-version")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return nil
	}

	versionInfo := parseJavaVersionInfo(string(output))
	if versionInfo.Version == "" {
		return nil
	}

	return &JavaRuntime{
		Path:    path,
		Version: versionInfo.Version,
		Vendor:  versionInfo.Vendor,
		Arch:    runtime.GOARCH,
	}
}

// DetectJavaRuntime attempts to find a suitable Java installation.
// If the user has selected a specific Java path, it takes priority.
func DetectJavaRuntime(androidHome string) *JavaRuntime {
	if selected := LoadSelectedJavaPath(); selected != "" {
		if rt := probeJava(selected); rt != nil {
			return rt
		}
	}

	for _, javaPath := range javaCandidatePaths(androidHome) {
		if rt := probeJava(javaPath); rt != nil {
			return rt
		}
	}

	return nil
}

// ValidateJavaPath probes a specific java executable path and returns its
// runtime info, or nil if it is not a usable Java executable.
func ValidateJavaPath(javaPath string) *JavaRuntime {
	return probeJava(javaPath)
}

// ScanJavaRuntimes returns all usable Java runtimes found on the system,
// deduplicated by resolved executable path. Embedded (managed) runtimes are
// flagged via IsEmbedded.
func ScanJavaRuntimes(androidHome string) []*JavaRuntime {
	home, _ := os.UserHomeDir()
	javaCacheDir := filepath.Join(home, ".adb-tool", "emulator", "java-runtime")

	var results []*JavaRuntime
	seen := make(map[string]bool)
	for _, javaPath := range javaCandidatePaths(androidHome) {
		rt := probeJava(javaPath)
		if rt == nil {
			continue
		}
		if seen[rt.Path] {
			continue
		}
		seen[rt.Path] = true
		rt.IsEmbedded = strings.HasPrefix(rt.Path, javaCacheDir)
		results = append(results, rt)
	}

	return results
}

// JavaRuntime represents a detected or installed Java runtime.
type JavaRuntime struct {
	ID         string `json:"id"`
	Path       string `json:"path"`
	Version    string `json:"version"`
	Vendor     string `json:"vendor"`
	Arch       string `json:"arch"`
	IsEmbedded bool   `json:"isEmbedded"`
}

// javaConfigPath returns the path to the persisted Java selection config.
func javaConfigPath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".adb-tool", "emulator", "java-config.json")
}

type javaConfig struct {
	SelectedPath string `json:"selectedPath"`
}

// LoadSelectedJavaPath returns the user-selected Java path, or "" if none.
func LoadSelectedJavaPath() string {
	data, err := os.ReadFile(javaConfigPath())
	if err != nil {
		return ""
	}
	var cfg javaConfig
	if err := json.Unmarshal(data, &cfg); err != nil {
		return ""
	}
	return cfg.SelectedPath
}

// SaveSelectedJavaPath persists the user-selected Java path.
func SaveSelectedJavaPath(path string) error {
	cfgPath := javaConfigPath()
	if err := os.MkdirAll(filepath.Dir(cfgPath), 0755); err != nil {
		return err
	}
	data, err := json.MarshalIndent(javaConfig{SelectedPath: path}, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(cfgPath, data, 0644)
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
