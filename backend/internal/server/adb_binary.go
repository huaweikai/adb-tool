package server

import (
	"archive/zip"
	"bytes"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"strings"
)

func FindOrExtractADB(zipData []byte) (string, error) {
	adbName := "adb"
	if runtime.GOOS == "windows" {
		adbName = "adb.exe"
	}

	cacheDir := filepath.Join(os.TempDir(), "adb-tool-cache")
	adbPath := filepath.Join(cacheDir, adbName)

	if _, err := os.Stat(adbPath); err == nil {
		if err := os.Chmod(adbPath, 0755); err != nil {
			return "", fmt.Errorf("failed to chmod adb binary: %w", err)
		}
		return adbPath, nil
	}

	if err := os.MkdirAll(cacheDir, 0755); err != nil {
		return "", fmt.Errorf("failed to create adb cache directory: %w", err)
	}

	reader, err := zip.NewReader(bytes.NewReader(zipData), int64(len(zipData)))
	if err != nil {
		return "", fmt.Errorf("failed to read zip: %w", err)
	}

	for _, f := range reader.File {
		name := filepath.Base(f.Name)
		if strings.EqualFold(name, adbName) || (runtime.GOOS == "windows" && strings.EqualFold(name, "adb.exe")) {
			rc, err := f.Open()
			if err != nil {
				return "", fmt.Errorf("failed to open adb in zip: %w", err)
			}

			dst, err := os.OpenFile(adbPath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0755)
			if err != nil {
				if closeErr := rc.Close(); closeErr != nil {
					return "", fmt.Errorf("failed to create adb binary: %w; also failed to close adb zip entry: %v", err, closeErr)
				}
				return "", fmt.Errorf("failed to create adb binary: %w", err)
			}

			_, copyErr := io.Copy(dst, rc)
			closeDstErr := dst.Close()
			closeSrcErr := rc.Close()
			if copyErr != nil {
				return "", fmt.Errorf("failed to extract adb: %w", copyErr)
			}
			if closeDstErr != nil {
				return "", fmt.Errorf("failed to close adb binary: %w", closeDstErr)
			}
			if closeSrcErr != nil {
				return "", fmt.Errorf("failed to close adb zip entry: %w", closeSrcErr)
			}

			if err := os.Chmod(adbPath, 0755); err != nil {
				return "", fmt.Errorf("failed to chmod adb binary: %w", err)
			}
			return adbPath, nil
		}
	}

	return "", fmt.Errorf("adb binary not found in platform-tools zip")
}
