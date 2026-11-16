package server

import "context"

type deviceDiscovery interface {
	DevicesContext(ctx context.Context) ([]Device, error)
}

type screenshotCapturer interface {
	CaptureScreenshot(ctx context.Context, serial string) ([]byte, error)
}

// Device describes one row in GET /api/devices. Android reports one row per
// transport; iOS reports one per physical device with its preferred transport.
// HardwareSerial associates the physical device with saved sessions.
type Device struct {
	Serial         string             `json:"serial"`
	HardwareSerial string             `json:"hardwareSerial,omitempty"`
	State          string             `json:"state"`
	Model          string             `json:"model"`
	Brand          string             `json:"brand"`
	SDK            string             `json:"sdk"`
	Platform       string             `json:"platform"`
	Transport      string             `json:"transport,omitempty"`
	Capabilities   []DeviceCapability `json:"capabilities"`
}

type DeviceCapability string

const (
	capabilityDeviceStatus  DeviceCapability = "deviceStatus"
	capabilityDeviceInfo    DeviceCapability = "deviceInfo"
	capabilityLiveLogs      DeviceCapability = "liveLogs"
	capabilityFiles         DeviceCapability = "files"
	capabilityApps          DeviceCapability = "apps"
	capabilityClipboard     DeviceCapability = "clipboard"
	capabilityViewHierarchy DeviceCapability = "viewHierarchy"
	capabilityAdbCommands   DeviceCapability = "adbCommands"
	capabilityTestSession   DeviceCapability = "testSession"
	capabilityScreenMirror  DeviceCapability = "screenMirror"
	capabilityScreenshot    DeviceCapability = "screenshot"
	capabilityCrashReports  DeviceCapability = "crashReports"
)
