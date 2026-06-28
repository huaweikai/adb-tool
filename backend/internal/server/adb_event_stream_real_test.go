package server

import (
	"bytes"
	"context"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"net"
	"os"
	"testing"
	"time"
)

// TestAdbEventStream_RealAdbServer connects to the actual adb server
// running on localhost:5037 (NOT a fake) to verify the wire protocol
// + JSON parsing works against real-world adb output. Skipped if no
// adb server is reachable.
//
// Run manually with: go test ./internal/server/ -run TestAdbEventStream_RealAdbServer -v
func TestAdbEventStream_RealAdbServer(t *testing.T) {
	if os.Getenv("TEST_REAL_ADB") == "" {
		t.Skip("set TEST_REAL_ADB=1 to run against the real adb server")
	}

	logger := log.New(os.Stderr, "[real-adb-test] ", log.LstdFlags)

	// Probe mode: dial adb directly, send host:track-devices, log the
	// first ~256 bytes of response. This is what revealed the OKAY
	// handshake has no length prefix and exposed the actual wire
	// format — running through AdbEventStream.Run hides both behind
	// the recover/handle-payload layers.
	probeRawAdb(t, logger)
	t.Logf("--- now running through AdbEventStream.Run ---")

	caps := newCapture()
	stream := NewAdbEventStream(0, caps.callback())
	stream.SetLogger(logger)

	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	defer cancel()

	done := make(chan struct{})
	go func() {
		defer close(done)
		stream.Run(ctx)
	}()

	select {
	case <-time.After(5 * time.Second):
	case <-done:
	}

	t.Logf("caps callbacks received: %d", len(caps.all))
	for i, c := range caps.all {
		t.Logf("  event %d: current=%d added=%v removed=%v", i, len(c.Current), c.Added, c.Removed)
	}
	t.Logf("final snapshot len: %d", len(stream.Snapshot()))
	for i, d := range stream.Snapshot() {
		t.Logf("  device %d: serial=%s state=%s model=%s", i, d.Serial, d.State, d.Model)
	}
}

// probeRawAdb opens a raw socket to adb, sends host:track-devices, and
// dumps the first ~512 bytes of response (in hex + ASCII). Used to
// inspect the real wire protocol without going through AdbEventStream's
// abstraction layers.
func probeRawAdb(t *testing.T, logger *log.Logger) {
	t.Helper()

	conn, err := net.Dial("tcp", "localhost:5037")
	if err != nil {
		t.Logf("probe: dial failed: %v", err)
		return
	}
	defer conn.Close()

	if _, err := conn.Write([]byte("0012host:track-devices")); err != nil {
		t.Logf("probe: write failed: %v", err)
		return
	}

	// Read up to 512 bytes with a short deadline.
	_ = conn.SetReadDeadline(time.Now().Add(2 * time.Second))
	buf := make([]byte, 512)
	n, err := io.ReadFull(conn, buf)
	if err != nil {
		// ReadFull may EOF early; that's fine, dump what we have.
		n = bytes.Index(buf, []byte{0})
		if n < 0 {
			n = 512
		}
	}

	// Dump first 64 bytes hex + ASCII.
	show := n
	if show > 64 {
		show = 64
	}
	t.Logf("probe: read %d bytes; first %d:", n, show)
	logger.Printf("probe hex: %s", hex.EncodeToString(buf[:show]))
	logger.Printf("probe ascii: %q", string(buf[:show]))

	// If we have a length prefix + payload structure, log lengths.
	if n >= 4 {
		hdr := string(buf[:4])
		logger.Printf("probe first 4 bytes: %q (would-be length %s)", hdr, hdr)
		fmt.Fprintf(os.Stderr, "[probe] first 4 bytes: %q\n", hdr)
	}
}