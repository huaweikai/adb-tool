package server

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestScrcpyArchCandidatesMapsGoArchToBundleDirs(t *testing.T) {
	tests := []struct {
		name   string
		goos   string
		goarch string
		want   []string
	}{
		{name: "darwin arm64", goos: "darwin", goarch: "arm64", want: []string{"aarch64", "x86_64"}},
		{name: "darwin amd64", goos: "darwin", goarch: "amd64", want: []string{"x86_64"}},
		{name: "windows 386", goos: "windows", goarch: "386", want: []string{"386"}},
		{name: "windows amd64", goos: "windows", goarch: "amd64", want: []string{"amd64", "386"}},
		{name: "windows arm64", goos: "windows", goarch: "arm64", want: []string{"amd64", "386"}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := scrcpyArchCandidates(tt.goos, tt.goarch)
			if !reflect.DeepEqual(got, tt.want) {
				t.Fatalf("unexpected candidates: got %v, want %v", got, tt.want)
			}
		})
	}
}

func TestSupportsBundledScrcpyOSOnlyAllowsWindowsAndDarwin(t *testing.T) {
	tests := []struct {
		goos string
		want bool
	}{
		{goos: "windows", want: true},
		{goos: "darwin", want: true},
		{goos: "linux", want: false},
		{goos: "freebsd", want: false},
	}

	for _, tt := range tests {
		t.Run(tt.goos, func(t *testing.T) {
			got := supportsBundledScrcpyOS(tt.goos)
			if got != tt.want {
				t.Fatalf("unexpected support result: got %v, want %v", got, tt.want)
			}
		})
	}
}

func TestChmodScrcpyExecutablesMarksScrcpyAndAdbExecutable(t *testing.T) {
	dir := t.TempDir()
	scrcpyPath := filepath.Join(dir, "scrcpy")
	adbPath := filepath.Join(dir, "adb")

	if err := os.WriteFile(scrcpyPath, []byte("scrcpy"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(adbPath, []byte("adb"), 0644); err != nil {
		t.Fatal(err)
	}

	if err := chmodScrcpyExecutables("darwin", dir, scrcpyPath); err != nil {
		t.Fatal(err)
	}

	assertExecutable(t, scrcpyPath)
	assertExecutable(t, adbPath)
}

func assertExecutable(t *testing.T, filePath string) {
	t.Helper()
	info, err := os.Stat(filePath)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode()&0111 == 0 {
		t.Fatalf("expected %s to be executable, mode=%v", filePath, info.Mode())
	}
}
