package emulator

import (
	"os"
	"path/filepath"
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
	} {
		if !strings.Contains(text, required) {
			t.Fatalf("config.ini missing %q: %q", required, text)
		}
	}
}

func TestStartEmulatorPassesSystemImagePathToSysdir(t *testing.T) {
	tmp := t.TempDir()
	sdkDir := filepath.Join(tmp, "sdk")
	dataDir := filepath.Join(tmp, "data")
	avdPath := filepath.Join(dataDir, "avd", "Pixel.avd")
	imagePath := filepath.Join(sdkDir, "system-images", "android-30-default-arm64-v8a")
	argsPath := filepath.Join(tmp, "args.txt")
	emulatorPath := filepath.Join(tmp, "fake-emulator.sh")

	if err := os.MkdirAll(avdPath, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(imagePath, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(imagePath, "system.img"), []byte("system"), 0644); err != nil {
		t.Fatal(err)
	}
	script := "#!/bin/sh\nprintf '%s\\n' \"$@\" > \"" + argsPath + "\"\nsleep 5\n"
	if err := os.WriteFile(emulatorPath, []byte(script), 0755); err != nil {
		t.Fatal(err)
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

	if err := manager.startEmulator(inst); err != nil {
		t.Fatalf("startEmulator returned error: %v", err)
	}
	if proc := manager.processes[inst.ID]; proc != nil {
		defer syscallKill(proc.PID)
	}

	var argsData []byte
	var err error
	for i := 0; i < 120; i++ {
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
