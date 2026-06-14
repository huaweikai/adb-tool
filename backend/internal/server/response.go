package server

import (
	"encoding/json"
	"net/http"
)

type apiResponse struct {
	OK    bool        `json:"ok"`
	Data  interface{} `json:"data"`
	Error string      `json:"error,omitempty"`
}

func writeJSON(w http.ResponseWriter, v interface{}) {
	writeAPIResponse(w, http.StatusOK, apiResponse{OK: true, Data: v})
}

func writeAPIError(w http.ResponseWriter, status int, message string) {
	writeAPIResponse(w, status, apiResponse{OK: false, Data: nil, Error: message})
}

func writeAPIErrorData(w http.ResponseWriter, status int, message string, data interface{}) {
	writeAPIResponse(w, status, apiResponse{OK: false, Data: data, Error: message})
}

func writeAPIResponse(w http.ResponseWriter, status int, resp apiResponse) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(resp); err != nil {
		Log.Add("http json response", "", err, 0)
	}
}
