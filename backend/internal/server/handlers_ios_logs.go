package server

import (
	"bufio"
	"context"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

type iosLogSocket struct {
	conn   *websocket.Conn
	cancel context.CancelFunc
}

func (sink iosLogSocket) Write(data []byte) (int, error) {
	_ = sink.conn.SetWriteDeadline(time.Now().Add(5 * time.Second))
	if err := sink.conn.WriteMessage(websocket.BinaryMessage, data); err != nil {
		sink.cancel()
		return 0, err
	}
	return len(data), nil
}

type iosLogBatch struct {
	mu     sync.Mutex
	buffer *bufio.Writer
}

func (b *iosLogBatch) Write(data []byte) (int, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.buffer.Write(data)
}

func (b *iosLogBatch) flush() {
	b.mu.Lock()
	defer b.mu.Unlock()
	_ = b.buffer.Flush() // The socket writer cancels the stream on failure.
}

func (s *Server) handleIOSLogs(w http.ResponseWriter, r *http.Request) {
	udid := s.iosTarget(w, r, capabilityIOSLiveLogs)
	if udid == "" {
		return
	}
	conn, err := s.upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	defer conn.Close()
	ctx, cancel := context.WithCancel(r.Context())
	defer cancel()
	stop := context.AfterFunc(s.ios.ctx, cancel)
	defer stop()

	conn.SetReadLimit(1024)
	go func() {
		defer cancel()
		for {
			if _, _, err := conn.ReadMessage(); err != nil {
				return
			}
		}
	}()
	sink := iosLogSocket{conn: conn, cancel: cancel}
	batch := &iosLogBatch{buffer: bufio.NewWriterSize(sink, 32*1024)}
	go func() {
		ticker := time.NewTicker(50 * time.Millisecond)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				batch.flush()
			}
		}
	}()
	err = s.ios.logs(ctx, udid, batch)
	if ctx.Err() != nil {
		return
	}
	batch.flush()
	if ctx.Err() != nil {
		return
	}
	code, message := websocket.CloseNormalClosure, ""
	if err != nil {
		Log.Add("iOS live logs", err.Error(), err, 0)
		code, message = websocket.CloseInternalServerErr, "iOS log stream failed"
	}
	_ = conn.WriteControl(websocket.CloseMessage, websocket.FormatCloseMessage(code, message), time.Now().Add(time.Second))
}
