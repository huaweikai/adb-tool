package emulator

import (
	"os"
	"path/filepath"
	"testing"
)

// TestScanSystemImagesDirRecursiveNonStandardLayout tests recursive scanning
// of non-standard directory structures that don't follow the android-XX/variant/arch pattern.
func TestScanSystemImagesDirRecursiveNonStandardLayout(t *testing.T) {
	root := t.TempDir()

	// Create a non-standard directory structure:
	// root/
	//   some-folder/
	//     android-34/
	//       google_apis/
	//         arm64-v8a/
	//           system.img
	//     another-folder/
	//       android-33/
	//         default/
	//           x86_64/
	//             system.img
	mustMkdir := func(p string) {
		t.Helper()
		if err := os.MkdirAll(p, 0755); err != nil {
			t.Fatal(err)
		}
	}
	mustWrite := func(p, content string) {
		t.Helper()
		mustMkdir(filepath.Dir(p))
		if err := os.WriteFile(p, []byte(content), 0644); err != nil {
			t.Fatal(err)
		}
	}

	// Non-standard structure
	mustWrite(filepath.Join(root, "some-folder", "android-34", "google_apis", "arm64-v8a", "system.img"), "system")
	mustWrite(filepath.Join(root, "another-folder", "android-33", "default", "x86_64", "system.img"), "system")

	im := NewImageManager("")
	scanned := im.scanSystemImagesDirRecursive(root)

	if len(scanned) != 2 {
		t.Fatalf("expected exactly 2 images, got %d: %#v", len(scanned), scanned)
	}

	gotIDs := map[string]bool{}
	for _, s := range scanned {
		gotIDs[s.ID] = true
	}
	for _, want := range []string{"android-34-google_apis-arm64-v8a", "android-33-default-x86_64"} {
		if !gotIDs[want] {
			t.Errorf("expected scan to find %q; got %v", want, gotIDs)
		}
	}
}

// TestScanSystemImagesDirRecursiveMacOSLayout tests scanning of macOS-style
// directory structures where system images might be in unexpected locations.
func TestScanSystemImagesDirRecursiveMacOSLayout(t *testing.T) {
	root := t.TempDir()

	// Create a macOS-style directory structure:
	// root/
	//   Library/
	//     Android/
	//       sdk/
	//         system-images/
	//           android-34/
	//             google_apis/
	//               arm64-v8a/
	//                 system.img
	//   .android/
	//     avd/
	//       test.avd/
	//         system.img
	mustMkdir := func(p string) {
		t.Helper()
		if err := os.MkdirAll(p, 0755); err != nil {
			t.Fatal(err)
		}
	}
	mustWrite := func(p, content string) {
		t.Helper()
		mustMkdir(filepath.Dir(p))
		if err := os.WriteFile(p, []byte(content), 0644); err != nil {
			t.Fatal(err)
		}
	}

	// Standard SDK structure
	mustWrite(filepath.Join(root, "Library", "Android", "sdk", "system-images", "android-34", "google_apis", "arm64-v8a", "system.img"), "system")

	// AVD structure (not a valid system image, should be ignored)
	mustWrite(filepath.Join(root, ".android", "avd", "test.avd", "system.img"), "system")

	im := NewImageManager("")
	scanned := im.scanSystemImagesDirRecursive(root)

	if len(scanned) != 1 {
		t.Fatalf("expected exactly 1 image, got %d: %#v", len(scanned), scanned)
	}

	if scanned[0].ID != "android-34-google_apis-arm64-v8a" {
		t.Errorf("expected image ID android-34-google_apis-arm64-v8a, got %s", scanned[0].ID)
	}
}

// TestScanSystemImagesDirRecursiveEmptyDirectory tests scanning of an empty directory.
func TestScanSystemImagesDirRecursiveEmptyDirectory(t *testing.T) {
	root := t.TempDir()

	im := NewImageManager("")
	scanned := im.scanSystemImagesDirRecursive(root)

	if len(scanned) != 0 {
		t.Fatalf("expected 0 images, got %d: %#v", len(scanned), scanned)
	}
}

// TestScanSystemImagesDirRecursiveNestedEmptyDirectories tests scanning of
// nested empty directories that don't contain any images.
func TestScanSystemImagesDirRecursiveNestedEmptyDirectories(t *testing.T) {
	root := t.TempDir()

	// Create nested empty directories
	if err := os.MkdirAll(filepath.Join(root, "a", "b", "c", "d"), 0755); err != nil {
		t.Fatal(err)
	}

	im := NewImageManager("")
	scanned := im.scanSystemImagesDirRecursive(root)

	if len(scanned) != 0 {
		t.Fatalf("expected 0 images, got %d: %#v", len(scanned), scanned)
	}
}

// TestScanSystemImagesDirRecursiveMultipleImagesInSameDirectory tests scanning
// of a directory that contains multiple system images at different levels.
func TestScanSystemImagesDirRecursiveMultipleImagesInSameDirectory(t *testing.T) {
	root := t.TempDir()

	mustMkdir := func(p string) {
		t.Helper()
		if err := os.MkdirAll(p, 0755); err != nil {
			t.Fatal(err)
		}
	}
	mustWrite := func(p, content string) {
		t.Helper()
		mustMkdir(filepath.Dir(p))
		if err := os.WriteFile(p, []byte(content), 0644); err != nil {
			t.Fatal(err)
		}
	}

	// Multiple images at different levels
	mustWrite(filepath.Join(root, "android-34", "default", "x86_64", "system.img"), "system")
	mustWrite(filepath.Join(root, "android-34", "google_apis", "arm64-v8a", "system.img"), "system")
	mustWrite(filepath.Join(root, "android-33", "default", "x86", "system.img"), "system")

	im := NewImageManager("")
	scanned := im.scanSystemImagesDirRecursive(root)

	if len(scanned) != 3 {
		t.Fatalf("expected exactly 3 images, got %d: %#v", len(scanned), scanned)
	}

	gotIDs := map[string]bool{}
	for _, s := range scanned {
		gotIDs[s.ID] = true
	}
	for _, want := range []string{
		"android-34-default-x86_64",
		"android-34-google_apis-arm64-v8a",
		"android-33-default-x86",
	} {
		if !gotIDs[want] {
			t.Errorf("expected scan to find %q; got %v", want, gotIDs)
		}
	}
}

// TestScanSDKRootDoesNotPickUpNonImageFiles tests that scanning an SDK root
// directory correctly finds system-images without picking up unrelated SDK
// files (build-tools, platforms, cmake, etc.).
func TestScanSDKRootDoesNotPickUpNonImageFiles(t *testing.T) {
	root := t.TempDir()

	mustMkdir := func(p string) {
		t.Helper()
		if err := os.MkdirAll(p, 0755); err != nil {
			t.Fatal(err)
		}
	}
	mustWrite := func(p, content string) {
		t.Helper()
		mustMkdir(filepath.Dir(p))
		if err := os.WriteFile(p, []byte(content), 0644); err != nil {
			t.Fatal(err)
		}
	}

	// SDK root structure
	// build-tools
	mustWrite(filepath.Join(root, "build-tools", "34.0.0", "aapt"), "binary")
	mustWrite(filepath.Join(root, "build-tools", "34.0.0", "dx.jar"), "jar")

	// platforms
	mustWrite(filepath.Join(root, "platforms", "android-34", "android.jar"), "jar")

	// cmake
	mustWrite(filepath.Join(root, "cmake", "3.22.1", "bin", "cmake"), "binary")

	// platform-tools
	mustWrite(filepath.Join(root, "platform-tools", "adb"), "binary")

	// Real system images
	mustWrite(filepath.Join(root, "system-images", "android-34", "default", "x86_64", "system.img"), "system")
	mustWrite(filepath.Join(root, "system-images", "android-33", "google_apis_playstore", "arm64-v8a", "system.img"), "system")

	// emulator
	mustWrite(filepath.Join(root, "emulator", "emulator"), "binary")

	im := NewImageManager("")
	scanned := im.scanImagesFromDir(root)

	if len(scanned) != 2 {
		t.Fatalf("expected exactly 2 images, got %d: %#v", len(scanned), scanned)
	}

	gotIDs := map[string]bool{}
	for _, s := range scanned {
		gotIDs[s.ID] = true
	}
	for _, want := range []string{"android-34-default-x86_64", "android-33-google_apis_playstore-arm64-v8a"} {
		if !gotIDs[want] {
			t.Errorf("expected scan to find %q; got %v", want, gotIDs)
		}
	}

	// Ensure no bogus entries
	for _, bad := range []string{
		"build-tools-34.0.0-aapt",
		"platforms-android-34-android.jar",
		"cmake-3.22.1-bin-cmake",
		"platform-tools-adb",
		"emulator-emulator",
	} {
		if gotIDs[bad] {
			t.Errorf("scan should NOT have found bogus entry %q", bad)
		}
	}
}

// TestScanAdbToolDirectory tests that scanning a .adb-tool directory correctly
// finds system-images under emulator/system-images.
func TestScanAdbToolDirectory(t *testing.T) {
	root := t.TempDir()

	mustMkdir := func(p string) {
		t.Helper()
		if err := os.MkdirAll(p, 0755); err != nil {
			t.Fatal(err)
		}
	}
	mustWrite := func(p, content string) {
		t.Helper()
		mustMkdir(filepath.Dir(p))
		if err := os.WriteFile(p, []byte(content), 0644); err != nil {
			t.Fatal(err)
		}
	}

	// .adb-tool directory structure
	adbToolDir := filepath.Join(root, ".adb-tool")

	// emulator/system-images
	mustWrite(filepath.Join(adbToolDir, "emulator", "system-images", "android-34", "default", "x86_64", "system.img"), "system")
	mustWrite(filepath.Join(adbToolDir, "emulator", "system-images", "android-33", "google_apis", "arm64-v8a", "system.img"), "system")

	// Other files that should not be scanned
	mustWrite(filepath.Join(adbToolDir, "emulator", "java-runtime", "jdk-21", "bin", "java"), "binary")
	mustWrite(filepath.Join(adbToolDir, "sdk", "cmdline-tools", "latest", "bin", "sdkmanager"), "binary")

	im := NewImageManager("")
	scanned := im.scanImagesFromDir(adbToolDir)

	if len(scanned) != 2 {
		t.Fatalf("expected exactly 2 images, got %d: %#v", len(scanned), scanned)
	}

	gotIDs := map[string]bool{}
	for _, s := range scanned {
		gotIDs[s.ID] = true
	}
	for _, want := range []string{"android-34-default-x86_64", "android-33-google_apis-arm64-v8a"} {
		if !gotIDs[want] {
			t.Errorf("expected scan to find %q; got %v", want, gotIDs)
		}
	}
}
