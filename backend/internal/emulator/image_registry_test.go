package emulator

import (
	"encoding/json"
	"errors"
	"os"
	"path"
	"path/filepath"
	"runtime"
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

// Regression: images installed under ~/.adb-tool/sdk/system-images
// (the managed Android SDK layout that ImageManager.ScanAndRegisterStorage
// also picks up) must be treated as managed, not external. Previously
// isManagedImagePath only recognised ~/.adb-tool/emulator/system-images,
// so deleting such an image only dropped the registry row while leaving
// ~1GB of system.img on disk.
func TestDeleteRegisteredImageRemovesManagedSDKDirectory(t *testing.T) {
	withTempHome(t, func(home string) {
		managedPath := filepath.Join(home, ".adb-tool", "sdk", "system-images", "android-30", "default", "x86_64")
		writeTestImageDir(t, managedPath)
		writeImageRegistry(t, []RegisteredImage{{
			ID:   "managed-sdk",
			Name: "Managed SDK Image",
			Path: managedPath,
		}})

		removed, err := DeleteRegisteredImage("managed-sdk", nil)
		if err != nil {
			t.Fatalf("DeleteRegisteredImage returned error: %v", err)
		}
		if removed.DeleteMode != ImageDeleteModeFilesRemoved {
			t.Fatalf("DeleteMode = %q, want %q", removed.DeleteMode, ImageDeleteModeFilesRemoved)
		}
		if _, err := os.Stat(managedPath); !os.IsNotExist(err) {
			t.Fatalf("managed SDK image directory still exists or stat failed unexpectedly: %v", err)
		}
		if got := LoadRegisteredImages(); len(got) != 0 {
			t.Fatalf("registry has %d image(s), want 0", len(got))
		}
	})
}

// Cross-platform check that isManagedImagePath handles typical macOS paths.
// Skipped on Windows: filepath.Join inside production code produces a
// Windows-style root (C:\Users\001\...), but the test inputs are Unix-style
// (/Users/001/...) so filepath.Rel fails to relate them across separator
// styles. On macOS / Linux runners, both sides are Unix-style and the test
// exercises the real production code path.
func TestIsManagedImagePath_MacOSPaths(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("filepath.Rel cannot cross Unix and Windows path separators; run on macOS/Linux")
	}
	withTempHome(t, func(home string) {
		macHome := "/Users/" + filepath.Base(home)
		cases := []struct {
			path string
			want bool
			why  string
		}{
			{path.Join(macHome, ".adb-tool", "emulator", "system-images", "android-35", "default", "x86_64"), true, "default storage"},
			{path.Join(macHome, ".adb-tool", "sdk", "system-images", "android-30", "default", "x86_64"), true, "managed SDK"},
			{path.Join(macHome, "Library", "Android", "sdk", "system-images", "android-33", "google_apis", "x86_64"), false, "Android Studio default - external"},
			{"/Volumes/external/sdk/system-images/android-30/default/x86", false, "external drive"},
		}
		for _, tc := range cases {
			got := isManagedImagePath(tc.path)
			if got != tc.want {
				t.Errorf("isManagedImagePath(%q) = %v, want %v (%s)", tc.path, got, tc.want, tc.why)
			}
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