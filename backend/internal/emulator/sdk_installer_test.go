package emulator

import (
	"strings"
	"testing"
)

func TestBuildSDKManagerEnvSetsAndroidHomeAndSDKRoot(t *testing.T) {
	env := buildSDKManagerEnv("/tmp/sdk", "")
	joined := strings.Join(env, "\n")

	if !strings.Contains(joined, "ANDROID_HOME=/tmp/sdk") {
		t.Errorf("env missing ANDROID_HOME=/tmp/sdk; got:\n%s", joined)
	}
	if !strings.Contains(joined, "ANDROID_SDK_ROOT=/tmp/sdk") {
		t.Errorf("env missing ANDROID_SDK_ROOT=/tmp/sdk; got:\n%s", joined)
	}
}

func TestBuildSDKManagerEnvOmitsJavaHomeWhenJavaPathEmpty(t *testing.T) {
	env := buildSDKManagerEnv("/tmp/sdk", "")

	for _, e := range env {
		if strings.HasPrefix(e, "JAVA_HOME=") {
			t.Errorf("expected no JAVA_HOME entry when javaPath empty; got %q (full env: %v)", e, env)
		}
	}
}

func TestBuildSDKManagerEnvDerivesJavaHomeFromJavaPath(t *testing.T) {
	cases := []struct {
		name      string
		javaPath  string
		wantJHome string
	}{
		{
			name:      "Adoptium JDK layout (Contents/Home/bin/java)",
			javaPath:  "/Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home/bin/java",
			wantJHome: "/Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home",
		},
		{
			name:      "Apple stub (/usr/bin/java)",
			javaPath:  "/usr/bin/java",
			wantJHome: "/usr",
		},
		{
			name:      "managed JRE in user cache",
			javaPath:  "/Users/test/.adb-tool/emulator/java-runtime/jdk-21/bin/java",
			wantJHome: "/Users/test/.adb-tool/emulator/java-runtime/jdk-21",
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			env := buildSDKManagerEnv("/tmp/sdk", tc.javaPath)
			wantEntry := "JAVA_HOME=" + tc.wantJHome

			var found string
			var count int
			for _, e := range env {
				if strings.HasPrefix(e, "JAVA_HOME=") {
					found = e
					count++
				}
			}

			if count != 1 {
				t.Errorf("exactly one JAVA_HOME entry expected, got %d (env: %v)", count, env)
			}
			if found != wantEntry {
				t.Errorf("JAVA_HOME=%q, want %q", found, wantEntry)
			}
		})
	}
}

func TestBuildSDKManagerEnvOverridesInheritedAndroidHome(t *testing.T) {
	// Simulate the user-profile case where the parent's ANDROID_HOME points
	// at an external macOS drive that fails the sandbox dyld check. The
	// caller's env may carry that value, but we always re-write BOTH
	// ANDROID_HOME and ANDROID_SDK_ROOT to the user-selected SDK path so
	// sdkmanager resolves to a usable root.
	t.Setenv("ANDROID_HOME", "/Volumes/external-blocked/sdk")
	t.Setenv("ANDROID_SDK_ROOT", "/Volumes/external-blocked/sdk")

	env := buildSDKManagerEnv("/Users/test/.adb-tool/sdk", "/usr/bin/java")

	// When an env var has duplicate keys, os/exec on Linux/macOS keeps the
	// last occurrence (POSIX getenv behavior). Verify our override is the
	// LAST entry with that key so the subprocess sees the right value.
	lastAndroidHome := ""
	lastAndroidSdkRoot := ""
	lastJavaHome := ""
	for _, e := range env {
		switch {
		case strings.HasPrefix(e, "ANDROID_HOME="):
			lastAndroidHome = e
		case strings.HasPrefix(e, "ANDROID_SDK_ROOT="):
			lastAndroidSdkRoot = e
		case strings.HasPrefix(e, "JAVA_HOME="):
			lastJavaHome = e
		}
	}

	wantAH := "ANDROID_HOME=/Users/test/.adb-tool/sdk"
	wantSR := "ANDROID_SDK_ROOT=/Users/test/.adb-tool/sdk"
	wantJH := "JAVA_HOME=/usr"

	if lastAndroidHome != wantAH {
		t.Errorf("last ANDROID_HOME entry = %q, want %q (sdkmanager would see the older blocked value)", lastAndroidHome, wantAH)
	}
	if lastAndroidSdkRoot != wantSR {
		t.Errorf("last ANDROID_SDK_ROOT entry = %q, want %q", lastAndroidSdkRoot, wantSR)
	}
	if lastJavaHome != wantJH {
		t.Errorf("last JAVA_HOME entry = %q, want %q", lastJavaHome, wantJH)
	}
}
