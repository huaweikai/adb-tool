//go:build darwin

package server

import (
	"os"
	"path/filepath"
)

func backendLogDir() string {
	home, _ := os.UserHomeDir()
	if home == "" {
		return os.TempDir()
	}
	return filepath.Join(home, "Library", "Application Support", "ADBTool")
}
