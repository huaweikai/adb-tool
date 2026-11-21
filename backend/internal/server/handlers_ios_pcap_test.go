package server

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"slices"
	"testing"
)

func TestIOSPcapHandlers(t *testing.T) {
	devices, err := parseIOSDevices([]byte(`[{"Identifier":"phone-pcap","UniqueDeviceID":"PHONE-PCAP","ConnectionType":"USB"}]`))
	if err != nil || len(devices) != 1 {
		t.Fatalf("discovery = %v, %v", devices, err)
	}

	pcapDir, err := iosPcapDir()
	if err != nil {
		t.Fatalf("failed to create pcap dir: %v", err)
	}
	testFilePath := filepath.Join(pcapDir, "test_capture.pcapng")
	testContent := []byte("fake-pcapng-binary-header-and-packets")
	if err := os.WriteFile(testFilePath, testContent, 0644); err != nil {
		t.Fatalf("failed to write test file: %v", err)
	}
	defer os.Remove(testFilePath)

	server := &Server{ios: &iosDiscovery{
		devices: devices,
		command: func(_ context.Context, args ...string) ([]byte, error) {
			if len(args) >= 4 && slices.Equal(args[:4], []string{"adb-tool-ios", "pcap-start", "--udid", "phone-pcap"}) {
				return []byte(`{"status":"capturing","active":true,"filePath":"` + filepath.ToSlash(testFilePath) + `","packets":0,"bytes":0}`), nil
			}
			if slices.Equal(args, []string{"adb-tool-ios", "pcap-status", "--udid", "phone-pcap"}) {
				return []byte(`{"status":"capturing","active":true,"filePath":"` + filepath.ToSlash(testFilePath) + `","packets":42,"bytes":1024,"duration":5.2}`), nil
			}
			if slices.Equal(args, []string{"adb-tool-ios", "pcap-stop", "--udid", "phone-pcap"}) {
				return []byte(`{"status":"stopped","active":false,"filePath":"` + filepath.ToSlash(testFilePath) + `","packets":42,"bytes":1024,"duration":5.2}`), nil
			}
			t.Fatalf("unexpected command: %v", args)
			return nil, nil
		},
	}}

	// 1. Test Start
	{
		rec := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodPost, "/api/ios/pcap/start?serial=ios:PHONE-PCAP&process=Safari&interface=en0", nil)
		server.handleIOSPcapStart(rec, req)
		if rec.Code != http.StatusOK {
			t.Fatalf("start status = %d, body = %s", rec.Code, rec.Body)
		}
		var resp struct {
			OK   bool           `json:"ok"`
			Data pcapStatusData `json:"data"`
		}
		if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil || !resp.OK || resp.Data.Status != "capturing" {
			t.Fatalf("unexpected start response: %s", rec.Body)
		}
	}

	// 2. Test Status
	{
		rec := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, "/api/ios/pcap/status?serial=ios:PHONE-PCAP", nil)
		server.handleIOSPcapStatus(rec, req)
		if rec.Code != http.StatusOK {
			t.Fatalf("status code = %d, body = %s", rec.Code, rec.Body)
		}
		var resp struct {
			OK   bool           `json:"ok"`
			Data pcapStatusData `json:"data"`
		}
		if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil || !resp.OK || resp.Data.Packets != 42 {
			t.Fatalf("unexpected status response: %s", rec.Body)
		}
	}

	// 3. Test Stop
	{
		rec := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodPost, "/api/ios/pcap/stop?serial=ios:PHONE-PCAP", nil)
		server.handleIOSPcapStop(rec, req)
		if rec.Code != http.StatusOK {
			t.Fatalf("stop code = %d, body = %s", rec.Code, rec.Body)
		}
		var resp struct {
			OK   bool           `json:"ok"`
			Data pcapStatusData `json:"data"`
		}
		if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil || !resp.OK || resp.Data.Status != "stopped" {
			t.Fatalf("unexpected stop response: %s", rec.Body)
		}
	}

	// 4. Test Download
	{
		rec := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, "/api/ios/pcap/download?serial=ios:PHONE-PCAP&path="+testFilePath, nil)
		server.handleIOSPcapDownload(rec, req)
		if rec.Code != http.StatusOK {
			t.Fatalf("download code = %d, body = %s", rec.Code, rec.Body)
		}
		if rec.Body.String() != string(testContent) {
			t.Fatalf("download content mismatch: got %q, want %q", rec.Body.String(), testContent)
		}
		if rec.Header().Get("Content-Type") != "application/vnd.tcpdump.pcap" {
			t.Fatalf("unexpected content type: %s", rec.Header().Get("Content-Type"))
		}
	}

	// 5. Security & error checks
	for _, test := range []struct {
		url  string
		want int
	}{
		{"/api/ios/pcap/start?serial=ios:UNKNOWN", http.StatusNotFound},
		{"/api/ios/pcap/start?serial=android-device", http.StatusBadRequest},
		{"/api/ios/pcap/download?serial=ios:PHONE-PCAP&path=../../etc/passwd", http.StatusForbidden},
		{"/api/ios/pcap/download?serial=ios:PHONE-PCAP&path=" + filepath.Join(pcapDir, "non_existent.pcapng"), http.StatusNotFound},
	} {
		rec := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, test.url, nil)
		if slices.Contains([]string{"/api/ios/pcap/start"}, req.URL.Path) {
			server.handleIOSPcapStart(rec, req)
		} else {
			server.handleIOSPcapDownload(rec, req)
		}
		if rec.Code != test.want {
			t.Errorf("url %s got code %d, want %d", test.url, rec.Code, test.want)
		}
	}
}
