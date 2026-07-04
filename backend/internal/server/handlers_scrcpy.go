package server

import (
	"encoding/json"
	"net/http"
	"strings"
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
//
// Accepts an optional JSON body with a `scrcpy_options` field:
//
//	POST /api/scrcpy/start?serial=xxx
//	Content-Type: application/json
//	{"scrcpy_options": {"max_size": 1024, "video_bit_rate": "8M", ...}}
//
// If the body is missing or empty, defaults are used. Invalid options
// return 400 with the validation error so the UI can surface it
// (instead of a confusing "scrcpy exited with code 1" five seconds
// later).
func (s *Server) handleScrcpyStart(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}

	opts := ScrcpyOptions{}
	// Body is optional — empty body means "just use defaults".
	if r.ContentLength != 0 && r.Body != nil {
		var body struct {
			Opts ScrcpyOptions `json:"scrcpy_options"`
		}
		dec := json.NewDecoder(r.Body)
		dec.DisallowUnknownFields()
		if err := dec.Decode(&body); err != nil {
			writeAPIError(w, http.StatusBadRequest, "invalid JSON body: "+err.Error())
			return
		}
		opts = body.Opts
	}

	if err := s.adb.StartScrcpy(serial, opts); err != nil {
		// Validate() errors get surfaced as 400, real spawn failures
		// as 500. Caller can branch on status code.
		if isValidationError(err) {
			writeAPIError(w, http.StatusBadRequest, err.Error())
			return
		}
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, map[string]interface{}{
		"status": "started",
		"serial": serial,
	})
}

// isValidationError identifies errors coming from ScrcpyOptions.Validate
// so we can return 400 instead of 500. The Validate wrapper prefixes
// the error with "invalid scrcpy options:" so a substring check is
// reliable.
func isValidationError(err error) bool {
	if err == nil {
		return false
	}
	return strings.Contains(err.Error(), "invalid scrcpy options:")
}

// handleScrcpyStop kills the mirror subprocess for the given device.
// Returns 200 even if nothing was running.
func (s *Server) handleScrcpyStop(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	if err := s.adb.StopScrcpy(serial); err != nil {
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

// handleScrcpyStatus reports whether scrcpy is running on the given
// device. Optional `serial` query param: when provided, only returns
// running=true if the running scrcpy is attached to that serial.
func (s *Server) handleScrcpyStatus(w http.ResponseWriter, r *http.Request) {
	requestedSerial := r.URL.Query().Get("serial")
	running, serial, pid, elapsed := s.adb.ScrcpyStatus(requestedSerial)

	writeJSON(w, map[string]interface{}{
		"running": running,
		"serial":  serial,
		"pid":     pid,
		"elapsed": int64(elapsed / time.Second),
	})
}