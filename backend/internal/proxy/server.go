package proxy

import (
	"bytes"
	"fmt"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	mitmcert "github.com/lqqyt2423/go-mitmproxy/cert"
	mitmproxy "github.com/lqqyt2423/go-mitmproxy/proxy"
	log "github.com/sirupsen/logrus"
)

func init() {
	// Keep proxy logs quiet by default; errors and warnings only
	log.SetLevel(log.WarnLevel)
}

// Server wraps go-mitmproxy for cross-platform HTTP/HTTPS capture and mocking.
type Server struct {
	caRootPath string
	ruleStore  *RuleStore
	sessionBuf *SessionStore
	port       int
	mitmProxy  *mitmproxy.Proxy
	ca         *CA
	running    int32
	mu         sync.Mutex
}

// Config holds initialization parameters for the proxy server.
type Config struct {
	Port       int
	StorageDir string
	MaxHistory int
}

// NewServer initializes a new MITM proxy server backed by go-mitmproxy.
func NewServer(cfg Config) (*Server, error) {
	if cfg.Port <= 0 {
		cfg.Port = 8899
	}
	caDir := cfg.StorageDir
	if caDir == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			caDir = filepath.Join(os.TempDir(), "adb_tool_ca")
		} else {
			caDir = filepath.Join(home, ".adb-tool", "ca")
		}
	}
	_ = os.MkdirAll(caDir, 0700)

	ruleStore := NewRuleStore(cfg.StorageDir)
	sessionBuf := NewSessionStore(cfg.MaxHistory)

	var ca *CA
	if signCA, err := mitmcert.NewSelfSignCA(caDir); err == nil && signCA != nil {
		rootCert := signCA.GetRootCA()
		ca = NewCAFromCert(rootCert)
	}

	return &Server{
		caRootPath: caDir,
		ruleStore:  ruleStore,
		sessionBuf: sessionBuf,
		port:       cfg.Port,
		ca:         ca,
	}, nil
}

// CA returns the CA wrapper instance.
func (s *Server) CA() *CA {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.ca
}

// Rules returns the RuleStore instance.
func (s *Server) Rules() *RuleStore {
	return s.ruleStore
}

// Sessions returns the SessionStore instance.
func (s *Server) Sessions() *SessionStore {
	return s.sessionBuf
}

// IsRunning reports whether the proxy is currently listening.
func (s *Server) IsRunning() bool {
	return atomic.LoadInt32(&s.running) == 1
}

// Port returns the active listening port.
func (s *Server) Port() int {
	return s.port
}

// Start begins listening on the given port.
func (s *Server) Start(port int) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if atomic.LoadInt32(&s.running) == 1 {
		if s.port == port {
			return nil
		}
		_ = s.stopLocked()
	}

	opts := &mitmproxy.Options{
		Addr:              fmt.Sprintf(":%d", port),
		SslInsecure:       true,
		CaRootPath:        s.caRootPath,
		StreamLargeBodies: 1024 * 1024 * 5,
	}

	p, err := mitmproxy.NewProxy(opts)
	if err != nil {
		return fmt.Errorf("create mitm proxy: %w", err)
	}

	addon := &proxyAddon{server: s}
	p.AddAddon(addon)

	cert := p.GetCertificate()
	s.ca = NewCAFromCert(&cert)
	s.mitmProxy = p
	s.port = port
	atomic.StoreInt32(&s.running, 1)

	go func() {
		if err := p.Start(); err != nil {
			// Proxy stopped or encountered a fatal listen error
		}
		atomic.StoreInt32(&s.running, 0)
	}()

	return nil
}

// Stop terminates the proxy listener.
func (s *Server) Stop() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.stopLocked()
}

func (s *Server) stopLocked() error {
	if atomic.LoadInt32(&s.running) == 0 || s.mitmProxy == nil {
		return nil
	}
	err := s.mitmProxy.Close()
	atomic.StoreInt32(&s.running, 0)
	s.mitmProxy = nil
	return err
}

// proxyAddon is the event hook plugin for go-mitmproxy.
type proxyAddon struct {
	mitmproxy.BaseAddon
	server *Server
}

// AccessProxyServer intercepts direct requests made to the proxy's IP:port (e.g. from browser).
func (a *proxyAddon) AccessProxyServer(req *http.Request, res http.ResponseWriter) {
	path := req.URL.Path
	if path == "/ca.crt" || path == "/cert/pem" {
		res.Header().Set("Content-Type", "application/x-x509-ca-cert")
		res.Header().Set("Content-Disposition", `attachment; filename="adb_tool_ca.crt"`)
		if a.server.CA() != nil {
			_, _ = res.Write(a.server.CA().GetCACertPEM())
		}
		return
	}
	if path == "/ca.der" || path == "/cert/der" {
		res.Header().Set("Content-Type", "application/x-x509-ca-cert")
		res.Header().Set("Content-Disposition", `attachment; filename="adb_tool_ca.der"`)
		if a.server.CA() != nil {
			_, _ = res.Write(a.server.CA().GetCACertDER())
		}
		return
	}

	// Render landing page HTML for mobile browser configuration
	res.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = res.Write([]byte(renderLandingHTML(a.server.Port())))
}

func extractHost(f *mitmproxy.Flow) string {
	host := f.Request.URL.Hostname()
	if host == "" {
		host = strings.Split(f.Request.URL.Host, ":")[0]
	}
	if host == "" {
		host = strings.Split(f.Request.Header.Get("Host"), ":")[0]
	}
	return strings.ToLower(strings.TrimSpace(host))
}

// Requestheaders intercepts headers before request body is read.
func (a *proxyAddon) Requestheaders(f *mitmproxy.Flow) {
	host := extractHost(f)
	// Magic domains for mobile cert install: mitm.it and adb.tool
	if host == "mitm.it" || host == "adb.tool" {
		f.Response = a.handleMitmLanding(f)
	}
}

// Request handles intercepted requests, matching Mock rules.
func (a *proxyAddon) Request(f *mitmproxy.Flow) {
	if f.Response != nil {
		return
	}

	host := extractHost(f)
	if host == "mitm.it" || host == "adb.tool" {
		f.Response = a.handleMitmLanding(f)
		return
	}

	fullURL := f.Request.URL.String()
	matchedRule := a.server.ruleStore.Match(f.Request.Method, fullURL)
	if matchedRule != nil && matchedRule.Action == "mock" {
		header := make(http.Header)
		for k, v := range matchedRule.MockHeaders {
			header.Set(k, v)
		}
		header.Set("X-Mocked-By", "ADB-Tool-Proxy")
		bodyBytes := []byte(matchedRule.MockBody)
		header.Set("Content-Length", strconv.Itoa(len(bodyBytes)))
		if header.Get("Content-Type") == "" {
			header.Set("Content-Type", "application/json; charset=utf-8")
		}

		f.Response = &mitmproxy.Response{
			StatusCode: matchedRule.MockStatus,
			Header:     header,
			Body:       bodyBytes,
		}

		// Record and broadcast mocked session
		sess := a.flowToSession(f, true, matchedRule.Name)
		a.server.sessionBuf.Add(sess)
	}
}

// Response handles responses from upstream servers, matching Rewrite rules and recording sessions.
func (a *proxyAddon) Response(f *mitmproxy.Flow) {
	if f.Response != nil && f.Response.Header.Get("X-Mocked-By") == "ADB-Tool-Proxy" {
		return
	}

	fullURL := f.Request.URL.String()
	matchedRule := a.server.ruleStore.Match(f.Request.Method, fullURL)
	isMocked := false
	matchedName := ""

	if matchedRule != nil && matchedRule.Action == "rewrite" {
		// Automatically decodes gzip, brotli, deflate, or zstd before modification
		f.Response.ReplaceToDecodedBody()
		if len(matchedRule.FindText) > 0 {
			f.Response.Body = bytes.ReplaceAll(
				f.Response.Body,
				[]byte(matchedRule.FindText),
				[]byte(matchedRule.ReplaceText),
			)
		}
		if matchedRule.MockStatus > 0 {
			f.Response.StatusCode = matchedRule.MockStatus
		}
		f.Response.Header.Set("X-Rewritten-By", "ADB-Tool-Proxy")
		f.Response.Header.Set("Content-Length", strconv.Itoa(len(f.Response.Body)))
		isMocked = true
		matchedName = matchedRule.Name
	}

	sess := a.flowToSession(f, isMocked, matchedName)
	a.server.sessionBuf.Add(sess)
}

func (a *proxyAddon) handleMitmLanding(f *mitmproxy.Flow) *mitmproxy.Response {
	path := f.Request.URL.Path
	ca := a.server.CA()

	if path == "/ca.crt" || path == "/cert/pem" {
		var pemData []byte
		if ca != nil {
			pemData = ca.GetCACertPEM()
		}
		return &mitmproxy.Response{
			StatusCode: 200,
			Header: http.Header{
				"Content-Type":        []string{"application/x-x509-ca-cert"},
				"Content-Disposition": []string{`attachment; filename="adb_tool_ca.crt"`},
				"Content-Length":      []string{strconv.Itoa(len(pemData))},
			},
			Body: pemData,
		}
	}

	if path == "/ca.der" || path == "/cert/der" {
		var derData []byte
		if ca != nil {
			derData = ca.GetCACertDER()
		}
		return &mitmproxy.Response{
			StatusCode: 200,
			Header: http.Header{
				"Content-Type":        []string{"application/x-x509-ca-cert"},
				"Content-Disposition": []string{`attachment; filename="adb_tool_ca.der"`},
				"Content-Length":      []string{strconv.Itoa(len(derData))},
			},
			Body: derData,
		}
	}

	html := renderLandingHTML(a.server.Port())
	return &mitmproxy.Response{
		StatusCode: 200,
		Header: http.Header{
			"Content-Type":   []string{"text/html; charset=utf-8"},
			"Content-Length": []string{strconv.Itoa(len(html))},
		},
		Body: []byte(html),
	}
}

func (a *proxyAddon) flowToSession(f *mitmproxy.Flow, isMocked bool, matchedRule string) *ProxySession {
	reqHeaders := make(map[string]string)
	for k, v := range f.Request.Header {
		reqHeaders[k] = strings.Join(v, ", ")
	}

	respHeaders := make(map[string]string)
	var respBody string
	var respSize int
	var statusCode int
	var statusText string

	if f.Response != nil {
		for k, v := range f.Response.Header {
			respHeaders[k] = strings.Join(v, ", ")
		}
		statusCode = f.Response.StatusCode
		statusText = http.StatusText(statusCode)
		respSize = len(f.Response.Body)

		// Decode body for UI text display
		decoded, err := f.Response.DecodedBody()
		if err == nil && len(decoded) > 0 {
			respBody = string(decoded)
		} else {
			respBody = string(f.Response.Body)
		}

		// Cap body string to 256KB to keep Flutter WebSocket bandwidth reasonable
		if len(respBody) > 256*1024 {
			respBody = respBody[:256*1024] + "\n...(truncated)"
		}
	}

	reqBodyBytes, _ := f.Request.DecodedBody()
	reqBody := string(reqBodyBytes)
	if len(reqBody) > 256*1024 {
		reqBody = reqBody[:256*1024] + "\n...(truncated)"
	}

	clientIP := ""
	if f.ConnContext != nil && f.ConnContext.ClientConn != nil && f.ConnContext.ClientConn.Conn != nil {
		clientIP = f.ConnContext.ClientConn.Conn.RemoteAddr().String()
	}

	scheme := f.Request.URL.Scheme
	if scheme == "" {
		if f.ConnContext != nil && f.ConnContext.ClientConn != nil && f.ConnContext.ClientConn.Tls {
			scheme = "https"
		} else {
			scheme = "http"
		}
	}

	duration := int(time.Since(f.StartTime).Milliseconds())
	if duration < 0 {
		duration = 0
	}

	return &ProxySession{
		ID:          f.Id.String(),
		Timestamp:   f.StartTime.UnixMilli(),
		Method:      f.Request.Method,
		URL:         f.Request.URL.String(),
		Host:        f.Request.URL.Host,
		Path:        f.Request.URL.Path,
		Scheme:      scheme,
		StatusCode:  statusCode,
		StatusText:  statusText,
		DurationMs:  int64(duration),
		ReqHeaders:  reqHeaders,
		ReqBody:     reqBody,
		ReqSize:     int64(len(f.Request.Body)),
		RespHeaders: respHeaders,
		RespBody:    respBody,
		RespSize:    int64(respSize),
		IsMocked:    isMocked,
		MatchedRule: matchedRule,
		ClientIP:    clientIP,
	}
}

// GetLocalIPs enumerates non-loopback IPv4 addresses of this host.
func GetLocalIPs() []string {
	var ips []string
	ifaces, err := net.Interfaces()
	if err != nil {
		return []string{"127.0.0.1"}
	}
	for _, iface := range ifaces {
		if iface.Flags&net.FlagUp == 0 || iface.Flags&net.FlagLoopback != 0 {
			continue
		}
		addrs, err := iface.Addrs()
		if err != nil {
			continue
		}
		for _, addr := range addrs {
			var ip net.IP
			switch v := addr.(type) {
			case *net.IPNet:
				ip = v.IP
			case *net.IPAddr:
				ip = v.IP
			}
			if ip != nil && ip.To4() != nil && !ip.IsLoopback() {
				ips = append(ips, ip.String())
			}
		}
	}
	if len(ips) == 0 {
		return []string{"127.0.0.1"}
	}
	return ips
}

func renderLandingHTML(port int) string {
	return fmt.Sprintf(`<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>ADB Tool Proxy CA</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 0; padding: 24px; background: #f7f9fa; color: #333; text-align: center; }
        .card { max-width: 480px; margin: 30px auto; background: #fff; border-radius: 12px; padding: 28px; box-shadow: 0 4px 16px rgba(0,0,0,0.08); }
        h1 { font-size: 20px; margin-bottom: 8px; color: #007aff; }
        p { font-size: 14px; color: #666; line-height: 1.5; }
        .btn { display: block; margin: 14px 0; padding: 12px 20px; background: #007aff; color: #fff; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 15px; }
        .btn.secondary { background: #34c759; }
        .note { font-size: 12px; color: #999; margin-top: 20px; text-align: left; background: #f0f4f8; padding: 12px; border-radius: 6px; }
    </style>
</head>
<body>
    <div class="card">
        <h1>ADB Tool Proxy CA</h1>
        <p>Traffic is successfully passing through ADB Tool Proxy (Port %d).</p>
        <p>Download and install the root certificate to inspect HTTPS traffic:</p>
        <a class="btn" href="/ca.crt">Download Certificate (.crt / PEM)</a>
        <a class="btn secondary" href="/ca.der">Download Certificate (.der)</a>
        <div class="note">
            <strong>iOS Instructions:</strong><br>
            1. Tap button above to download profile.<br>
            2. Settings &rarr; Profile Downloaded &rarr; Install.<br>
            3. Settings &rarr; General &rarr; About &rarr; Certificate Trust Settings &rarr; Enable full trust.<br><br>
            <strong>Android Instructions:</strong><br>
            1. Tap button above to download ca.crt.<br>
            2. Settings &rarr; Security &rarr; Install Certificate &rarr; CA Certificate.
        </div>
    </div>
</body>
</html>`, port)
}
