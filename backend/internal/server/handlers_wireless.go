package server

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"
	"time"
)

// handleAdbWirelessPair pairs the desktop with a device over Wi-Fi.
func (s *Server) handleAdbWirelessPair(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	defer r.Body.Close()
	var req struct {
		Address string `json:"address"`
		Code    string `json:"code"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	req.Address = strings.TrimSpace(req.Address)
	req.Code = strings.TrimSpace(req.Code)
	if req.Address == "" || req.Code == "" {
		writeAPIError(w, http.StatusBadRequest, "address and code required")
		return
	}
	output, err := s.adb.WirelessPairContext(r.Context(), req.Address, req.Code)
	if err != nil {
		writeAPIErrorData(w, http.StatusBadRequest, err.Error(), map[string]interface{}{"ok": false, "output": output})
		return
	}
	writeJSON(w, map[string]interface{}{"ok": true, "output": output})
}

// handleAdbWirelessConnect connects to a paired device over Wi-Fi.
func (s *Server) handleAdbWirelessConnect(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	defer r.Body.Close()
	var req struct {
		Address string `json:"address"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	req.Address = strings.TrimSpace(req.Address)
	if req.Address == "" {
		writeAPIError(w, http.StatusBadRequest, "address required")
		return
	}
	output, err := s.adb.WirelessConnectContext(r.Context(), req.Address)
	if err != nil {
		writeAPIErrorData(w, http.StatusBadRequest, err.Error(), map[string]interface{}{"ok": false, "output": output})
		return
	}
	writeJSON(w, map[string]interface{}{"ok": true, "output": output})
}

// handleAdbWirelessDisconnect drops the wireless ADB connection for a serial.
func (s *Server) handleAdbWirelessDisconnect(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	defer r.Body.Close()
	var req struct {
		Serial string `json:"serial"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	req.Serial = strings.TrimSpace(req.Serial)
	if req.Serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	output, err := s.adb.WirelessDisconnectContext(r.Context(), req.Serial)
	if err != nil {
		writeAPIErrorData(w, http.StatusBadRequest, err.Error(), map[string]interface{}{"ok": false, "output": output})
		return
	}
	writeJSON(w, map[string]interface{}{"ok": true, "output": output})
}

// handleAdbWirelessScan scans for devices reachable over Wi-Fi ADB.
func (s *Server) handleAdbWirelessScan(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		writeAPIError(w, http.StatusMethodNotAllowed, "GET required")
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
	defer cancel()
	devices, output, err := s.adb.ScanWirelessAdb(ctx)
	data := map[string]interface{}{"devices": devices, "output": output}
	if err != nil {
		if ctx.Err() == context.DeadlineExceeded {
			writeJSON(w, data)
			return
		}
		writeAPIErrorData(w, http.StatusBadRequest, err.Error(), data)
		return
	}
	writeJSON(w, data)
}
