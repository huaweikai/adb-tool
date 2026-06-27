package server

import (
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"path/filepath"
	"strings"
)

const (
	DefaultListenAddr = "127.0.0.1:9876"

	maxReadFileBytes = 10 << 20 // 10 MiB, for in-memory text preview only

	// Fix (code-review M2): cap walk depth on user-supplied scan paths so a
	// pathological root-level path can't pin a goroutine for minutes. 16
	// is enough to cover the SDK's nested "system-images/android-XX/<variant>/..."
	// layout with room to spare.
	maxScanPathDepth = 16
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

// Fix (code-review M2): validate a user-supplied scan/import path before
// handing it to filepath.Walk. Previous behaviour accepted any path,
// including "/" or "C:\", which could pin a goroutine for minutes walking
// the whole filesystem. This enforces:
//   - non-empty, absolute
//   - no ".." component
//   - not a filesystem root
//
// Depth limiting is enforced by [maxScanPathDepth] in the walker itself;
// see callers.
func validateScanPath(p string) (string, error) {
	p = strings.TrimSpace(p)
	if p == "" {
		return "", errors.New("path required")
	}
	if !filepath.IsAbs(p) {
		return "", errors.New("path must be an absolute path")
	}
	for _, part := range strings.Split(filepath.ToSlash(p), "/") {
		if part == ".." {
			return "", errors.New("path must not contain '..'")
		}
	}
	abs, err := filepath.Abs(filepath.Clean(p))
	if err != nil {
		return "", errors.New("invalid path")
	}
	// Reject filesystem roots: '/', '\', 'C:\', 'C:/'.
	cleaned := filepath.Clean(abs)
	sep := string(filepath.Separator)
	if cleaned == sep {
		return "", errors.New("refusing to scan filesystem root")
	}
	if len(cleaned) == 3 && cleaned[1] == ':' && (string(cleaned[2]) == sep || string(cleaned[2]) == "/") {
		return "", errors.New("refusing to scan drive root")
	}
	return abs, nil
}

// Fix (code-review M7): sanitize a user-supplied component that flows
// into a download ID, which then gets joined into a destPath. Without
// this, an ID containing "../etc" would let the caller escape the
// managed download root.
func sanitizeDownloadIDComponent(s string) (string, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return "", errors.New("id required")
	}
	if len(s) > 64 {
		return "", errors.New("id too long (max 64 chars)")
	}
	if strings.ContainsAny(s, "/\\:\x00") {
		return "", errors.New("id must not contain path separators or NUL")
	}
	if strings.Contains(s, "..") {
		return "", errors.New("id must not contain '..'")
	}
	return s, nil
}

// Fix (code-review M3): validate that a user-supplied download URL is
// safe to dereference. Blocks:
//   - non-http(s) schemes (file://, ftp://, gopher://, javascript:...)
//   - loopback (127.0.0.0/8, ::1) and link-local (169.254.0.0/16, fe80::/10)
//   - "localhost" by name
//
// Private (RFC1918 / ULA) ranges are NOT blocked — users legitimately
// host internal mirrors (e.g. Nexus / Artifactory in CI).
func validateDownloadURL(rawURL string) error {
	rawURL = strings.TrimSpace(rawURL)
	if rawURL == "" {
		return errors.New("url required")
	}
	u, err := url.Parse(rawURL)
	if err != nil {
		return fmt.Errorf("invalid url: %w", err)
	}
	scheme := strings.ToLower(u.Scheme)
	if scheme != "http" && scheme != "https" {
		return fmt.Errorf("url scheme %q not allowed; use http or https", u.Scheme)
	}
	host := u.Hostname()
	if host == "" {
		return errors.New("url has no host")
	}
	lowerHost := strings.ToLower(host)
	if lowerHost == "localhost" || strings.HasSuffix(lowerHost, ".localhost") {
		return errors.New("url must not point at localhost")
	}
	if ip := net.ParseIP(host); ip != nil {
		if ip.IsLoopback() || ip.IsLinkLocalUnicast() || ip.IsLinkLocalMulticast() || ip.IsUnspecified() {
			return fmt.Errorf("url must not point at %s", ip)
		}
	}
	return nil
}
