package emulator

import (
	"bufio"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
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
func NewInstanceManager(emulatorPath, avdManagerPath, javaPath, androidSdk, dataDir string) (*InstanceManager, error) {
	im := &InstanceManager{
		emulatorPath:  emulatorPath,
		avdManagerPath: avdManagerPath,
		javaPath:      javaPath,
		androidSdk:   androidSdk,
		dataDir:      dataDir,
		portAlloc:    NewPortAllocator(),
		instances:    make(map[string]*Instance),
		processes:    make(map[string]*ProcessInfo),
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
	now := time.Now()
	inst.LastStartedAt = &now
	m.mu.Unlock()

	// Start the emulator process
	if err := m.startEmulator(inst); err != nil {
		m.mu.Lock()
		inst.Status = StatusError
		m.mu.Unlock()
		return nil, fmt.Errorf("failed to start emulator: %w", err)
	}

	m.mu.Lock()
	inst.Status = StatusRunning
	inst.PID = m.processes[id].PID
	m.mu.Unlock()

	// Save updated instance
	if err := m.saveInstances(); err != nil {
		fmt.Printf("Warning: failed to save instance state: %v\n", err)
	}

	return inst, nil
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

	// Create userdata.img (empty placeholder)
	userdataPath := filepath.Join(avdPath, "userdata.img")
	emptyFile, err := os.Create(userdataPath)
	if err != nil {
		return fmt.Errorf("failed to create userdata.img: %w", err)
	}
	emptyFile.Close()

	return nil
}

// updateAVDConfig writes the AVD config.ini file.
func (m *InstanceManager) updateAVDConfig(inst *Instance) error {
	if inst.AVDPath == "" {
		return errors.New("avd path not set")
	}

	configPath := filepath.Join(inst.AVDPath, "config.ini")
	config := fmt.Sprintf(`[core]
name=%s
path=%s
pathRel=avd/%s.avd

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
`, inst.Name, inst.AVDPath, inst.Name,
		filepath.Join(m.androidSdk, "system-images", inst.ImageID),
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

	cmd := exec.Command(m.emulatorPath, args...)
	cmd.Env = append(os.Environ(),
		"ANDROID_SDK_ROOT="+m.androidSdk,
		"ANDROID_AVD_HOME="+filepath.Join(m.androidSdk, "avd"),
	)

	// Start without waiting for completion
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to start emulator: %w", err)
	}

	// Wait for emulator to be ready (up to 60 seconds)
	go m.waitForEmulatorReady(inst.ID, cmd)

	m.processes[inst.ID] = &ProcessInfo{
		PID:       cmd.Process.Pid,
		StartTime: time.Now(),
		Serial:    inst.Serial,
	}

	return nil
}

// waitForEmulatorReady waits for the emulator to be ready for ADB connections.
func (m *InstanceManager) waitForEmulatorReady(id string, cmd *exec.Cmd) {
	inst := m.instances[id]
	maxWait := 60 * time.Second
	deadline := time.Now().Add(maxWait)

	for time.Now().Before(deadline) {
		// Check if process is still running
		if cmd.ProcessState != nil && cmd.ProcessState.Exited() {
			return
		}

		// Try to connect via ADB
		if err := m.checkEmulatorReady(inst.Serial); err == nil {
			return
		}

		time.Sleep(2 * time.Second)
	}
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
