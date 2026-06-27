package emulator

import (
	"archive/zip"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// SDKManager handles Android SDK import and management.
type SDKManager struct {
	sdkPath string
}

// NewSDKManager creates a new SDK manager.
func NewSDKManager() *SDKManager {
	home, _ := os.UserHomeDir()
	return &SDKManager{
		sdkPath: filepath.Join(home, ".adb-tool", "sdk"),
	}
}

// GetSDKPath returns the configured SDK path.
func (s *SDKManager) GetSDKPath() string {
	return s.sdkPath
}

// ImportSDKFromZip extracts an Android SDK zip to the managed directory.
func (s *SDKManager) ImportSDKFromZip(zipPath string) error {
	// Create SDK directory
	if err := os.MkdirAll(s.sdkPath, 0755); err != nil {
		return fmt.Errorf("failed to create SDK directory: %w", err)
	}

	// Open zip file
	reader, err := zip.OpenReader(zipPath)
	if err != nil {
		return fmt.Errorf("failed to open zip: %w", err)
	}
	defer reader.Close()

	// Check for nested structure (e.g., android-sdk-macOS/)
	hasRootDir := s.hasSingleRootDir(reader.File)

	// Extract files
	for _, file := range reader.File {
		if err := s.extractFile(file, hasRootDir); err != nil {
			return fmt.Errorf("failed to extract %s: %w", file.Name, err)
		}
	}

	return nil
}

// hasSingleRootDir checks if zip has a single root directory.
func (s *SDKManager) hasSingleRootDir(files []*zip.File) bool {
	if len(files) == 0 {
		return false
	}

	firstName := filepath.ToSlash(files[0].Name)
	rootDir := filepath.ToSlash(filepath.Dir(firstName))

	// Check if all files share the same root directory
	for _, file := range files[1:] {
		name := filepath.ToSlash(file.Name)
		dir := filepath.ToSlash(filepath.Dir(name))
		if dir != rootDir && dir != "." {
			return false
		}
	}

	return rootDir != "."
}

// extractFile extracts a single file from the zip.
func (s *SDKManager) extractFile(file *zip.File, stripRoot bool) error {
	name := filepath.ToSlash(file.Name)

	// Strip root directory if present
	if stripRoot {
		parts := splitPath(name)
		if len(parts) > 1 {
			name = filepath.Join(parts[1:]...)
		} else {
			name = parts[0]
		}
	}

	if name == "" || name == "." {
		return nil
	}

	targetPath := filepath.Join(s.sdkPath, name)

	// Fix (code-review B1): prevent zip-slip — reject entries whose resolved
	// path escapes the SDK root. Mirrors download_manager.go's ExtractZip
	// guard, but applied AFTER stripRoot so a single-root wrapper directory
	// is unwrapped before the check (otherwise "../" inside the wrapper
	// would always reject the whole archive).
	cleanRoot := filepath.Clean(s.sdkPath) + string(filepath.Separator)
	if !strings.HasPrefix(filepath.Clean(targetPath), cleanRoot) && filepath.Clean(targetPath) != filepath.Clean(s.sdkPath) {
		return fmt.Errorf("illegal file path (zip-slip): %s", file.Name)
	}

	// Create parent directories
	if err := os.MkdirAll(filepath.Dir(targetPath), 0755); err != nil {
		return err
	}

	// Skip directories
	if file.FileInfo().IsDir() {
		return os.MkdirAll(targetPath, 0755)
	}

	// Extract file
	src, err := file.Open()
	if err != nil {
		return err
	}
	defer src.Close()

	dst, err := os.OpenFile(targetPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, file.Mode())
	if err != nil {
		return err
	}
	defer dst.Close()

	_, err = io.Copy(dst, src)
	return err
}

// splitPath splits a path into components.
func splitPath(p string) []string {
	var parts []string
	for p != "." && p != "/" && p != "" {
		parts = append([]string{filepath.Base(p)}, parts...)
		p = filepath.Dir(p)
	}
	return parts
}

// GetSDKSize returns the total size of the SDK directory.
func (s *SDKManager) GetSDKSize() (int64, error) {
	var total int64
	err := filepath.Walk(s.sdkPath, func(_ string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() {
			total += info.Size()
		}
		return nil
	})
	return total, err
}

// DeleteSDK removes the entire SDK directory.
func (s *SDKManager) DeleteSDK() error {
	return os.RemoveAll(s.sdkPath)
}

// GetEmulatorPath returns the path to the emulator binary.
func (s *SDKManager) GetEmulatorPath() string {
	emulatorPath := executableName(filepath.Join(s.sdkPath, "emulator", "emulator"))
	if _, err := os.Stat(emulatorPath); err == nil {
		return emulatorPath
	}

	// Try cmdline-tools path
	cmdlineEmulator := executableName(filepath.Join(s.sdkPath, "cmdline-tools", "latest", "bin", "emulator"))
	if _, err := os.Stat(cmdlineEmulator); err == nil {
		return cmdlineEmulator
	}

	return ""
}

// GetAvdmanagerPath returns the path to avdmanager.
func (s *SDKManager) GetAvdmanagerPath() string {
	return findSDKTool(s.sdkPath, "avdmanager")
}

// GetJavaPath returns the path to Java in the SDK.
func (s *SDKManager) GetJavaPath() string {
	// Check for bundled JRE
	jrePath := executableName(filepath.Join(s.sdkPath, "jre", "bin", "java"))
	if _, err := os.Stat(jrePath); err == nil {
		// Return the jre/bin directory
		return filepath.Join(s.sdkPath, "jre", "bin")
	}

	// Check for full JDK
	jdkPath := executableName(filepath.Join(s.sdkPath, "jdk", "bin", "java"))
	if _, err := os.Stat(jdkPath); err == nil {
		return filepath.Join(s.sdkPath, "jdk", "bin")
	}

	return ""
}

// Exists checks if the SDK directory exists.
func (s *SDKManager) Exists() bool {
	_, err := os.Stat(s.sdkPath)
	return err == nil
}
