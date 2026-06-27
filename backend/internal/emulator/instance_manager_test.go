package emulator

import (
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"
)

func TestEnsureAVDConfigRepairsPointerIniTarget(t *testing.T) {
	tmp := t.TempDir()
	sdkDir := filepath.Join(tmp, "sdk")
	dataDir := filepath.Join(tmp, "data")
	avdHome := filepath.Join(dataDir, "avd")
	avdPath := filepath.Join(avdHome, "Pixel.avd")
	imagePath := filepath.Join(sdkDir, "system-images", "android-30-default-arm64-v8a")

	if err := os.MkdirAll(avdPath, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(imagePath, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(imagePath, "system.img"), []byte("system"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(avdPath, "config.ini"), []byte("[core]\nname=Pixel\n"), 0644); err != nil {
		t.Fatal(err)
	}
	pointerPath := filepath.Join(avdHome, "Pixel.ini")
	if err := os.WriteFile(pointerPath, []byte("path="+avdPath+"\n"), 0644); err != nil {
		t.Fatal(err)
	}

	manager := &InstanceManager{androidSdk: sdkDir, dataDir: dataDir}
	inst := &Instance{Name: "Pixel", ImageID: "android-30-default-arm64-v8a", AVDPath: avdPath}

	if err := manager.ensureAVDConfig(inst); err != nil {
		t.Fatalf("ensureAVDConfig returned error: %v", err)
	}

	data, err := os.ReadFile(pointerPath)
	if err != nil {
		t.Fatal(err)
	}
	text := string(data)
	if !strings.Contains(text, "target=android-30\n") {
		t.Fatalf("pointer ini missing target: %q", text)
	}
	if !strings.Contains(text, "path.rel=Pixel.avd\n") {
		t.Fatalf("pointer ini missing relative path: %q", text)
	}
}

func TestEnsureAVDConfigRepairsMissingLCDDimensions(t *testing.T) {
	tmp := t.TempDir()
	sdkDir := filepath.Join(tmp, "sdk")
	dataDir := filepath.Join(tmp, "data")
	avdHome := filepath.Join(dataDir, "avd")
	avdPath := filepath.Join(avdHome, "Pixel.avd")
	imagePath := filepath.Join(sdkDir, "system-images", "android-30-default-arm64-v8a")
	if err := os.MkdirAll(avdPath, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(imagePath, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(imagePath, "system.img"), []byte("system"), 0644); err != nil {
		t.Fatal(err)
	}
	oldConfig := "AvdId=Pixel\n" +
		"image.sysdir.1=system-images/android-30/default/arm64-v8a/\n" +
		"abi.type=arm64-v8a\n" +
		"hw.cpu.arch=arm64\n" +
		"tag.id=default\n" +
		"tag.ids=default\n" +
		"hw.screenWidth=1080\n" +
		"hw.screenHeight=1920\n" +
		"hw.lcd.density=420\n"
	if err := os.WriteFile(filepath.Join(avdPath, "config.ini"), []byte(oldConfig), 0644); err != nil {
		t.Fatal(err)
	}

	manager := &InstanceManager{androidSdk: sdkDir, dataDir: dataDir}
	inst := &Instance{
		Name:    "Pixel",
		ImageID: "android-30-default-arm64-v8a",
		AVDPath: avdPath,
		Config:  InstanceConfig{Cores: 4, MemoryMB: 4096, Width: 1080, Height: 1920, Density: 420, GPUMode: "auto"},
	}

	if err := manager.ensureAVDConfig(inst); err != nil {
		t.Fatalf("ensureAVDConfig returned error: %v", err)
	}
	data, err := os.ReadFile(filepath.Join(avdPath, "config.ini"))
	if err != nil {
		t.Fatal(err)
	}
	text := string(data)
	for _, required := range []string{"hw.lcd.width=1080\n", "hw.lcd.height=1920\n"} {
		if !strings.Contains(text, required) {
			t.Fatalf("config.ini missing %q: %q", required, text)
		}
	}
}

func TestUpdateAVDConfigWritesFlatEmulatorKeys(t *testing.T) {
	tmp := t.TempDir()
	sdkDir := filepath.Join(tmp, "sdk")
	dataDir := filepath.Join(tmp, "data")
	avdPath := filepath.Join(dataDir, "avd", "Pixel.avd")
	imagePath := filepath.Join(sdkDir, "system-images", "android-30-default-arm64-v8a")

	if err := os.MkdirAll(avdPath, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(imagePath, 0755); err != nil {
		t.Fatal(err)
	}

	manager := &InstanceManager{androidSdk: sdkDir, dataDir: dataDir}
	inst := &Instance{
		Name:    "Pixel",
		ImageID: "android-30-default-arm64-v8a",
		AVDPath: avdPath,
		Config:  InstanceConfig{Cores: 4, MemoryMB: 4096, Width: 1080, Height: 1920, Density: 420, GPUMode: "auto"},
	}

	if err := manager.updateAVDConfig(inst); err != nil {
		t.Fatalf("updateAVDConfig returned error: %v", err)
	}

	data, err := os.ReadFile(filepath.Join(avdPath, "config.ini"))
	if err != nil {
		t.Fatal(err)
	}
	text := string(data)
	for _, forbidden := range []string{"[core]", "[image]", "[hw]"} {
		if strings.Contains(text, forbidden) {
			t.Fatalf("config.ini contains unsupported section %q: %q", forbidden, text)
		}
	}
	for _, required := range []string{
		"image.sysdir.1=system-images/android-30/default/arm64-v8a/\n",
		"abi.type=arm64-v8a\n",
		"hw.cpu.arch=arm64\n",
		"tag.id=default\n",
		"tag.ids=default\n",
		"hw.sdCard=no\n",
		"path.rel=Pixel.avd\n",
		"hw.lcd.width=1080\n",
		"hw.lcd.height=1920\n",
		"hw.lcd.density=420\n",
	} {
		if !strings.Contains(text, required) {
			t.Fatalf("config.ini missing %q: %q", required, text)
		}
	}
}

func TestBootLogStallAloneIsNotFatal(t *testing.T) {
	if shouldTreatBootLogStallAsFatal(10 * time.Second) {
		t.Fatalf("10s boot log stall must not be fatal by itself")
	}
	if shouldTreatBootLogStallAsFatal(2 * time.Minute) {
		t.Fatalf("boot log stall must not be fatal by itself; boot timeout handles real hangs")
	}
}

func TestListDoesNotUseWrapperPIDToMarkRunningInstanceStopped(t *testing.T) {
	manager := &InstanceManager{
		instances: map[string]*Instance{
			"instance-1": {
				ID:     "instance-1",
				Status: StatusRunning,
				PID:    -1,
			},
		},
		processes: map[string]*ProcessInfo{
			"instance-1": {PID: -1},
		},
	}

	instances := manager.List()
	if len(instances) != 1 {
		t.Fatalf("len(instances) = %d, want 1", len(instances))
	}
	if instances[0].Status != StatusRunning {
		t.Fatalf("status = %s, want %s", instances[0].Status, StatusRunning)
	}
}

func TestRecordEmulatorFailureDoesNotClobberRunningInstance(t *testing.T) {
	tmp := t.TempDir()
	logPath := filepath.Join(tmp, "emulator.log")
	if err := os.WriteFile(logPath, []byte("INFO         | Boot completed in 33762 ms\n"), 0644); err != nil {
		t.Fatal(err)
	}

	manager := &InstanceManager{
		instances: map[string]*Instance{
			"instance-1": {
				ID:     "instance-1",
				Status: StatusRunning,
				Serial: "emulator-5554",
			},
		},
		processes: map[string]*ProcessInfo{
			"instance-1": {PID: 1234},
		},
	}

	manager.recordEmulatorFailure("instance-1", "emulator log stalled for 10s — process likely dead", logPath)

	inst := manager.instances["instance-1"]
	if inst.Status != StatusRunning {
		t.Fatalf("status = %s, want %s", inst.Status, StatusRunning)
	}
	if _, ok := manager.processes["instance-1"]; !ok {
		t.Fatalf("process entry was removed for running instance")
	}
}

func TestStartEmulatorPassesSystemImagePathToSysdir(t *testing.T) {
	tmp := t.TempDir()
	sdkDir := filepath.Join(tmp, "sdk")
	dataDir := filepath.Join(tmp, "data")
	avdPath := filepath.Join(dataDir, "avd", "Pixel.avd")
	imagePath := filepath.Join(sdkDir, "system-images", "android-30-default-arm64-v8a")
	argsPath := filepath.Join(tmp, "args.txt")

	if err := os.MkdirAll(avdPath, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(imagePath, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(imagePath, "system.img"), []byte("system"), 0644); err != nil {
		t.Fatal(err)
	}

	// Fix (code-review M17): the previous version wrote a .sh shebang
	// script. On Windows a .sh is not a Win32 PE so `exec.Command` returned
	// "%1 is not a valid Win32 application" and the test failed 100% on
	// Windows.
	//
	// The reliable cross-platform replacement is a tiny Go binary
	// (`fake-emulator` on POSIX, `fake-emulator.exe` on Windows) compiled
	// in-test from a single source file via `go build`. `go build
	// <file.go>` doesn't require a go.mod in the destination dir and is
	// always available in `go test` environments. The binary writes each
	// argv onto its own line in `args.txt` in its working directory and
	// sleeps so the parent can read the file before the process exits.
	emulatorPath := filepath.Join(tmp, "fake-emulator")
	if runtime.GOOS == "windows" {
		emulatorPath += ".exe"
	}
	const fakeSrc = `package main

import (
	"fmt"
	"os"
	"time"
)

func main() {
	f, err := os.Create("args.txt")
	if err != nil {
		os.Exit(1)
	}
	// Write args first, close, THEN sleep. We need the file flushed and
	// closed before the parent reads it. A 200ms sleep keeps the test
	// snappy and is short enough that t.TempDir cleanup (which races
	// against the still-running process) doesn't trip on Windows file
	// locks held by the child via cmd.Stdout/Stderr.
	for _, arg := range os.Args[1:] {
		fmt.Fprintln(f, arg)
	}
	f.Close()
	time.Sleep(200 * time.Millisecond)
}
`
	srcPath := filepath.Join(tmp, "fake-emulator-main.go")
	if err := os.WriteFile(srcPath, []byte(fakeSrc), 0644); err != nil {
		t.Fatal(err)
	}
	build := exec.Command("go", "build", "-o", emulatorPath, srcPath)
	if out, err := build.CombinedOutput(); err != nil {
		t.Fatalf("go build fake-emulator failed: %v\n%s", err, out)
	}

	manager := &InstanceManager{
		emulatorPath: emulatorPath,
		androidSdk:   sdkDir,
		dataDir:      dataDir,
		processes:    map[string]*ProcessInfo{},
	}
	inst := &Instance{
		ID:          "instance-1",
		Name:        "Pixel",
		ImageID:     "android-30-default-arm64-v8a",
		AVDPath:     avdPath,
		ConsolePort: 5554,
		Config:      InstanceConfig{Cores: 2, MemoryMB: 2048, GPUMode: "auto"},
	}

	// startEmulator runs the emulator binary without setting cmd.Dir, so
	// the child inherits this test's cwd. Chdir into tmp/ so the fake
	// binary's "create args.txt in cwd" lands somewhere predictable.
	// t.Chdir auto-restores when the test ends.
	t.Chdir(tmp)

	if err := manager.startEmulator(inst); err != nil {
		t.Fatalf("startEmulator returned error: %v", err)
	}
	if proc := manager.processes[inst.ID]; proc != nil {
		defer syscallKill(proc.PID)
	}

	var argsData []byte
	var err error
	for i := 0; i < 240; i++ {
		argsData, err = os.ReadFile(argsPath)
		if err == nil {
			break
		}
		time.Sleep(25 * time.Millisecond)
	}
	if err != nil {
		t.Fatalf("failed to read captured args: %v", err)
	}

	lines := strings.Split(strings.TrimSpace(string(argsData)), "\n")
	var sysdir string
	for i := 0; i < len(lines)-1; i++ {
		if lines[i] == "-sysdir" {
			sysdir = lines[i+1]
			break
		}
	}
	if sysdir != imagePath {
		t.Fatalf("-sysdir = %q, want %q; args=%v", sysdir, imagePath, lines)
	}
}

func TestDeleteRemovesAVDDirectoryAndPointerIni(t *testing.T) {
	tmp := t.TempDir()
	dataDir := filepath.Join(tmp, "data")
	avdHome := filepath.Join(dataDir, "avd")
	avdPath := filepath.Join(avdHome, "aaa.avd")
	pointerPath := filepath.Join(avdHome, "aaa.ini")
	if err := os.MkdirAll(avdPath, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(avdPath, "config.ini"), []byte("AvdId=aaa\n"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(pointerPath, []byte("path="+avdPath+"\n"), 0644); err != nil {
		t.Fatal(err)
	}

	manager := &InstanceManager{
		dataDir:   dataDir,
		portAlloc: NewPortAllocator(),
		instances: map[string]*Instance{
			"instance-1": {
				ID:          "instance-1",
				Name:        "aaa",
				AVDPath:     avdPath,
				Status:      StatusStopped,
				ConsolePort: 5554,
				ADBPort:     5555,
			},
		},
	}

	if err := manager.Delete("instance-1"); err != nil {
		t.Fatalf("Delete returned error: %v", err)
	}
	if _, err := os.Stat(avdPath); !os.IsNotExist(err) {
		t.Fatalf("AVD directory still exists or stat failed unexpectedly: %v", err)
	}
	if _, err := os.Stat(pointerPath); !os.IsNotExist(err) {
		t.Fatalf("pointer ini still exists or stat failed unexpectedly: %v", err)
	}
}

func TestDeleteReturnsErrorAndKeepsInstanceWhenAVDPathIsAFile(t *testing.T) {
	tmp := t.TempDir()
	dataDir := filepath.Join(tmp, "data")
	avdHome := filepath.Join(dataDir, "avd")
	avdPath := filepath.Join(avdHome, "aaa.avd")
	if err := os.MkdirAll(avdHome, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(avdPath, []byte("not a directory"), 0644); err != nil {
		t.Fatal(err)
	}

	manager := &InstanceManager{
		dataDir:   dataDir,
		portAlloc: NewPortAllocator(),
		instances: map[string]*Instance{
			"instance-1": {
				ID:          "instance-1",
				Name:        "aaa",
				AVDPath:     avdPath,
				Status:      StatusStopped,
				ConsolePort: 5554,
				ADBPort:     5555,
			},
		},
	}

	err := manager.Delete("instance-1")
	if err == nil {
		t.Fatal("Delete returned nil error")
	}
	if !strings.Contains(err.Error(), "failed to delete AVD directory") {
		t.Fatalf("Delete error = %q, want AVD deletion failure", err.Error())
	}
	if _, ok := manager.instances["instance-1"]; !ok {
		t.Fatal("instance was removed after failed AVD deletion")
	}
	if _, err := os.Stat(avdPath); err != nil {
		t.Fatalf("AVD path should remain after failed delete: %v", err)
	}
}
