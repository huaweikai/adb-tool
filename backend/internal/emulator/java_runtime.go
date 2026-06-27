package emulator

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
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

// JavaRuntimeDir returns the managed directory where embedded Java runtimes
// live. Each runtime is unpacked into its own sub-directory keyed by `id`.
func JavaRuntimeDir() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".adb-tool", "emulator", "java-runtime")
}

// SanitizeJavaRuntimeID rejects IDs that could escape the managed runtime
// directory. We restrict to a small alphabet so users can safely call into
// DownloadManager and ImportJavaFromZip with arbitrary frontend input.
func SanitizeJavaRuntimeID(id string) error {
	if id == "" {
		return fmt.Errorf("id is required")
	}
	if len(id) > 64 {
		return fmt.Errorf("id too long")
	}
	for _, r := range id {
		switch {
		case r >= 'a' && r <= 'z':
		case r >= 'A' && r <= 'Z':
		case r >= '0' && r <= '9':
		case r == '-' || r == '_' || r == '.':
		default:
			return fmt.Errorf("id contains invalid character %q", r)
		}
	}
	return nil
}

// ImportJavaFromZip extracts a Java runtime archive (zip) into the managed
// java-runtime directory under `runtimeID`. The archive may have a single
// top-level directory (typical for Temurin / Adoptium) or unpack straight
// into the destination. After extracting, it probes the resulting `bin/java`
// to make sure we got a usable runtime and returns the resolved path.
func ImportJavaFromZip(zipPath, runtimeID string) (string, error) {
	if err := SanitizeJavaRuntimeID(runtimeID); err != nil {
		return "", err
	}

	destDir := filepath.Join(JavaRuntimeDir(), runtimeID)
	if err := os.MkdirAll(destDir, 0755); err != nil {
		return "", fmt.Errorf("failed to create runtime dir: %w", err)
	}

	// Extract zip into a temp sub-dir, then move the inner directory up.
	tmpExtract := filepath.Join(destDir, "_staging")
	if err := os.RemoveAll(tmpExtract); err != nil {
		return "", fmt.Errorf("failed to clean staging: %w", err)
	}
	if err := os.MkdirAll(tmpExtract, 0755); err != nil {
		return "", fmt.Errorf("failed to create staging: %w", err)
	}

	if err := ExtractZip(zipPath, tmpExtract); err != nil {
		_ = os.RemoveAll(tmpExtract)
		return "", fmt.Errorf("failed to extract zip: %w", err)
	}

	javaBin, err := flattenJavaIntoDest(tmpExtract, destDir)
	if err != nil {
		_ = os.RemoveAll(tmpExtract)
		_ = os.RemoveAll(destDir)
		return "", err
	}
	_ = os.RemoveAll(tmpExtract)

	return verifyAndRegister(javaBin, destDir, runtimeID)
}

// RegisterJavaFromExtractedDir registers an *already extracted* java tree
// at [srcDir] into the managed java-runtime directory keyed by [runtimeID].
// Used by the download flow, which has already run ExtractZip on the
// downloaded archive and is handing us the unpacked directory directly.
//
// We used to call ImportJavaFromZip here too, but that helper expected a
// real .zip file and would re-try to extract the directory, blowing up
// with "open <srcDir>: system cannot find the file" — meaning the
// download would fail and the java runtime never actually landed in the
// managed cache. This helper closes that gap.
func RegisterJavaFromExtractedDir(srcDir, runtimeID string) (string, error) {
	if err := SanitizeJavaRuntimeID(runtimeID); err != nil {
		return "", err
	}

	destDir := filepath.Join(JavaRuntimeDir(), runtimeID)
	if err := os.MkdirAll(destDir, 0755); err != nil {
		return "", fmt.Errorf("failed to create runtime dir: %w", err)
	}
	// Wipe any stale install under the same id.
	entries, err := os.ReadDir(destDir)
	if err == nil {
		for _, e := range entries {
			_ = os.RemoveAll(filepath.Join(destDir, e.Name()))
		}
	}

	// Stage the source into a temp dir under destDir so flattenJavaIntoDest
	// can treat the layout uniformly (single-root vs flat). We use a
	// copy-then-flatten rather than rename because srcDir may live
	// somewhere else on disk.
	stage := filepath.Join(destDir, "_staging")
	if err := os.RemoveAll(stage); err != nil {
		return "", err
	}
	if err := os.MkdirAll(stage, 0755); err != nil {
		return "", err
	}
	if err := copyTreeInto(srcDir, stage); err != nil {
		_ = os.RemoveAll(stage)
		_ = os.RemoveAll(destDir)
		return "", fmt.Errorf("failed to stage extracted tree: %w", err)
	}

	javaBin, err := flattenJavaIntoDest(stage, destDir)
	if err != nil {
		_ = os.RemoveAll(stage)
		_ = os.RemoveAll(destDir)
		return "", err
	}
	_ = os.RemoveAll(stage)

	return verifyAndRegister(javaBin, destDir, runtimeID)
}

// verifyAndRegister probes [javaBin] and — if it is a usable Java —
// persists a log line and returns the path. If probe fails, the [destDir]
// is wiped and an error is returned.
func verifyAndRegister(javaBin, destDir, runtimeID string) (string, error) {
	rt := probeJava(javaBin)
	if rt == nil {
		_ = os.RemoveAll(destDir)
		return "", fmt.Errorf("extracted archive is not a usable Java runtime")
	}
	log.Printf("[java] import: id=%s path=%s version=%s vendor=%s", runtimeID, javaBin, rt.Version, rt.Vendor)
	return javaBin, nil
}

// copyTreeInto recursively copies every entry of [src] under [dst]. Unlike
// a wholesale `os.Rename`, this lets us move a tree across volumes and
// also clean up partial output on failure.
func copyTreeInto(src, dst string) error {
	entries, err := os.ReadDir(src)
	if err != nil {
		return err
	}
	for _, e := range entries {
		s := filepath.Join(src, e.Name())
		d := filepath.Join(dst, e.Name())
		info, err := e.Info()
		if err != nil {
			return err
		}
		if info.IsDir() {
			if err := os.MkdirAll(d, info.Mode().Perm()); err != nil {
				return err
			}
			if err := copyTreeInto(s, d); err != nil {
				return err
			}
		} else {
			if err := copyFile(s, d, info.Mode().Perm()); err != nil {
				return err
			}
		}
	}
	return nil
}

func copyFile(src, dst string, mode os.FileMode) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.OpenFile(dst, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, mode)
	if err != nil {
		return err
	}
	defer out.Close()
	_, err = io.Copy(out, in)
	return err
}

// flattenJavaIntoDest takes a staging directory containing an extracted
// Java tree and promotes the inner java tree to `destDir`. Handles both
// layouts:
//
//   - Single-root layout (Temurin):  staging/jdk-21.0.5+11/{bin,conf,lib,...}
//   - Flat layout:                    staging/{bin,conf,lib,...}
//
// In both cases the destination ends up as destDir/{bin,conf,lib,...} so
// javaCandidatePaths() can find bin/java on every platform.
func flattenJavaIntoDest(staging, destDir string) (string, error) {
	entries, err := os.ReadDir(staging)
	if err != nil {
		return "", fmt.Errorf("failed to read staging: %w", err)
	}

	// Pick the inner java tree.
	var inner string
	if len(entries) == 1 && entries[0].IsDir() {
		// Single-root layout.
		inner = filepath.Join(staging, entries[0].Name())
	} else {
		// Flat layout — use staging itself.
		inner = staging
	}

	javaBin := filepath.Join(inner, "bin", "java")
	if runtime.GOOS == "windows" {
		javaBin += ".exe"
	}
	if _, err := os.Stat(javaBin); err != nil {
		return "", fmt.Errorf("extracted tree has no bin/java (looked at %s)", javaBin)
	}

	// Move every entry of `inner` to `destDir`, overwriting stale files from
	// a previous import. We rename one by one rather than `os.Rename(inner,
	// destDir)` so we can leave the staging directory in place.
	innerEntries, err := os.ReadDir(inner)
	if err != nil {
		return "", err
	}
	for _, e := range innerEntries {
		src := filepath.Join(inner, e.Name())
		dst := filepath.Join(destDir, e.Name())
		_ = os.RemoveAll(dst)
		if err := os.Rename(src, dst); err != nil {
			return "", fmt.Errorf("failed to move %s: %w", e.Name(), err)
		}
	}

	// IMPORTANT: `javaBin` is the *staging* path. After the renames above
	// those files now live under `destDir` instead, so we have to rewrite
	// the returned path. Returning the stale staging path made
	// probeJava() see a missing file and abort the import with
	// "extracted archive is not a usable Java runtime".
	relBin, err := filepath.Rel(inner, javaBin)
	if err != nil {
		return "", err
	}
	return filepath.Join(destDir, relBin), nil
}

// DeleteJavaRuntime removes a managed Java runtime by id.
func DeleteJavaRuntime(runtimeID string) error {
	if err := SanitizeJavaRuntimeID(runtimeID); err != nil {
		return err
	}
	return os.RemoveAll(filepath.Join(JavaRuntimeDir(), runtimeID))
}

// SupportedJavaVersions lists the Java major versions we surface in the UI
// for the "Download Java" dialog. Order matters — first entry is the
// recommended default.
var SupportedJavaVersions = []string{"17", "21", "11"}

// DefaultJavaDownloadURL returns the Adoptium (Eclipse Temurin) download URL
// for a given Java major version, sized for the current platform. Adoptium
// ships cross-platform .zip archives that include the JRE layout our
// javaCandidatePaths() helper already probes, so no tar.gz handling needed.
//
// Endpoint docs: https://api.adoptium.net/v3/binary/latest/{feature_version}/ga/{os}/{arch}/jdk/hotspot/normal/eclipse?project=jdk
func DefaultJavaDownloadURL(version string) (string, error) {
	osName, archName, err := adoptiumPlatformTokens()
	if err != nil {
		return "", err
	}
	return fmt.Sprintf(
		"https://api.adoptium.net/v3/binary/latest/%s/ga/%s/%s/jdk/hotspot/normal/eclipse?project=jdk",
		version, osName, archName,
	), nil
}

func adoptiumPlatformTokens() (string, string, error) {
	var osName, archName string
	switch runtime.GOOS {
	case "darwin":
		osName = "mac"
	case "windows":
		osName = "windows"
	case "linux":
		osName = "linux"
	default:
		return "", "", fmt.Errorf("unsupported OS for default Java download: %s", runtime.GOOS)
	}
	switch runtime.GOARCH {
	case "amd64", "x86_64":
		archName = "x64"
	case "arm64", "aarch64":
		archName = "aarch64"
	default:
		return "", "", fmt.Errorf("unsupported arch for default Java download: %s", runtime.GOARCH)
	}
	return osName, archName, nil
}
