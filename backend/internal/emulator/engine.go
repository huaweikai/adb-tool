package emulator

import (
	"encoding/json"
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
	// SelectedSDKInvalid is true when a persisted SDK selection exists but the
	// path is no longer usable, so the UI can warn the user.
	SelectedSDKInvalid bool   `json:"selectedSDKInvalid,omitempty"`
	SelectedSDKPath    string `json:"selectedSDKPath,omitempty"`
}

// sdkConfigPath returns the path to the persisted SDK selection config.
func sdkConfigPath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".adb-tool", "emulator", "sdk-config.json")
}

type sdkConfig struct {
	SelectedPath string `json:"selectedPath"`
}

// LoadSelectedSDKPath returns the user-selected SDK path, or "" if none.
func LoadSelectedSDKPath() string {
	data, err := os.ReadFile(sdkConfigPath())
	if err != nil {
		return ""
	}
	var cfg sdkConfig
	if err := json.Unmarshal(data, &cfg); err != nil {
		return ""
	}
	return cfg.SelectedPath
}

// SaveSelectedSDKPath persists the user-selected SDK path.
func SaveSelectedSDKPath(path string) error {
	cfgPath := sdkConfigPath()
	if err := os.MkdirAll(filepath.Dir(cfgPath), 0755); err != nil {
		return err
	}
	data, err := json.MarshalIndent(sdkConfig{SelectedPath: path}, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(cfgPath, data, 0644)
}

// sdkPathHasEmulator reports whether the given SDK path contains the emulator binary.
func sdkPathHasEmulator(sdkPath string) bool {
	emulatorPath := filepath.Join(sdkPath, "emulator", "emulator")
	if runtime.GOOS == "windows" {
		emulatorPath += ".exe"
	}
	_, err := os.Stat(emulatorPath)
	return err == nil
}

// SdkPathHasToolchain reports whether the given SDK path contains a usable
// command-line toolchain — sdkmanager + avdmanager — under known SDK layouts.
//
// A path with a working toolchain but no emulator binary is still a *valid*
// Android SDK: it just means the user hasn't run sdkmanager to download the
// emulator package yet. We treat it as usable so the UI can guide them
// through that next step instead of flat-out rejecting the path.
//
// Exported so the HTTP handlers can run the same check before calling
// DetectEmulatorEngine (to fail fast with a clear error).
func SdkPathHasToolchain(sdkPath string) bool {
	return findSDKTool(sdkPath, "sdkmanager") != "" && findSDKTool(sdkPath, "avdmanager") != ""
}

func cmdlineToolsBinCandidates(sdkPath string) []string {
	return []string{
		filepath.Join(sdkPath, "cmdline-tools", "latest", "bin"),
		filepath.Join(sdkPath, "cmdline-tools", "bin"),
		filepath.Join(sdkPath, "tools", "bin"),
	}
}

func findSDKTool(sdkPath, name string) string {
	for _, binDir := range cmdlineToolsBinCandidates(sdkPath) {
		if path := findBinary(filepath.Join(binDir, name)); path != "" {
			return path
		}
	}
	return ""
}

// sdkPathIsAcceptable reports whether the given SDK path is something we can
// work with: either it has an emulator binary already, or it has a usable
// toolchain (so the user can install the emulator with sdkmanager).
func sdkPathIsAcceptable(sdkPath string) bool {
	return sdkPathHasEmulator(sdkPath) || SdkPathHasToolchain(sdkPath)
}

// DefaultSDKPath returns the default SDK path in .adb-tool.
func DefaultSDKPath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".adb-tool", "sdk")
}

// DetectEmulatorEngine attempts to find the Android SDK emulator on the system.
// Priority: 1) ~/.adb-tool/sdk, 2) ANDROID_HOME env, 3) common locations.
//
// A path is considered acceptable when it has EITHER:
//   - the emulator binary already installed, OR
//   - a working cmdline-tools toolchain (sdkmanager + avdmanager) so the user
//     can install the emulator themselves.
//
// This lets a freshly-installed SDK that only has cmdline-tools be selected
// as the active SDK without the UI forcing them to download emulator first.
func DetectEmulatorEngine(androidHome, emulatorPath string) (*Engine, error) {
	engine := &Engine{}

	// Priority 0: Honor the user's persisted SDK selection if still usable.
	if selected := LoadSelectedSDKPath(); selected != "" {
		engine.SelectedSDKPath = selected
		if sdkPathIsAcceptable(selected) {
			engine.SDKPath = selected
			engine.AndroidHome = selected
		} else {
			// Persisted selection is no longer usable; flag it and fall back.
			engine.SelectedSDKInvalid = true
		}
	}

	// Priority 1: Use explicitly provided androidHome (higher priority than persisted)
	if androidHome != "" && sdkPathIsAcceptable(androidHome) {
		engine.SDKPath = androidHome
		engine.AndroidHome = androidHome
		engine.SelectedSDKPath = "" // Clear persisted since we're using explicit
		engine.SelectedSDKInvalid = false
	}

	// Priority 2: Check our managed SDK path
	managedSDK := DefaultSDKPath()
	if engine.SDKPath == "" && sdkPathIsAcceptable(managedSDK) {
		engine.SDKPath = managedSDK
		engine.AndroidHome = managedSDK
	}

	// Priority 3: Check environment variables
	if engine.AndroidHome == "" {
		if androidHomeEnv := os.Getenv("ANDROID_HOME"); androidHomeEnv != "" && sdkPathIsAcceptable(androidHomeEnv) {
			engine.AndroidHome = androidHomeEnv
			engine.SDKPath = androidHomeEnv
		} else if androidSdkRoot := os.Getenv("ANDROID_SDK_ROOT"); androidSdkRoot != "" && sdkPathIsAcceptable(androidSdkRoot) {
			engine.AndroidHome = androidSdkRoot
			engine.SDKPath = androidSdkRoot
		}
	}

	// Priority 4: Last-resort environment-variable fallback (even if the path
	// doesn't pass the strict "has emulator or toolchain" check — let detectToolchain
	// figure out what's actually usable below).
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

	// Check toolchain (avdmanager, sdkmanager) — must run before IsValid so the
	// "toolchain ready but emulator missing" case is reported correctly.
	detectToolchain(engine)

	// Validate. The engine is considered usable when EITHER:
	//   - the emulator binary checks out, OR
	//   - the toolchain (avdmanager + Java) is ready so the user can install
	//     the emulator themselves via sdkmanager.
	if engine.EmulatorPath != "" {
		if err := validateEmulatorBinary(engine); err != nil {
			engine.Error = err.Error()
			engine.IsValid = false
		} else {
			engine.IsValid = true
			engine.LastVerified = time.Now().Format(time.RFC3339)
		}
	} else if engine.ToolchainReady {
		// Toolchain ready but emulator not yet installed. We intentionally do
		// NOT set engine.Error here — the UI already conveys this via the
		// engine card's red ✗ Emulator chip + orange "部分就绪" badge, and a
		// popup-level error message would just be noise. Engine.Error is
		// reserved for actual failures (bad binary, broken config, ...).
		engine.IsValid = true
		engine.LastVerified = time.Now().Format(time.RFC3339)
	}

	return engine, nil
}

// getEmulatorCandidates returns common emulator binary locations for the current platform.
//
// Note: ANDROID_HOME / ANDROID_SDK_ROOT are intentionally NOT included here.
// Those env-var paths often point at SDKs the user didn't choose — for
// instance an external drive whose binaries stat fine but fail at runtime
// under macOS's external-volume sandbox. Adopting such an emulator makes
// the engine report "ready" with a (stale) version string, then crash on
// every instance start. If the user wants that SDK they can pick it
// explicitly via /api/emulator/sdk/use, which writes the selection to disk
// and gets used in preference to env-var paths.
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

	engine.AvdmanagerPath = findSDKTool(sdkPath, "avdmanager")
	engine.SdkmanagerPath = findSDKTool(sdkPath, "sdkmanager")

	// Check Java
	detectJava(engine, sdkPath)

	// Toolchain is ready if we have both avdmanager and Java
	engine.ToolchainReady = engine.AvdmanagerPath != "" && engine.JavaPath != ""
}

// findBinary checks if a binary exists and is executable.
//
// Windows resolution order: <path>.exe → <path>.bat → <path>.
// Modern Android cmdline-tools (>= 8.0) only ship .bat wrappers + .jar files
// under cmdline-tools/latest/bin/ (no .exe), so .bat is a required fallback.
// Go's exec.Command handles .bat natively on Windows (it shells out via
// cmd.exe internally), so downstream callers can pass the returned path
// straight to exec.CommandContext without any extra massaging.
func findBinary(path string) string {
	if runtime.GOOS == "windows" {
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
	}
	if _, err := os.Stat(path); err == nil {
		return path
	}
	return ""
}

// detectJava resolves the effective Java runtime via the single source of
// truth (DetectJavaRuntime), which honors the user's persisted selection.
func detectJava(engine *Engine, sdkPath string) {
	if rt := DetectJavaRuntime(sdkPath); rt != nil {
		engine.JavaPath = rt.Path
		engine.JavaVersion = rt.Version
	}
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

	result.HasAvdmanager = findSDKTool(path, "avdmanager") != ""

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
