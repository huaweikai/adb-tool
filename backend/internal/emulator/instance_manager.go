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
	emulatorPath string
	avdManagerPath string
	javaPath     string
	androidSdk   string
	dataDir      string
	portAlloc    *PortAllocator
	instances    map[string]*Instance
	processes    map[string]*ProcessInfo
	mu           sync.RWMutex
	// imageManager is used to look up the on-disk path of a system image when
	// generating an AVD's config.ini. May be nil, in which case we fall back to
	// constructing the path from the imageID (legacy behaviour, often wrong).
	imageManager *ImageManager
}

// Instance represents a single emulator instance (AVD).
type Instance struct {
	ID           string          `json:"id"`
	ImageID      string          `json:"imageId"`
	Name         string          `json:"name"`
	AVDPath      string          `json:"avdPath"`
	Config       InstanceConfig  `json:"config"`
	Status       InstanceStatus   `json:"status"`
	ConsolePort  int             `json:"consolePort"`
	ADBPort      int             `json:"adbPort"`
	PID          int             `json:"pid,omitempty"`
	Serial       string          `json:"serial"`
	SnapshotID   string          `json:"snapshotId,omitempty"`
	CreatedAt    time.Time       `json:"createdAt"`
	LastStartedAt *time.Time     `json:"lastStartedAt,omitempty"`
	// LogPath is the file where the emulator's stdout/stderr is captured.
	LogPath string `json:"logPath,omitempty"`
	// LastError records the most recent failure reason (startup crash, etc.).
	LastError string `json:"lastError,omitempty"`
}

// InstanceConfig holds hardware configuration for an AVD.
type InstanceConfig struct {
	Cores       int    `json:"cores"`
	MemoryMB    int    `json:"memoryMb"`
	Width       int    `json:"width"`
	Height      int    `json:"height"`
	Density     int    `json:"density"`
	SDCardSize  string `json:"sdcardSize,omitempty"`
	GPUMode     string `json:"gpuMode"`
}

// InstanceStatus represents the current state of an instance.
type InstanceStatus string

const (
	StatusStopped  InstanceStatus = "stopped"
	StatusStarting  InstanceStatus = "starting"
	StatusRunning   InstanceStatus = "running"
	StatusError     InstanceStatus = "error"
)

// ProcessInfo tracks a running emulator process.
type ProcessInfo struct {
	PID       int
	StartTime time.Time
	Serial    string
}

// CreateInstanceRequest holds parameters for creating a new AVD.
type CreateInstanceRequest struct {
	Name      string         `json:"name"`
	ImageID   string         `json:"imageId"`
	Config    InstanceConfig `json:"config"`
}

// NewInstanceManager creates a new instance manager.
//
// imageManager may be nil — when present it's used to resolve a system image's
// real on-disk path when writing an AVD's config.ini. Passing nil falls back
// to the legacy <androidSdk>/system-images/<imageID> heuristic, which is only
// correct for imageIDs that don't contain dashes.
func NewInstanceManager(emulatorPath, avdManagerPath, javaPath, androidSdk, dataDir string, imageManager *ImageManager) (*InstanceManager, error) {
	im := &InstanceManager{
		emulatorPath:  emulatorPath,
		avdManagerPath: avdManagerPath,
		javaPath:      javaPath,
		androidSdk:   androidSdk,
		dataDir:      dataDir,
		portAlloc:    NewPortAllocator(),
		instances:    make(map[string]*Instance),
		processes:    make(map[string]*ProcessInfo),
		imageManager: imageManager,
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
func (m *InstanceManager) Stop(id string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	inst, ok := m.instances[id]
	if !ok {
		return fmt.Errorf("instance not found: %s", id)
	}

	if inst.Status != StatusRunning {
		return nil // Already stopped
	}

	if err := m.stopInstanceLocked(inst); err != nil {
		return err
	}

	inst.Status = StatusStopped
	inst.PID = 0

	return m.saveInstancesLocked()
}

// List returns all instances.
func (m *InstanceManager) List() []*Instance {
	m.mu.RLock()
	defer m.mu.RUnlock()

	instances := make([]*Instance, 0, len(m.instances))
	for _, inst := range m.instances {
		// Update status based on actual process state
		if inst.Status == StatusRunning {
			if proc, ok := m.processes[inst.ID]; ok {
				if !isProcessRunning(proc.PID) {
					inst.Status = StatusStopped
					inst.PID = 0
				}
			} else {
				inst.Status = StatusStopped
				inst.PID = 0
			}
		}
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

	// Check if still running
	if inst.Status == StatusRunning {
		if proc, ok := m.processes[inst.ID]; ok {
			if !isProcessRunning(proc.PID) {
				inst.Status = StatusStopped
				inst.PID = 0
			}
		} else {
			inst.Status = StatusStopped
			inst.PID = 0
		}
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

	configPath := filepath.Join(inst.AVDPath, "config.ini")
	config := fmt.Sprintf(`[core]
name=%s
path=%s
pathRel=%s

[image]
systemPath=%s

[hw]
cpu.cores=%d
hw.ramSize=%d
hw.screen=dynamic
hw.sdCard.path=%s
hw.gps=yes
hw.gpu.enabled=1
hw.gpu.mode=%s

[disk]
dataPartition.size=2G

[screen]
hw.screenWidth=%d
hw.screenHeight=%d
hw.lcd.density=%d
`, inst.Name, inst.AVDPath, inst.AVDPath,
		systemPath,
		inst.Config.Cores,
		inst.Config.MemoryMB,
		filepath.Join(inst.AVDPath, "sdcard.img"),
		inst.Config.GPUMode,
		inst.Config.Width,
		inst.Config.Height,
		inst.Config.Density)

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

	// Add AVD path if not in standard location
	if inst.AVDPath != "" && !strings.HasPrefix(inst.AVDPath, filepath.Join(m.androidSdk, "avd")) {
		args = append(args, "-sysdir", inst.AVDPath)
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
	cmd.Env = append(os.Environ(),
		"ANDROID_SDK_ROOT="+m.androidSdk,
		"ANDROID_AVD_HOME="+filepath.Join(m.androidSdk, "avd"),
	)
	cmd.Stdout = logFile
	cmd.Stderr = logFile

	// Start without waiting for completion
	if err := cmd.Start(); err != nil {
		logFile.Close()
		// Best-effort cleanup; ignore error.
		_ = os.Remove(logPath)
		return fmt.Errorf("failed to start emulator: %w", err)
	}

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

	return nil
}

// monitorEmulatorProcess watches a freshly-launched emulator for two failure
// modes that the previous implementation silently swallowed:
//
//  1. Immediate exit (within ~3s) — usually a configuration problem:
//     bad systemPath, missing KVM/HVF, bad AVD config.ini, etc.
//  2. Crash during the boot window — process disappears before ADB connects.
//
// In both cases we set the instance status to StatusError and surface a
// tail of emulator.log in LastError so the user can see what went wrong.
func (m *InstanceManager) monitorEmulatorProcess(id string, cmd *exec.Cmd, logFile *os.File) {
	defer logFile.Close()

	// Phase 1: immediate-crash detection.
	time.Sleep(3 * time.Second)
	if !isProcessRunning(cmd.Process.Pid) {
		m.recordEmulatorFailure(id, "emulator exited within 3s of launch", logFile.Name())
		return
	}

	// Phase 2: boot window. Wait for ADB to connect, but keep watching the
	// process so we notice if it dies mid-boot.
	inst := m.getInstance(id)
	if inst == nil {
		return
	}

	maxWait := 90 * time.Second
	deadline := time.Now().Add(maxWait)
	for time.Now().Before(deadline) {
		if !isProcessRunning(cmd.Process.Pid) {
			m.recordEmulatorFailure(id, "emulator process died during boot", logFile.Name())
			return
		}

		if err := m.checkEmulatorReady(inst.Serial); err == nil {
			log.Printf("[emulator] instance %s ready on %s", id, inst.Serial)
			m.mu.Lock()
			if inst, ok := m.instances[id]; ok {
				inst.Status = StatusRunning
			}
			m.mu.Unlock()
			return
		}

		time.Sleep(2 * time.Second)
	}

	// Boot timed out but the process is still alive — don't kill it (could
	// just be a slow machine), but mark the instance as errored so the UI
	// doesn't sit at "Starting" forever.
	m.recordEmulatorFailure(id, "emulator boot timed out after 90s", logFile.Name())
}

// recordEmulatorFailure flips an instance to StatusError, captures the tail
// of the emulator log into LastError, and drops the dead process from
// m.processes so List() doesn't keep advertising a ghost PID.
func (m *InstanceManager) recordEmulatorFailure(id, reason, logPath string) {
	tail := readLogTail(logPath, 40)
	errMsg := fmt.Sprintf("%s. Log: %s\n--- last log lines ---\n%s", reason, logPath, tail)
	log.Printf("[emulator] instance %s: %s", id, errMsg)

	m.mu.Lock()
	defer m.mu.Unlock()
	if inst, ok := m.instances[id]; ok {
		inst.Status = StatusError
		inst.LastError = errMsg
		inst.LastStartedAt = nil
		inst.PID = 0
	}
	delete(m.processes, id)
}

// getInstance fetches an instance under the read lock.
func (m *InstanceManager) getInstance(id string) *Instance {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.instances[id]
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
		// Don't save runtime state (PID, status)
		saveInst := *inst
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

// readLogTail returns up to the last `maxLines` non-empty lines of a log file.
// Used to embed a short, useful error snippet into LastError when an emulator
// crashes — the full log is still on disk at logPath for the user to inspect.
func readLogTail(logPath string, maxLines int) string {
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
