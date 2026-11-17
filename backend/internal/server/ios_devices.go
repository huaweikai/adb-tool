package server

import (
	"bytes"
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
	return &iosDiscovery{ctx: shutdownCtx, command: func(ctx context.Context, args ...string) ([]byte, error) {
		ctx, cancel := context.WithTimeout(ctx, 25*time.Second)
		defer cancel()
		if err := shutdownCtx.Err(); err != nil {
			return nil, err
		}
		stop := context.AfterFunc(shutdownCtx, cancel)
		defer stop()
		var output bytes.Buffer
		err := runIOSCLI(ctx, cli, &output, args...)
		return output.Bytes(), err
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
		path = filepath.Join(filepath.Dir(executable), name)
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
			Capabilities: []DeviceCapability{capabilityCrashReports, capabilityIOSLiveLogs},
			iosUDID:      udid,
		}
	}
	devices := make([]Device, 0, len(byID))
	for _, device := range byID {
		devices = append(devices, device)
	}
	slices.SortFunc(devices, func(a, b Device) int { return strings.Compare(a.Serial, b.Serial) })
	return devices, nil
}
