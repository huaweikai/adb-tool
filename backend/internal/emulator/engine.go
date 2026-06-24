package emulator

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

// Engine represents the Android SDK emulator engine configuration.
type Engine struct {
	AndroidHome    string `json:"androidHome"`
	EmulatorPath   string `json:"emulatorPath"`
	AvdmanagerPath string `json:"avdmanagerPath"`
	SdkmanagerPath string `json:"sdkmanagerPath"`
	JavaPath       string `json:"javaPath"`
	JavaVersion    string `json:"javaVersion"`
	EmulatorVersion string `json:"emulatorVersion"`
	IsValid        bool   `json:"isValid"`
	ToolchainReady bool   `json:"toolchainReady"`
	LastVerified   string `json:"lastVerified,omitempty"`
	Error          string `json:"error,omitempty"`
}

// DetectEmulatorEngine attempts to find the Android SDK emulator on the system.
// It checks common locations and validates the emulator binary.
func DetectEmulatorEngine(androidHome, emulatorPath string) (*Engine, error) {
	engine := &Engine{
		AndroidHome:  androidHome,
		EmulatorPath: emulatorPath,
	}

	// If androidHome is provided, derive emulator path
	if androidHome != "" {
		engine.AndroidHome = androidHome
		if emulatorPath == "" {
			emulatorPath = filepath.Join(androidHome, "emulator", "emulator")
			if runtime.GOOS == "windows" {
				emulatorPath += ".exe"
			}
			engine.EmulatorPath = emulatorPath
		}
	}

	// If emulatorPath is provided directly, use it
	if emulatorPath != "" && engine.AndroidHome == "" {
		// Try to derive AndroidHome from emulator path
		emulatorDir := filepath.Dir(emulatorPath)
		if parent := filepath.Dir(emulatorDir); filepath.Base(emulatorDir) == "emulator" {
			engine.AndroidHome = parent
		}
		engine.EmulatorPath = emulatorPath
	}

	// Try to detect if no path provided
	if engine.EmulatorPath == "" {
		candidates := getEmulatorCandidates()
		for _, candidate := range candidates {
			if _, err := os.Stat(candidate); err == nil {
				engine.EmulatorPath = candidate
				break
			}
		}
	}

	// Validate emulator binary
	if engine.EmulatorPath != "" {
		if err := validateEmulatorBinary(engine); err != nil {
			engine.Error = err.Error()
			engine.IsValid = false
			return engine, nil
		}
		engine.IsValid = true
		engine.LastVerified = time.Now().Format(time.RFC3339)
	}

	// Check toolchain (avdmanager, sdkmanager)
	detectToolchain(engine)

	return engine, nil
}

// getEmulatorCandidates returns common emulator binary locations for the current platform.
func getEmulatorCandidates() []string {
	var candidates []string

	home, err := os.UserHomeDir()
	if err != nil {
		return candidates
	}

	switch runtime.GOOS {
	case "darwin":
		candidates = []string{
			filepath.Join(home, "Library", "Android", "sdk", "emulator", "emulator"),
			"/usr/local/share/android-sdk/emulator/emulator",
		}
	case "windows":
		candidates = []string{
			filepath.Join(home, "AppData", "Local", "Android", "Sdk", "emulator", "emulator.exe"),
		}
	case "linux":
		candidates = []string{
			filepath.Join(home, "Android", "Sdk", "emulator", "emulator"),
			"/opt/android-sdk/emulator/emulator",
		}
	}

	// Also check environment variables
	if androidHome := os.Getenv("ANDROID_HOME"); androidHome != "" {
		emulatorPath := filepath.Join(androidHome, "emulator", "emulator")
		if runtime.GOOS == "windows" {
			emulatorPath += ".exe"
		}
		candidates = append([]string{emulatorPath}, candidates...)
	}
	if androidSdkRoot := os.Getenv("ANDROID_SDK_ROOT"); androidSdkRoot != "" {
		emulatorPath := filepath.Join(androidSdkRoot, "emulator", "emulator")
		if runtime.GOOS == "windows" {
			emulatorPath += ".exe"
		}
		candidates = append([]string{emulatorPath}, candidates...)
	}

	return candidates
}

// validateEmulatorBinary checks if the emulator binary exists and is executable.
func validateEmulatorBinary(engine *Engine) error {
	info, err := os.Stat(engine.EmulatorPath)
	if err != nil {
		return fmt.Errorf("emulator not found: %w", err)
	}
	if info.IsDir() {
		return fmt.Errorf("emulator path is a directory")
	}

	// Try to get version
	cmd := exec.Command(engine.EmulatorPath, "-version")
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to run emulator -version: %w", err)
	}

	// Parse version from output
	versionOutput := string(output)
	engine.EmulatorVersion = parseEmulatorVersion(versionOutput)

	return nil
}

// parseEmulatorVersion extracts version info from emulator -version output.
func parseEmulatorVersion(output string) string {
	lines := strings.Split(output, "\n")
	for _, line := range lines {
		if strings.Contains(line, "Android emulator version") {
			// Extract version number
			parts := strings.Split(line, "version")
			if len(parts) >= 2 {
				version := strings.TrimSpace(parts[1])
				version = strings.Split(version, " ")[0]
				return version
			}
		}
	}
	// Fallback: return first line
	if len(lines) > 0 {
		return strings.TrimSpace(lines[0])
	}
	return ""
}

// detectToolchain checks for avdmanager and sdkmanager availability.
func detectToolchain(engine *Engine) {
	if engine.AndroidHome == "" {
		return
	}

	// Check cmdline-tools first (modern SDK structure)
	cmdlineToolsLatest := filepath.Join(engine.AndroidHome, "cmdline-tools", "latest", "bin")
	engine.AvdmanagerPath = findBinary(filepath.Join(cmdlineToolsLatest, "avdmanager"))
	engine.SdkmanagerPath = findBinary(filepath.Join(cmdlineToolsLatest, "sdkmanager"))

	// Check older tools/bin as fallback
	if engine.AvdmanagerPath == "" {
		toolsBin := filepath.Join(engine.AndroidHome, "tools", "bin")
		if path := findBinary(filepath.Join(toolsBin, "avdmanager")); path != "" {
			engine.AvdmanagerPath = path
		}
	}
	if engine.SdkmanagerPath == "" {
		toolsBin := filepath.Join(engine.AndroidHome, "tools", "bin")
		if path := findBinary(filepath.Join(toolsBin, "sdkmanager")); path != "" {
			engine.SdkmanagerPath = path
		}
	}

	// Check Java
	detectJava(engine)

	// Toolchain is ready if we have both avdmanager and Java
	engine.ToolchainReady = engine.AvdmanagerPath != "" && engine.JavaPath != ""
}

// findBinary checks if a binary exists and is executable.
func findBinary(path string) string {
	if runtime.GOOS == "windows" && !strings.HasSuffix(path, ".exe") {
		if _, err := os.Stat(path + ".exe"); err == nil {
			return path + ".exe"
		}
	}
	if _, err := os.Stat(path); err == nil {
		return path
	}
	return ""
}

// detectJava attempts to find a suitable Java installation.
func detectJava(engine *Engine) {
	javaCandidates := []string{}

	// Check JAVA_HOME
	if javaHome := os.Getenv("JAVA_HOME"); javaHome != "" {
		javaCandidates = append(javaCandidates, filepath.Join(javaHome, "bin", "java"))
	}

	// Check Android SDK bundled Java runtime
	if engine.AndroidHome != "" {
		javaRuntime := filepath.Join(engine.AndroidHome, "jre", "bin", "java")
		javaCandidates = append(javaCandidates, javaRuntime)
		javaRuntime = filepath.Join(engine.AndroidHome, "java-runtime", "bin", "java")
		javaCandidates = append(javaCandidates, javaRuntime)
	}

	// Check system PATH
	javaCandidates = append(javaCandidates, "java")

	for _, javaPath := range javaCandidates {
		if path := findBinary(javaPath); path != "" {
			cmd := exec.Command(path, "-version")
			output, err := cmd.Output()
			if err != nil {
				continue
			}
			engine.JavaPath = path
			engine.JavaVersion = parseJavaVersion(string(output))
			return
		}
	}
}

// parseJavaVersion extracts Java version info.
func parseJavaVersion(output string) string {
	lines := strings.Split(output, "\n")
	if len(lines) >= 1 {
		return strings.TrimSpace(lines[0])
	}
	return ""
}
