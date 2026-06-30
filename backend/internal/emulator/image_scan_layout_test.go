package emulator

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// writeBogusSDKLayout builds an SDK-root-shaped tree that previously caused
// the scanner to register every 3-level-deep subdir as a system image:
//
//	<root>/
//	  build-tools/34.0.0/lib/                 (no system.img)
//	  build-tools/34.0.0/lib64/               (no system.img)
//	  cmake/3.22.1/bin/                       (no system.img)
//	  platforms/android-34/                   (decoy; not an image)
//	  system-images/android-34/default/x86_64/system.img
//	  system-images/android-33/google_apis_playstore/arm64-v8a/system.img
func writeBogusSDKLayout(t *testing.T, root string) {
	t.Helper()
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

	// Build-tools subdirs — no system.img inside any.
	mustMkdir(filepath.Join(root, "build-tools", "34.0.0", "lib"))
	mustMkdir(filepath.Join(root, "build-tools", "34.0.0", "lib64"))
	mustMkdir(filepath.Join(root, "build-tools", "34.0.0", "lld-bin"))

	// CMake — same decoy.
	mustMkdir(filepath.Join(root, "cmake", "3.22.1", "bin"))

	// Platforms — looks like an apiLevel dir but isn't.
	mustMkdir(filepath.Join(root, "platforms", "android-34"))

	// Real images — both should survive the layout guard.
	mustWrite(filepath.Join(root, "system-images", "android-34", "default", "x86_64", "system.img"), "system")
	mustMkdir(filepath.Join(root, "system-images", "android-34", "default", "x86_64"))
	mustWrite(filepath.Join(root, "system-images", "android-33", "google_apis_playstore", "arm64-v8a", "system.img"), "system")
	mustMkdir(filepath.Join(root, "system-images", "android-33", "google_apis_playstore", "arm64-v8a"))
}

// TestScanSystemImagesDirRejectsNonAndroidSDKLayout ensures bogus SDK-tool
// directories (build-tools/, cmake/, platforms/) under the scan root don't
// leak into the image list. Regression for the "scanned the whole SDK root
// and got 50 phantom images" bug.
func TestScanSystemImagesDirRejectsNonAndroidSDKLayout(t *testing.T) {
	root := t.TempDir()
	writeBogusSDKLayout(t, root)

	im := NewImageManager("")
	scanned := im.scanSystemImagesDir(filepath.Join(root, "system-images"))

	if len(scanned) != 2 {
		t.Fatalf("expected exactly 2 real images, got %d: %#v", len(scanned), scanned)
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
	for _, bad := range []string{"build-tools-34.0.0-lib", "build-tools-34.0.0-lib64", "cmake-3.22.1-bin"} {
		if gotIDs[bad] {
			t.Errorf("scan should NOT have found bogus entry %q", bad)
		}
	}
}

// TestScanSystemImagesDirRootIsSDKSkipsNonImageChildren covers the original
// bug surface: pointing the scanner at an SDK root instead of a system-images
// dir. The scanner must not pick up build-tools/cmake/platforms entries as
// "apiLevelDir" candidates — only directories matching `android-<level>`.
func TestScanSystemImagesDirRootIsSDKSkipsNonImageChildren(t *testing.T) {
	root := t.TempDir()
	writeBogusSDKLayout(t, root)

	im := NewImageManager("")
	// Point at the SDK root (NOT the system-images subfolder) — same as
	// the user did in the bug report.
	scanned := im.scanSystemImagesDir(root)

	if len(scanned) != 0 {
		ids := make([]string, 0, len(scanned))
		for _, s := range scanned {
			ids = append(ids, s.ID)
		}
		t.Fatalf("scanning the SDK root must return zero images, got %d: %v", len(scanned), ids)
	}
}

// TestScanAndRegisterSkipsBogusTopLevel covers the integrate path:
// ScanAndRegister on an SDK root must end up with a clean (empty) registry
// — no bogus entries, no valid=false leftovers. The bogus entries from
// earlier scan rounds (manifested before this fix landed) should also be
// pruned on the next ScanAndRegister call.
func TestScanAndRegisterSkipsBogusTopLevel(t *testing.T) {
	tmp := t.TempDir()
	t.Setenv("HOME", tmp)

	root := t.TempDir()
	writeBogusSDKLayout(t, root)

	// Seed the registry with a stale bogus entry that pre-existed the fix.
	if err := saveRegisteredImagesLocked([]RegisteredImage{
		{ID: "build-tools-34.0.0-lib", Path: filepath.Join(root, "build-tools", "34.0.0", "lib"), Valid: false},
		{ID: "cmake-3.22.1-bin", Path: filepath.Join(root, "cmake", "3.22.1", "bin"), Valid: false},
	}); err != nil {
		t.Fatal(err)
	}

	im := NewImageManager("")
	if _, err := im.ScanAndRegister(root); err != nil {
		t.Fatal(err)
	}

	reg := LoadRegisteredImages()
	// After the scan, we expect: 0 bogus entries, 0 real entries
	// (we scanned the SDK root, not its system-images subfolder).
	for _, e := range reg {
		if !e.Valid {
			t.Errorf("registry still has invalid entry id=%s path=%s", e.ID, e.Path)
		}
		if strings.HasPrefix(e.ID, "build-tools-") || strings.HasPrefix(e.ID, "cmake-") || strings.HasPrefix(e.ID, "platforms-") {
			t.Errorf("registry kept bogus id=%s", e.ID)
		}
	}
}
