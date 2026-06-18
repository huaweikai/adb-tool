package server

import (
	"archive/zip"
	"bytes"
	"encoding/base64"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

const clipboardHelperPackage = "com.adbtool.clipboard"

func validateClipboardApk(apkBytes []byte) error {
	if len(apkBytes) < 1024 {
		return fmt.Errorf("clipboard helper apk missing or too small")
	}
	reader, err := zip.NewReader(bytes.NewReader(apkBytes), int64(len(apkBytes)))
	if err != nil {
		return fmt.Errorf("clipboard helper apk is not a valid apk archive")
	}
	for _, file := range reader.File {
		if file.Name == "AndroidManifest.xml" || strings.HasSuffix(file.Name, ".dex") {
			return nil
		}
	}
	return fmt.Errorf("clipboard helper apk missing manifest or dex files")
}

func (m *AdbManager) IsClipboardHelperInstalled(serial string) bool {
	out, err := m.run("-s", serial, "shell", "pm", "list", "packages", clipboardHelperPackage)
	if err != nil {
		return false
	}
	return strings.Contains(out, clipboardHelperPackage)
}

func (m *AdbManager) InstallClipboardHelper(serial string, apkBytes []byte) error {
	if err := validateClipboardApk(apkBytes); err != nil {
		return err
	}
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
	_, err := m.run("-s", serial, "shell", "am", "start", "-n", clipboardHelperPackage+"/.SetClipboardActivity", "--es", "text", encoded)
	return err
}

func (m *AdbManager) UninstallClipboardHelper(serial string) error {
	_, err := m.run("-s", serial, "uninstall", clipboardHelperPackage)
	return err
}
