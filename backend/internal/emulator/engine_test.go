package emulator

import (
	"os"
	"path/filepath"
	"runtime"
	"testing"
)

func TestSdkPathHasToolchainAcceptsCmdlineToolsBinWithoutLatest(t *testing.T) {
	sdkPath := t.TempDir()
	binPath := filepath.Join(sdkPath, "cmdline-tools", "bin")
	writeTestTool(t, binPath, "sdkmanager")
	writeTestTool(t, binPath, "avdmanager")

	if !SdkPathHasToolchain(sdkPath) {
		t.Fatal("SdkPathHasToolchain rejected cmdline-tools/bin layout")
	}

	engine := &Engine{SDKPath: sdkPath, AndroidHome: sdkPath}
	detectToolchain(engine)

	if engine.SdkmanagerPath == "" {
		t.Fatal("detectToolchain did not resolve sdkmanager from cmdline-tools/bin")
	}
	if engine.AvdmanagerPath == "" {
		t.Fatal("detectToolchain did not resolve avdmanager from cmdline-tools/bin")
	}
}

func TestCheckSDKPathUsesSameToolchainLookup(t *testing.T) {
	sdkPath := t.TempDir()
	binPath := filepath.Join(sdkPath, "cmdline-tools", "bin")
	writeTestTool(t, binPath, "avdmanager")

	info := checkSDKPath(sdkPath)
	if info == nil {
		t.Fatal("checkSDKPath returned nil")
	}
	if !info.HasAvdmanager {
		t.Fatal("checkSDKPath did not detect avdmanager from cmdline-tools/bin")
	}
}

func writeTestTool(t *testing.T, dir, name string) string {
	t.Helper()
	if err := os.MkdirAll(dir, 0755); err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(dir, name)
	if runtime.GOOS == "windows" {
		path += ".bat"
	}
	if err := os.WriteFile(path, []byte("echo test\n"), 0755); err != nil {
		t.Fatal(err)
	}
	return path
}
