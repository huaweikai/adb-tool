package server

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

func TestIOSLogStreamSendsRawBytesAndStopsOnDisconnect(t *testing.T) {
	stopped := make(chan string, 1)
	const logLine = "原始日志\r\n"
	server := &Server{ios: &iosDiscovery{
		ctx: context.Background(),
		devices: []Device{{
			Serial: "ios:PHONE-A", iosUDID: "phone-a", Capabilities: []DeviceCapability{capabilityIOSLiveLogs},
		}},
		logs: func(ctx context.Context, udid string, output io.Writer) error {
			if _, err := io.WriteString(output, logLine); err != nil {
				return err
			}
			<-ctx.Done()
			stopped <- udid
			return ctx.Err()
		},
	}}
	host := httptest.NewServer(http.HandlerFunc(server.handleIOSLogs))
	defer host.Close()
	url := "ws" + strings.TrimPrefix(host.URL, "http") + "?serial=ios:PHONE-A"
	socket, _, err := websocket.DefaultDialer.Dial(url, nil)
	if err != nil {
		t.Fatal(err)
	}
	defer socket.Close()
	_ = socket.SetReadDeadline(time.Now().Add(3 * time.Second))
	kind, data, err := socket.ReadMessage()
	if err != nil || kind != websocket.BinaryMessage || string(data) != logLine {
		t.Fatalf("first message = %d %q, %v", kind, data, err)
	}
	_ = socket.Close()
	select {
	case udid := <-stopped:
		if udid != "phone-a" {
			t.Fatalf("streamed unexpected device %q", udid)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("process context survived WebSocket disconnect")
	}
}
