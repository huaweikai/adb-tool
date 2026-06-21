package server

import (
	"net/http"
	"time"
)

// handleScrcpyStart spawns the bundled scrcpy subprocess against the
// given device. Kills any previous scrcpy instance first — there's
// only one SDL window per host.
//
// The "video stream lives in scrcpy's own window" model means the HTTP
// response here is just an acknowledgement; the actual mirror pixels
// appear in the OS-level window scrcpy opens. The Flutter UI tells the
// user "scrcpy window should be visible now" rather than trying to
// embed the stream (which would need scrcpy-web + webview).
func (s *Server) handleScrcpyStart(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}

	if err := s.adb.StartScrcpy(serial); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, map[string]interface{}{
		"status": "started",
		"serial": serial,
	})
}

// handleScrcpyStop kills the running scrcpy subprocess. Returns 200
// even if nothing was running — stopping a non-running scrcpy is a
// no-op from the user's perspective and shouldn't surface as an error.
func (s *Server) handleScrcpyStop(w http.ResponseWriter, r *http.Request) {
	if err := s.adb.StopScrcpy(); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]interface{}{"status": "stopped"})
}

// handleScrcpyAction fires a system-level shortcut (home/back/recents/
// power/etc.) against the given device. Uses `adb shell input keyevent`
// so it works regardless of whether the scrcpy window is focused or
// even running — these are device-side events, not host key presses.
func (s *Server) handleScrcpyAction(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	action := scrcpyAction(r.URL.Query().Get("action"))

	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	if action == "" {
		writeAPIError(w, http.StatusBadRequest, "action required")
		return
	}
	// Reject unknown actions at the handler boundary so the error
	// surfaces as 400 instead of a generic 500 from the adb layer.
	if _, err := action.androidKeyCode(); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}

	if err := s.adb.ScrcpyShortcut(serial, action); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]interface{}{
		"status": "ok",
		"action": string(action),
	})
}

// handleScrcpyStatus reports whether scrcpy is running and on which
// device. Optional `serial` query param: when provided, only returns
// running=true if the running scrcpy is attached to that serial.
// Used by the Flutter UI on tab open to decide whether to show
// "Start" or "Stop".
func (s *Server) handleScrcpyStatus(w http.ResponseWriter, r *http.Request) {
	running, serial, pid, elapsed := s.adb.ScrcpyStatus()

	requestedSerial := r.URL.Query().Get("serial")
	if requestedSerial != "" && serial != requestedSerial {
		running = false
	}

	writeJSON(w, map[string]interface{}{
		"running": running,
		"serial":  serial,
		"pid":     pid,
		"elapsed": int64(elapsed / time.Second),
	})
}