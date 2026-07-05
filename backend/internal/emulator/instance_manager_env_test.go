package emulator

import (
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

// TestBuildEmulatorEnvOverwritesStaleParent ensures that buildEmulatorEnv
// strips any pre-existing entries for the keys it sets (ANDROID_SDK_ROOT,
// ANDROID_AVD_HOME, JAVA_HOME) and re-appends our values at the end.
// This is the Mac/Fix for the silent-crash seen when the parent process
// (Flutter desktop app launched as a .app bundle) had a stale
// ANDROID_AVD_HOME in its env that overrode ours.
func TestBuildEmulatorEnvOverwritesStaleParent(t *testing.T) {
	// Simulate a parent env that has stale entries pointing somewhere
	// else. We want our values to win.
	parent := []string{
		"PATH=/usr/bin:/bin",
		"ANDROID_AVD_HOME=/Users/foo/.android/avd",
		"HOME=/Users/foo",
		"ANDROID_SDK_ROOT=/old/sdk/root",
		"JAVA_HOME=/old/java/bin",
	}

	got := buildEmulatorEnv(parent, "/new/sdk", "/new/data", "/new/jdk/bin/java")

	// Extract the effective values via suffix matching.
	gotValue := func(key string) string {
		for _, e := range got {
			if strings.HasPrefix(e, key+"=") {
				return strings.TrimPrefix(e, key+"=")
			}
		}
		return ""
	}

	if v := gotValue("ANDROID_AVD_HOME"); v != "/new/data/avd" {
		t.Errorf("ANDROID_AVD_HOME = %q, want /new/data/avd", v)
	}
	if v := gotValue("ANDROID_SDK_ROOT"); v != "/new/sdk" {
		t.Errorf("ANDROID_SDK_ROOT = %q, want /new/sdk", v)
	}
	if v := gotValue("JAVA_HOME"); v != "/new/jdk" {
		t.Errorf("JAVA_HOME = %q, want /new/jdk (parent of bin)", v)
	}
	if v := gotValue("PATH"); v != "/usr/bin:/bin" {
		t.Errorf("PATH = %q, want /usr/bin:/bin (unchanged)", v)
	}
	if v := gotValue("HOME"); v != "/Users/foo" {
		t.Errorf("HOME = %q, want /Users/foo (unchanged)", v)
	}
}

// TestBuildEmulatorEnvJavaHomeIsJdkRoot verifies the JAVA_HOME we set
// points at the JDK root (one level above bin/), not at bin/ itself.
// emulator 36.x on macOS prefers JAVA_HOME to be the JDK home; setting
// it to bin/ has historically caused tools.jar / JRE selection issues.
func TestBuildEmulatorEnvJavaHomeIsJdkRoot(t *testing.T) {
	// Adoptium / Zulu / Oracle layout: <JDK>/bin/java
	javaBin := "/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home/bin/java"
	got := buildEmulatorEnv(nil, "/sdk", "/data", javaBin)

	gotValue := ""
	for _, e := range got {
		if strings.HasPrefix(e, "JAVA_HOME=") {
			gotValue = strings.TrimPrefix(e, "JAVA_HOME=")
			break
		}
	}
	want := "/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home"
	if gotValue != want {
		t.Errorf("JAVA_HOME = %q, want %q", gotValue, want)
	}
}

// TestBuildEmulatorEnvOmitsJavaWhenEmpty verifies JAVA_HOME isn't set
// when no Java path was configured. Setting JAVA_HOME="" would break
// any launcher that uses it to find tools.jar.
func TestBuildEmulatorEnvOmitsJavaWhenEmpty(t *testing.T) {
	got := buildEmulatorEnv(nil, "/sdk", "/data", "")
	for _, e := range got {
		if strings.HasPrefix(e, "JAVA_HOME=") {
			t.Errorf("JAVA_HOME should be omitted when javaBin is empty, got %q", e)
		}
	}
}

// TestBuildEmulatorEnvOmitsEmptyAndroidSdkRoot is the macOS-fix
// regression: setting ANDROID_SDK_ROOT to "" is NOT the same as
// leaving it unset. emulator 36.x on macOS treats the empty-string
// form as "explicitly invalid" and refuses to fall back to ANDROID_HOME.
// We must therefore drop the override entirely if the SDK path
// is empty (which happens on cold start before DetectEmulatorEngine
// has populated the field).
func TestBuildEmulatorEnvOmitsEmptyAndroidSdkRoot(t *testing.T) {
	got := buildEmulatorEnv(nil, "", "/data", "")
	for _, e := range got {
		if strings.HasPrefix(e, "ANDROID_SDK_ROOT=") {
			t.Errorf("ANDROID_SDK_ROOT must NOT be set when androidSdk is empty (would force empty string into child env). got %q", e)
		}
	}
}

// TestBuildEmulatorEnvStripsStaleEmpty confirms a stale empty-string
// ANDROID_SDK_ROOT from the parent env (e.g. macOS GUI launch
// context, or a parent's accidentally-set value) is also stripped
// rather than propagated, so the child sees the key as unset and
// can fall back to ANDROID_HOME.
func TestBuildEmulatorEnvStripsStaleEmpty(t *testing.T) {
	parent := []string{"ANDROID_SDK_ROOT="} // empty, from parent
	got := buildEmulatorEnv(parent, "", "/data", "")
	for _, e := range got {
		if strings.HasPrefix(e, "ANDROID_SDK_ROOT=") {
			t.Errorf("ANDROID_SDK_ROOT (empty) should not appear in child env, got %q", e)
		}
	}
}

// TestBuildEmulatorEnvPreservesParentKeys confirms keys we don't
// override pass through unchanged (PATH, HOME, custom user vars).
// Cross-platform: on darwin we also set DYLD_LIBRARY_PATH, which is
// expected to land at the end and shouldn't show up in the
// preserved-keys slice.
func TestBuildEmulatorEnvPreservesParentKeys(t *testing.T) {
	parent := []string{
		"PATH=/usr/bin",
		"HOME=/Users/foo",
		"LANG=en_US.UTF-8",
		"ADB_TOOL_DEBUG=1",
	}
	got := buildEmulatorEnv(parent, "/sdk", "/data", "")

	overrides := map[string]bool{
		"ANDROID_SDK_ROOT":  true,
		"ANDROID_AVD_HOME":  true,
		"ANDROID_HOME":      true, // always stripped — see TestBuildEmulatorEnvStripsAndroidHome
		"JAVA_HOME":         true,
		"DYLD_LIBRARY_PATH": true,
	}
	var remainder []string
	for _, e := range got {
		eq := strings.IndexByte(e, '=')
		if eq > 0 && overrides[e[:eq]] {
			continue
		}
		remainder = append(remainder, e)
	}
	if !reflect.DeepEqual(remainder, parent) {
		t.Errorf("non-overridden keys leaked or changed: got %v, want %v", remainder, parent)
	}
}

// TestBuildEmulatorEnvAppendsAtEnd is a sanity check that our
// overrides are at the very end of the slice. The Android emulator
// reads ANDROID_AVD_HOME via getenv which returns the first match in
// the raw envp; putting ours last would be a bug only if the kernel
// returned the last match instead — but we want to be defensive.
func TestBuildEmulatorEnvAppendsAtEnd(t *testing.T) {
	parent := []string{"PATH=/usr/bin"}
	got := buildEmulatorEnv(parent, "/sdk", "/data", "/jdk/bin/java")
	// Expect PATH + at least 3 overrides (ANDROID_SDK_ROOT,
	// ANDROID_AVD_HOME, JAVA_HOME). On darwin there's also
	// DYLD_LIBRARY_PATH for a 4th override.
	if len(got) < 4 {
		t.Fatalf("expected >= 4 entries, got %d: %v", len(got), got)
	}
	last := got[len(got)-1]
	overrides := []string{
		"JAVA_HOME=",
		"DYLD_LIBRARY_PATH=",
		"ANDROID_SDK_ROOT=",
		"ANDROID_AVD_HOME=",
	}
	isOverride := false
	for _, prefix := range overrides {
		if strings.HasPrefix(last, prefix) {
			isOverride = true
			break
		}
	}
	if !isOverride {
		t.Errorf("last entry should be one of our overrides, got %q", last)
	}
	// The trailing N entries should all be overrides (in any order).
	for i := len(got) - 4; i < len(got); i++ {
		e := got[i]
		ok := false
		for _, prefix := range overrides {
			if strings.HasPrefix(e, prefix) {
				ok = true
				break
			}
		}
		if !ok {
			t.Errorf("entry %d should be one of our overrides, got %q", i, e)
		}
	}
}

// Ensure filepath.Join on the data dir produces the expected layout.
func TestBuildEmulatorEnvAVDHomeLayout(t *testing.T) {
	dataDir := filepath.Join("/root", ".adb-tool", "emulator")
	got := buildEmulatorEnv(nil, "/sdk", dataDir, "")
	for _, e := range got {
		if strings.HasPrefix(e, "ANDROID_AVD_HOME=") {
			want := "ANDROID_AVD_HOME=" + filepath.Join(dataDir, "avd")
			if e != want {
				t.Errorf("got %q, want %q", e, want)
			}
			return
		}
	}
	t.Fatal("ANDROID_AVD_HOME not set")
}

// TestBuildEmulatorEnvOmitsEmptyAvdHome is the symmetric case to
// TestBuildEmulatorEnvOmitsEmptyAndroidSdkRoot: setting ANDROID_AVD_HOME=""
// would also force an empty value. dataDir="" means we don't know
// where the user's AVDs live, so we let the emulator fall back to
// its defaults rather than poisoning its env with empty strings.
func TestBuildEmulatorEnvOmitsEmptyAvdHome(t *testing.T) {
	got := buildEmulatorEnv(nil, "/sdk", "", "")
	for _, e := range got {
		if strings.HasPrefix(e, "ANDROID_AVD_HOME=") {
			t.Errorf("ANDROID_AVD_HOME must NOT be set when dataDir is empty, got %q", e)
		}
	}
}

// TestBuildEmulatorEnvStripsAndroidHome is the Mac-fix regression
// for the FATAL "Broken AVD system path" error. Android Studio on
// macOS exports ANDROID_HOME pointing at its own SDK (often on an
// external volume that may not be readable from our Go backend's
// sandboxed process). The emulator launcher checks ANDROID_HOME
// BEFORE ANDROID_SDK_ROOT and bails if ANDROID_HOME points at an
// unreadable directory. We always drop ANDROID_HOME so the child
// uses our ANDROID_SDK_ROOT instead.
func TestBuildEmulatorEnvStripsAndroidHome(t *testing.T) {
	parent := []string{
		"ANDROID_HOME=/Volumes/studio/SDK", // user's Studio SDK, possibly unreadable
		"PATH=/usr/bin",
	}
	got := buildEmulatorEnv(parent, "/our/sdk", "/our/data", "")
	for _, e := range got {
		if strings.HasPrefix(e, "ANDROID_HOME=") {
			t.Errorf("ANDROID_HOME must always be stripped (Android Studio sets it to an external volume that may be unreadable), got %q in env", e)
		}
	}
}