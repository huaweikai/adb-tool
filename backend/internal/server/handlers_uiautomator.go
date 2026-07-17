package server

import (
	"net/http"
)

func (s *Server) handleViewHierarchyDump(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}

	dump, err := s.adb.dumpViewHierarchy(serial)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if dump == nil || dump.Hierarchy == nil {
		writeAPIError(w, http.StatusInternalServerError, "dump returned empty")
		return
	}
	writeJSON(w, map[string]interface{}{
		"hierarchy": dump.Hierarchy,
		"rotation":  dump.Rotation,
	})
}
