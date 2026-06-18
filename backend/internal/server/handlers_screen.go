package server

import (
	"net/http"
	"time"
)

// handleScreenshot captures and returns a PNG screenshot of the device.
func (s *Server) handleScreenshot(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	data, err := s.adb.Screenshot(serial)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	w.Header().Set("Content-Type", "image/png")
	if _, err := w.Write(data); err != nil {
		Log.Add("http screenshot response", "", err, 0)
	}
}

// handleScreenRecord controls screen recording (start / stop / status).
// The recordingSerial / recordStarted fields on Server are guarded by recordMu.
func (s *Server) handleScreenRecord(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	action := r.URL.Query().Get("action")

	switch action {
	case "start":
		if serial == "" {
			writeAPIError(w, http.StatusBadRequest, "serial required")
			return
		}
		s.recordMu.Lock()
		// If we think a recording is already in flight (e.g. the previous
		// session was killed without calling /stop), stop it first so the
		// device-side process is killed and we're in a clean state to start
		// a fresh one. The previous recording is unrecoverable anyway.
		if s.recordingSerial != "" {
			staleSerial := s.recordingSerial
			s.recordingSerial = ""
			s.recordStarted = time.Time{}
			s.recordMu.Unlock()
			// Best-effort cleanup — ignore errors (process may already be dead).
			s.adb.StopScreenRecord(staleSerial)
		} else {
			s.recordMu.Unlock()
		}
		if err := s.adb.StartScreenRecord(serial); err != nil {
			writeAPIError(w, http.StatusInternalServerError, err.Error())
			return
		}
		s.recordMu.Lock()
		s.recordingSerial = serial
		s.recordStarted = time.Now()
		s.recordMu.Unlock()
		writeJSON(w, map[string]interface{}{"status": "recording", "serial": serial})

	case "stop":
		s.recordMu.Lock()
		if s.recordingSerial == "" {
			s.recordMu.Unlock()
			writeAPIError(w, http.StatusConflict, "not recording")
			return
		}
		serial := s.recordingSerial
		started := s.recordStarted
		s.recordMu.Unlock()

		err := s.adb.StopScreenRecord(serial)

		s.recordMu.Lock()
		if s.recordingSerial == serial {
			s.recordingSerial = ""
			s.recordStarted = time.Time{}
		}
		s.recordMu.Unlock()

		if err != nil {
			writeAPIError(w, http.StatusInternalServerError, err.Error())
			return
		}

		elapsed := time.Since(started).Seconds()
		writeJSON(w, map[string]interface{}{
			"status":  "stopped",
			"elapsed": elapsed,
		})

	case "status":
		s.recordMu.Lock()
		if s.recordingSerial == "" {
			s.recordMu.Unlock()
			writeJSON(w, map[string]interface{}{"recording": false})
			return
		}
		serial := s.recordingSerial
		started := s.recordStarted
		s.recordMu.Unlock()

		if !s.adb.IsScreenRecording(serial) {
			s.recordMu.Lock()
			if s.recordingSerial == serial {
				s.recordingSerial = ""
				s.recordStarted = time.Time{}
			}
			s.recordMu.Unlock()
			writeJSON(w, map[string]interface{}{"recording": false})
			return
		}

		elapsed := time.Since(started).Seconds()
		writeJSON(w, map[string]interface{}{
			"recording": true,
			"serial":    serial,
			"elapsed":   elapsed,
		})

	default:
		writeAPIError(w, http.StatusBadRequest, "action must be start, stop, or status")
	}
}

// handleScreenRecordVideo returns the most recently recorded screen video and cleans it up.
func (s *Server) handleScreenRecordVideo(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}
	data, err := s.adb.PullRecordedVideo(serial)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	go s.adb.CleanRecordedVideo(serial)
	w.Header().Set("Content-Type", "video/mp4")
	w.Header().Set("Content-Disposition", "attachment; filename=\"screen-record.mp4\"")
	if _, err := w.Write(data); err != nil {
		Log.Add("http screen-record response", "", err, 0)
	}
}
