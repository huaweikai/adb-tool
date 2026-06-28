package server

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// fakeAdbServer simulates the adb wire protocol's host:track-devices
// endpoint. One connection accepted, OKAY handshake, then JSON payloads
// pumped on demand from the test via push().
//
// Lifecycle: newFakeAdbServer registers t.Cleanup that signals stopCh
// and waits for serve() to return via doneCh. Without that signal,
// serve() would poll forever and the test would hang on cleanup.
type fakeAdbServer struct {
	listener net.Listener
	addr     string

	mu     sync.Mutex
	pushes [][]byte // queued JSON payloads, sent in order

	accepted  chan struct{} // closed once a connection lands
	stopCh    chan struct{} // external signal to stop serve()
	stopOnce  sync.Once
	doneCh    chan struct{} // closed when serve() returns

	// when set, refuse the next connection (close listener early
	// before Accept) to simulate "server not running"
	refuseOnce atomic.Bool
}

func newFakeAdbServer(t *testing.T) *fakeAdbServer {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	s := &fakeAdbServer{
		listener: ln,
		addr:     ln.Addr().String(),
		accepted: make(chan struct{}),
		stopCh:   make(chan struct{}),
		doneCh:   make(chan struct{}),
	}
	go s.serve()
	t.Cleanup(func() {
		s.shutdown()
		<-s.doneCh
	})
	return s
}

// shutdown signals serve() to exit. Idempotent.
func (s *fakeAdbServer) shutdown() {
	s.stopOnce.Do(func() { close(s.stopCh) })
}

func (s *fakeAdbServer) serve() {
	defer close(s.doneCh)

	if s.refuseOnce.Load() {
		return
	}

	conn, err := s.listener.Accept()
	if err != nil {
		return
	}
	defer conn.Close()
	close(s.accepted)

	// Verify the client request
	var hdr [4]byte
	if _, err := io.ReadFull(conn, hdr[:]); err != nil {
		return
	}
	n, err := decodeHexLength(hdr[:])
	if err != nil {
		return
	}
	req := make([]byte, n)
	if _, err := io.ReadFull(conn, req); err != nil {
		return
	}
	if string(req) != "host:track-devices" {
		return
	}

	// OKAY handshake. The handshake response is a raw 4-byte token
	// ("OKAY" or "FAIL"), NOT length-prefixed �?unlike the payloads
	// that follow. See readOkayOrFail.
	if _, err := conn.Write([]byte("OKAY")); err != nil {
		return
	}

	for {
		s.mu.Lock()
		if len(s.pushes) == 0 {
			s.mu.Unlock()
			select {
			case <-s.stopCh:
				return
			case <-time.After(20 * time.Millisecond):
				continue
			}
		}
		payload := s.pushes[0]
		s.pushes = s.pushes[1:]
		s.mu.Unlock()

		prefix := fmt.Sprintf("%04x", len(payload))
		if _, err := conn.Write([]byte(prefix)); err != nil {
			return
		}
		if _, err := conn.Write(payload); err != nil {
			return
		}
	}
}

func (s *fakeAdbServer) push(payload []byte) {
	s.mu.Lock()
	s.pushes = append(s.pushes, payload)
	s.mu.Unlock()
}

// trackJSON builds a JSON payload for host:track-devices with the given
// serials marked online ("device" state). Stable order for assertions.
//
// Kept for the defensive JSON-format path in handlePayload �?newer
// adb versions don't actually emit this format (they emit text), but
// we still parse it if it shows up.
func trackJSON(serials ...string) []byte {
	arr := make([]trackDevice, 0, len(serials))
	for _, s := range serials {
		arr = append(arr, trackDevice{
			Serial: s,
			State:  "device",
			Model:  "Pixel-Test",
		})
	}
	b, _ := json.Marshal(arr)
	return b
}

// trackText builds a TEXT payload for host:track-devices. This is what
// real adb (recent versions) actually emits �?one `<serial>\t<state>`
// line per device, terminated with `\n`. State defaults to "device".
func trackText(serials ...string) []byte {
	var b strings.Builder
	for _, s := range serials {
		b.WriteString(s)
		b.WriteByte('\t')
		b.WriteString("device")
		b.WriteByte('\n')
	}
	return []byte(b.String())
}

// waitFor polls until cond returns true or timeout. Returns whether cond
// was satisfied.
func waitFor(timeout time.Duration, cond func() bool) bool {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if cond() {
			return true
		}
		time.Sleep(5 * time.Millisecond)
	}
	return cond()
}

// captureChanges is a thread-safe collector for onChange callbacks.
type captureChanges struct {
	mu   sync.Mutex
	all  []trackDeviceChange
	seen map[string]int // serial -> count of events that included it
}

func newCapture() *captureChanges {
	return &captureChanges{seen: map[string]int{}}
}

func (c *captureChanges) callback() onChangeFn {
	return func(change trackDeviceChange) {
		c.mu.Lock()
		defer c.mu.Unlock()
		c.all = append(c.all, change)
		for _, s := range change.Added {
			c.seen[s]++
		}
		for _, s := range change.Removed {
			c.seen[s]--
		}
	}
}

func (c *captureChanges) snapshot() []trackDeviceChange {
	c.mu.Lock()
	defer c.mu.Unlock()
	out := make([]trackDeviceChange, len(c.all))
	copy(out, c.all)
	return out
}

func TestAdbEventStream_FirstEventTreatedAsFullSnapshot(t *testing.T) {
	srv := newFakeAdbServer(t)

	port, err := portFromAddr(srv.addr)
	if err != nil {
		t.Fatalf("parse addr: %v", err)
	}

	cap := newCapture()
	stream := NewAdbEventStream(port, cap.callback())
	stream.SetLogger(testLogger(t))

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	done := make(chan struct{})
	go func() {
		stream.Run(ctx)
		close(done)
	}()
	defer stream.Stop()

	// Wait for the fake server to accept before pushing.
	select {
	case <-srv.accepted:
	case <-time.After(2 * time.Second):
		t.Fatal("fake server didn't accept connection")
	}

	srv.push(trackText("alpha", "bravo"))

	if !waitFor(2*time.Second, func() bool {
		return len(cap.snapshot()) == 1
	}) {
		t.Fatalf("expected 1 callback, got %d: %+v", len(cap.snapshot()), cap.snapshot())
	}

	got := cap.snapshot()[0]
	if len(got.Added) != 2 || got.Added[0] != "alpha" || got.Added[1] != "bravo" {
		t.Errorf("expected Added=[alpha,bravo], got %v", got.Added)
	}
	if len(got.Removed) != 0 {
		t.Errorf("expected empty Removed, got %v", got.Removed)
	}
	if len(got.Current) != 2 {
		t.Errorf("expected 2 devices in Current, got %d", len(got.Current))
	}
}

func TestAdbEventStream_DiffAddAndRemove(t *testing.T) {
	srv := newFakeAdbServer(t)
	port, _ := portFromAddr(srv.addr)

	cap := newCapture()
	stream := NewAdbEventStream(port, cap.callback())
	stream.SetLogger(testLogger(t))

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	done := make(chan struct{})
	go func() {
		stream.Run(ctx)
		close(done)
	}()
	defer stream.Stop()

	<-srv.accepted

	// Snapshot 1: alpha, bravo
	srv.push(trackText("alpha", "bravo"))
	if !waitFor(time.Second, func() bool { return len(cap.snapshot()) == 1 }) {
		t.Fatal("did not receive first event")
	}

	// Snapshot 2: bravo gone, charlie added
	srv.push(trackText("bravo", "charlie"))
	if !waitFor(time.Second, func() bool { return len(cap.snapshot()) == 2 }) {
		t.Fatalf("did not receive second event; got %d events", len(cap.snapshot()))
	}

	got := cap.snapshot()[1]
	if len(got.Added) != 1 || got.Added[0] != "charlie" {
		t.Errorf("expected Added=[charlie], got %v", got.Added)
	}
	if len(got.Removed) != 1 || got.Removed[0] != "alpha" {
		t.Errorf("expected Removed=[alpha], got %v", got.Removed)
	}
}

func TestAdbEventStream_NoDiffNoCallback(t *testing.T) {
	srv := newFakeAdbServer(t)
	port, _ := portFromAddr(srv.addr)

	cap := newCapture()
	stream := NewAdbEventStream(port, cap.callback())
	stream.SetLogger(testLogger(t))

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	done := make(chan struct{})
	go func() {
		stream.Run(ctx)
		close(done)
	}()
	defer stream.Stop()

	<-srv.accepted

	srv.push(trackText("alpha", "bravo"))
	if !waitFor(time.Second, func() bool { return len(cap.snapshot()) == 1 }) {
		t.Fatal("did not receive first event")
	}

	// Same snapshot again
	srv.push(trackText("alpha", "bravo"))

	// Give it time; we want exactly 1 callback
	time.Sleep(150 * time.Millisecond)
	if got := len(cap.snapshot()); got != 1 {
		t.Errorf("expected 1 callback for unchanged snapshot, got %d", got)
	}
}

func TestAdbEventStream_BadJSONDoesNotKillStream(t *testing.T) {
	srv := newFakeAdbServer(t)
	port, _ := portFromAddr(srv.addr)

	cap := newCapture()
	stream := NewAdbEventStream(port, cap.callback())
	stream.SetLogger(testLogger(t))

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	done := make(chan struct{})
	go func() {
		stream.Run(ctx)
		close(done)
	}()
	defer stream.Stop()

	<-srv.accepted

	srv.push([]byte("this is not json"))
	srv.push(trackText("alpha"))

	if !waitFor(time.Second, func() bool {
		return len(cap.snapshot()) == 1
	}) {
		t.Fatalf("expected to recover from bad JSON and deliver 1 valid event; got %d callbacks",
			len(cap.snapshot()))
	}
}

func TestAdbEventStream_StopExitsCleanly(t *testing.T) {
	srv := newFakeAdbServer(t)
	port, _ := portFromAddr(srv.addr)

	cap := newCapture()
	stream := NewAdbEventStream(port, cap.callback())
	stream.SetLogger(testLogger(t))

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	done := make(chan struct{})
	go func() {
		stream.Run(ctx)
		close(done)
	}()

	<-srv.accepted

	stream.Stop()
	stream.Stop() // idempotent

	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("Run did not return within 2s of Stop()")
	}
}

func TestAdbEventStream_ConnectFailureExitsAfterContextCancel(t *testing.T) {
	// Listener that never accepts: stream should sit in retry loop
	// until ctx is cancelled.
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	defer ln.Close()
	// Accept and immediately close �?port still bound for a moment but
	// dial will fail. Easier: use a port that's almost certainly closed.
	// Simplest: just take the port and close the listener immediately
	// so the port is free but nothing accepts.
	port, _ := portFromAddr(ln.Addr().String())
	ln.Close()

	cap := newCapture()
	stream := NewAdbEventStream(port, cap.callback())
	stream.SetLogger(testLogger(t))

	ctx, cancel := context.WithCancel(context.Background())

	done := make(chan struct{})
	go func() {
		stream.Run(ctx)
		close(done)
	}()

	// Let it retry once or twice
	time.Sleep(200 * time.Millisecond)

	cancel()

	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("Run did not return within 2s of context cancel during connect failure")
	}

	if got := len(cap.snapshot()); got != 0 {
		t.Errorf("expected no callbacks during connect failure, got %d", got)
	}
}

func TestAdbEventStream_FailResponseReturnsError(t *testing.T) {
	// Spin up a fake server that responds with FAIL to track-devices.
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	defer ln.Close()
	port, _ := portFromAddr(ln.Addr().String())

	go func() {
		conn, err := ln.Accept()
		if err != nil {
			return
		}
		defer conn.Close()
		// drain request
		var hdr [4]byte
		io.ReadFull(conn, hdr[:])
		n, _ := decodeHexLength(hdr[:])
		req := make([]byte, n)
		io.ReadFull(conn, req)
		// respond FAIL with reason. OKAY/FAIL is a raw 4-byte token
		// (not length-prefixed); only the trailing reason is.
		reason := "device not found"
		conn.Write([]byte("FAIL"))
		conn.Write([]byte(fmt.Sprintf("%04x%s", len(reason), reason)))
	}()

	cap := newCapture()
	stream := NewAdbEventStream(port, cap.callback())
	stream.SetLogger(testLogger(t))

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Run should keep retrying. We just verify it doesn't blow up
	// and delivers nothing.
	done := make(chan struct{})
	go func() {
		stream.Run(ctx)
		close(done)
	}()

	time.Sleep(300 * time.Millisecond)
	if got := len(cap.snapshot()); got != 0 {
		t.Errorf("expected no callbacks on FAIL, got %d", got)
	}

	cancel()
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("Run did not return within 2s of cancel")
	}
}

// portFromAddr extracts the port from a "host:port" address.
func portFromAddr(addr string) (int, error) {
	_, portStr, err := net.SplitHostPort(addr)
	if err != nil {
		return 0, err
	}
	var p int
	if _, err := fmt.Sscanf(portStr, "%d", &p); err != nil {
		return 0, err
	}
	return p, nil
}

// testLogger returns a *log.Logger whose output flows through t.Log when
// tests run in verbose mode. In quiet runs it discards output so test
// logs stay readable. Errors still surface via t.Fatal in callbacks.
func testLogger(t *testing.T) *log.Logger {
	return log.New(&tWriter{t: t}, "", 0)
}

type tWriter struct {
	t *testing.T
}

func (w *tWriter) Write(p []byte) (int, error) {
	if !testing.Verbose() {
		return len(p), nil
	}
	w.t.Log(strings.TrimRight(string(p), "\n"))
	return len(p), nil
}
