package server

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"slices"
	"strings"
	"sync"
	"time"
)

type iosDiscovery struct {
	ctx     context.Context
	command func(context.Context, ...string) ([]byte, error)
	logs    func(context.Context, string, io.Writer) error
	mu      sync.RWMutex
	devices []Device
}

func newIOSDiscovery(shutdownCtx context.Context, cli string) *iosDiscovery {
	daemon := newIOSDaemon(shutdownCtx, cli)
	return &iosDiscovery{ctx: shutdownCtx, command: func(ctx context.Context, args ...string) ([]byte, error) {
		ctx, cancel := context.WithTimeout(ctx, 25*time.Second)
		defer cancel()
		if err := shutdownCtx.Err(); err != nil {
			return nil, err
		}
		stop := context.AfterFunc(shutdownCtx, cancel)
		defer stop()
		return daemon.Call(ctx, args...)
	}, logs: func(ctx context.Context, udid string, output io.Writer) error {
		return runIOSCLI(ctx, cli, output, "syslog", "live", "--udid", udid)
	}}
}

func findIOSCLI() string {
	path := os.Getenv("ADB_TOOL_PYMOBILEDEVICE3")
	if path == "" {
		executable, err := os.Executable()
		if err != nil {
			return ""
		}
		name := "pymobiledevice3"
		if runtime.GOOS == "windows" {
			name += ".exe"
		}
		execDir := filepath.Dir(executable)
		candidates := []string{
			filepath.Join(execDir, name),
			filepath.Join(execDir, "..", "..", "dist", "ios-tools", name),
			filepath.Join(execDir, "..", "..", "..", "dist", "ios-tools", name),
		}
		for _, c := range candidates {
			if info, err := os.Stat(c); err == nil && info.Mode().IsRegular() {
				return c
			}
		}
		return ""
	}
	if info, err := os.Stat(path); err == nil && info.Mode().IsRegular() {
		return path
	}
	return ""
}

func (d *iosDiscovery) snapshot() []Device {
	if d == nil {
		return nil
	}
	d.mu.RLock()
	defer d.mu.RUnlock()
	return slices.Clone(d.devices)
}

func (d *iosDiscovery) run(ctx context.Context, onChange func(added, removed []string)) {
	for ctx.Err() == nil {
		d.refresh(ctx, onChange)

		timer := time.NewTimer(15 * time.Second)
		select {
		case <-ctx.Done():
			timer.Stop()
			return
		case <-timer.C:
		}
	}
}

func (d *iosDiscovery) refresh(ctx context.Context, onChange func(added, removed []string)) {
	output, err := d.command(ctx, "usbmux", "list")
	var devices []Device
	if err == nil {
		devices, err = parseIOSDevices(output)
	}
	if ctx.Err() != nil {
		return
	}
	if err != nil {
		Log.Add("iOS device discovery", err.Error(), err, 0)
		return
	}
	d.update(devices, onChange)
}

func (d *iosDiscovery) update(devices []Device, onChange func(added, removed []string)) {
	d.mu.Lock()
	previous := d.devices
	if slices.EqualFunc(previous, devices, func(a, b Device) bool {
		return a.Serial == b.Serial && a.Model == b.Model && a.Transport == b.Transport && a.iosUDID == b.iosUDID
	}) {
		d.mu.Unlock()
		return
	}
	d.devices = devices
	d.mu.Unlock()
	onChange(iosDeviceDifference(devices, previous), iosDeviceDifference(previous, devices))
}

func iosDeviceDifference(devices, other []Device) []string {
	serials := make(map[string]bool, len(other))
	for _, device := range other {
		serials[device.Serial] = true
	}
	var difference []string
	for _, device := range devices {
		if !serials[device.Serial] {
			difference = append(difference, device.Serial)
		}
	}
	return difference
}

func parseIOSDevices(output []byte) ([]Device, error) {
	var records []struct {
		Identifier     string
		UniqueDeviceID string
		DeviceName     string
		ProductType    string
		ConnectionType string
	}
	if err := json.Unmarshal(output, &records); err != nil {
		return nil, err
	}
	if records == nil {
		return nil, errors.New("expected an array in the iOS device list")
	}
	byID := make(map[string]Device, len(records))
	for _, record := range records {
		var transport string
		switch record.ConnectionType {
		case "USB":
			transport = "usb"
		case "Network":
			transport = "wifi"
		default:
			continue
		}
		udid := strings.TrimSpace(record.Identifier)
		id := strings.TrimSpace(record.UniqueDeviceID)
		if id == "" {
			id = udid
		}
		if id == "" {
			continue
		}
		if udid == "" {
			udid = id
		}
		serial := "ios:" + strings.ToUpper(id)
		if existing, ok := byID[serial]; ok && existing.Transport == "usb" {
			continue
		}
		name := record.DeviceName
		if name == "" {
			name = record.ProductType
		}
		byID[serial] = Device{
			Serial: serial, HardwareSerial: serial, State: "device", Model: name,
			Brand: "Apple", Platform: "ios", Transport: transport,
			Capabilities: []DeviceCapability{
				capabilityDeviceStatus,
				capabilityDeviceInfo,
				capabilityFiles,
				capabilityApps,
				capabilityClipboard,
				capabilityTestSession,
				capabilityScreenshot,
				capabilityCrashReports,
				capabilityIOSLiveLogs,
				capabilityIOSPcap,
				capabilityNetworkProxy,
			},
			iosUDID: udid,
		}
	}
	devices := make([]Device, 0, len(byID))
	for _, device := range byID {
		devices = append(devices, device)
	}
	slices.SortFunc(devices, func(a, b Device) int { return strings.Compare(a.Serial, b.Serial) })
	return devices, nil
}

func (d *iosDiscovery) udidFor(serial string, capability DeviceCapability) (string, error) {
	if d == nil {
		return "", errors.New("iOS device is unavailable")
	}
	for _, device := range d.snapshot() {
		if device.Serial == serial && device.iosUDID != "" && slices.Contains(device.Capabilities, capability) {
			return device.iosUDID, nil
		}
	}
	return "", errors.New("iOS device is unavailable")
}

func (d *iosDiscovery) CaptureScreenshot(ctx context.Context, serial string) ([]byte, error) {
	udid, err := d.udidFor(serial, capabilityScreenshot)
	if err != nil {
		return nil, err
	}
	dir, err := os.MkdirTemp("", "adb-tool-ios-shot-")
	if err != nil {
		return nil, err
	}
	defer os.RemoveAll(dir)
	target := filepath.Join(dir, "screenshot.png")
	if _, err := d.command(ctx, "developer", "dvt", "screenshot", "--udid", udid, target); err != nil {
		// Fall back to legacy developer screenshot command if dvt fails.
		if _, fallbackErr := d.command(ctx, "developer", "screenshot", "--udid", udid, target); fallbackErr != nil {
			Log.Add("iOS screenshot", err.Error(), err, 0)
			return nil, err
		}
	}
	data, err := os.ReadFile(target)
	if err != nil {
		return nil, err
	}
	if len(data) == 0 {
		return nil, errors.New("empty screenshot captured")
	}
	return data, nil
}

func (d *iosDiscovery) DeviceStatus(ctx context.Context, serial string) (*DeviceStatus, error) {
	udid, err := d.udidFor(serial, capabilityDeviceStatus)
	if err != nil {
		return nil, err
	}
	out, err := d.command(ctx, "adb-tool-ios", "status", "--udid", udid)
	if err != nil {
		return nil, err
	}
	var status DeviceStatus
	if err := json.Unmarshal(out, &status); err != nil {
		return nil, err
	}
	if status.TopProcesses == nil {
		status.TopProcesses = []ProcessStatus{}
	}
	return &status, nil
}

func (d *iosDiscovery) DeviceDetail(ctx context.Context, serial string) (map[string]string, error) {
	udid, err := d.udidFor(serial, capabilityDeviceInfo)
	if err != nil {
		return nil, err
	}
	out, err := d.command(ctx, "adb-tool-ios", "props", "--udid", udid)
	if err != nil {
		return nil, err
	}
	var props map[string]string
	if err := json.Unmarshal(out, &props); err != nil {
		return nil, err
	}
	return props, nil
}

func (d *iosDiscovery) InstalledPackages(ctx context.Context, serial string) ([]PackageInfo, error) {
	udid, err := d.udidFor(serial, capabilityApps)
	if err != nil {
		return nil, err
	}
	out, err := d.command(ctx, "adb-tool-ios", "apps-list", "--udid", udid)
	if err != nil {
		return nil, err
	}
	var pkgs []PackageInfo
	if err := json.Unmarshal(out, &pkgs); err != nil {
		return nil, err
	}
	return pkgs, nil
}

func (d *iosDiscovery) UninstallPackage(ctx context.Context, serial, bundleID string) error {
	udid, err := d.udidFor(serial, capabilityApps)
	if err != nil {
		return err
	}
	_, err = d.command(ctx, "adb-tool-ios", "apps-uninstall", "--udid", udid, bundleID)
	return err
}

func (d *iosDiscovery) InstallPackage(ctx context.Context, serial, localPath string) (string, error) {
	udid, err := d.udidFor(serial, capabilityApps)
	if err != nil {
		return "", err
	}
	out, err := d.command(ctx, "adb-tool-ios", "apps-install", "--udid", udid, localPath)
	return string(out), err
}

func (d *iosDiscovery) SendClipboard(ctx context.Context, serial, text string) error {
	udid, err := d.udidFor(serial, capabilityClipboard)
	if err != nil {
		return err
	}
	_, err = d.command(ctx, "adb-tool-ios", "clipboard-set", "--udid", udid, text)
	return err
}

func (d *iosDiscovery) ListFiles(ctx context.Context, serial, path string) ([]FileEntry, error) {
	udid, err := d.udidFor(serial, capabilityFiles)
	if err != nil {
		return nil, err
	}
	out, err := d.command(ctx, "adb-tool-ios", "afc-ls", "--udid", udid, path)
	if err != nil {
		return nil, err
	}
	var entries []FileEntry
	if err := json.Unmarshal(out, &entries); err != nil {
		return nil, err
	}
	return entries, nil
}

func (d *iosDiscovery) FileStat(ctx context.Context, serial, path string) (FileStat, error) {
	udid, err := d.udidFor(serial, capabilityFiles)
	if err != nil {
		return FileStat{}, err
	}
	out, err := d.command(ctx, "adb-tool-ios", "afc-stat", "--udid", udid, path)
	if err != nil {
		return FileStat{}, err
	}
	var st FileStat
	if err := json.Unmarshal(out, &st); err != nil {
		return FileStat{}, err
	}
	return st, nil
}

func (d *iosDiscovery) ReadFile(ctx context.Context, serial, path string) (string, error) {
	udid, err := d.udidFor(serial, capabilityFiles)
	if err != nil {
		return "", err
	}
	out, err := d.command(ctx, "adb-tool-ios", "afc-cat", "--udid", udid, path)
	if err != nil {
		return "", err
	}
	return string(out), nil
}

func (d *iosDiscovery) PullFileToPath(ctx context.Context, serial, remotePath, localPath string) error {
	udid, err := d.udidFor(serial, capabilityFiles)
	if err != nil {
		return err
	}
	_, err = d.command(ctx, "adb-tool-ios", "afc-pull", "--udid", udid, remotePath, localPath)
	return err
}

func (d *iosDiscovery) PushFileFromPath(ctx context.Context, serial, localPath, remotePath string) error {
	udid, err := d.udidFor(serial, capabilityFiles)
	if err != nil {
		return err
	}
	_, err = d.command(ctx, "adb-tool-ios", "afc-push", "--udid", udid, localPath, remotePath)
	return err
}

func (d *iosDiscovery) DeleteFile(ctx context.Context, serial, path string) error {
	udid, err := d.udidFor(serial, capabilityFiles)
	if err != nil {
		return err
	}
	_, err = d.command(ctx, "adb-tool-ios", "afc-rm", "--udid", udid, path)
	return err
}

func (d *iosDiscovery) RenameFile(ctx context.Context, serial, from, to string) error {
	udid, err := d.udidFor(serial, capabilityFiles)
	if err != nil {
		return err
	}
	_, err = d.command(ctx, "adb-tool-ios", "afc-mv", "--udid", udid, from, to)
	return err
}

func (d *iosDiscovery) MakeDir(ctx context.Context, serial, path string) error {
	udid, err := d.udidFor(serial, capabilityFiles)
	if err != nil {
		return err
	}
	_, err = d.command(ctx, "adb-tool-ios", "afc-mkdir", "--udid", udid, path)
	return err
}

func (d *iosDiscovery) TouchFile(ctx context.Context, serial, path string) error {
	udid, err := d.udidFor(serial, capabilityFiles)
	if err != nil {
		return err
	}
	_, err = d.command(ctx, "adb-tool-ios", "afc-touch", "--udid", udid, path)
	return err
}

func (d *iosDiscovery) StartPcap(ctx context.Context, serial, outPath, process, iface string) ([]byte, error) {
	udid, err := d.udidFor(serial, capabilityIOSPcap)
	if err != nil {
		return nil, err
	}
	args := []string{"adb-tool-ios", "pcap-start", "--udid", udid, outPath}
	if process != "" {
		args = append(args, process)
	} else if iface != "" {
		args = append(args, "")
	}
	if iface != "" {
		args = append(args, iface)
	}
	return d.command(ctx, args...)
}

func (d *iosDiscovery) PcapStatus(ctx context.Context, serial string) ([]byte, error) {
	udid, err := d.udidFor(serial, capabilityIOSPcap)
	if err != nil {
		return nil, err
	}
	return d.command(ctx, "adb-tool-ios", "pcap-status", "--udid", udid)
}

func (d *iosDiscovery) StopPcap(ctx context.Context, serial string) ([]byte, error) {
	udid, err := d.udidFor(serial, capabilityIOSPcap)
	if err != nil {
		return nil, err
	}
	return d.command(ctx, "adb-tool-ios", "pcap-stop", "--udid", udid)
}
