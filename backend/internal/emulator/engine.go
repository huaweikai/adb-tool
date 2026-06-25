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
	SDKPath         string `json:"sdkPath"`
	AndroidHome     string `json:"androidHome"`
	EmulatorPath    string `json:"emulatorPath"`
	AvdmanagerPath  string `json:"avdmanagerPath"`
	SdkmanagerPath  string `json:"sdkmanagerPath"`
	JavaPath        string `json:"javaPath"`
	JavaVersion     string `json:"javaVersion"`
	EmulatorVersion string `json:"emulatorVersion"`
	IsValid         bool   `json:"isValid"`
	ToolchainReady  bool   `json:"toolchainReady"`
	LastVerified    string `json:"lastVerified,omitempty"`
	Error           string `json:"error,omitempty"`
}

// DefaultSDKPath returns the default SDK path in .adb-tool.
func DefaultSDKPath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".adb-tool", "sdk")
}

// DetectEmulatorEngine attempts to find the Android SDK emulator on the system.
// Priority: 1) ~/.adb-tool/sdk, 2) ANDROID_HOME env, 3) common locations.
func DetectEmulatorEngine(androidHome, emulatorPath string) (*Engine, error) {
	engine := &Engine{}

	// Priority 1: Check our managed SDK path
	managedSDK := DefaultSDKPath()
	if _, err := os.Stat(filepath.Join(managedSDK, "emulator", "emulator")); err == nil {
		engine.SDKPath = managedSDK
		engine.AndroidHome = managedSDK
	}

	// Priority 2: Use provided androidHome
	if androidHome != "" {
		engine.AndroidHome = androidHome
		if _, err := os.Stat(filepath.Join(androidHome, "emulator")); err == nil {
			if engine.SDKPath == "" {
				engine.SDKPath = androidHome
			}
		}
	}

	// Priority 3: Check environment variables
	if engine.AndroidHome == "" {
		if androidHome := os.Getenv("ANDROID_HOME"); androidHome != "" {
			engine.AndroidHome = androidHome
		} else if androidSdkRoot := os.Getenv("ANDROID_SDK_ROOT"); androidSdkRoot != "" {
			engine.AndroidHome = androidSdkRoot
		}
	}

	// Find emulator binary
	if emulatorPath != "" {
		engine.EmulatorPath = emulatorPath
	} else if engine.AndroidHome != "" {
		emulatorPath := filepath.Join(engine.AndroidHome, "emulator", "emulator")
		if runtime.GOOS == "windows" {
			emulatorPath += ".exe"
		}
		if _, err := os.Stat(emulatorPath); err == nil {
			engine.EmulatorPath = emulatorPath
		}
	}

	// Auto-detect if still not found
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

	// Our managed SDK first
	candidates = append(candidates, filepath.Join(home, ".adb-tool", "sdk", "emulator", "emulator"))

	switch runtime.GOOS {
	case "darwin":
		candidates = append(candidates,
			filepath.Join(home, "Library", "Android", "sdk", "emulator", "emulator"),
			"/usr/local/share/android-sdk/emulator/emulator",
		)
	case "windows":
		candidates = append(candidates,
			filepath.Join(home, "AppData", "Local", "Android", "Sdk", "emulator", "emulator.exe"),
		)
	case "linux":
		candidates = append(candidates,
			filepath.Join(home, "Android", "Sdk", "emulator", "emulator"),
			"/opt/android-sdk/emulator/emulator",
		)
	}

	// Environment variables
	if androidHome := os.Getenv("ANDROID_HOME"); androidHome != "" {
		candidates = append([]string{filepath.Join(androidHome, "emulator", "emulator")}, candidates...)
	}
	if androidSdkRoot := os.Getenv("ANDROID_SDK_ROOT"); androidSdkRoot != "" {
		candidates = append([]string{filepath.Join(androidSdkRoot, "emulator", "emulator")}, candidates...)
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
			parts := strings.Split(line, "version")
			if len(parts) >= 2 {
				version := strings.TrimSpace(parts[1])
				version = strings.Split(version, " ")[0]
				return version
			}
		}
	}
	if len(lines) > 0 {
		return strings.TrimSpace(lines[0])
	}
	return ""
}

// detectToolchain checks for avdmanager and sdkmanager availability.
func detectToolchain(engine *Engine) {
	sdkPath := engine.AndroidHome
	if sdkPath == "" {
		sdkPath = engine.SDKPath
	}
	if sdkPath == "" {
		return
	}

	// Check cmdline-tools first
	cmdlineToolsLatest := filepath.Join(sdkPath, "cmdline-tools", "latest", "bin")
	engine.AvdmanagerPath = findBinary(filepath.Join(cmdlineToolsLatest, "avdmanager"))
	engine.SdkmanagerPath = findBinary(filepath.Join(cmdlineToolsLatest, "sdkmanager"))

	// Fallback to older tools/bin
	if engine.AvdmanagerPath == "" {
		toolsBin := filepath.Join(sdkPath, "tools", "bin")
		if path := findBinary(filepath.Join(toolsBin, "avdmanager")); path != "" {
			engine.AvdmanagerPath = path
		}
	}
	if engine.SdkmanagerPath == "" {
		toolsBin := filepath.Join(sdkPath, "tools", "bin")
		if path := findBinary(filepath.Join(toolsBin, "sdkmanager")); path != "" {
			engine.SdkmanagerPath = path
		}
	}

	// Check Java
	detectJava(engine, sdkPath)

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
func detectJava(engine *Engine, sdkPath string) {
	javaCandidates := []string{}

	// Check JAVA_HOME
	if javaHome := os.Getenv("JAVA_HOME"); javaHome != "" {
		javaCandidates = append(javaCandidates, filepath.Join(javaHome, "bin", "java"))
	}

	// Check Android SDK bundled Java runtime
	if sdkPath != "" {
		javaRuntime := filepath.Join(sdkPath, "jre", "bin", "java")
		javaCandidates = append(javaCandidates, javaRuntime)
		javaRuntime = filepath.Join(sdkPath, "java-runtime", "bin", "java")
		javaCandidates = append(javaCandidates, javaRuntime)
	}

	// Check our managed Java runtime
	home, _ := os.UserHomeDir()
	managedJava := filepath.Join(home, ".adb-tool", "emulator", "java-runtime", "bin", "java")
	javaCandidates = append(javaCandidates, managedJava)

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

// SDKInfo represents a detected Android SDK installation.
type SDKInfo struct {
	Path          string `json:"path"`
	Name          string `json:"name"`
	HasEmulator   bool   `json:"hasEmulator"`
	HasAvdmanager bool   `json:"hasAvdmanager"`
	HasJava       bool   `json:"hasJava"`
	Version       string `json:"version,omitempty"`
}

// ScanSystemSDKs scans common locations for Android SDK installations.
func ScanSystemSDKs() []SDKInfo {
	var results []SDKInfo
	seen := make(map[string]bool)

	// Check common SDK locations
	candidates := getSDKCandidates()
	for _, path := range candidates {
		if seen[path] {
			continue
		}

		info := checkSDKPath(path)
		if info != nil {
			results = append(results, *info)
			seen[path] = true
		}
	}

	return results
}

// getSDKCandidates returns common Android SDK installation paths.
func getSDKCandidates() []string {
	var candidates []string

	home, err := os.UserHomeDir()
	if err != nil {
		return candidates
	}

	switch runtime.GOOS {
	case "darwin":
		candidates = append(candidates,
			filepath.Join(home, "Library", "Android", "sdk"),
			"/usr/local/share/android-sdk",
		)
	case "windows":
		candidates = append(candidates,
			filepath.Join(home, "AppData", "Local", "Android", "Sdk"),
		)
	case "linux":
		candidates = append(candidates,
			filepath.Join(home, "Android", "Sdk"),
			"/opt/android-sdk",
			"/usr/local/android-sdk",
		)
	}

	// Environment variables
	if androidHome := os.Getenv("ANDROID_HOME"); androidHome != "" {
		candidates = append([]string{androidHome}, candidates...)
	}
	if androidSdkRoot := os.Getenv("ANDROID_SDK_ROOT"); androidSdkRoot != "" {
		candidates = append([]string{androidSdkRoot}, candidates...)
	}

	// Our managed SDK
	managed := filepath.Join(home, ".adb-tool", "sdk")
	candidates = append(candidates, managed)

	return candidates
}

// checkSDKPath checks if a path contains a valid Android SDK.
// It returns the info even if the SDK is partial (e.g., missing emulator)
// or inaccessible (returns with all components false but still listed).
func checkSDKPath(path string) *SDKInfo {
	info, err := os.Stat(path)
	if err != nil {
		// Path doesn't exist or is inaccessible - still return it with all false
		// This allows ANDROID_HOME to be shown even if we can't access contents
		return &SDKInfo{
			Path: path,
			Name: filepath.Base(path),
		}
	}
	if !info.IsDir() {
		return nil
	}

	result := &SDKInfo{
		Path: path,
		Name: filepath.Base(path),
	}

	// Check emulator (optional component)
	emulatorPath := filepath.Join(path, "emulator", "emulator")
	if runtime.GOOS == "windows" {
		emulatorPath += ".exe"
	}
	if _, err := os.Stat(emulatorPath); err == nil {
		result.HasEmulator = true
		// Try to get version
		if version := getEmulatorVersion(emulatorPath); version != "" {
			result.Version = version
			result.Name = "Android SDK " + version
		}
	}

	// Check avdmanager (optional component)
	avdPath := filepath.Join(path, "cmdline-tools", "latest", "bin", "avdmanager")
	if runtime.GOOS == "windows" {
		avdPath += ".bat"
	}
	if _, err := os.Stat(avdPath); err == nil {
		result.HasAvdmanager = true
	}

	// Also check older cmdline-tools location
	if !result.HasAvdmanager {
		oldAvdPath := filepath.Join(path, "tools", "bin", "avdmanager")
		if runtime.GOOS == "windows" {
			oldAvdPath += ".bat"
		}
		if _, err := os.Stat(oldAvdPath); err == nil {
			result.HasAvdmanager = true
		}
	}

	// Check Java in SDK (optional component)
	javaPaths := []string{
		filepath.Join(path, "jre", "bin", "java"),
		filepath.Join(path, "jdk", "bin", "java"),
		filepath.Join(path, "java-runtime", "bin", "java"),
	}
	for _, javaPath := range javaPaths {
		if runtime.GOOS == "windows" {
			javaPath += ".exe"
		}
		if _, err := os.Stat(javaPath); err == nil {
			result.HasJava = true
			break
		}
	}

	return result
}

// getEmulatorVersion gets the emulator version.
func getEmulatorVersion(emulatorPath string) string {
	cmd := exec.Command(emulatorPath, "-version")
	output, err := cmd.Output()
	if err != nil {
		return ""
	}
	return parseEmulatorVersion(string(output))
}
