package server

import (
	"fmt"
	"net/http"
	"runtime/debug"
	"time"
)

// slowRequestThreshold is the elapsed time at which a request's response
// gets a separate "http res slow" log entry. Keeps the log readable while
// still surfacing hangs caused by external adb interference.
const slowRequestThreshold = 500 * time.Millisecond

// statusRecorder wraps http.ResponseWriter so we can read the status code
// after the handler finishes.
type statusRecorder struct {
	http.ResponseWriter
	status int
	wrote  bool
}

func (r *statusRecorder) WriteHeader(code int) {
	if r.wrote {
		return
	}
	r.status = code
	r.wrote = true
	r.ResponseWriter.WriteHeader(code)
}

func (r *statusRecorder) Write(b []byte) (int, error) {
	if !r.wrote {
		r.status = http.StatusOK
		r.wrote = true
	}
	return r.ResponseWriter.Write(b)
}

func observeHTTP(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}

		// Always log request entry — cheap and helps correlate with backend.log.
		Log.Add(
			fmt.Sprintf("http req %s %s", r.Method, r.URL.Path),
			fmt.Sprintf("from=%s ua=%q", r.RemoteAddr, r.Header.Get("User-Agent")),
			nil, 0,
		)

		next.ServeHTTP(rec, r)

		elapsed := time.Since(start)
		// Only log slow responses (>500ms). Catches hangs from adb interference
		// (Android Studio grabbing the adb server, device lockups, etc.) without
		// flooding the log on healthy 5s polling intervals.
		if elapsed >= slowRequestThreshold {
			Log.Add(
				fmt.Sprintf("http res slow %s %s status=%d", r.Method, r.URL.Path, rec.status),
				fmt.Sprintf("elapsed=%dms", elapsed.Milliseconds()),
				nil, elapsed,
			)
		}
	})
}

func recoverHTTP(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		defer func() {
			if v := recover(); v != nil {
				stack := string(debug.Stack())
				err := fmt.Errorf("%v", v)
				Log.Add(fmt.Sprintf("panic http %s %s", r.Method, r.URL.Path), stack, err, time.Since(start))
				http.Error(w, "internal server error", http.StatusInternalServerError)
			}
		}()
		next.ServeHTTP(w, r)
	})
}

func goSafe(name string, fn func()) {
	go func() {
		defer recoverPanic("panic goroutine " + name)
		fn()
	}()
}

func recoverPanic(command string) func() {
	start := time.Now()
	return func() {
		if v := recover(); v != nil {
			Log.Add(command, string(debug.Stack()), fmt.Errorf("%v", v), time.Since(start))
		}
	}
}
