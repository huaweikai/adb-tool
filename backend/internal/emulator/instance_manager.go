package emulator

import (
	"bufio"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
)

// InstanceManager handles emulator instance lifecycle (create, delete, start, stop).
type InstanceManager struct {
	emulatorPath   string
	avdManagerPath string
	javaPath       string
	androidSdk     string
	dataDir        string
	portAlloc      *PortAllocator
	instances      map[string]*Instance
	processes      map[string]*ProcessInfo
	mu             sync.RWMutex
	// imageManager is used to look up the on-disk path of a system image when
	// generating an AVD's config.ini. May be nil, in which case we fall back to
	// constructing the path from the imageID (legacy behaviour, often wrong).
	imageManager *ImageManager
	// statusMonitor is set by SetStatusMonitor after construction. nil
	// until then, in which case boot-progress updates are silently dropped.
	statusMonitor *StatusMonitor
	// stopping tracks instances that the user explicitly stopped while
	// they were still booting. monitorEmulatorProcess checks this so
	// that, when it sees the process die, it doesn't overwrite the
	// already-cancelled StatusStopped with a spurious StatusError.
	stopping map[string]bool
}

// Instance represents a single emulator instance (AVD).
type Instance struct {
	ID            string         `json:"id"`
	ImageID       string         `json:"imageId"`
	Name          string         `json:"name"`
	AVDPath       string         `json:"avdPath"`
	Config        InstanceConfig `json:"config"`
	Status        InstanceStatus `json:"status"`
	ConsolePort   int            `json:"consolePort"`
	ADBPort       int            `json:"adbPort"`
	PID           int            `json:"pid,omitempty"`
	Serial        string         `json:"serial"`
	SnapshotID    string         `json:"snapshotId,omitempty"`
	CreatedAt     time.Time      `json:"createdAt"`
	LastStartedAt *time.Time     `json:"lastStartedAt,omitempty"`
	// LogPath is the file where the emulator's stdout/stderr is captured.
	LogPath string `json:"logPath,omitempty"`
	// LastError records the most recent failure reason (startup crash, etc.).
	LastError string `json:"lastError,omitempty"`
	// BootStage names the current phase of the boot sequence. One of
	// "launching", "booting", "adb_connecting", "ready". Empty outside
	// StatusStarting / StatusRunning.
	BootStage string `json:"bootStage,omitempty"`
	// BootProgress is a 0-100 estimate of how far through the boot we are.
	// Updated as monitorEmulatorProcess advances; never persists to disk.
	BootProgress int `json:"bootProgress,omitempty"`
	// BootMessage is a short human-readable description of the current
	// stage (e.g. "Starting kernel…", "Android is starting up…"). Surfaced
	// verbatim in the UI so the user has something to read while waiting.
	BootMessage string `json:"bootMessage,omitempty"`
}

// InstanceConfig holds hardware configuration for an AVD.
type InstanceConfig struct {
	Cores      int    `json:"cores"`
	MemoryMB   int    `json:"memoryMb"`
	Width      int    `json:"width"`
	Height     int    `json:"height"`
	Density    int    `json:"density"`
	SDCardSize string `json:"sdcardSize,omitempty"`
	GPUMode    string `json:"gpuMode"`
}

// InstanceStatus represents the current state of an instance.
type InstanceStatus string

const (
	StatusStopped  InstanceStatus = "stopped"
	StatusStarting InstanceStatus = "starting"
	StatusRunning  InstanceStatus = "running"
	StatusError    InstanceStatus = "error"
)

// ProcessInfo tracks a running emulator process.
type ProcessInfo struct {
	PID       int
	StartTime time.Time
	Serial    string
}

// CreateInstanceRequest holds parameters for creating a new AVD.
type CreateInstanceRequest struct {
	Name    string         `json:"name"`
	ImageID string         `json:"imageId"`
	Config  InstanceConfig `json:"config"`
}

// NewInstanceManager creates a new instance manager.
//
// imageManager may be nil — when present it's used to resolve a system image's
// real on-disk path when writing an AVD's config.ini. Passing nil falls back
// to the legacy <androidSdk>/system-images/<imageID> heuristic, which is only
// correct for imageIDs that don't contain dashes.
func NewInstanceManager(emulatorPath, avdManagerPath, javaPath, androidSdk, dataDir string, imageManager *ImageManager) (*InstanceManager, error) {
	im := &InstanceManager{
		emulatorPath:   emulatorPath,
		avdManagerPath: avdManagerPath,
		javaPath:       javaPath,
		androidSdk:     androidSdk,
		dataDir:        dataDir,
		portAlloc:      NewPortAllocator(),
		instances:      make(map[string]*Instance),
		processes:      make(map[string]*ProcessInfo),
		imageManager:   imageManager,
		stopping:       make(map[string]bool),
	}

	// Load existing instances from disk
	if err := im.loadInstances(); err != nil {
		// Non-fatal, just log
		fmt.Printf("Warning: could not load existing instances: %v\n", err)
	}

	// Scan for orphaned emulator processes
	if err := im.scanOrphanedProcesses(); err != nil {
		fmt.Printf("Warning: could not scan orphaned processes: %v\n", err)
	}

	return im, nil
}

// UpdateToolchainPaths refreshes the emulator + avdmanager binary paths the
// InstanceManager will use when launching instances. Called by the SDK
// use handler whenever the user picks a new SDK root, so a freshly
// installed emulator (via the SDK installer) gets picked up without a
// server restart.
func (m *InstanceManager) UpdateToolchainPaths(emulatorPath, avdManagerPath string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if emulatorPath != "" {
		m.emulatorPath = emulatorPath
	}
	if avdManagerPath != "" {
		m.avdManagerPath = avdManagerPath
	}
}

// SetStatusMonitor wires the StatusMonitor into the InstanceManager so
// boot-progress updates from bootProgressTracker can be pushed to any
// watching WebSocket clients. Safe to call once after construction;
// subsequent calls are no-ops.
func (m *InstanceManager) SetStatusMonitor(sm *StatusMonitor) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.statusMonitor = sm
}

// Create creates a new emulator instance (AVD).
func (m *InstanceManager) Create(req CreateInstanceRequest) (*Instance, error) {
	// Validate name
	if req.Name == "" {
		return nil, errors.New("instance name is required")
	}
	if strings.ContainsAny(req.Name, " ./\\:*?\"<>|") {
		return nil, errors.New("instance name contains invalid characters")
	}

	// Allocate ports
	consolePort, adbPort, err := m.portAlloc.Allocate()
	if err != nil {
		return nil, fmt.Errorf("failed to allocate ports: %w", err)
	}

	// Generate ID
	id := uuid.New().String()
	now := time.Now()

	// Set default config
	config := req.Config
	if config.Cores == 0 {
		config.Cores = 4
	}
	if config.MemoryMB == 0 {
		config.MemoryMB = 4096
	}
	if config.Width == 0 {
		config.Width = 1080
	}
	if config.Height == 0 {
		config.Height = 1920
	}
	if config.Density == 0 {
		config.Density = 420
	}
	if config.GPUMode == "" {
		config.GPUMode = "auto"
	}

	// Create instance
	inst := &Instance{
		ID:          id,
		ImageID:     req.ImageID,
		Name:        req.Name,
		AVDPath:     "", // Will be set during AVD creation
		Config:      config,
		Status:      StatusStopped,
		ConsolePort: consolePort,
		ADBPort:     adbPort,
		Serial:      GetSerial(consolePort),
		CreatedAt:   now,
	}

	// Create AVD using avdmanager if available, otherwise create manually
	if m.avdManagerPath != "" && m.javaPath != "" {
		if err := m.createAVDWithAvdManager(inst); err != nil {
			m.portAlloc.Release(consolePort, adbPort)
			return nil, fmt.Errorf("failed to create AVD: %w", err)
		}
	} else {
		// Fallback: create AVD directory structure manually
		if err := m.createAVDManually(inst); err != nil {
			m.portAlloc.Release(consolePort, adbPort)
			return nil, fmt.Errorf("failed to create AVD: %w", err)
		}
	}

	// Save instance
	m.mu.Lock()
	m.instances[id] = inst
	m.mu.Unlock()

	if err := m.saveInstances(); err != nil {
		fmt.Printf("Warning: failed to save instances: %v\n", err)
	}

	return inst, nil
}

// Delete deletes an emulator instance.
func (m *InstanceManager) Delete(id string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	inst, ok := m.instances[id]
	if !ok {
		return fmt.Errorf("instance not found: %s", id)
	}

	// Stop if running
	if inst.Status == StatusRunning {
		if err := m.stopInstanceLocked(inst); err != nil {
			fmt.Printf("Warning: failed to stop instance before deletion: %v\n", err)
		}
	}

	// Delete AVD directory
	if inst.AVDPath != "" {
		os.RemoveAll(inst.AVDPath)
	}

	// Release ports
	m.portAlloc.Release(inst.ConsolePort, inst.ADBPort)

	// Remove from instances
	delete(m.instances, id)

	// Save changes
	if err := m.saveInstancesLocked(); err != nil {
		return fmt.Errorf("failed to save after deletion: %w", err)
	}

	return nil
}

// Start starts an emulator instance.
//
// Returns synchronously after a short settle window so that "instant death"
// failures (bad AVD config, missing system image, etc.) are reported to the
// caller instead of being silently swallowed. The actual transition to
// StatusRunning happens once ADB can talk to the emulator — see
// monitorEmulatorProcess.
func (m *InstanceManager) Start(id string) (*Instance, error) {
	m.mu.Lock()
	inst, ok := m.instances[id]
	if !ok {
		m.mu.Unlock()
		return nil, fmt.Errorf("instance not found: %s", id)
	}

	if inst.Status == StatusRunning {
		m.mu.Unlock()
		return inst, nil // Already running
	}

	inst.Status = StatusStarting
	inst.LastError = ""
	now := time.Now()
	inst.LastStartedAt = &now
	m.mu.Unlock()

	// Self-heal AVDs created by older backend versions (or by avdmanager
	// directly) that lack the fields emulator 36.x needs to identify
	// the system image and CPU model. updateAVDConfig overwrites
	// config.ini wholesale, so this is safe to run on every Start.
	if err := m.ensureAVDConfig(inst); err != nil {
		log.Printf("[emulator] warning: could not self-heal AVD config for %s: %v", id, err)
	}

	// Start the emulator process
	if err := m.startEmulator(inst); err != nil {
		m.mu.Lock()
		inst.Status = StatusError
		inst.LastError = err.Error()
		m.mu.Unlock()
		return nil, fmt.Errorf("failed to start emulator: %w", err)
	}

	// Settle window: monitorEmulatorProcess sleeps for 3s before checking the
	// process. We wait slightly longer here so we can surface its verdict to
	// the caller. If the process is still alive after this window we return
	// StatusStarting and let the boot phase finish asynchronously.
	time.Sleep(3500 * time.Millisecond)

	m.mu.RLock()
	current := *inst
	proc, hasProc := m.processes[id]
	m.mu.RUnlock()

	if hasProc {
		current.PID = proc.PID
		current.LogPath = inst.LogPath
	}

	if current.Status == StatusError {
		return nil, errors.New(current.LastError)
	}

	// Save updated instance
	if err := m.saveInstances(); err != nil {
		fmt.Printf("Warning: failed to save instance state: %v\n", err)
	}

	return &current, nil
}

// Stop stops a running emulator instance.
//
// Also handles the "cancel a start that's still in progress" case: the
// UI exposes a stop button while status == StatusStarting so the user
// can abort a hung boot. monitorEmulatorProcess will see the dead
// process and (correctly) flip the instance to StatusError; we force
// it to StatusStopped here so the result is what the user asked for.
func (m *InstanceManager) Stop(id string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	inst, ok := m.instances[id]
	if !ok {
		return fmt.Errorf("instance not found: %s", id)
	}

	if inst.Status != StatusRunning && inst.Status != StatusStarting {
		return nil // Already stopped / errored
	}

	if err := m.stopInstanceLocked(inst); err != nil {
		return err
	}

	inst.Status = StatusStopped
	inst.PID = 0
	// Reset boot progress so a subsequent start begins from a clean
	// state instead of showing the previous run's terminal values.
	inst.BootStage = ""
	inst.BootProgress = 0
	inst.BootMessage = ""

	return m.saveInstancesLocked()
}

// List returns all instances.
func (m *InstanceManager) List() []*Instance {
	m.mu.RLock()
	defer m.mu.RUnlock()

	instances := make([]*Instance, 0, len(m.instances))
	for _, inst := range m.instances {
		instances = append(instances, inst)
	}

	return instances
}

// Get returns a specific instance by ID.
func (m *InstanceManager) Get(id string) (*Instance, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	inst, ok := m.instances[id]
	if !ok {
		return nil, fmt.Errorf("instance not found: %s", id)
	}

	return inst, nil
}

// createAVDWithAvdManager creates an AVD using the avdmanager tool.
func (m *InstanceManager) createAVDWithAvdManager(inst *Instance) error {
	avdHome := filepath.Join(m.androidSdk, "avd")
	if err := os.MkdirAll(avdHome, 0755); err != nil {
		return fmt.Errorf("failed to create avd home: %w", err)
	}

	// Determine skin from density
	skin := getSkinFromDensity(inst.Config.Density)

	// Build avdmanager command
	cmd := exec.Command(m.javaPath, "-jar", m.avdManagerPath, "create", "avd",
		"--name", inst.Name,
		"--package", inst.ImageID,
		"--path", filepath.Join(avdHome, inst.Name+".avd"),
	)
	if skin != "" {
		cmd.Args = append(cmd.Args, "--skin", skin)
	}

	cmd.Env = append(os.Environ(),
		"ANDROID_SDK_ROOT="+m.androidSdk,
		"JAVA_HOME="+filepath.Dir(m.javaPath),
	)

	if _, err := cmd.CombinedOutput(); err != nil {
		// Try manual creation as fallback
		return m.createAVDManually(inst)
	}

	inst.AVDPath = filepath.Join(avdHome, inst.Name+".avd")

	// Modify config.ini with our settings
	return m.updateAVDConfig(inst)
}

// createAVDManually creates AVD directory structure without avdmanager.
func (m *InstanceManager) createAVDManually(inst *Instance) error {
	avdHome := filepath.Join(m.dataDir, "avd")
	if err := os.MkdirAll(avdHome, 0755); err != nil {
		return fmt.Errorf("failed to create avd home: %w", err)
	}

	avdPath := filepath.Join(avdHome, inst.Name+".avd")
	if err := os.MkdirAll(avdPath, 0755); err != nil {
		return fmt.Errorf("failed to create avd directory: %w", err)
	}

	inst.AVDPath = avdPath

	// Write the AVD pointer ini alongside the .avd directory. emulator uses
	// <ANDROID_AVD_HOME>/<name>.ini as the entry point when launched with
	// `-avd <name>`; without it the emulator cannot locate the AVD even when
	// config.ini's `path` field is absolute. avdmanager would normally create
	// this file for us, but we hit createAVDManually only when avdmanager
	// failed (typically due to stdin prompts), so we have to write it here.
	//
	// The `target=` line is critical: without it, emulator 36.x falls back
	// to a 32-bit ARM default and refuses to boot with
	// "CPU Architecture 'arm' is not supported".
	iniPath := filepath.Join(avdHome, inst.Name+".ini")
	if err := m.writeAVDPointer(inst, iniPath); err != nil {
		return err
	}

	// Create config.ini
	if err := m.updateAVDConfig(inst); err != nil {
		return err
	}

	// NOTE: we deliberately do NOT create an empty userdata.img here. The
	// emulator treats a zero-byte userdata.img as a corrupt disk image and
	// aborts on boot. Instead, let the emulator create/initialize it on first
	// start (which is its default behaviour when the file is missing).

	return nil
}

func (m *InstanceManager) writeAVDPointer(inst *Instance, iniPath string) error {
	if iniPath == "" {
		iniPath = filepath.Join(filepath.Dir(inst.AVDPath), inst.Name+".ini")
	}
	iniContent := fmt.Sprintf("avd.ini.encoding=UTF-8\npath=%s\npath.rel=%s\ntarget=%s\n",
		inst.AVDPath,
		filepath.Base(inst.AVDPath),
		parseImageTarget(inst.ImageID),
	)
	if err := os.WriteFile(iniPath, []byte(iniContent), 0644); err != nil {
		return fmt.Errorf("failed to write avd ini: %w", err)
	}
	return nil
}

// resolveSystemImagePath returns the absolute on-disk path to the system image
// directory for inst.ImageID. It first tries the imageManager registry (the
// source of truth); if that fails (manager missing, image not registered, or
// path missing on disk) it falls back to a best-effort join under
// <androidSdk>/system-images — this fallback matches avdmanager's layout and
// is the only path that ever works without registration.
func (m *InstanceManager) resolveSystemImagePath(inst *Instance) (string, error) {
	if m.imageManager != nil {
		if img := m.imageManager.GetImage(inst.ImageID); img != nil {
			if img.LocalPath != "" {
				if _, err := os.Stat(img.LocalPath); err == nil {
					return img.LocalPath, nil
				}
			}
		}
	}

	// Fallback: <androidSdk>/system-images/<imageID>. This is wrong for imageIDs
	// like "android-30-google_apis-x86_64" (dashes don't match the nested
	// directory layout) but keeps us functional when the registry is empty.
	candidate := filepath.Join(m.androidSdk, "system-images", inst.ImageID)
	if _, err := os.Stat(candidate); err == nil {
		return candidate, nil
	}

	return "", fmt.Errorf("system image %q not found (looked up via imageManager and %s)", inst.ImageID, candidate)
}

// parseImageTarget extracts the SDK target from an imageID like
// "android-30-default-arm64-v8a" → "android-30".
//
// avdmanager writes `target=android-<api>` into the AVD's .ini; without it
// the emulator can't determine which system images are compatible and falls
// back to a 32-bit ARM default that emulator 36.x no longer supports (FATAL:
// "CPU Architecture 'arm' is not supported").
func parseImageTarget(imageID string) string {
	parts := strings.SplitN(imageID, "-", 3)
	if len(parts) < 2 {
		return imageID
	}
	return parts[0] + "-" + parts[1]
}

// parseImageVariant extracts the system-image variant (the middle segment
// between API level and ABI) from an imageID like "android-30-default-arm64-v8a"
// → "default". avdmanager writes this as `tag.id` / `tag.ids` in config.ini;
// without them emulator 36.x refuses to boot with "Broken AVD system path".
func parseImageVariant(imageID string) string {
	// imageID layout is "<apiLevel>-<variant>-<arch>"; arch itself can
	// contain dashes (arm64-v8a), so we split into at most 4 pieces and
	// take index 2 (variant).
	parts := strings.SplitN(imageID, "-", 4)
	if len(parts) < 3 {
		return ""
	}
	return parts[2]
}

// parseImageArch extracts the (abi, cpuArch) pair from an imageID like
// "android-30-default-arm64-v8a" → ("arm64-v8a", "arm64").
//
// `abi` matches the value avdmanager writes as abi.type in config.ini (the
// on-disk ABI of the system image). `cpuArch` matches hw.cpu.arch (the CPU
// model the emulator should emulate). When either is unknown we return empty
// strings and let the emulator auto-detect from image.sysdir.1.
//
// Note: the arch segment may itself contain a dash (arm64-v8a, armeabi-v7a),
// so we split imageID into ≤4 pieces and rejoin anything after variant.
func parseImageArch(imageID string) (abi, cpuArch string) {
	parts := strings.SplitN(imageID, "-", 4)
	if len(parts) < 4 {
		return "", ""
	}
	abi = parts[3]
	switch abi {
	case "arm64-v8a":
		cpuArch = "arm64"
	case "x86_64":
		cpuArch = "x86_64"
	case "x86":
		cpuArch = "x86"
	case "armeabi-v7a":
		cpuArch = "arm"
	default:
		return "", ""
	}
	return abi, cpuArch
}

// updateAVDConfig writes the AVD config.ini file.
//
// Notes on the path fields:
//   - `path` is an absolute path to the AVD directory; emulator uses this
//     directly without consulting ANDROID_AVD_HOME.
//   - `pathRel` mirrors `path` so legacy avdmanager-style resolution (relative
//     to ANDROID_AVD_HOME) also works.
//   - `systemPath` is the absolute path to the system image directory. It is
//     resolved via the imageManager rather than guessed from the imageID,
//     because imageIDs use dashes (e.g. android-30-google_apis-x86_64) but
//     the on-disk layout uses nested directories (android-30/google_apis/x86_64).
func (m *InstanceManager) updateAVDConfig(inst *Instance) error {
	if inst.AVDPath == "" {
		return errors.New("avd path not set")
	}

	systemPath, err := m.resolveSystemImagePath(inst)
	if err != nil {
		return err
	}
	_ = systemPath

	// Derive abi / cpuArch / variant from the imageID so emulator 36.x
	// picks the right CPU model and the right system image directory.
	//
	// Without `abi.type` + `hw.cpu.arch` the emulator defaults to 32-bit ARM
	// and dies with "CPU Architecture 'arm' is not supported".
	//
	// Without `image.sysdir.1` (relative to ANDROID_SDK_ROOT) + `tag.id` /
	// `tag.ids` the emulator refuses to boot with "Broken AVD system path"
	// even when `systemPath` is set to the correct absolute path — emulator
	// 36.x does not consult `systemPath` for system-image lookup, only
	// `image.sysdir.*`.
	abi, cpuArch := parseImageArch(inst.ImageID)
	variant := parseImageVariant(inst.ImageID)

	// image.sysdir.1 is a path relative to ANDROID_SDK_ROOT (NOT absolute).
	// avdmanager writes this with a trailing slash; we mirror that.
	sysDirRel := filepath.ToSlash(filepath.Join("system-images",
		parseImageTarget(inst.ImageID), variant, abi)) + "/"

	configPath := filepath.Join(inst.AVDPath, "config.ini")
	config := fmt.Sprintf(`AvdId=%s
avd.ini.displayname=%s
avd.ini.encoding=UTF-8
abi.type=%s
hw.cpu.arch=%s
hw.cpu.ncore=%d
hw.ramSize=%d
hw.screen=dynamic
hw.sdCard=%s
hw.gps=yes
hw.gpu.enabled=yes
hw.gpu.mode=%s
image.sysdir.1=%s
path=%s
path.rel=%s
tag.id=%s
tag.ids=%s
disk.dataPartition.size=2G
hw.lcd.width=%d
hw.lcd.height=%d
hw.lcd.density=%d
hw.screenWidth=%d
hw.screenHeight=%d
`, inst.Name,
		inst.Name,
		abi,
		cpuArch,
		inst.Config.Cores,
		inst.Config.MemoryMB,
		sdCardSetting(inst),
		inst.Config.GPUMode,
		sysDirRel,
		inst.AVDPath,
		filepath.Base(inst.AVDPath),
		variant,
		variant,
		inst.Config.Width,
		inst.Config.Height,
		inst.Config.Density,
		inst.Config.Width,
		inst.Config.Height)

	if err := os.WriteFile(configPath, []byte(config), 0644); err != nil {
		return fmt.Errorf("failed to write config.ini: %w", err)
	}

	return nil
}

// startEmulator launches the emulator process.
//
// stdout/stderr are captured to <AVDPath>/emulator.log so we have a permanent
// record of what the emulator said — and a tail of that log is attached to
// the instance's LastError when the process dies unexpectedly, instead of
// silently swallowing the failure.
func (m *InstanceManager) startEmulator(inst *Instance) error {
	if m.emulatorPath == "" {
		return errors.New("emulator path not configured")
	}

	args := []string{
		"-avd", inst.Name,
		"-port", strconv.Itoa(inst.ConsolePort),
		"-no-snapshot",
		"-no-window",
		"-no-audio",
		"-cores", strconv.Itoa(inst.Config.Cores),
		"-memory", strconv.Itoa(inst.Config.MemoryMB),
		"-gpu", inst.Config.GPUMode,
	}

	if systemPath, err := m.resolveSystemImagePath(inst); err == nil && systemPath != "" {
		args = append(args, "-sysdir", systemPath)
	} else if err != nil {
		return err
	}

	// Capture emulator output to a per-AVD log file. Without this, anything
	// the emulator writes to stdout/stderr (errors, warnings, boot logs) is
	// lost when the child process exits.
	logPath := filepath.Join(inst.AVDPath, "emulator.log")
	logFile, err := os.Create(logPath)
	if err != nil {
		return fmt.Errorf("failed to create emulator log file: %w", err)
	}

	cmd := exec.Command(m.emulatorPath, args...)
	// Point ANDROID_AVD_HOME at our managed AVD directory (`<dataDir>/avd`,
	// i.e. ~/.adb-tool/emulator/avd). Previously this was set to
	// `<androidSdk>/avd` which is the SDK root, but our AVDs live alongside
	// the emulator cache, not the SDK — that mismatch caused
	// "ANDROID_AVD_HOME is defined but there is no file <name>.ini" at boot.
	cmdEnv := []string{
		"ANDROID_SDK_ROOT=" + m.androidSdk,
		"ANDROID_AVD_HOME=" + filepath.Join(m.dataDir, "avd"),
	}
	// Fix (code-review M5): previously we only set JAVA_HOME when
	// invoking avdmanager (~line 443) but not when launching the
	// emulator binary itself. The two processes therefore loaded
	// different JREs (whatever the OS resolved vs. our selected Java),
	// causing subtle divergence (locale, crypto providers, modules).
	// Pass JAVA_HOME to the emulator child when we have one configured.
	if m.javaPath != "" {
		cmdEnv = append(cmdEnv, "JAVA_HOME="+filepath.Dir(m.javaPath))
	}
	cmd.Env = append(os.Environ(), cmdEnv...)
	cmd.Stdout = logFile
	cmd.Stderr = logFile

	// Start without waiting for completion
	if err := cmd.Start(); err != nil {
		logFile.Close()
		// Best-effort cleanup; ignore error.
		_ = os.Remove(logPath)
		return fmt.Errorf("failed to start emulator: %w", err)
	}
	// Close the parent's copy of the log file now that the child has
	// inherited its own FD. Without this:
	//   - the parent leaks an OS file handle for the entire emulator
	//     lifetime (hours, in practice).
	//   - on Windows the file cannot be deleted while the parent's
	//     handle is open, which breaks tests that use a temp AVD dir
	//     (TestStartEmulatorPassesSystemImagePathToSysdir cleanup).
	cmd.Stdout = nil
	cmd.Stderr = nil
	logFile.Close()

	inst.LogPath = logPath

	m.processes[inst.ID] = &ProcessInfo{
		PID:       cmd.Process.Pid,
		StartTime: time.Now(),
		Serial:    inst.Serial,
	}

	// Watch the process for the first few seconds to catch immediate-boot
	// failures (bad system image path, missing KVM, broken AVD config, ...).
	// Without this the API reports success even though the emulator died.
	go m.monitorEmulatorProcess(inst.ID, cmd, logFile)
	// Drive the live progress bar / stage label the UI shows while the
	// instance is starting. The monitor above only flips the final
	// StatusRunning/StatusError; this loop tails the log every 1.5s and
	// maps keyword matches to user-visible boot stages.
	go m.bootProgressTracker(inst.ID, logPath)

	return nil
}

// monitorEmulatorProcess watches a freshly-launched emulator for two failure
// modes that the previous implementation silently swallowed:
//
//  1. Immediate exit (bad systemPath, missing KVM/HVF, bad AVD config.ini, ...).
//  2. Crash during the boot window.
//
// IMPORTANT: we no longer use `cmd.Process.Pid` (the emulator.exe wrapper)
// as the liveness signal. On modern Android emulator builds the wrapper is
// short-lived — it forks the real qemu-system-x86_64-headless.exe and exits
// within ~1s. The previous "is wrapper alive after 3s" check therefore fired
// on every successful boot, marking a perfectly-running instance as error
// while adb devices still showed emulator-5554 device. The user-visible
// symptom was "backend says error, but the emulator is clearly up".
//
// We don't watch for "Boot completed" here either — bootProgressTracker is
// already tailing the log every 1.5s and flips the instance to StatusRunning
// when it sees the keyword. Doing it twice would just duplicate the
// broadcast. This loop's job is the negative side of the boot story:
//
//   - adb get-state == device as a fallback if the log keyword check somehow
//     misses (e.g. log file got rotated).
//   - emulator.log growth stalling for 10s → wrapper died before forking qemu.
//   - No log file 5s in → bad emulator path / missing binary.
//   - 180s wall-clock without any readiness signal → boot really hung.
func (m *InstanceManager) monitorEmulatorProcess(id string, cmd *exec.Cmd, logFile *os.File) {
	defer logFile.Close()

	logPath := logFile.Name()

	// Give the wrapper a brief moment to fork qemu and start writing the
	// log. This is the closest equivalent to the old "wrapper still alive
	// at +3s" check, but tolerates the wrapper exiting as long as qemu is
	// now running.
	time.Sleep(2 * time.Second)

	maxWait := 180 * time.Second
	deadline := time.Now().Add(maxWait)
	const noLogTimeout = 5 * time.Second

	lastLogSize := int64(-1)
	lastLogChange := time.Now()
	logEverGrew := false

	for time.Now().Before(deadline) {
		inst := m.getInstance(id)
		if inst == nil {
			return
		}
		if inst.Status != StatusStarting {
			return
		}
		// User clicked Stop — back off so recordEmulatorFailure doesn't
		// overwrite StatusStopped with StatusError.
		if m.stopping[id] {
			return
		}

		// Fallback readiness signal: ADB sees the serial as a usable
		// device. The primary path is bootProgressTracker detecting
		// "Boot completed" in the log; this catches the corner case where
		// the log file is missing or the keyword never appears.
		if err := m.checkEmulatorReady(inst.Serial); err == nil {
			m.markEmulatorReady(id, inst.Serial)
			return
		}

		// Liveness: during a normal emulator boot the log can legitimately go
		// quiet for more than 10 seconds while ADB still reports "offline".
		// Do not treat log stalling as fatal by itself; the 180s boot timeout is
		// the authoritative hang detector once the process produced any log.
		if info, err := os.Stat(logPath); err == nil {
			if info.Size() != lastLogSize {
				lastLogSize = info.Size()
				lastLogChange = time.Now()
				logEverGrew = true
			}
			if logEverGrew && shouldTreatBootLogStallAsFatal(time.Since(lastLogChange)) {
				m.recordEmulatorFailure(id, "emulator log stalled — process likely dead", logPath)
				return
			}
		} else if !logEverGrew && time.Since(lastLogChange) > noLogTimeout {
			// No log file 5s in → fatal (bad emulator path, missing binary,
			// etc). Without this we'd wait the full 180s on a broken config.
			m.recordEmulatorFailure(id, "emulator produced no log output", logPath)
			return
		}

		time.Sleep(2 * time.Second)
	}

	// Boot timed out. Don't kill the wrapper (could just be slow) — but
	// mark the instance as errored so the UI doesn't sit at "Starting"
	// forever.
	m.recordEmulatorFailure(id, "emulator boot timed out after 180s", logPath)
}

func shouldTreatBootLogStallAsFatal(_ time.Duration) bool {
	return false
}

// markEmulatorReady is the shared "we are now StatusRunning" path used by
// the two readiness signals in monitorEmulatorProcess (ADB get-state and
// "Boot completed" in the log). Writes the same terminal values both
// signals would have written, and broadcasts once so any UI that missed
// the tracker's push still sees the transition.
func (m *InstanceManager) markEmulatorReady(id, serial string) {
	log.Printf("[emulator] instance %s ready on %s", id, serial)
	m.mu.Lock()
	inst, ok := m.instances[id]
	if !ok {
		m.mu.Unlock()
		return
	}
	inst.Status = StatusRunning
	inst.BootStage = "ready"
	inst.BootProgress = 100
	inst.BootMessage = "启动完成"
	m.mu.Unlock()
	if m.statusMonitor != nil {
		m.statusMonitor.BroadcastStatus(id, StatusRunning, "ready", 100, "启动完成")
	}
}

// recordEmulatorFailure flips an instance to StatusError, captures the tail
// of the emulator log into LastError, and drops the dead process from
// m.processes so List() doesn't keep advertising a ghost PID.
func (m *InstanceManager) recordEmulatorFailure(id, reason, logPath string) {
	tail := ReadLogTail(logPath, 40)
	errMsg := fmt.Sprintf("%s. Log: %s\n--- last log lines ---\n%s", reason, logPath, tail)
	log.Printf("[emulator] instance %s: %s", id, errMsg)

	// Fix (code-review B6): previous version had `defer m.mu.Unlock()`
	// PLUS an explicit `m.mu.Unlock()` in the stopping branch → double
	// Unlock panic. New shape uses a single Lock/Unlock pair; the
	// per-branch semantics are preserved:
	//   - stopping[id] set: Stop is in flight and owns the process entry.
	//     Just clear the stopping flag; Stop will tear down processes.
	//   - StatusStarting: flip to StatusError, drop the dead process entry.
	//   - any other status: leave both status and processes alone (Stop
	//     or the user has already moved the instance).
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.stopping[id] {
		delete(m.stopping, id)
		return
	}
	inst, ok := m.instances[id]
	if !ok || inst.Status != StatusStarting {
		return
	}
	inst.Status = StatusError
	inst.LastError = errMsg
	inst.LastStartedAt = nil
	inst.PID = 0
	// Wipe boot progress so the UI doesn't keep showing a half-finished
	// bar on an errored instance.
	inst.BootStage = ""
	inst.BootProgress = 0
	inst.BootMessage = ""
	delete(m.processes, id)
}

// bootProgressTracker polls the emulator log every 1.5s and updates the
// instance's BootStage / BootProgress / BootMessage based on keyword
// matches. Runs until the instance leaves StatusStarting (either to
// StatusRunning, in which case monitorEmulatorProcess sets the terminal
// values, or to StatusError, in which case we exit). The log only emits
// on events, so we also nudge the progress bar forward during quiet
// periods so the user sees motion.
//
// boot stages, in order:
//   - "launching"        process just forked
//   - "booting_kernel"   qemu/userspace boot props written
//   - "booting_android"  graphics / Vulkan init
//   - "adb_connecting"   GRPC server up, adb registration
//   - "ready"            monitorEmulatorProcess flipped to StatusRunning
func (m *InstanceManager) bootProgressTracker(id, logPath string) {
	const pollInterval = 1500 * time.Millisecond

	// Seed the initial state so the UI has something to render
	// immediately after Start returns.
	m.updateBootState(id, "launching", 5, "正在启动 emulator 进程…")

	stage := "launching"
	progress := 5
	message := "正在启动 emulator 进程…"

	seenLines := 0
	ticker := time.NewTicker(pollInterval)
	defer ticker.Stop()

	// applyUpdate is the only path that writes boot state + broadcasts,
	// so we never double-fire the same stage+progress twice in a row.
	applyUpdate := func(nextStage string, nextProgress int, nextMessage string) {
		if nextStage == stage && nextProgress == progress && nextMessage == message {
			return
		}
		stage, progress, message = nextStage, nextProgress, nextMessage
		m.updateBootState(id, stage, progress, message)
	}

	for range ticker.C {
		cur := m.getInstance(id)
		if cur == nil {
			return
		}
		// monitorEmulatorProcess already took over (running / error) —
		// stop our own loop. StatusRunning also implies "ready", which
		// monitorEmulatorProcess has already broadcast, so there's
		// nothing for us to do.
		if cur.Status != StatusStarting {
			return
		}

		lines, total := tailLogLines(logPath, seenLines)
		seenLines = total

		if len(lines) == 0 {
			// Quiet period. Nudge progress forward so the bar keeps
			// moving, but cap before the "ready" zone so we never
			// accidentally race past monitorEmulatorProcess.
			if progress < 85 {
				applyUpdate(stage, progress+1, message)
			}
			continue
		}

		// Match keywords in newest line(s). Once we see "Boot completed"
		// we hand off to monitorEmulatorProcess and stop advancing.
		for _, line := range lines {
			switch {
			case strings.Contains(line, "Boot completed"):
				// First write the final boot fields so the WS payload we
				// broadcast reflects "ready@100". Then promote the instance
				// to StatusRunning — applyUpdate only writes the boot fields,
				// it intentionally leaves Status as StatusStarting so this
				// loop can keep tracking mid-boot transitions. Boot completed
				// is the terminal event, so flipping Status here is correct,
				// and it also stops monitorEmulatorProcess from re-running
				// its own "Boot completed" detection.
				applyUpdate("ready", 100, "启动完成")
				m.markEmulatorReady(id, cur.Serial)
				return
			case strings.Contains(line, "Started GRPC server") || strings.Contains(line, "Advertising in"):
				applyUpdate("adb_connecting", 80, "正在连接 ADB…")
			case strings.Contains(line, "Graphics Adapter") || strings.Contains(line, "Vulkan externalMemoryMode"):
				if progress < 50 {
					applyUpdate("booting_android", 50, "Android 正在启动…")
				}
			case strings.Contains(line, "Userspace boot properties") || strings.Contains(line, "qemu=1"):
				if progress < 20 {
					applyUpdate("booting_kernel", 20, "正在启动内核…")
				}
			}
		}
	}
}

// updateBootState writes the boot fields on the instance and broadcasts
// them to any watching WebSocket clients. Safe to call from any
// goroutine; locks m.mu internally.
func (m *InstanceManager) updateBootState(id, stage string, progress int, message string) {
	m.mu.Lock()
	inst, ok := m.instances[id]
	if !ok {
		m.mu.Unlock()
		return
	}
	inst.BootStage = stage
	inst.BootProgress = progress
	inst.BootMessage = message
	sm := m.statusMonitor
	m.mu.Unlock()

	if sm != nil {
		sm.BroadcastStatus(id, StatusStarting, stage, progress, message)
	}
}

// tailLogLines returns the lines in logPath after the first `skip`
// lines, plus the file's total line count. Used by bootProgressTracker
// to know which lines are new since the last poll. Returns (nil, skip)
// if the file hasn't grown.
func tailLogLines(logPath string, skip int) ([]string, int) {
	data, err := os.ReadFile(logPath)
	if err != nil {
		return nil, skip
	}
	lines := strings.Split(strings.TrimRight(string(data), "\n"), "\n")
	if len(lines) == 1 && lines[0] == "" {
		return nil, 0
	}
	if skip >= len(lines) {
		return nil, len(lines)
	}
	return lines[skip:], len(lines)
}

// sdCardSetting returns the value to write for `hw.sdCard` in config.ini.
//
// We default to "no" — the emulator tries to create a missing sdcard.img
// on first boot, but if a previous run already created one and then
// the user deleted it, the next boot fails with "Could not open
// .../sdcard.img". Disabling sdcard sidesteps that whole class of bugs.
// If the user explicitly requested a non-empty SDCardSize, point
// hw.sdCard at the AVD's local sdcard.img so they can mount it.
func sdCardSetting(inst *Instance) string {
	if inst.Config.SDCardSize == "" {
		return "no"
	}
	return filepath.Join(inst.AVDPath, "sdcard.img")
}

// getInstance fetches an instance under the read lock.
func (m *InstanceManager) getInstance(id string) *Instance {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.instances[id]
}

// ensureAVDConfig re-writes config.ini if any of the fields emulator
// 36.x needs to identify the system image are missing. AVDs created
// by older versions of this backend (or directly by avdmanager) lack
// `image.sysdir.1`, `abi.type`, `tag.id`/`tag.ids`, and `hw.cpu.arch`,
// which causes the emulator to die with
// "CPU Architecture 'arm' is not supported" at launch. We detect this
// lazily on Start instead of migrating at load time, so the hot
// List() path stays cheap.
//
// updateAVDConfig overwrites the whole file with the canonical layout,
// which is also fine on a healthy AVD (it produces an idempotent
// re-write) — we just skip that re-write when nothing is missing to
// avoid bumping mtime on every boot.
func (m *InstanceManager) ensureAVDConfig(inst *Instance) error {
	if inst.AVDPath == "" {
		return nil // Nothing to repair; startEmulator will fail later.
	}
	configPath := filepath.Join(inst.AVDPath, "config.ini")
	data, err := os.ReadFile(configPath)
	if err != nil {
		return err
	}
	required := []string{"image.sysdir.1", "abi.type", "tag.id", "tag.ids", "hw.cpu.arch", "hw.lcd.width", "hw.lcd.height", "hw.lcd.density"}
	missing := false
	for _, key := range required {
		if !strings.Contains(string(data), key+"=") {
			missing = true
			break
		}
	}
	if !missing {
		expectedDisplay := []string{
			fmt.Sprintf("hw.lcd.width=%d", inst.Config.Width),
			fmt.Sprintf("hw.lcd.height=%d", inst.Config.Height),
			fmt.Sprintf("hw.lcd.density=%d", inst.Config.Density),
		}
		for _, expected := range expectedDisplay {
			if !strings.Contains(string(data), expected) {
				missing = true
				break
			}
		}
	}
	if missing {
		log.Printf("[emulator] repairing AVD config at %s (missing %v)", configPath, required)
		if err := m.updateAVDConfig(inst); err != nil {
			return err
		}
	}
	return m.writeAVDPointer(inst, "")
}

// checkEmulatorReady checks if emulator is ready via ADB.
func (m *InstanceManager) checkEmulatorReady(serial string) error {
	cmd := exec.Command("adb", "-s", serial, "get-state")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return err
	}
	if strings.Contains(string(output), "device") {
		return nil
	}
	return errors.New("emulator not ready")
}

// stopInstanceLocked stops an instance (must hold lock).
func (m *InstanceManager) stopInstanceLocked(inst *Instance) error {
	// Mark this instance as user-cancelled BEFORE killing the process.
	// monitorEmulatorProcess races with us: once it sees the process is
	// dead, it would call recordEmulatorFailure and overwrite our
	// StatusStopped with StatusError. The stopping flag tells it to
	// back off and leave the status as-is.
	m.stopping[inst.ID] = true

	if proc, ok := m.processes[inst.ID]; ok {
		// Try graceful shutdown via ADB first
		exec.Command("adb", "-s", inst.Serial, "emu", "kill").Run()

		// Give it time to shutdown gracefully
		time.Sleep(2 * time.Second)

		// Kill if still running
		if isProcessRunning(proc.PID) {
			syscallKill(proc.PID)
		}

		delete(m.processes, inst.ID)
	}

	return nil
}

// scanOrphanedProcesses scans for and cleans up orphaned emulator processes.
func (m *InstanceManager) scanOrphanedProcesses() error {
	// Find all emulator processes
	cmd := exec.Command("pgrep", "-f", "emulator.*-avd")
	output, err := cmd.CombinedOutput()
	if err != nil {
		// No processes found
		return nil
	}

	scanner := bufio.NewScanner(strings.NewReader(string(output)))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}

		pid, err := strconv.Atoi(line)
		if err != nil {
			continue
		}

		// Mark as orphaned - we'll clean up on next startup
		fmt.Printf("Found orphaned emulator process: PID %d\n", pid)
	}

	return nil
}

// saveInstances saves instance state to disk.
func (m *InstanceManager) saveInstances() error {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.saveInstancesLocked()
}

// saveInstancesLocked saves instance state (must hold lock).
func (m *InstanceManager) saveInstancesLocked() error {
	if m.dataDir == "" {
		return nil
	}

	instancesPath := filepath.Join(m.dataDir, "instances.json")

	data := make([]*Instance, 0, len(m.instances))
	for _, inst := range m.instances {
		// Strip runtime-only fields before persisting. We want a fresh
		// boot every time the backend restarts — the user shouldn't see
		// a "ready" instance with PID 0, and a half-finished progress
		// bar from the previous session would be misleading.
		saveInst := *inst
		saveInst.PID = 0
		saveInst.Status = StatusStopped
		saveInst.BootStage = ""
		saveInst.BootProgress = 0
		saveInst.BootMessage = ""
		saveInst.LastError = ""
		data = append(data, &saveInst)
	}

	jsonData, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal instances: %w", err)
	}

	return os.WriteFile(instancesPath, jsonData, 0644)
}

// loadInstances loads instance state from disk.
func (m *InstanceManager) loadInstances() error {
	if m.dataDir == "" {
		return nil
	}

	instancesPath := filepath.Join(m.dataDir, "instances.json")

	data, err := os.ReadFile(instancesPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return fmt.Errorf("failed to read instances file: %w", err)
	}

	var instances []*Instance
	if err := json.Unmarshal(data, &instances); err != nil {
		return fmt.Errorf("failed to unmarshal instances: %w", err)
	}

	for _, inst := range instances {
		inst.Status = StatusStopped // Reset status on load
		inst.PID = 0
		m.instances[inst.ID] = inst

		// Re-allocate ports for consistency
		m.portAlloc.Allocate() // We already allocated these when created
	}

	return nil
}

// isProcessRunning checks if a process with given PID is running.
func isProcessRunning(pid int) bool {
	if pid <= 0 {
		return false
	}
	process, err := os.FindProcess(pid)
	if err != nil {
		return false
	}
	return process.Signal(os.Signal(nil)) == nil
}

// syscallKill sends SIGKILL to a process (platform-specific).
func syscallKill(pid int) {
	process, _ := os.FindProcess(pid)
	process.Kill()
}

// getSkinFromDensity returns a skin string for the given density.
func getSkinFromDensity(density int) string {
	switch {
	case density <= 160:
		return "QVGA"
	case density <= 240:
		return "HVGA"
	case density <= 320:
		return "WVGA800"
	case density <= 480:
		return "WXGA720"
	default:
		return "1080x1920"
	}
}

// computeSHA256 computes SHA-256 hash of a file.
func computeSHA256(path string) (string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	hash := sha256.Sum256(data)
	return hex.EncodeToString(hash[:]), nil
}

// ReadLogTail returns up to the last `maxLines` non-empty lines of a log
// file. Used to embed a short, useful error snippet into LastError when
// an emulator crashes — the full log is still on disk at logPath for
// the user to inspect. Exported so the HTTP /log endpoint can reuse it.
func ReadLogTail(logPath string, maxLines int) string {
	data, err := os.ReadFile(logPath)
	if err != nil {
		return fmt.Sprintf("(could not read log: %v)", err)
	}
	lines := strings.Split(strings.TrimRight(string(data), "\n"), "\n")
	if len(lines) > maxLines {
		lines = lines[len(lines)-maxLines:]
	}
	// Drop trailing blank lines so the snippet is meaningful.
	for len(lines) > 0 && strings.TrimSpace(lines[len(lines)-1]) == "" {
		lines = lines[:len(lines)-1]
	}
	return strings.Join(lines, "\n")
}
