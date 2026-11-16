package server

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"slices"
	"testing"
)

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
