package server

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"

	"adb-tool/backend/internal/proxy"
)

func (s *Server) handleProxyStart(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	defer r.Body.Close()

	if s.proxyServer == nil {
		writeAPIError(w, http.StatusInternalServerError, "proxy engine not initialized")
		return
	}

	var req struct {
		Port int `json:"port"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)
	port := req.Port
	if port <= 0 {
		port = s.proxyServer.Port()
		if port <= 0 {
			port = 8899
		}
	}

	if err := s.proxyServer.Start(port); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	Log.Add("proxy started", fmt.Sprintf("listening on :%d", s.proxyServer.Port()), nil, 0)
	writeJSON(w, map[string]interface{}{
		"ok":   true,
		"port": s.proxyServer.Port(),
	})
}

func (s *Server) handleProxyStop(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}

	if s.proxyServer == nil {
		writeAPIError(w, http.StatusInternalServerError, "proxy engine not initialized")
		return
	}

	if err := s.proxyServer.Stop(); err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	Log.Add("proxy stopped", "", nil, 0)
	writeJSON(w, map[string]interface{}{
		"ok": true,
	})
}

func (s *Server) handleProxyStatus(w http.ResponseWriter, r *http.Request) {
	if s.proxyServer == nil {
		writeJSON(w, map[string]interface{}{
			"running":      false,
			"port":         8899,
			"lanIps":       proxy.GetLocalIPs(),
			"sessionCount": 0,
			"ruleCount":    0,
		})
		return
	}

	writeJSON(w, map[string]interface{}{
		"running":      s.proxyServer.IsRunning(),
		"port":         s.proxyServer.Port(),
		"lanIps":       proxy.GetLocalIPs(),
		"sessionCount": s.proxyServer.Sessions().Count(),
		"ruleCount":    len(s.proxyServer.Rules().GetAll()),
	})
}

func (s *Server) handleProxySessions(w http.ResponseWriter, r *http.Request) {
	if s.proxyServer == nil {
		writeJSON(w, []*proxy.ProxySession{})
		return
	}

	filter := r.URL.Query().Get("filter")
	limitStr := r.URL.Query().Get("limit")
	limit := 100
	if l, err := strconv.Atoi(limitStr); err == nil && l > 0 {
		limit = l
	}

	sessions := s.proxyServer.Sessions().GetAll(filter, limit)
	writeJSON(w, sessions)
}

func (s *Server) handleProxySessionDetail(w http.ResponseWriter, r *http.Request) {
	if s.proxyServer == nil {
		writeAPIError(w, http.StatusNotFound, "session not found")
		return
	}

	id := r.URL.Query().Get("id")
	sess := s.proxyServer.Sessions().GetByID(id)
	if sess == nil {
		writeAPIError(w, http.StatusNotFound, "session not found")
		return
	}
	writeJSON(w, sess)
}

func (s *Server) handleProxySessionsClear(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	if s.proxyServer != nil {
		s.proxyServer.Sessions().Clear()
	}
	writeJSON(w, map[string]interface{}{"ok": true})
}

func (s *Server) handleProxyRules(w http.ResponseWriter, r *http.Request) {
	if s.proxyServer == nil {
		writeAPIError(w, http.StatusInternalServerError, "proxy engine not initialized")
		return
	}

	switch r.Method {
	case http.MethodGet:
		rules := s.proxyServer.Rules().GetAll()
		writeJSON(w, rules)

	case http.MethodPost:
		defer r.Body.Close()
		var rule proxy.MockRule
		if err := json.NewDecoder(r.Body).Decode(&rule); err != nil {
			writeAPIError(w, http.StatusBadRequest, err.Error())
			return
		}
		saved := s.proxyServer.Rules().Save(&rule)
		writeJSON(w, saved)

	case http.MethodDelete:
		id := r.URL.Query().Get("id")
		if id == "" {
			writeAPIError(w, http.StatusBadRequest, "id required")
			return
		}
		ok := s.proxyServer.Rules().Delete(id)
		writeJSON(w, map[string]interface{}{"ok": ok})

	default:
		writeAPIError(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (s *Server) handleProxyCACert(w http.ResponseWriter, r *http.Request) {
	if s.proxyServer == nil || s.proxyServer.CA() == nil {
		writeAPIError(w, http.StatusInternalServerError, "CA not initialized")
		return
	}

	format := r.URL.Query().Get("format")
	if format == "der" {
		w.Header().Set("Content-Type", "application/x-x509-ca-cert")
		w.Header().Set("Content-Disposition", `attachment; filename="adb_tool_ca.der"`)
		_, _ = w.Write(s.proxyServer.CA().GetCACertDER())
		return
	}

	w.Header().Set("Content-Type", "application/x-x509-ca-cert")
	w.Header().Set("Content-Disposition", `attachment; filename="adb_tool_ca.crt"`)
	_, _ = w.Write(s.proxyServer.CA().GetCACertPEM())
}

func (s *Server) handleProxyWs(w http.ResponseWriter, r *http.Request) {
	if s.proxyServer == nil {
		http.Error(w, "proxy not initialized", http.StatusInternalServerError)
		return
	}

	conn, err := s.upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	defer conn.Close()

	ch := s.proxyServer.Sessions().Subscribe()
	defer s.proxyServer.Sessions().Unsubscribe(ch)

	for session := range ch {
		if err := conn.WriteJSON(session); err != nil {
			break
		}
	}
}

// Android ADB Proxy helper handlers

func (s *Server) handleProxyAdbSet(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeAPIError(w, http.StatusMethodNotAllowed, "POST required")
		return
	}
	defer r.Body.Close()

	var req struct {
		Serial string `json:"serial"`
		Host   string `json:"host"`
		Port   int    `json:"port"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeAPIError(w, http.StatusBadRequest, err.Error())
		return
	}
	req.Serial = strings.TrimSpace(req.Serial)
	req.Host = strings.TrimSpace(req.Host)
	if req.Serial == "" || req.Host == "" || req.Port <= 0 {
		writeAPIError(w, http.StatusBadRequest, "serial, host and port required")
		return
	}

	proxyAddr := fmt.Sprintf("%s:%d", req.Host, req.Port)
	out, err := s.adb.runRawContext(r.Context(), "-s", req.Serial, "shell", "settings", "put", "global", "http_proxy", proxyAddr)
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, fmt.Sprintf("set proxy error: %v (out: %s)", err, out))
		return
	}
	Log.Add("adb proxy set", fmt.Sprintf("device=%s proxy=%s", req.Serial, proxyAddr), nil, 0)
	writeJSON(w, map[string]interface{}{"ok": true, "proxy": proxyAddr})
}

func (s *Server) handleProxyAdbClear(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
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

	_, _ = s.adb.runRawContext(r.Context(), "-s", req.Serial, "shell", "settings", "put", "global", "http_proxy", ":0")
	_, _ = s.adb.runRawContext(r.Context(), "-s", req.Serial, "shell", "settings", "delete", "global", "http_proxy")
	_, _ = s.adb.runRawContext(r.Context(), "-s", req.Serial, "shell", "settings", "delete", "global", "global_http_proxy_host")
	_, _ = s.adb.runRawContext(r.Context(), "-s", req.Serial, "shell", "settings", "delete", "global", "global_http_proxy_port")

	Log.Add("adb proxy cleared", fmt.Sprintf("device=%s", req.Serial), nil, 0)
	writeJSON(w, map[string]interface{}{"ok": true})
}

func (s *Server) handleProxyAdbStatus(w http.ResponseWriter, r *http.Request) {
	serial := strings.TrimSpace(r.URL.Query().Get("serial"))
	if serial == "" {
		writeAPIError(w, http.StatusBadRequest, "serial required")
		return
	}

	out, err := s.adb.runRawContext(r.Context(), "-s", serial, "shell", "settings", "get", "global", "http_proxy")
	if err != nil {
		writeAPIError(w, http.StatusInternalServerError, err.Error())
		return
	}
	proxyVal := strings.TrimSpace(out)
	if proxyVal == "null" || proxyVal == ":0" {
		proxyVal = ""
	}
	writeJSON(w, map[string]interface{}{"proxy": proxyVal})
}
