//go:build windows

package server

import (
	"os"
	"path/filepath"
)

func backendLogDir() string {
	appdata := os.Getenv("APPDATA")
	if appdata == "" {
		return os.TempDir()
	}
	return filepath.Join(appdata, "ADBTool")
}
