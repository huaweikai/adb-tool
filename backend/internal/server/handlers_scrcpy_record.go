// HTTP handlers for the windowless scrcpy recording endpoints. Mirror
// the handlers_scrcpy.go surface in shape but with the destination
// path computed by the backend (see ScrcpyRecordingSandboxDir in
// adb_scrcpy_record.go) — the Flutter side just kicks off the
// recording and the file shows up under ~/.adb-tool/scrcpy_recordings.
//
// All write paths use the standard envelope (see response.go). 4xx
// responses carry the discriminator in `data` so the Flutter side can
// tell mirror-busy from record-busy without parsing error strings.
package server

import (
	"errors"
	"net/http"
	"strconv"
	"time"
)

// handleScrcpyRecordingStart spawns a windowless scrcpy that records
// to a per-call file under ScrcpyRecordingSandboxDir(). See
// adb_scrcpy_record.go for the full conflict / force semantics.
//
// Request:
//
//	POST /api/scrcpy/record/start?serial=xxx[&force=true]
//
// Responses:
//   200 — {status: "started", serial, outputPath}
//   400 — invalid serial
//   409 — scrcpy busy (mirror or recording). `data.kind` is "mirror" or "record".
//   500 — spawn failure / scrcpy binary missing / sandbox dir error / adb-side error
func (s *Server) handleScrcpyRecordingStart(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	serial := q.Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	force, _ := strconv.ParseBool(q.Get("force"))

	outputPath, err := s.adb.StartScrcpyRecording(serial, force)
	if err == nil {
		writeJSON(w, map[string]interface{}{
			"status":     "started",
			"serial":     serial,
			"outputPath": outputPath,
		})
		return
	}

	var busy *scrcpyRecordBusyError
	if errors.As(err, &busy) {
		// 409 with the kind so the UI can branch on it
		// ("scrcpy is mirroring" vs "another recording is in progress").
		writeAPIResponse(w, http.StatusConflict, apiResponse{
			OK:    false,
			Data:  map[string]interface{}{"kind": string(busy.Kind), "serial": busy.Serial},
			Error: err.Error(),
		})
		return
	}

	// Spawn / binary / sandbox-dir errors land here.
	writeAPIError(w, http.StatusInternalServerError, err.Error())
}

// handleScrcpyRecordingStop gracefully stops the recording subprocess.
// No-op if nothing is running (returns 200 either way so the UI can
// safely call it on every state transition).
func (s *Server) handleScrcpyRecordingStop(w http.ResponseWriter, r *http.Request) {
	if err := s.adb.StopScrcpyRecording(); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, map[string]interface{}{"status": "stopped"})
}

// handleScrcpyRecordingStatus reports the windowless recording
// subprocess state. Mirrors /api/scrcpy/status in shape but adds
// `outputPath` (the host file scrcpy is writing to) so the UI can
// show "recording → /path/to/file.mp4" without having to re-derive
// it from settings.
func (s *Server) handleScrcpyRecordingStatus(w http.ResponseWriter, r *http.Request) {
	running, serial, outputPath, pid, elapsed := s.adb.ScrcpyRecordingStatus()

	requestedSerial := r.URL.Query().Get("serial")
	if requestedSerial != "" && serial != requestedSerial {
		// Caller asked about a specific device and the recording is on
		// a different one — report as not running. Matches the
		// /api/scrcpy/status behavior.
		running = false
		serial = ""
		outputPath = ""
		pid = 0
		elapsed = 0
	}

	writeJSON(w, map[string]interface{}{
		"running":    running,
		"serial":     serial,
		"outputPath": outputPath,
		"pid":        pid,
		"elapsed":    int64(elapsed / time.Second),
	})
}
