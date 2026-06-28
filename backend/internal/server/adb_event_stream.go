package server

import (
	"bufio"
	"context"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"sort"
	"sync"
	"time"
)

// DefaultAdbServerPort is the standard port the adb server listens on.
// Override at stream construction time when ANDROID_ADB_SERVER_PORT is set
// in the environment.
const DefaultAdbServerPort = 5037

// trackDevice mirrors the JSON shape of one element in the
// `host:track-devices` event stream. Wire-protocol keys differ from our
// internal Device (e.g. `transport_id` vs our `TransportID`), so we map
// explicitly in handlePayload rather than relying on json tags against
// the shared Device type.
type trackDevice struct {
	Serial      string `json:"serial"`
	State       string `json:"state"`
	Product     string `json:"product"`
	Model       string `json:"model"`
	Device      string `json:"device"`
	TransportID string `json:"transport_id"`
}

// trackDeviceChange is what we hand to the consumer callback. Carries
// the full current snapshot plus the diffed add/remove sets so the
// consumer (LogcatStreamManager, /ws/devices broadcaster) doesn't need
// to re-diff.
type trackDeviceChange struct {
	Current []Device // snapshot in adb-server order
	Added   []string // serials that are new since last event
	Removed []string // serials that disappeared since last event
}

// onChangeFn is the user-supplied callback. Invoked synchronously inside
// the read loop; the consumer must not block.
type onChangeFn func(change trackDeviceChange)

// AdbEventStream holds one persistent TCP connection to the adb server
// at localhost:$ANDROID_ADB_SERVER_PORT (default 5037) and surfaces
// device-list changes via onChange. Owns no goroutines outside Run; it
// is safe to call Stop from any goroutine and any number of times.
type AdbEventStream struct {
	port     int
	onChange onChangeFn
	logger   *log.Logger

	stopCh   chan struct{}
	stopOnce sync.Once

	// last snapshot, mutated only inside Run.
	last map[string]Device
}

// NewAdbEventStream constructs a stream. port 0 selects the default 5037.
func NewAdbEventStream(port int, onChange onChangeFn) *AdbEventStream {
	if port == 0 {
		port = DefaultAdbServerPort
	}
	return &AdbEventStream{
		port:     port,
		onChange: onChange,
		logger:   log.New(io.Discard, "", 0),
		stopCh:   make(chan struct{}),
	}
}

// SetLogger attaches a logger for diagnostic output. Default is silent;
// pass nil to silence.
func (s *AdbEventStream) SetLogger(l *log.Logger) {
	if l == nil {
		s.logger = log.New(io.Discard, "", 0)
		return
	}
	s.logger = l
}

// Port returns the port this stream will dial. Useful for tests that
// want to point a fake adb server at the same value.
func (s *AdbEventStream) Port() int { return s.port }

// Stop signals Run to exit and tear down the connection. Safe from any
// goroutine, multiple times.
func (s *AdbEventStream) Stop() {
	s.stopOnce.Do(func() { close(s.stopCh) })
}

// Run blocks until ctx is cancelled, Stop is called, or the adb server
// drops the connection and we give up. Reconnects with exponential
// backoff (1s → 30s) on any connection or handshake error.
//
// On reconnect we drop the in-memory snapshot so the next event is
// treated as a fresh full snapshot (everything in `Added`). This keeps
// the consumer from missing device-add events that happened while we
// were disconnected.
func (s *AdbEventStream) Run(ctx context.Context) {
	backoff := time.Second
	const maxBackoff = 30 * time.Second

	for {
		select {
		case <-ctx.Done():
			return
		case <-s.stopCh:
			return
		default:
		}

		err := s.connectAndStream(ctx)
		if err == nil {
			// Clean shutdown via Stop or ctx cancel.
			return
		}

		s.logger.Printf("adb event stream: %v (retry in %s)", err, backoff)
		// Drop snapshot so re-connect delivers a fresh full diff.
		s.last = nil

		select {
		case <-ctx.Done():
			return
		case <-s.stopCh:
			return
		case <-time.After(backoff):
		}

		backoff *= 2
		if backoff > maxBackoff {
			backoff = maxBackoff
		}
	}
}

// connectAndStream opens one TCP connection, performs the
// host:track-devices handshake, then pumps JSON device lists until the
// server disconnects, ctx cancels, or Stop is called.
func (s *AdbEventStream) connectAndStream(ctx context.Context) error {
	addr := fmt.Sprintf("localhost:%d", s.port)
	dialer := net.Dialer{Timeout: 5 * time.Second}
	conn, err := dialer.DialContext(ctx, "tcp", addr)
	if err != nil {
		return fmt.Errorf("dial %s: %w", addr, err)
	}
	defer conn.Close()

	if err := conn.SetDeadline(time.Now().Add(10 * time.Second)); err != nil {
		return fmt.Errorf("set handshake deadline: %w", err)
	}

	// Send "0012host:track-devices" (0012 is the hex length of the payload).
	const cmd = "host:track-devices"
	req := fmt.Sprintf("%04x%s", len(cmd), cmd)
	if _, err := conn.Write([]byte(req)); err != nil {
		return fmt.Errorf("write request: %w", err)
	}

	if err := readOkayOrFail(conn); err != nil {
		return err
	}

	// Clear deadline for the long-lived streaming phase.
	if err := conn.SetDeadline(time.Time{}); err != nil {
		return fmt.Errorf("clear stream deadline: %w", err)
	}

	reader := bufio.NewReader(conn)
	for {
		select {
		case <-ctx.Done():
			return nil
		case <-s.stopCh:
			return nil
		default:
		}

		payload, err := readLengthPrefixed(reader)
		if err != nil {
			return fmt.Errorf("read payload: %w", err)
		}
		if err := s.handlePayload(payload); err != nil {
			// Bad payload: log and keep reading. A single malformed
			// event shouldn't kill the stream.
			s.logger.Printf("adb event stream: handle payload: %v", err)
		}
	}
}

// readOkayOrFail reads the 4-byte hex length + OKAY / FAIL response.
// On FAIL, it also reads the trailing reason payload so the stream is
// left in a clean state for the caller to decide what to do.
func readOkayOrFail(r io.Reader) error {
	body, err := readLengthPrefixed(r)
	if err != nil {
		return fmt.Errorf("read response: %w", err)
	}
	switch string(body) {
	case "OKAY":
		return nil
	case "FAIL":
		reason, rerr := readLengthPrefixed(r)
		if rerr != nil {
			return fmt.Errorf("FAIL (reason unreadable: %v)", rerr)
		}
		return fmt.Errorf("adb server returned FAIL: %s", string(reason))
	default:
		return fmt.Errorf("unexpected response: %q", string(body))
	}
}

// readLengthPrefixed reads one 4-byte ASCII hex length followed by
// exactly that many payload bytes.
func readLengthPrefixed(r io.Reader) ([]byte, error) {
	var hdr [4]byte
	if _, err := io.ReadFull(r, hdr[:]); err != nil {
		return nil, err
	}
	n, err := decodeHexLength(hdr[:])
	if err != nil {
		return nil, fmt.Errorf("decode length %q: %w", hdr, err)
	}
	payload := make([]byte, n)
	if _, err := io.ReadFull(r, payload); err != nil {
		return nil, fmt.Errorf("read %d payload bytes: %w", n, err)
	}
	return payload, nil
}

func decodeHexLength(b []byte) (int, error) {
	if len(b) != 4 {
		return 0, fmt.Errorf("expected 4 hex chars, got %d", len(b))
	}
	n, err := hex.DecodeString(string(b))
	if err != nil {
		return 0, err
	}
	// adb wire protocol uses 2-byte big-endian length, top 2 bytes
	// of the 4-hex-char prefix are always zero in practice.
	return int(n[0])<<8 | int(n[1]), nil
}

// handlePayload decodes one JSON device list, diffs against the last
// known snapshot, and invokes onChange when there's a diff.
func (s *AdbEventStream) handlePayload(payload []byte) error {
	var raw []trackDevice
	if err := json.Unmarshal(payload, &raw); err != nil {
		return fmt.Errorf("decode json: %w", err)
	}

	current := make(map[string]Device, len(raw))
	currentOrder := make([]Device, 0, len(raw))
	for _, td := range raw {
		d := Device{
			Serial: td.Serial,
			State:  td.State,
			Model:  td.Model,
		}
		current[td.Serial] = d
		currentOrder = append(currentOrder, d)
	}

	if s.last == nil {
		// First event after (re)connect: treat the whole snapshot as
		// "added" so consumers don't miss connects that happened
		// during the disconnect window.
		added := make([]string, 0, len(current))
		for serial := range current {
			added = append(added, serial)
		}
		sort.Strings(added)
		if len(added) > 0 {
			s.invokeChange(trackDeviceChange{
				Current: currentOrder,
				Added:   added,
			})
		}
		s.last = current
		return nil
	}

	var added, removed []string
	for serial := range current {
		if _, ok := s.last[serial]; !ok {
			added = append(added, serial)
		}
	}
	for serial := range s.last {
		if _, ok := current[serial]; !ok {
			removed = append(removed, serial)
		}
	}

	if len(added) > 0 || len(removed) > 0 {
		sort.Strings(added)
		sort.Strings(removed)
		s.invokeChange(trackDeviceChange{
			Current: currentOrder,
			Added:   added,
			Removed: removed,
		})
	}
	s.last = current
	return nil
}

// invokeChange guards against nil callback and panics in user code, so
// one buggy consumer can't kill the stream for everyone else.
func (s *AdbEventStream) invokeChange(c trackDeviceChange) {
	if s.onChange == nil {
		return
	}
	defer func() {
		if r := recover(); r != nil {
			s.logger.Printf("adb event stream: onChange panic: %v", r)
		}
	}()
	s.onChange(c)
}
