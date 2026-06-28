package server

import (
	"bufio"
	"bytes"
	"context"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"sort"
	"strings"
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

	// snapshotMu protects snapshot for concurrent reads from
	// Snapshot() while Run() updates it on each track-devices event.
	snapshotMu sync.RWMutex
	snapshot   []Device // current device list, in adb-server order

	// last is the snapshot keyed by serial, used for diffing. Mutated
	// only inside Run under snapshotMu.
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

// Snapshot returns a copy of the current device list. Safe to call
// from any goroutine. Returns an empty slice (not nil) when the
// stream hasn't seen its first event yet, so callers can range over
// it without nil checks.
func (s *AdbEventStream) Snapshot() []Device {
	s.snapshotMu.RLock()
	defer s.snapshotMu.RUnlock()
	out := make([]Device, len(s.snapshot))
	copy(out, s.snapshot)
	return out
}

// publishSnapshot replaces both `snapshot` and `last` atomically.
// Caller must hold snapshotMu for writing.
func (s *AdbEventStream) publishSnapshot(currentOrder []Device, current map[string]Device) {
	s.snapshotMu.Lock()
	s.snapshot = currentOrder
	s.last = current
	s.snapshotMu.Unlock()
}

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

// readOkayOrFail reads the host-command handshake response.
//
// Adb wire protocol quirk: the OKAY/FAIL response to a host command
// like `host:track-devices` is a RAW 4-byte token with no length
// prefix (unlike every payload that follows, which IS length-prefixed).
// On FAIL, the reason is then sent as a length-prefixed payload.
//
// The previous version of this function called readLengthPrefixed,
// which expected a 4-hex-digit length prefix — that matched a
// well-formed fake server but never worked against real adb, which
// sends bare "OKAY" / "FAIL".
func readOkayOrFail(r io.Reader) error {
	var hdr [4]byte
	if _, err := io.ReadFull(r, hdr[:]); err != nil {
		return fmt.Errorf("read handshake: %w", err)
	}
	switch string(hdr[:]) {
	case "OKAY":
		return nil
	case "FAIL":
		reason, rerr := readLengthPrefixed(r)
		if rerr != nil {
			return fmt.Errorf("FAIL (reason unreadable: %v)", rerr)
		}
		return fmt.Errorf("adb server returned FAIL: %s", string(reason))
	default:
		return fmt.Errorf("unexpected handshake response: %q", string(hdr[:]))
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

// handlePayload decodes one device list (text or JSON format), diffs
// against the last known snapshot, and invokes onChange when there's
// a diff.
//
// Format note: real adb's `host:track-devices` emits one event per
// device-list change, in a TEXT format that's the same shape as
// `adb devices` (without the `-l` extras):
//
//	<serial>\t<state>\n
//	<serial>\t<state>\n
//	...
//
// The earlier JSON assumption came from a misread of the adb source —
// the actual response is text. We still accept JSON if the payload
// starts with `[` (defensive: older adb versions or future changes).
func (s *AdbEventStream) handlePayload(payload []byte) error {
	trimmed := bytes.TrimSpace(payload)
	if len(trimmed) == 0 {
		return nil
	}

	var devices []Device
	if trimmed[0] == '[' {
		devices = parseTrackJSON(trimmed)
	} else {
		devices = parseTrackText(trimmed)
	}

	current := make(map[string]Device, len(devices))
	currentOrder := make([]Device, 0, len(devices))
	for _, d := range devices {
		current[d.Serial] = d
		currentOrder = append(currentOrder, d)
	}

	// Snapshot the previous state under the read lock so Snapshot()
	// callers (HTTP handler, etc.) see a consistent view while we
	// compute the diff.
	s.snapshotMu.RLock()
	prev := s.last
	s.snapshotMu.RUnlock()

	var added, removed []string
	if prev == nil {
		// First event after (re)connect: treat the whole snapshot as
		// "added" so consumers don't miss connects that happened
		// during the disconnect window.
		for serial := range current {
			added = append(added, serial)
		}
	} else {
		for serial := range current {
			if _, ok := prev[serial]; !ok {
				added = append(added, serial)
			}
		}
		for serial := range prev {
			if _, ok := current[serial]; !ok {
				removed = append(removed, serial)
			}
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
	s.publishSnapshot(currentOrder, current)
	return nil
}

// parseTrackJSON parses the legacy JSON-array format
// (e.g. [{"serial":"...","state":"device",...}]). Kept for defensive
// compatibility with older adb versions / forks.
func parseTrackJSON(payload []byte) []Device {
	var raw []trackDevice
	if err := json.Unmarshal(payload, &raw); err != nil {
		return nil
	}
	out := make([]Device, 0, len(raw))
	for _, td := range raw {
		out = append(out, Device{
			Serial: td.Serial,
			State:  td.State,
			Model:  td.Model,
		})
	}
	return out
}

// parseTrackText parses the modern adb text format:
//
//	<serial>\t<state>\n
//	<serial>\t<state>\n
//
// Each line is tab-separated. State is one of: device, offline,
// unauthorized, recovery, sideload, bootloader. Lines starting with
// `*` (header marker) are skipped. Unlike `adb devices -l`, this
// stream does NOT include product:/model:/device:/transport_id:
// columns — those need to be fetched separately if needed.
func parseTrackText(payload []byte) []Device {
	out := make([]Device, 0, 4)
	for _, line := range strings.Split(string(payload), "\n") {
		line = strings.TrimRight(line, "\r")
		if line == "" || strings.HasPrefix(line, "*") {
			continue
		}
		fields := strings.SplitN(line, "\t", 3)
		if len(fields) < 2 {
			continue
		}
		serial := strings.TrimSpace(fields[0])
		state := strings.TrimSpace(fields[1])
		if serial == "" {
			continue
		}
		out = append(out, Device{Serial: serial, State: state})
	}
	return out
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
