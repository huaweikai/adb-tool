package emulator

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestAcceptSDKLicensesCreatesFiles(t *testing.T) {
	tmp := t.TempDir()
	t.Setenv("HOME", tmp)

	if err := acceptSDKLicenses(); err != nil {
		t.Fatalf("acceptSDKLicenses: %v", err)
	}

	licensesDir := filepath.Join(tmp, ".android", "licenses")
	for _, hash := range cmdlineToolsLicenseHashes {
		target := filepath.Join(licensesDir, hash)
		if _, err := os.Stat(target); err != nil {
			t.Errorf("expected %s to exist after acceptSDKLicenses: %v", target, err)
		}
	}
}

func TestAcceptSDKLicensesIsIdempotent(t *testing.T) {
	tmp := t.TempDir()
	t.Setenv("HOME", tmp)

	// Run twice; we shouldn't lose the first run's writes or any
	// timestamps should not reset.
	if err := acceptSDKLicenses(); err != nil {
		t.Fatalf("first: %v", err)
	}
	licensesDir := filepath.Join(tmp, ".android", "licenses")
	firstStat, err := os.Stat(filepath.Join(licensesDir, cmdlineToolsLicenseHashes[0]))
	if err != nil {
		t.Fatal(err)
	}

	if err := acceptSDKLicenses(); err != nil {
		t.Fatalf("second: %v", err)
	}
	secondStat, err := os.Stat(filepath.Join(licensesDir, cmdlineToolsLicenseHashes[0]))
	if err != nil {
		t.Fatal(err)
	}

	// mtime should be unchanged (we don't touch existing files).
	if !firstStat.ModTime().Equal(secondStat.ModTime()) {
		t.Errorf("acceptSDKLicenses reset mtime on existing file: was %v, now %v",
			firstStat.ModTime(), secondStat.ModTime())
	}
}

func TestResolveSDKManagerClasspathFindsFatJar(t *testing.T) {
	tmp := t.TempDir()
	lib := filepath.Join(tmp, "cmdline-tools", "latest", "lib")
	if err := os.MkdirAll(lib, 0755); err != nil {
		t.Fatal(err)
	}
	fat := filepath.Join(lib, "sdkmanager-classpath.jar")
	if err := os.WriteFile(fat, []byte("not-a-real-jar"), 0644); err != nil {
		t.Fatal(err)
	}
	// A decoy jar — should be ignored.
	if err := os.WriteFile(filepath.Join(lib, "decoy.jar"), []byte("x"), 0644); err != nil {
		t.Fatal(err)
	}

	binDir := filepath.Join(tmp, "cmdline-tools", "latest", "bin")
	if err := os.MkdirAll(binDir, 0755); err != nil {
		t.Fatal(err)
	}
	sdkmanagerBin := filepath.Join(binDir, "sdkmanager")
	if err := os.WriteFile(sdkmanagerBin, []byte("#!/bin/sh\n"), 0755); err != nil {
		t.Fatal(err)
	}

	classpath, appHome, err := resolveSDKManagerClasspath(sdkmanagerBin)
	if err != nil {
		t.Fatalf("resolveSDKManagerClasspath: %v", err)
	}
	if classpath != fat {
		t.Errorf("expected fast-path fat jar; got %q", classpath)
	}
	if !strings.HasSuffix(appHome, filepath.Join("cmdline-tools", "latest")) {
		t.Errorf("appHome wrong: %q", appHome)
	}
}

func TestResolveSDKManagerClasspathFallsBackToAggregatedJars(t *testing.T) {
	tmp := t.TempDir()
	lib := filepath.Join(tmp, "cmdline-tools", "latest", "lib")
	if err := os.MkdirAll(lib, 0755); err != nil {
		t.Fatal(err)
	}
	// No sdkmanager-classpath.jar; only auxiliary jars.
	for _, name := range []string{"a.jar", "b.jar", "c.jar"} {
		if err := os.WriteFile(filepath.Join(lib, name), []byte("x"), 0644); err != nil {
			t.Fatal(err)
		}
	}
	// Also throw in a non-jar entry — must be ignored.
	if err := os.WriteFile(filepath.Join(lib, "README.txt"), []byte("hi"), 0644); err != nil {
		t.Fatal(err)
	}

	binDir := filepath.Join(tmp, "cmdline-tools", "latest", "bin")
	if err := os.MkdirAll(binDir, 0755); err != nil {
		t.Fatal(err)
	}
	sdkmanagerBin := filepath.Join(binDir, "sdkmanager")
	if err := os.WriteFile(sdkmanagerBin, []byte("#!/bin/sh\n"), 0755); err != nil {
		t.Fatal(err)
	}

	classpath, _, err := resolveSDKManagerClasspath(sdkmanagerBin)
	if err != nil {
		t.Fatalf("resolveSDKManagerClasspath: %v", err)
	}
	parts := strings.Split(classpath, ":")
	if len(parts) != 3 {
		t.Fatalf("classpath should have 3 jars, got %d: %q", len(parts), classpath)
	}
	if filepath.Base(parts[0]) != "a.jar" ||
		filepath.Base(parts[1]) != "b.jar" ||
		filepath.Base(parts[2]) != "c.jar" {
		t.Errorf("classpath jars wrong order: %q", classpath)
	}
	// README.txt must not be in the classpath.
	if strings.Contains(classpath, "README") {
		t.Errorf("non-jar entry leaked into classpath: %q", classpath)
	}
}

func TestResolveSDKManagerClasspathErrorsOnEmptyLib(t *testing.T) {
	tmp := t.TempDir()
	lib := filepath.Join(tmp, "cmdline-tools", "latest", "lib")
	if err := os.MkdirAll(lib, 0755); err != nil {
		t.Fatal(err)
	}
	binDir := filepath.Join(tmp, "cmdline-tools", "latest", "bin")
	if err := os.MkdirAll(binDir, 0755); err != nil {
		t.Fatal(err)
	}
	sdkmanagerBin := filepath.Join(binDir, "sdkmanager")
	if err := os.WriteFile(sdkmanagerBin, []byte("#!/bin/sh\n"), 0755); err != nil {
		t.Fatal(err)
	}

	_, _, err := resolveSDKManagerClasspath(sdkmanagerBin)
	if err == nil {
		t.Errorf("expected error when lib/ is empty")
	}
}
