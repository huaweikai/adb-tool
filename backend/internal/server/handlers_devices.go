package server

import (
	"fmt"
	"net/http"
	"time"
)

// handleDevices returns the list of currently connected devices.
//
// Backed by the AdbEventStream's snapshot (one persistent track-devices
// connection feeds the snapshot in near-realtime), so this no longer
// spawns `adb devices -l` per request. If the stream isn't connected
// yet the snapshot is an empty slice — the client treats that as
// "no devices", not as a backend failure. Backend liveness should be
// detected via /api/identify or similar.
func (s *Server) handleDevices(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	Log.Add("handle devices start", "", nil, 0)

	devices := s.eventStream.Snapshot()
	onlineCount := 0
	for _, d := range devices {
		if d.State == "device" {
			onlineCount++
		}
	}
	Log.Add(
		"handle devices done",
		fmt.Sprintf("total=%d online=%d", len(devices), onlineCount),
		nil, time.Since(start),
	)
	writeJSON(w, devices)
}

// handleClear clears the logcat buffer for a device.
func (s *Server) handleClear(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	if err := s.adb.ClearLogcat(serial); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

// handleDeviceInfo returns the getprop output for a device.
func (s *Server) handleDeviceInfo(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	output, err := s.adb.Shell(serial, "getprop")
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]string{"props": output})
}

// handlePackagePID returns the PID of a running package, or empty string on error.
func (s *Server) handlePackagePID(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	packageName := r.URL.Query().Get("package")
	if serial == "" || packageName == "" {
		writeAPIError(w, http.StatusBadRequest, "serial and package required")
		return
	}
	pid, err := s.adb.GetPackagePID(serial, packageName)
	if err != nil {
		writeAPIErrorData(w, http.StatusInternalServerError, err.Error(), map[string]string{"pid": ""})
		return
	}
	writeJSON(w, map[string]string{"pid": pid})
}

// handleRunningPackages returns the list of packages currently running on the device.
func (s *Server) handleRunningPackages(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	pkgs, err := s.adb.GetRunningPackages(serial)
	if err != nil {
		writeAPIErrorData(w, http.StatusInternalServerError, err.Error(), map[string]interface{}{"packages": []string{}})
		return
	}
	if pkgs == nil {
		pkgs = []string{}
	}
	writeJSON(w, map[string]interface{}{"packages": pkgs})
}

// handleAdbPath returns the path of the ADB binary in use.
func (s *Server) handleAdbPath(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]string{"path": s.adb.AdbPath()})
}

// handleDeviceDetail returns the full set of device properties (parsed getprop).
func (s *Server) handleDeviceDetail(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	props, err := s.adb.DeviceDetail(serial)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if props == nil {
		props = map[string]string{}
	}
	writeJSON(w, map[string]interface{}{"props": props})
}

// handleDeviceStatus returns the live device status snapshot (battery, memory, cpu, ...).
func (s *Server) handleDeviceStatus(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	status, err := s.adb.DeviceStatus(r.Context(), serial)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]interface{}{"status": status})
}
