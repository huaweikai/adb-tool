package emulator

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"testing"
)

func TestDeleteRegisteredImageRemovesManagedDirectory(t *testing.T) {
	withTempHome(t, func(home string) {
		managedPath := filepath.Join(home, ".adb-tool", "emulator", "system-images", "android-35", "default", "x86_64")
		writeTestImageDir(t, managedPath)
		writeImageRegistry(t, []RegisteredImage{{
			ID:   "managed",
			Name: "Managed Image",
			Path: managedPath,
		}})

		removed, err := DeleteRegisteredImage("managed", nil)
		if err != nil {
			t.Fatalf("DeleteRegisteredImage returned error: %v", err)
		}
		if removed.DeleteMode != ImageDeleteModeFilesRemoved {
			t.Fatalf("DeleteMode = %q, want %q", removed.DeleteMode, ImageDeleteModeFilesRemoved)
		}
		if _, err := os.Stat(managedPath); !os.IsNotExist(err) {
			t.Fatalf("managed image directory still exists or stat failed unexpectedly: %v", err)
		}
		if got := LoadRegisteredImages(); len(got) != 0 {
			t.Fatalf("registry has %d image(s), want 0", len(got))
		}
	})
}

func TestDeleteRegisteredImageOnlyUnregistersExternalDirectory(t *testing.T) {
	withTempHome(t, func(home string) {
		externalPath := filepath.Join(t.TempDir(), "external-image")
		writeTestImageDir(t, externalPath)
		writeImageRegistry(t, []RegisteredImage{{
			ID:   "external",
			Name: "External Image",
			Path: externalPath,
		}})

		removed, err := DeleteRegisteredImage("external", nil)
		if err != nil {
			t.Fatalf("DeleteRegisteredImage returned error: %v", err)
		}
		if removed.DeleteMode != ImageDeleteModeRegistryOnly {
			t.Fatalf("DeleteMode = %q, want %q", removed.DeleteMode, ImageDeleteModeRegistryOnly)
		}
		if _, err := os.Stat(filepath.Join(externalPath, "system.img")); err != nil {
			t.Fatalf("external image files should remain: %v", err)
		}
		if got := LoadRegisteredImages(); len(got) != 0 {
			t.Fatalf("registry has %d image(s), want 0", len(got))
		}
	})
}

func TestDeleteRegisteredImageReturnsErrorForUnknownID(t *testing.T) {
	withTempHome(t, func(home string) {
		writeImageRegistry(t, []RegisteredImage{{
			ID:   "exists",
			Name: "Existing",
			Path: filepath.Join(home, "existing"),
		}})

		_, err := DeleteRegisteredImage("does-not-exist", nil)
		if err == nil {
			t.Fatal("expected error for unknown id, got nil")
		}
		if got := LoadRegisteredImages(); len(got) != 1 {
			t.Fatalf("registry has %d image(s), want 1 (delete must not touch other entries)", len(got))
		}
	})
}

func TestDeleteRegisteredImageBlockedByInUseCheck(t *testing.T) {
	withTempHome(t, func(home string) {
		managedPath := filepath.Join(home, ".adb-tool", "emulator", "system-images", "android-35", "default", "x86_64")
		writeTestImageDir(t, managedPath)
		writeImageRegistry(t, []RegisteredImage{{
			ID:   "in-use",
			Name: "In Use Image",
			Path: managedPath,
		}})

		check := func(imageID string) []string {
			if imageID == "in-use" {
				return []string{"aaa", "bbb"}
			}
			return nil
		}

		_, err := DeleteRegisteredImage("in-use", check)
		if err == nil {
			t.Fatal("expected error when in-use check reports users, got nil")
		}
		var inUseErr *ImageInUseError
		if !errors.As(err, &inUseErr) {
			t.Fatalf("expected *ImageInUseError, got %T: %v", err, err)
		}
		if len(inUseErr.UsedBy) != 2 || inUseErr.UsedBy[0] != "aaa" || inUseErr.UsedBy[1] != "bbb" {
			t.Fatalf("UsedBy = %v, want [aaa bbb]", inUseErr.UsedBy)
		}
		// Files and registry entry must remain untouched.
		if _, err := os.Stat(managedPath); err != nil {
			t.Fatalf("managed image directory should still exist: %v", err)
		}
		if got := LoadRegisteredImages(); len(got) != 1 {
			t.Fatalf("registry has %d image(s), want 1 (delete must not run when blocked)", len(got))
		}
	})
}

func TestDeleteRegisteredImageProceedsWhenInUseCheckReturnsEmpty(t *testing.T) {
	withTempHome(t, func(home string) {
		managedPath := filepath.Join(home, ".adb-tool", "emulator", "system-images", "android-30", "default", "x86_64")
		writeTestImageDir(t, managedPath)
		writeImageRegistry(t, []RegisteredImage{{
			ID:   "unused",
			Name: "Unused Image",
			Path: managedPath,
		}})

		check := func(imageID string) []string {
			// Caller claims "no instance uses this" — we should still delete.
			return nil
		}

		removed, err := DeleteRegisteredImage("unused", check)
		if err != nil {
			t.Fatalf("DeleteRegisteredImage returned error: %v", err)
		}
		if removed.DeleteMode != ImageDeleteModeFilesRemoved {
			t.Fatalf("DeleteMode = %q, want %q", removed.DeleteMode, ImageDeleteModeFilesRemoved)
		}
		if got := LoadRegisteredImages(); len(got) != 0 {
			t.Fatalf("registry has %d image(s), want 0", len(got))
		}
	})
}

func withTempHome(t *testing.T, fn func(home string)) {
	t.Helper()
	home := t.TempDir()
	oldHome := os.Getenv("HOME")
	oldUserProfile := os.Getenv("USERPROFILE")
	if err := os.Setenv("HOME", home); err != nil {
		t.Fatal(err)
	}
	if err := os.Setenv("USERPROFILE", home); err != nil {
		t.Fatal(err)
	}
	defer func() {
		_ = os.Setenv("HOME", oldHome)
		_ = os.Setenv("USERPROFILE", oldUserProfile)
	}()
	fn(home)
}

func writeTestImageDir(t *testing.T, dir string) {
	t.Helper()
	if err := os.MkdirAll(dir, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "system.img"), []byte("system"), 0644); err != nil {
		t.Fatal(err)
	}
}

func writeImageRegistry(t *testing.T, images []RegisteredImage) {
	t.Helper()
	path := imageRegistryPath()
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		t.Fatal(err)
	}
	data, err := json.MarshalIndent(images, "", "  ")
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, data, 0644); err != nil {
		t.Fatal(err)
	}
}