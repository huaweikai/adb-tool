package server

import (
	"os"
	"path/filepath"
	"testing"
)

func TestValidateClipboardApkAcceptsEmbeddedHelperArchive(t *testing.T) {
	apkPath := filepath.Join("..", "..", "clipboard-helper.apk")
	apkBytes, err := os.ReadFile(apkPath)
	if err != nil {
		t.Fatalf("read clipboard helper apk: %v", err)
	}
	if err := validateClipboardApk(apkBytes); err != nil {
		t.Fatalf("expected bundled clipboard helper apk to validate: %v", err)
	}
}

func TestValidateClipboardApkRejectsNonZip(t *testing.T) {
	if err := validateClipboardApk([]byte("not an apk archive")); err == nil {
		t.Fatal("expected non-zip apk validation to fail")
	}
}
