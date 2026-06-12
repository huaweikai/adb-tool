package server

import (
	"encoding/json"
	"io/fs"
	"net/http"

	"github.com/gorilla/websocket"
)

type Server struct {
	adb      *AdbManager
	webFS    fs.FS
	upgrader websocket.Upgrader
}

func New(adbPath string, webFS fs.FS) *Server {
	return &Server{
		adb:   NewAdbManager(adbPath),
		webFS: webFS,
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool { return true },
		},
	}
}

func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("/api/devices", s.handleDevices)
	mux.HandleFunc("/api/clear", s.handleClear)
	mux.HandleFunc("/api/info", s.handleDeviceInfo)
	mux.HandleFunc("/api/package-pid", s.handlePackagePID)
	mux.HandleFunc("/api/running-packages", s.handleRunningPackages)
	mux.HandleFunc("/ws/logs", s.handleLogStream)
	mux.HandleFunc("/api/adb-path", s.handleAdbPath)

	webFS, err := fs.Sub(s.webFS, "web")
	if err != nil {
		panic("web directory not found in embedded FS: " + err.Error())
	}
	mux.Handle("/", http.FileServer(http.FS(webFS)))

	return mux
}

func (s *Server) handleDevices(w http.ResponseWriter, r *http.Request) {
	devices, err := s.adb.Devices()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if devices == nil {
		devices = []Device{}
	}
	writeJSON(w, devices)
}

func (s *Server) handleClear(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		http.Error(w, "serial required", http.StatusBadRequest)
		return
	}
	if err := s.adb.ClearLogcat(serial); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

func (s *Server) handleDeviceInfo(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		http.Error(w, "serial required", http.StatusBadRequest)
		return
	}
	output, err := s.adb.Shell(serial, "getprop")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]string{"props": output})
}

func (s *Server) handlePackagePID(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	packageName := r.URL.Query().Get("package")
	if serial == "" || packageName == "" {
		http.Error(w, "serial and package required", http.StatusBadRequest)
		return
	}
	pid, err := s.adb.GetPackagePID(serial, packageName)
	if err != nil {
		writeJSON(w, map[string]string{"error": err.Error(), "pid": ""})
		return
	}
	writeJSON(w, map[string]string{"pid": pid})
}

func (s *Server) handleRunningPackages(w http.ResponseWriter, r *http.Request) {
	serial := r.URL.Query().Get("serial")
	if serial == "" {
		http.Error(w, "serial required", http.StatusBadRequest)
		return
	}
	pkgs, err := s.adb.GetRunningPackages(serial)
	if err != nil {
		writeJSON(w, map[string]interface{}{"error": err.Error(), "packages": []string{}})
		return
	}
	if pkgs == nil {
		pkgs = []string{}
	}
	writeJSON(w, map[string]interface{}{"packages": pkgs})
}

func (s *Server) handleAdbPath(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]string{"path": s.adb.AdbPath()})
}

func (s *Server) handleLogStream(w http.ResponseWriter, r *http.Request) {
	conn, err := s.upgrader.Upgrade(w, r, nil)
	if err != nil {
		http.Error(w, "websocket upgrade failed", http.StatusBadRequest)
		return
	}

	session := NewLogSession(conn, s.adb)
	session.Run()
}

func writeJSON(w http.ResponseWriter, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(v)
}
