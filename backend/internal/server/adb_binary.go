package server

import (
	"archive/zip"
	"bytes"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
)

func FindOrExtractADB(zipData []byte) (string, error) {
	adbName := "adb"
	if runtime.GOOS == "windows" {
		adbName = "adb.exe"
	}

	cacheDir := filepath.Join(os.TempDir(), "adb-tool-cache")
	adbPath := filepath.Join(cacheDir, adbName)

	if _, err := os.Stat(adbPath); err == nil {
		if areExtractedFilesComplete(cacheDir, zipData) {
			if err := os.Chmod(adbPath, 0755); err != nil {
				return "", fmt.Errorf("failed to chmod adb binary: %w", err)
			}
			return adbPath, nil
		}
		_ = os.Remove(adbPath)
	}

	if err := os.MkdirAll(cacheDir, 0755); err != nil {
		return "", fmt.Errorf("failed to create adb cache directory: %w", err)
	}

	reader, err := zip.NewReader(bytes.NewReader(zipData), int64(len(zipData)))
	if err != nil {
		return "", fmt.Errorf("failed to read platform-tools zip: %w", err)
	}

	for _, f := range reader.File {
		if f.FileInfo().IsDir() {
			continue
		}
		rel, err := filepath.Rel("platform-tools", filepath.FromSlash(f.Name))
		if err != nil {
			return "", fmt.Errorf("failed to compute relative path for %s: %w", f.Name, err)
		}
		dstPath := filepath.Join(cacheDir, rel)

		if err := os.MkdirAll(filepath.Dir(dstPath), 0755); err != nil {
			return "", fmt.Errorf("failed to create directory for %s: %w", rel, err)
		}

		rc, err := f.Open()
		if err != nil {
			return "", fmt.Errorf("failed to open %s in zip: %w", f.Name, err)
		}

		dst, err := os.OpenFile(dstPath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0755)
		if err != nil {
			rc.Close()
			return "", fmt.Errorf("failed to create %s: %w", rel, err)
		}

		_, copyErr := io.Copy(dst, rc)
		closeErr := dst.Close()
		rc.Close()
		if copyErr != nil {
			return "", fmt.Errorf("failed to extract %s: %w", rel, copyErr)
		}
		if closeErr != nil {
			return "", fmt.Errorf("failed to close %s: %w", rel, closeErr)
		}
	}

	if err := os.Chmod(adbPath, 0755); err != nil {
		return "", fmt.Errorf("failed to chmod adb binary: %w", err)
	}
	return adbPath, nil
}

// areExtractedFilesComplete checks whether every non-directory entry in the
// platform-tools zip has been extracted to the cache directory. This ensures
// that upgrades to a newer platform-tools zip trigger a fresh extraction.
func areExtractedFilesComplete(cacheDir string, zipData []byte) bool {
	reader, err := zip.NewReader(bytes.NewReader(zipData), int64(len(zipData)))
	if err != nil {
		return false
	}
	for _, f := range reader.File {
		if f.FileInfo().IsDir() {
			continue
		}
		rel, err := filepath.Rel("platform-tools", filepath.FromSlash(f.Name))
		if err != nil {
			return false
		}
		dstPath := filepath.Join(cacheDir, rel)
		if _, err := os.Stat(dstPath); err != nil {
			return false
		}
	}
	return true
}
