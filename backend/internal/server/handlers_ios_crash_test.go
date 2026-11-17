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

func TestIOSCrashReportsListAndDownload(t *testing.T) {
	const name = "Sample Report.ips"
	const contents = "{\"raw\":true}\n"
	devices, err := parseIOSDevices([]byte(`[{"Identifier":"phone-a","UniqueDeviceID":"PHONE-A","ConnectionType":"USB"}]`))
	if err != nil || len(devices) != 1 {
		t.Fatalf("discovery = %v, %v", devices, err)
	}
	server := &Server{ios: &iosDiscovery{
		devices: devices,
		command: func(_ context.Context, args ...string) ([]byte, error) {
			if slices.Equal(args, []string{"crash", "ls", "--udid", "phone-a"}) {
				return []byte("/DiagnosticLogs\r\n/" + name + "\r\n/" + name + "\n/../escape.ips\n"), nil
			}
			if len(args) != 6 || !slices.Equal(args[:4], []string{"crash", "pull", "--udid", "phone-a"}) || args[5] != "/"+name {
				t.Fatalf("unexpected command: %v", args)
			}
			return nil, os.WriteFile(filepath.Join(args[4], name), []byte(contents), 0600)
		},
	}}
	list := httptest.NewRecorder()
	server.handleIOSCrashReports(list, httptest.NewRequest(http.MethodGet, "/api/ios/crash-reports?serial=ios:PHONE-A", nil))
	var payload struct{ Data []string }
	if err := json.Unmarshal(list.Body.Bytes(), &payload); err != nil || list.Code != http.StatusOK || !slices.Equal(payload.Data, []string{name}) {
		t.Fatalf("unexpected list: %d %s", list.Code, list.Body)
	}
	download := httptest.NewRecorder()
	server.handleIOSCrashReport(download, httptest.NewRequest(http.MethodGet, "/api/ios/crash-report?serial=ios:PHONE-A&name=Sample+Report.ips", nil))
	if download.Code != http.StatusOK || download.Body.String() != contents || download.Header().Get("Content-Disposition") == "" {
		t.Fatalf("unexpected download: %d %s", download.Code, download.Body)
	}

	for _, test := range []struct {
		query string
		want  int
	}{
		{"serial=ios:PHONE-A&name=..%2Fescape.ips", http.StatusBadRequest},
		{"serial=ios:PHONE-B&name=Sample.ips", http.StatusNotFound},
		{"serial=ANDROID&name=Sample.ips", http.StatusBadRequest},
	} {
		response := httptest.NewRecorder()
		server.handleIOSCrashReport(response, httptest.NewRequest(http.MethodGet, "/api/ios/crash-report?"+test.query, nil))
		if response.Code != test.want {
			t.Errorf("request %s returned %d, want %d", test.query, response.Code, test.want)
		}
	}
}
