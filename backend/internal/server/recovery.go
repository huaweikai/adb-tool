package server

import (
	"fmt"
	"net/http"
	"runtime/debug"
	"time"
)

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
