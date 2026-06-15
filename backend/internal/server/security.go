package server

import (
	"errors"
	"net"
	"net/http"
	"net/url"
	"path/filepath"
	"strings"
)

const (
	DefaultListenAddr = "127.0.0.1:9876"

	maxReadFileBytes = 10 << 20 // 10 MiB, for in-memory text preview only
)

func isAllowedWebSocketOrigin(r *http.Request) bool {
	origin := r.Header.Get("Origin")
	if origin == "" {
		return true
	}
	u, err := url.Parse(origin)
	if err != nil {
		return false
	}
	switch u.Hostname() {
	case "localhost", "127.0.0.1", "::1":
		return true
	default:
		return false
	}
}

func isLoopbackIP(ip net.IP) bool {
	if ip == nil {
		return false
	}
	return ip.IsLoopback()
}

func clientIP(r *http.Request) net.IP {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return nil
	}
	return net.ParseIP(host)
}

func requireLoopback(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !isLoopbackIP(clientIP(r)) {
			writeAPIError(w, http.StatusForbidden, "forbidden")
			return
		}
		next.ServeHTTP(w, r)
	})
}

func validateSessionDir(sessionDir string) (string, error) {
	sessionDir = strings.TrimSpace(sessionDir)
	if sessionDir == "" {
		return "", errors.New("sessionDir required")
	}
	if !filepath.IsAbs(sessionDir) {
		return "", errors.New("sessionDir must be an absolute path")
	}
	for _, part := range strings.Split(filepath.ToSlash(sessionDir), "/") {
		if part == ".." {
			return "", errors.New("invalid sessionDir")
		}
	}
	abs, err := filepath.Abs(filepath.Clean(sessionDir))
	if err != nil {
		return "", errors.New("invalid sessionDir")
	}
	return abs, nil
}
