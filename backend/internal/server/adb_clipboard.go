package server

import (
	"archive/zip"
	"bytes"
	"encoding/base64"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strconv"
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

func (m *AdbManager) getInstalledHelperVersion(serial string) int {
	out, err := m.run("-s", serial, "shell", "pm", "list", "packages", "--show-versioncode", clipboardHelperPackage)
	if err != nil {
		log.Printf("[helper] version check failed: serial=%s err=%v", serial, err)
		return 0
	}
	for _, line := range strings.Split(out, "\n") {
		line = strings.TrimSpace(line)
		if strings.Contains(line, clipboardHelperPackage) {
			for _, token := range strings.Fields(line) {
				if strings.HasPrefix(token, "versionCode:") {
					verStr := strings.TrimPrefix(token, "versionCode:")
					if ver, err := strconv.Atoi(verStr); err == nil {
						log.Printf("[helper] version found: serial=%s version=%d", serial, ver)
						return ver
					}
				}
			}
		}
	}
	log.Printf("[helper] version not found in output: serial=%s out=%q", serial, strings.TrimSpace(out))
	return 0
}

func (m *AdbManager) ensureHelperInstalled(serial string, apkBytes []byte) error {
	// Always try to install. ADB's -r (replace) + -d (allow downgrade)
	// handles version comparison natively and is fast when versions match.
	if err := validateClipboardApk(apkBytes); err != nil {
		return err
	}
	tmpFile := filepath.Join(os.TempDir(), "clipboard-helper.apk")
	if err := os.WriteFile(tmpFile, apkBytes, 0644); err != nil {
		return fmt.Errorf("write temp apk: %w", err)
	}
	defer os.Remove(tmpFile)
	_, err := m.run("-s", serial, "install", "-r", "-d", tmpFile)
	if err != nil {
		log.Printf("[helper] install failed: serial=%s err=%v", serial, err)
		return err
	}
	log.Printf("[helper] install success: serial=%s", serial)
	return nil
}

func (m *AdbManager) IsClipboardHelperInstalled(serial string) bool {
	return m.getInstalledHelperVersion(serial) > 0
}

func (m *AdbManager) InstallClipboardHelper(serial string, apkBytes []byte) error {
	return m.ensureHelperInstalled(serial, apkBytes)
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
