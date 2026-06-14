package server

import (
	"encoding/base64"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

func (m *AdbManager) IsClipboardHelperInstalled(serial string) bool {
	out, err := m.run("-s", serial, "shell", "pm", "list", "packages", "com.adbtool.clipboard")
	if err != nil {
		return false
	}
	return strings.Contains(out, "com.adbtool.clipboard")
}

func (m *AdbManager) InstallClipboardHelper(serial string, apkBytes []byte) error {
	tmpFile := filepath.Join(os.TempDir(), "clipboard-helper.apk")
	if err := os.WriteFile(tmpFile, apkBytes, 0644); err != nil {
		return fmt.Errorf("write temp apk: %w", err)
	}
	defer os.Remove(tmpFile)
	_, err := m.run("-s", serial, "install", "-r", "-d", tmpFile)
	return err
}

func (m *AdbManager) SendClipboard(serial, text string) error {
	encoded := base64.StdEncoding.EncodeToString([]byte(text))
	_, err := m.run("-s", serial, "shell", "am", "start", "-n", "com.adbtool.clipboard/.SetClipboardActivity", "--es", "text", encoded)
	return err
}

func (m *AdbManager) UninstallClipboardHelper(serial string) error {
	_, err := m.run("-s", serial, "uninstall", "com.adbtool.clipboard")
	return err
}
