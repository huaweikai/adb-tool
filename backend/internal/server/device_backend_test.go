package server

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"testing/fstest"
)

type testScreenshotCapturer func(context.Context, string) ([]byte, error)

func (capture testScreenshotCapturer) CaptureScreenshot(ctx context.Context, serial string) ([]byte, error) {
	return capture(ctx, serial)
}

func TestScreenshotRouteUsesDeviceCapturer(t *testing.T) {
	const serial = "192.168.1.2:5555"
	const png = "\x89PNG\r\n\x1a\n"
	server := &Server{
		webFS: fstest.MapFS{},
		screenshotCapturer: testScreenshotCapturer(func(_ context.Context, target string) ([]byte, error) {
			if target != serial {
				t.Fatalf("capture target = %q, want %q", target, serial)
			}
			return []byte(png), nil
		}),
	}

	request := httptest.NewRequest(http.MethodGet, "/api/screenshot?serial="+serial, nil)
	request.RemoteAddr = "127.0.0.1:12345"
	response := httptest.NewRecorder()
	server.Handler().ServeHTTP(response, request)
	if response.Code != http.StatusOK || response.Header().Get("Content-Type") != "image/png" || response.Body.String() != png {
		t.Fatalf("unexpected screenshot response: status %d, headers %v, body %q", response.Code, response.Header(), response.Body.String())
	}
}
