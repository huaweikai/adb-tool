package server

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"slices"
	"strings"
	"testing"
)

func osWriteTestFile(path string, data []byte) error {
	return os.WriteFile(path, data, 0600)
}

func TestIOSScreenRecordingUnavailableUntilNativeCapture(t *testing.T) {
	for _, action := range []string{"start", "stop", "status"} {
		t.Run(action, func(t *testing.T) {
			server := &Server{recordingSerial: "android-recording"}
			res := httptest.NewRecorder()
			server.handleScreenRecord(res, httptest.NewRequest(http.MethodGet,
				"/api/screen-record?serial=ios:PHONE-A&action="+action, nil))
			if res.Code != http.StatusNotImplemented || server.recordingSerial != "android-recording" {
				t.Fatalf("unsupported recording changed state: %d, %q", res.Code, server.recordingSerial)
			}
		})
	}
	res := httptest.NewRecorder()
	(&Server{}).handleScreenRecordVideo(res, httptest.NewRequest(http.MethodGet,
		"/api/screen-record/video?serial=ios:PHONE-A", nil))
	if res.Code != http.StatusNotImplemented {
		t.Fatalf("unsupported video download returned %d", res.Code)
	}
}

func TestIOSDevicesStableAcrossWirelessAndUSB(t *testing.T) {
	dual, err := parseIOSDevices([]byte(`[
		{"Identifier":"phone-a","ConnectionType":"Network","DeviceName":"First iPhone"},
		{"UniqueDeviceID":"PHONE-A","ConnectionType":"USB","DeviceName":"First iPhone"},
		{"Identifier":"phone-b","ConnectionType":"Network","DeviceName":"Second iPhone"},
		{"ConnectionType":"Network"}
	]`))
	if err != nil || len(dual) != 2 {
		t.Fatalf("discovery = %v, %v, want two physical devices", dual, err)
	}
	if dual[0].Serial != "ios:PHONE-A" || dual[0].HardwareSerial != dual[0].Serial ||
		dual[0].Transport != "usb" || dual[1].Serial != "ios:PHONE-B" || dual[1].Transport != "wifi" {
		t.Fatalf("unexpected transports: %+v", dual)
	}

	wireless, err := parseIOSDevices([]byte(`[
		{"UniqueDeviceID":"phone-a","ConnectionType":"Network","DeviceName":"First iPhone"},
		{"Identifier":"phone-b","ConnectionType":"Network","DeviceName":"Second iPhone"}
	]`))
	if err != nil || len(wireless) != 2 {
		t.Fatalf("wireless discovery = %v, %v, want two physical devices", wireless, err)
	}
	discovery := &iosDiscovery{devices: dual}
	changed := false
	discovery.update(wireless, func(added, removed []string) {
		changed = true
		if len(added) > 0 || len(removed) > 0 {
			t.Fatalf("transport switch added %v or removed %v", added, removed)
		}
	})
	if !changed || discovery.snapshot()[0].Transport != "wifi" {
		t.Fatal("transport switch did not publish the new snapshot")
	}
}

func TestIOSRefreshKeepsLastSnapshotUntilSuccessfulScan(t *testing.T) {
	const serial = "ios:PHONE-A"
	discovery := &iosDiscovery{devices: []Device{{Serial: serial}}}
	for _, test := range []struct {
		name   string
		output string
		err    error
	}{
		{name: "CLI failed", err: context.DeadlineExceeded},
		{name: "invalid JSON", output: "incomplete output"},
		{name: "missing list", output: "null"},
	} {
		t.Run(test.name, func(t *testing.T) {
			discovery.command = func(context.Context, ...string) ([]byte, error) {
				return []byte(test.output), test.err
			}
			discovery.refresh(context.Background(), func(_, _ []string) {
				t.Fatal("failed scan emitted a device change")
			})
			if rows := discovery.snapshot(); len(rows) != 1 || rows[0].Serial != serial {
				t.Fatalf("failed scan discarded the known device: %v", rows)
			}
		})
	}
	discovery.command = func(context.Context, ...string) ([]byte, error) {
		return []byte("[]"), nil
	}
	changed := false
	discovery.refresh(context.Background(), func(added, removed []string) {
		changed = true
		if len(added) != 0 || !slices.Equal(removed, []string{serial}) {
			t.Fatalf("successful scan reported unexpected change: +%v -%v", added, removed)
		}
	})
	if !changed || len(discovery.snapshot()) != 0 {
		t.Fatal("successful empty scan did not remove the device")
	}
}

func TestIOSScreenshotUsesDVTAndFallback(t *testing.T) {
	const png = "\x89PNG\r\n\x1a\n"
	devices, err := parseIOSDevices([]byte(`[{"Identifier":"phone-a","UniqueDeviceID":"PHONE-A","ConnectionType":"USB"}]`))
	if err != nil || len(devices) != 1 {
		t.Fatalf("discovery = %v, %v", devices, err)
	}
	if !slices.Equal(devices[0].Capabilities, []DeviceCapability{
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
	}) {
		t.Fatalf("unexpected capabilities: %v", devices[0].Capabilities)
	}

	t.Run("dvt screenshot succeeds", func(t *testing.T) {
		server := &Server{ios: &iosDiscovery{
			devices: devices,
			command: func(_ context.Context, args ...string) ([]byte, error) {
				if len(args) != 6 || !slices.Equal(args[:5], []string{"developer", "dvt", "screenshot", "--udid", "phone-a"}) {
					t.Fatalf("unexpected command: %v", args)
				}
				return nil, osWriteTestFile(args[5], []byte(png))
			},
		}}
		response := httptest.NewRecorder()
		server.handleScreenshot(response, httptest.NewRequest(http.MethodGet, "/api/screenshot?serial=ios:PHONE-A", nil))
		if response.Code != http.StatusOK || response.Header().Get("Content-Type") != "image/png" || response.Body.String() != png {
			t.Fatalf("unexpected response: %d %s", response.Code, response.Body.String())
		}
	})

	t.Run("legacy developer screenshot fallback succeeds", func(t *testing.T) {
		calls := 0
		server := &Server{ios: &iosDiscovery{
			devices: devices,
			command: func(_ context.Context, args ...string) ([]byte, error) {
				calls++
				if calls == 1 {
					return nil, errors.New("dvt unavailable")
				}
				if len(args) != 5 || !slices.Equal(args[:4], []string{"developer", "screenshot", "--udid", "phone-a"}) {
					t.Fatalf("unexpected fallback command: %v", args)
				}
				return nil, osWriteTestFile(args[4], []byte(png))
			},
		}}
		response := httptest.NewRecorder()
		server.handleScreenshot(response, httptest.NewRequest(http.MethodGet, "/api/screenshot?serial=ios:PHONE-A", nil))
		if response.Code != http.StatusOK || response.Body.String() != png {
			t.Fatalf("unexpected fallback response: %d %s", response.Code, response.Body.String())
		}
	})
}

type fixedDeviceDiscovery struct {
	devices []Device
	err     error
}

func (d fixedDeviceDiscovery) DevicesContext(context.Context) ([]Device, error) {
	return d.devices, d.err
}

func TestDeviceListCombinesPlatforms(t *testing.T) {
	phone := Device{Serial: "ios:PHONE-A", Platform: "ios", Transport: "wifi", State: "device"}
	android := Device{Serial: "android-a", Platform: "android", State: "device"}
	for _, test := range []struct {
		name    string
		android fixedDeviceDiscovery
		ios     *iosDiscovery
		want    []string
	}{
		{"both platforms", fixedDeviceDiscovery{devices: []Device{android}}, &iosDiscovery{devices: []Device{phone}}, []string{android.Serial, phone.Serial}},
		{"Android unavailable", fixedDeviceDiscovery{err: errors.New("ADB unavailable")}, &iosDiscovery{devices: []Device{phone}}, []string{phone.Serial}},
		{"iOS unavailable", fixedDeviceDiscovery{devices: []Device{android}}, nil, []string{android.Serial}},
	} {
		t.Run(test.name, func(t *testing.T) {
			server := &Server{deviceDiscovery: test.android, ios: test.ios}
			response := httptest.NewRecorder()
			server.handleDevices(response, httptest.NewRequest(http.MethodGet, "/api/devices", nil))
			var payload struct {
				Data []Device
			}
			if err := json.Unmarshal(response.Body.Bytes(), &payload); err != nil {
				t.Fatal(err)
			}
			var serials []string
			for _, device := range payload.Data {
				serials = append(serials, device.Serial)
			}
			if response.Code != http.StatusOK || !slices.Equal(serials, test.want) {
				t.Fatalf("status %d, devices %v, want %v", response.Code, serials, test.want)
			}
		})
	}
}

func TestIOSHandlersStatusFilesAppsClipboard(t *testing.T) {
	devices, err := parseIOSDevices([]byte(`[{"Identifier":"phone-a","UniqueDeviceID":"PHONE-A","ConnectionType":"USB"}]`))
	if err != nil || len(devices) != 1 {
		t.Fatalf("discovery = %v, %v", devices, err)
	}
	server := &Server{ios: &iosDiscovery{
		devices: devices,
		command: func(_ context.Context, args ...string) ([]byte, error) {
			switch {
			case slices.Equal(args, []string{"adb-tool-ios", "status", "--udid", "phone-a"}):
				return []byte(`{"batteryLevel":"88","batteryStatus":"Charging","storageTotal":"128.0 GB"}`), nil
			case slices.Equal(args, []string{"adb-tool-ios", "props", "--udid", "phone-a"}):
				return []byte(`{"ProductType":"iPhone17,2","ProductVersion":"27.3"}`), nil
			case slices.Equal(args, []string{"adb-tool-ios", "apps-list", "--udid", "phone-a"}):
				return []byte(`[{"packageName":"com.example.demo","sourceDir":"Demo (1.0)"}]`), nil
			case slices.Equal(args, []string{"adb-tool-ios", "afc-ls", "--udid", "phone-a", "/"}):
				return []byte(`[{"name":"DCIM","path":"/DCIM","isDir":true,"permissions":"drwxr-xr-x"}]`), nil
			case slices.Equal(args, []string{"adb-tool-ios", "clipboard-set", "--udid", "phone-a", "hello ios"}):
				return nil, nil
			default:
				t.Fatalf("unexpected iOS CLI args: %v", args)
				return nil, nil
			}
		},
	}}

	t.Run("device status", func(t *testing.T) {
		res := httptest.NewRecorder()
		server.handleDeviceStatus(res, httptest.NewRequest(http.MethodGet, "/api/device-status?serial=ios:PHONE-A", nil))
		if res.Code != http.StatusOK || !strings.Contains(res.Body.String(), `"batteryLevel":"88"`) {
			t.Fatalf("unexpected status response: %d %s", res.Code, res.Body.String())
		}
	})

	t.Run("device detail", func(t *testing.T) {
		res := httptest.NewRecorder()
		server.handleDeviceDetail(res, httptest.NewRequest(http.MethodGet, "/api/device-detail?serial=ios:PHONE-A", nil))
		if res.Code != http.StatusOK || !strings.Contains(res.Body.String(), `"ProductType":"iPhone17,2"`) {
			t.Fatalf("unexpected detail response: %d %s", res.Code, res.Body.String())
		}
	})

	t.Run("packages list", func(t *testing.T) {
		res := httptest.NewRecorder()
		server.handlePackages(res, httptest.NewRequest(http.MethodGet, "/api/packages?serial=ios:PHONE-A", nil))
		if res.Code != http.StatusOK || !strings.Contains(res.Body.String(), `"packageName":"com.example.demo"`) {
			t.Fatalf("unexpected packages response: %d %s", res.Code, res.Body.String())
		}
	})

	t.Run("files list", func(t *testing.T) {
		res := httptest.NewRecorder()
		server.handleFiles(res, httptest.NewRequest(http.MethodGet, "/api/files?serial=ios:PHONE-A&path=/", nil))
		if res.Code != http.StatusOK || !strings.Contains(res.Body.String(), `"name":"DCIM"`) {
			t.Fatalf("unexpected files response: %d %s", res.Code, res.Body.String())
		}
	})

	t.Run("clipboard send", func(t *testing.T) {
		res := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodPost, "/api/clipboard/send?serial=ios:PHONE-A", strings.NewReader(`{"text":"hello ios"}`))
		server.handleClipboardSend(res, req)
		if res.Code != http.StatusOK {
			t.Fatalf("unexpected clipboard response: %d %s", res.Code, res.Body.String())
		}
	})
}
