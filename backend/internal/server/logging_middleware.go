package server

import (
	"fmt"
	"net/http"
	"strings"
	"time"
)

// loggingMiddleware records every API/WebSocket request to the backend
// log so the user can see them in the in-app "backend logs" tab.
//
// Why this exists: the Flutter desktop app swallows stdout from debugPrint
// in some launch modes (especially production builds), so client-side
// tracing can go invisible. Logging on the server side is always visible
// via /api/backend-logs. Filter is strict — only /api/* and /ws/* go in,
// so the static asset paths (which can be hundreds of requests on first
// launch) don't drown out the useful signal.
//
// Captures: HTTP method, full request URI (including query string),
// response status code, response byte count, and wall time. Status 0
// means the handler wrote a body without WriteHeader — we treat that
// as 200 since net/http's default is 200.
func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		lrw := &loggingResponseWriter{ResponseWriter: w, status: 200}
		next.ServeHTTP(lrw, r)
		elapsed := time.Since(start)

		path := r.URL.Path
		if !strings.HasPrefix(path, "/api/") && !strings.HasPrefix(path, "/ws/") {
			return
		}

		Log.Add(
			fmt.Sprintf("HTTP %s %s", r.Method, r.URL.RequestURI()),
			fmt.Sprintf("status=%d bytes=%d elapsed=%s", lrw.status, lrw.bytes, elapsed),
			nil,
			elapsed,
		)
	})
}

// loggingResponseWriter wraps http.ResponseWriter to capture the status
// code and total bytes written. Default status is 200 since net/http
// treats an unset status as 200 OK.
type loggingResponseWriter struct {
	http.ResponseWriter
	status int
	bytes  int
}

func (lrw *loggingResponseWriter) WriteHeader(code int) {
	lrw.status = code
	lrw.ResponseWriter.WriteHeader(code)
}

func (lrw *loggingResponseWriter) Write(b []byte) (int, error) {
	n, err := lrw.ResponseWriter.Write(b)
	lrw.bytes += n
	return n, err
}