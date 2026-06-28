package server

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"log"
	"os/exec"
	"regexp"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

// CrashKind classifies the type of crash detected by the matcher.
type CrashKind string

const (
	CrashKindCrash  CrashKind = "crash"  // FATAL EXCEPTION (Java/Kotlin)
	CrashKindAnr    CrashKind = "anr"    // ANR in <pkg> / Input dispatching timed out
	CrashKindNative CrashKind = "native" // signal SIGSEGV/SIGABRT/etc, tombstone
)

// CrashEvent is the structured crash notification broadcast to all
// crash subscribers. Serial identifies the device; StackTrace contains
// enough context for triage without forcing the consumer to re-query
// the log buffer.
type CrashEvent struct {
	Type       CrashKind `json:"type"`
	Serial     string    `json:"serial"`
	Package    string    `json:"package"`
	Summary    string    `json:"summary"`
	StackTrace string    `json:"stackTrace"`
	DetectedAt time.Time `json:"detectedAt"`
}

// crashPatterns is the set of regexes applied to each logcat line.
// Compile-once at package init. Patterns are conservative: each is a
// well-known signature in Android logcat output. False positives are
// expected on chatty apps — the toast-notification toggle is the
// user-facing escape hatch.
var crashPatterns = []*regexp.Regexp{
	regexp.MustCompile(`FATAL EXCEPTION`),
	regexp.MustCompile(`AndroidRuntime.*FATAL`),
	regexp.MustCompile(`ANR in [a-zA-Z0-9_.]+`),
	regexp.MustCompile(`Input dispatching timed out`),
	regexp.MustCompile(`signal \d+ \(SIG(SEGV|ABRT|BUS|ILL)\)`),
	regexp.MustCompile(`tombstone written to:`),
	regexp.MustCompile(`Force Finishing .* due to`),
	regexp.MustCompile(`Process [a-zA-Z0-9_.]+ has died`),
}

var crashPackagePattern = regexp.MustCompile(`at ([a-zA-Z0-9_.]+)/`)

// crashPackagePatterns: try each in order, first match wins.
// Patterns cover the common FATAL EXCEPTION / ANR / native crash
// shapes. False negatives are fine — we just won't show a package;
// false positives produce a wrong label in the notification.
var crashPackageExtractors = []*regexp.Regexp{
	// Java/Kotlin stack frame: at <pkg>.<Class>(...) — captures pkg
	// up to the first ".ClassName" boundary (ClassName starts with
	// uppercase by convention).
	regexp.MustCompile(`at\s+([a-zA-Z0-9_.$]+?)\.[A-Z][a-zA-Z0-9_$]*`),
	// ANR header: ANR in <pkg>
	regexp.MustCompile(`ANR in ([a-zA-Z0-9_.]+)`),
	// Process header: Process: <pkg>
	regexp.MustCompile(`Process: ([a-zA-Z0-9_.]+)`),
}

// logcatTagPattern extracts the tag from a standard logcat line:
//
//	MM-DD HH:MM:SS.mmm  PID TID PRIO TAG: message
//
// Returns the tag without the trailing colon, or "" if the line
// doesn't look like logcat.
var logcatTagPattern = regexp.MustCompile(`^\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d{3}\s+\d+\s+\d+\s+\w\s+(\S+?):`)

// classKind maps a crash pattern index to its CrashKind. Index matches
// the order in crashPatterns.
var crashPatternKind = []CrashKind{
	CrashKindCrash,  // FATAL EXCEPTION
	CrashKindCrash,  // AndroidRuntime.*FATAL
	CrashKindAnr,    // ANR in
	CrashKindAnr,    // Input dispatching timed out
	CrashKindNative, // signal SIG*
	CrashKindNative, // tombstone
	CrashKindCrash,  // Force Finishing
	CrashKindCrash,  // Process died
}

// LineSubscription is the handle returned by LogcatStreamManager.Subscribe.
// cancel must be called when the consumer is done; the channel is closed
// after cancel returns.
type LineSubscription struct {
	Lines  <-chan string
	cancel func()
}

// Cancel unsubscribes. Safe to call multiple times.
func (s *LineSubscription) Cancel() {
	if s != nil && s.cancel != nil {
		s.cancel()
	}
}

// CrashSubscription is the handle returned by LogcatStreamManager.SubscribeCrash.
type CrashSubscription struct {
	Events <-chan CrashEvent
	cancel func()
}

// Cancel unsubscribes from crash events.
func (s *CrashSubscription) Cancel() {
	if s != nil && s.cancel != nil {
		s.cancel()
	}
}

// spawnFn starts a logcat subprocess for the given serial and returns
// its stdout reader and a kill function. Injected for testability;
// default impl shells out via adbManagerSpawn.
type spawnFn func(serial string) (stdout io.ReadCloser, kill func() error, err error)

// adbManagerSpawn is the production spawnFn: shells out via the
// project-wide adb binary. Caller is responsible for invoking kill()
// to terminate the subprocess.
func adbManagerSpawn(m *AdbManager) spawnFn {
	return func(serial string) (io.ReadCloser, func() error, error) {
		execCmd, stdout, err := m.StartLogcat(serial, LogFilter{})
		if err != nil {
			return nil, nil, err
		}
		kill := func() error {
			if execCmd != nil && execCmd.Process != nil {
				return execCmd.Process.Kill()
			}
			return nil
		}
		return stdout, kill, nil
	}
}

// seedFn dumps the device-side logcat history as a string. nil means
// no seed (e.g. in tests that don't need the round-trip).
type seedFn func(serial string) (string, error)

func adbManagerSeed(m *AdbManager) seedFn {
	return func(serial string) (string, error) {
		return m.GetRecentLogcat(serial, seedLinesOnStart)
	}
}

// LogcatStreamManager owns one persistent adb logcat subprocess per
// device (per the project-wide "single source of truth" rule) and
// fans the line stream out to:
//   - LineSubscription consumers (WS Logcat, session-logcat,
//     local-recording, ...)
//   - A ring buffer for GetRecentLogcat-style queries
//   - A regex matcher that emits CrashEvents to crash subscribers
type LogcatStreamManager struct {
	adb    *AdbManager
	spawn  spawnFn
	seed   seedFn
	logger *log.Logger

	mu      sync.Mutex
	streams map[string]*deviceStream

	// ctx cancels all deviceStream goroutines on shutdown.
	ctx    context.Context
	cancel context.CancelFunc

	// Tracks overall close so callers can wait for full teardown.
	wg sync.WaitGroup
}

// NewLogcatStreamManager constructs a manager. adb is required for the
// default spawnFn + seedFn; pass nil + SetSpawnFunc / SetSeedFunc to
// defer wiring in tests.
func NewLogcatStreamManager(adb *AdbManager) *LogcatStreamManager {
	ctx, cancel := context.WithCancel(context.Background())
	m := &LogcatStreamManager{
		adb:     adb,
		spawn:   adbManagerSpawn(adb),
		seed:    adbManagerSeed(adb),
		logger:  log.New(io.Discard, "", 0),
		streams: make(map[string]*deviceStream),
		ctx:     ctx,
		cancel:  cancel,
	}
	return m
}

// SetSpawnFunc overrides the subprocess spawn function (test seam).
func (m *LogcatStreamManager) SetSpawnFunc(fn spawnFn) {
	m.mu.Lock()
	m.spawn = fn
	m.mu.Unlock()
}

// SetSeedFunc overrides the device-history seed function (test seam).
// Pass nil to disable seeding.
func (m *LogcatStreamManager) SetSeedFunc(fn seedFn) {
	m.mu.Lock()
	m.seed = fn
	m.mu.Unlock()
}

// SetLogger attaches a logger for diagnostics.
func (m *LogcatStreamManager) SetLogger(l *log.Logger) {
	if l == nil {
		m.logger = log.New(io.Discard, "", 0)
		return
	}
	m.logger = l
}

// Ensure starts the watcher for serial if not already running. Safe to
// call from any goroutine and any number of times. If the watcher
// previously went offline (after exhausting retries), Ensure resets
// its retry counter and triggers a fresh start.
func (m *LogcatStreamManager) Ensure(serial string) {
	m.mu.Lock()
	defer m.mu.Unlock()

	ds, ok := m.streams[serial]
	if !ok {
		ds = newDeviceStream(serial, m.spawn, m.seed, m.logger)
		m.streams[serial] = ds
	}
	ds.ensure()
}

// Close stops the watcher for serial and waits for its goroutine to
// exit. Subscribers receive a closed Lines channel. The map entry is
// removed. If serial is not active, Close is a no-op.
func (m *LogcatStreamManager) Close(serial string) {
	m.mu.Lock()
	ds, ok := m.streams[serial]
	delete(m.streams, serial)
	m.mu.Unlock()

	if !ok {
		return
	}
	ds.shutdown()
}

// CloseAll stops every active watcher. Used during server shutdown.
func (m *LogcatStreamManager) CloseAll() {
	m.mu.Lock()
	streams := make([]*deviceStream, 0, len(m.streams))
	for _, ds := range m.streams {
		streams = append(streams, ds)
	}
	m.streams = make(map[string]*deviceStream)
	m.mu.Unlock()

	for _, ds := range streams {
		ds.shutdown()
	}
	m.cancel()
	m.wg.Wait()
}

// Subscribe registers a new line consumer. replayLines controls how
// many recent lines from the ring buffer to deliver immediately (the
// WS Logcat screen uses 200 so a freshly opened page shows context
// instead of a blank slate).
//
// Returns the subscription handle and an error if the watcher isn't
// running yet (caller should Ensure first, then Subscribe).
func (m *LogcatStreamManager) Subscribe(serial string, replayLines int) (LineSubscription, error) {
	m.mu.Lock()
	ds, ok := m.streams[serial]
	m.mu.Unlock()
	if !ok {
		return LineSubscription{}, fmt.Errorf("no watcher for serial %q", serial)
	}
	return ds.subscribe(replayLines), nil
}

// SubscribeCrash registers a new crash event consumer.
func (m *LogcatStreamManager) SubscribeCrash(serial string) (CrashSubscription, error) {
	m.mu.Lock()
	ds, ok := m.streams[serial]
	m.mu.Unlock()
	if !ok {
		return CrashSubscription{}, fmt.Errorf("no watcher for serial %q", serial)
	}
	return ds.subscribeCrash(), nil
}

// Recent returns up to n most recent lines from the ring buffer in
// chronological order. If the watcher isn't running, returns nil.
func (m *LogcatStreamManager) Recent(serial string, n int) []string {
	m.mu.Lock()
	ds, ok := m.streams[serial]
	m.mu.Unlock()
	if !ok {
		return nil
	}
	return ds.recent(n)
}

// IsRunning reports whether the watcher has an active subprocess for
// serial (vs starting / offline / closed).
func (m *LogcatStreamManager) IsRunning(serial string) bool {
	m.mu.Lock()
	ds, ok := m.streams[serial]
	m.mu.Unlock()
	if !ok {
		return false
	}
	return ds.isRunning()
}

// ActiveSerials returns the serials of all currently-known watchers,
// regardless of state. Useful for diagnostics.
func (m *LogcatStreamManager) ActiveSerials() []string {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := make([]string, 0, len(m.streams))
	for s := range m.streams {
		out = append(out, s)
	}
	return out
}

// =====================================================================
// deviceStream — per-device state and goroutine.
// =====================================================================

type streamState int

const (
	stateStarting streamState = iota
	stateRunning
	stateOffline // exceeded retry budget; sits idle until Ensure() resets
	stateStopped // explicit Close(); will not restart
)

// Tunables for the manager. Exposed as vars (not consts) so tests can
// shrink the retry budget and backoff durations.
var (
	ringBufferCapacity = 5000
	subscriberBuffer   = 2000
	maxRetries         = 5
	seedLinesOnStart   = 5000

	// Backoff schedule for subprocess death: index 1 = first retry,
	// index 5 = fifth retry. Index 0 is unused.
	retryBackoff = []time.Duration{
		0,
		1 * time.Second,
		2 * time.Second,
		4 * time.Second,
		8 * time.Second,
		16 * time.Second,
	}

	// Crash coalescing window: matching lines within this window that
	// share the same first-matching-line hash get coalesced into one
	// event.
	crashCoalesceWindow = 5 * time.Second
	crashContextLines   = 50
	crashStackMaxBytes  = 200 * 1024 // 200 KB cap per event
)

// deviceStream is the per-device state. Lifetime is managed by the
// containing LogcatStreamManager; concurrency on its fields is via
// internal mutexes.
type deviceStream struct {
	serial string
	spawn  spawnFn
	seed   seedFn
	logger *log.Logger

	mu         sync.Mutex
	state      streamState
	retryCount int

	ring    *ringBuffer
	lineSub *subscriberSet // line consumers
	crashSub *subscriberSet // crash event consumers

	// Crash coalescing state: at most one in-flight pendingCrash at a
	// time, keyed by stack-hash. When a new matching line arrives with
	// a different hash, the pending one flushes first.
	pendingCrash *pendingCrashEvent
	pendingSince time.Time

	// flushTimer fires crashCoalesceWindow after the last matching line
	// arrived; on fire, it flushes pendingCrash. Reset on every new
	// matching line of the same hash. Without this, a single FATAL
	// EXCEPTION with no follow-up stack frames would never be emitted
	// because nothing else would call flushPendingLocked.
	flushTimer *time.Timer

	// Last subprocess activity (for diagnostics + idle detection).
	lastLineAt atomic.Int64 // unix nano of most recently delivered line

	// Lifecycle: run goroutine + cancellation context + done signal.
	runCtx    context.Context
	runCancel context.CancelFunc
	runDone   chan struct{}

	// currentKill is the kill func returned by the latest successful
	// spawn. shutdown() captures it (under mu) and invokes it so the
	// read loop unblocks immediately when the user wants to stop,
	// rather than waiting for scanner EOF from a still-running
	// subprocess. Only meaningful while state == stateRunning.
	currentKill func() error
}

// pendingCrashEvent is the in-flight coalesced crash being built up.
type pendingCrashEvent struct {
	hash        string // first line's content hash (stack-hash)
	kind        CrashKind
	packageName string
	tag         string // logcat tag of the first matching line; coalesce key
	summary     string // first matching line
	lines       []string
	flushed     bool
}

// newDeviceStream constructs (but does not start) a deviceStream.
// runCtx / runCancel / runDone are intentionally left nil so the first
// ensure() can detect "never spawned" and kick off the goroutine.
func newDeviceStream(serial string, spawn spawnFn, seed seedFn, logger *log.Logger) *deviceStream {
	ds := &deviceStream{
		serial:   serial,
		spawn:    spawn,
		seed:     seed,
		logger:   logger,
		state:    stateStarting,
		ring:     newRingBuffer(ringBufferCapacity),
		lineSub:  newSubscriberSet(),
		crashSub: newSubscriberSet(),
	}
	return ds
}

// ensure makes sure a run goroutine is alive. Called by the manager.
//
// First call (runDone == nil) — spawn a fresh goroutine.
// stateOffline — previous goroutine exited after retry budget; reset
// retry counter and spawn a fresh one.
// stateRunning / stateStarting (runDone != nil) — goroutine already
// alive, no-op.
// shutdown() is the only way to stop the goroutine (sets stateStopped).
func (ds *deviceStream) ensure() {
	ds.mu.Lock()

	if ds.state == stateStopped {
		ds.mu.Unlock()
		return
	}

	// runDone == nil  → first call, never spawned.
	// stateOffline    → previous goroutine fully exited.
	needsStart := ds.runDone == nil || ds.state == stateOffline

	if !needsStart {
		// Goroutine is alive (Running or in-flight Starting). No-op.
		ds.mu.Unlock()
		return
	}

	if ds.state == stateOffline {
		ds.retryCount = 0
	}
	ds.state = stateStarting
	ds.runCtx, ds.runCancel = context.WithCancel(context.Background())
	ds.runDone = make(chan struct{})
	ds.currentKill = nil
	ds.mu.Unlock()

	go ds.run()
}

// shutdown cancels the run goroutine and waits for it to exit.
func (ds *deviceStream) shutdown() {
	ds.mu.Lock()
	if ds.state == stateStopped {
		ds.mu.Unlock()
		return
	}
	ds.state = stateStopped
	cancel := ds.runCancel
	kill := ds.currentKill
	ds.currentKill = nil
	ds.mu.Unlock()

	if cancel != nil {
		cancel()
	}
	// Force the subprocess to exit so readLoop unblocks; otherwise
	// scanner.Scan() parks forever on the still-open stdout pipe and
	// run() never closes runDone. kill() is idempotent (killOnce in
	// the fake source, ErrProcessDone for *exec.Cmd in prod).
	if kill != nil {
		_ = kill()
	}

	// Wait for goroutine to exit.
	<-ds.runDone

	// Stop the crash flush timer so it can't fire after we close the
	// subscriber channels (sending on a closed channel panics).
	ds.mu.Lock()
	if ds.flushTimer != nil {
		ds.flushTimer.Stop()
		ds.flushTimer = nil
	}
	ds.mu.Unlock()

	// Close all subscriber channels.
	ds.lineSub.closeAll()
	ds.crashSub.closeAll()
}

// run is the lifecycle goroutine. It runs for the entire lifetime of
// the deviceStream (from first ensure() until shutdown()). It loops
// over spawn/read/retry until shutdown or retry budget exhaustion.
func (ds *deviceStream) run() {
	defer close(ds.runDone)

	for {
		// Bail on shutdown.
		if ds.runCtx.Err() != nil {
			return
		}

		// Spawn subprocess.
		stdout, kill, err := ds.spawn(ds.serial)
		if err != nil {
			ds.handleSpawnFailure(err)
			if ds.isStopped() {
				return
			}
			continue
		}

		// Race window: shutdown() may have flipped state to Stopped
		// while we were spawning. If so, kill the subprocess we just
		// got (shutdown saw currentKill=nil and won't call it) and
		// exit. Without this check the spawned process leaks and
		// shutdown blocks forever on <-runDone.
		ds.mu.Lock()
		if ds.state == stateStopped {
			ds.mu.Unlock()
			_ = kill()
			return
		}
		// Stash kill so shutdown() can interrupt a blocked readLoop
		// without waiting for natural EOF.
		ds.currentKill = kill
		ds.mu.Unlock()

		// Seed ring buffer from device-side history on first start
		// only.
		if ds.retryCount == 0 && !ds.ring.filledFromSeed() {
			ds.trySeed()
		}

		ds.mu.Lock()
		ds.state = stateRunning
		ds.retryCount = 0
		ds.mu.Unlock()

		ds.logger.Printf("logcat stream[%s]: started", ds.serial)
		readErr := ds.readLoop(stdout)

		// Subprocess is done (EOF or error). Clear currentKill and
		// make sure the process is actually dead before retrying.
		ds.mu.Lock()
		ds.currentKill = nil
		ds.mu.Unlock()
		if kill != nil {
			_ = kill()
		}

		if ds.isStopped() {
			return
		}

		if readErr != nil {
			ds.logger.Printf("logcat stream[%s]: subprocess exited: %v", ds.serial, readErr)
		} else {
			ds.logger.Printf("logcat stream[%s]: subprocess exited", ds.serial)
		}

		// Should we retry?
		ds.mu.Lock()
		ds.retryCount++
		exceeded := ds.retryCount > maxRetries
		ds.mu.Unlock()

		if exceeded {
			ds.logger.Printf("logcat stream[%s]: retry budget exhausted, going offline", ds.serial)
			ds.flushPendingCrash()
			ds.mu.Lock()
			ds.state = stateOffline
			ds.mu.Unlock()
			return
		}

		// Backoff before retrying. Respect cancellation.
		backoff := retryBackoff[ds.retryCount]
		ds.logger.Printf("logcat stream[%s]: retrying in %s (attempt %d/%d)",
			ds.serial, backoff, ds.retryCount, maxRetries)
		select {
		case <-time.After(backoff):
		case <-ds.runCtx.Done():
			return
		}
	}
}

func (ds *deviceStream) isStopped() bool {
	ds.mu.Lock()
	defer ds.mu.Unlock()
	return ds.state == stateStopped
}

// readLoop reads lines from stdout and dispatches them to subscribers
// + ring buffer + crash matcher. Returns when stdout EOF / error.
func (ds *deviceStream) readLoop(stdout io.Reader) error {
	scanner := bufio.NewScanner(stdout)
	scanner.Buffer(make([]byte, 64*1024), 1024*1024) // up to 1MB lines

	for scanner.Scan() {
		line := scanner.Text()
		ds.lastLineAt.Store(time.Now().UnixNano())

		// 1) Ring buffer first — always records, regardless of subs
		ds.ring.push(line)

		// 2) Fan out to line subscribers (drop-old on overflow)
		ds.lineSub.broadcast(line)

		// 3) Crash matching (cheap; compiled regexes)
		ds.matchCrash(line)
	}

	ds.flushPendingCrash()
	return scanner.Err()
}

func (ds *deviceStream) handleSpawnFailure(err error) {
	ds.logger.Printf("logcat stream[%s]: spawn failed: %v", ds.serial, err)
	ds.mu.Lock()
	ds.retryCount++
	exceeded := ds.retryCount > maxRetries
	ds.mu.Unlock()
	if exceeded {
		ds.mu.Lock()
		ds.state = stateOffline
		ds.mu.Unlock()
		return
	}
	backoff := retryBackoff[ds.retryCount]
	select {
	case <-time.After(backoff):
	case <-ds.runCtx.Done():
	}
}

// trySeed calls the seed function (production: `adb logcat -d -t N`)
// once to populate the ring buffer from device-side history. Errors
// are logged and ignored; the subprocess will keep reading new lines
// regardless.
func (ds *deviceStream) trySeed() {
	if ds.seed == nil {
		return
	}
	out, err := ds.seed(ds.serial)
	if err != nil {
		ds.logger.Printf("logcat stream[%s]: seed failed: %v", ds.serial, err)
		return
	}
	count := 0
	for _, line := range strings.Split(out, "\n") {
		if line == "" {
			continue
		}
		ds.ring.push(line)
		count++
	}
	ds.ring.markSeeded()
	ds.logger.Printf("logcat stream[%s]: seeded %d lines from device history", ds.serial, count)
}

// recent returns up to n most recent lines in chronological order.
func (ds *deviceStream) recent(n int) []string {
	return ds.ring.snapshot(n)
}

func (ds *deviceStream) isRunning() bool {
	ds.mu.Lock()
	defer ds.mu.Unlock()
	return ds.state == stateRunning
}

// =====================================================================
// Subscribe / subscribeCrash
// =====================================================================

func (ds *deviceStream) subscribe(replay int) LineSubscription {
	ch := ds.lineSub.add(subscriberBuffer)
	cancel := func() { ds.lineSub.remove(ch) }

	// Replay up to `replay` lines from the ring buffer so the
	// consumer has immediate context. Delivered synchronously before
	// returning — these lines go to the channel without blocking
	// (buffered).
	if replay > 0 {
		for _, line := range ds.ring.snapshot(replay) {
			select {
			case ch <- line:
			default:
				// channel already full; skip replay
			}
		}
	}

	return LineSubscription{Lines: ch, cancel: cancel}
}

func (ds *deviceStream) subscribeCrash() CrashSubscription {
	ch := ds.crashSub.addCrash(64) // crash events are sparse; small buffer
	cancel := func() { ds.crashSub.removeCrash(ch) }
	return CrashSubscription{Events: ch, cancel: cancel}
}

// =====================================================================
// Crash matching
// =====================================================================

// matchCrash scans `line` against the pattern set and coalesces
// matching bursts into a single CrashEvent. Tag (e.g. "AndroidRuntime",
// "ActivityManager", "libc") is the primary coalesce key: lines from
// the same tag within crashCoalesceWindow are appended to the same
// pending event, whether or not they individually match a pattern.
// This handles the standard FATAL EXCEPTION shape:
//
//	AndroidRuntime: FATAL EXCEPTION: main
//	AndroidRuntime: Process: com.example.foo, PID: 1234
//	AndroidRuntime: java.lang.RuntimeException: boom
//	AndroidRuntime:     at com.example.foo.MainActivity.onCreate(...)
//	AndroidRuntime:     at android.app.Activity.performCreate(...)
//
// …which has only one pattern-matching line but five useful context
// lines, all sharing the "AndroidRuntime" tag.
func (ds *deviceStream) matchCrash(line string) {
	ds.mu.Lock()
	defer ds.mu.Unlock()

	tag := extractLogcatTag(line)

	// Tag-based coalesce: while a pending crash exists for the same
	// tag, append (regardless of pattern match). This captures both
	// the FATAL header and the stack frames / Process / Caused-by
	// lines that follow.
	if ds.pendingCrash != nil && tag != "" && tag == ds.pendingCrash.tag {
		ds.pendingCrash.lines = append(ds.pendingCrash.lines, line)
		if ds.pendingCrash.packageName == "" {
			if pkg := extractCrashPackage(line); pkg != "" {
				ds.pendingCrash.packageName = pkg
			}
		}
		ds.pendingSince = time.Now()
		ds.scheduleFlushLocked()
		return
	}

	idx, matched := matchCrashPattern(line)
	if !matched {
		return
	}

	// Different tag (or no tag) with a matching pattern: flush any
	// in-flight pending first, then start a fresh event.
	if ds.pendingCrash != nil {
		ds.flushPendingLocked()
	}

	hash := crashHash(line)
	kind := crashPatternKind[idx]
	pkg := extractCrashPackage(line)

	ds.pendingCrash = &pendingCrashEvent{
		hash:        hash,
		kind:        kind,
		packageName: pkg,
		tag:         tag,
		summary:     line,
		lines:       []string{line},
	}
	ds.pendingSince = time.Now()
	ds.scheduleFlushLocked()
}

// scheduleFlushLocked arms a timer that flushes pendingCrash after
// crashCoalesceWindow. Must be called with ds.mu held. Safe to call
// when pendingCrash is nil — it just cancels any stale timer.
func (ds *deviceStream) scheduleFlushLocked() {
	if ds.flushTimer != nil {
		ds.flushTimer.Stop()
	}
	ds.flushTimer = time.AfterFunc(crashCoalesceWindow, func() {
		ds.mu.Lock()
		defer ds.mu.Unlock()
		// Pending may already be flushed (e.g. by a different-hash
		// match or by EOF). flushPendingLocked is idempotent.
		if ds.pendingCrash != nil {
			ds.flushPendingLocked()
		}
		ds.flushTimer = nil
	})
}

func (ds *deviceStream) flushPendingCrash() {
	ds.mu.Lock()
	defer ds.mu.Unlock()
	ds.flushPendingLocked()
}

func (ds *deviceStream) flushPendingLocked() {
	if ds.pendingCrash == nil || ds.pendingCrash.flushed {
		// Defensive: cancel any stale timer that's pointing at nothing.
		if ds.flushTimer != nil {
			ds.flushTimer.Stop()
			ds.flushTimer = nil
		}
		return
	}
	pc := ds.pendingCrash
	pc.flushed = true

	// Build the event.
	ev := CrashEvent{
		Type:       pc.kind,
		Serial:     ds.serial,
		Package:    pc.packageName,
		Summary:    pc.summary,
		StackTrace: strings.Join(pc.lines, "\n"),
		DetectedAt: ds.pendingSince,
	}

	// Apply stack size cap.
	if len(ev.StackTrace) > crashStackMaxBytes {
		ev.StackTrace = ev.StackTrace[:crashStackMaxBytes] + "\n... [truncated]"
	}

	ds.crashSub.broadcastCrash(ev)

	// Reset.
	ds.pendingCrash = nil
	ds.pendingSince = time.Time{}
	if ds.flushTimer != nil {
		ds.flushTimer.Stop()
		ds.flushTimer = nil
	}
}

func matchCrashPattern(line string) (int, bool) {
	for i, re := range crashPatterns {
		if re.MatchString(line) {
			return i, true
		}
	}
	return -1, false
}

// crashHash is a content-based hash used to coalesce matching lines
// that belong to the same crash. We use the first 200 chars of the
// first matching line — long enough to disambiguate, short enough to
// be cheap.
func crashHash(line string) string {
	if len(line) > 200 {
		line = line[:200]
	}
	return line
}

func extractCrashPackage(line string) string {
	for _, re := range crashPackageExtractors {
		m := re.FindStringSubmatch(line)
		if len(m) >= 2 {
			return m[1]
		}
	}
	return ""
}

func extractLogcatTag(line string) string {
	m := logcatTagPattern.FindStringSubmatch(line)
	if len(m) < 2 {
		return ""
	}
	return strings.TrimSuffix(m[1], ":")
}

func totalLen(s []string) int {
	n := 0
	for _, x := range s {
		n += len(x) + 1
	}
	return n
}

// =====================================================================
// ringBuffer — fixed-capacity FIFO of strings.
// =====================================================================

type ringBuffer struct {
	mu       sync.Mutex
	buf      []string
	head     int  // index of oldest element
	size     int  // number of valid elements (≤ len(buf))
	cap      int  // capacity (== len(buf) once allocated)
	seeded   bool // has the device-side seed run yet?
}

func newRingBuffer(capacity int) *ringBuffer {
	return &ringBuffer{
		buf: make([]string, capacity),
		cap: capacity,
	}
}

func (r *ringBuffer) push(s string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.size < r.cap {
		r.buf[(r.head+r.size)%r.cap] = s
		r.size++
		return
	}
	r.buf[r.head] = s
	r.head = (r.head + 1) % r.cap
}

func (r *ringBuffer) snapshot(n int) []string {
	r.mu.Lock()
	defer r.mu.Unlock()
	if n <= 0 || r.size == 0 {
		return nil
	}
	if n > r.size {
		n = r.size
	}
	out := make([]string, n)
	// Start at (head + size - n) so we get the n most recent in order.
	start := (r.head + r.size - n) % r.cap
	for i := 0; i < n; i++ {
		out[i] = r.buf[(start+i)%r.cap]
	}
	return out
}

func (r *ringBuffer) filledFromSeed() bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.seeded
}

func (r *ringBuffer) markSeeded() {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.seeded = true
}

// =====================================================================
// subscriberSet — fan-out with drop-old backpressure.
// =====================================================================

type subscriberSet struct {
	mu       sync.Mutex
	channels []chan string
	crashChs []chan CrashEvent
}

func newSubscriberSet() *subscriberSet {
	return &subscriberSet{}
}

func (s *subscriberSet) add(buf int) chan string {
	s.mu.Lock()
	defer s.mu.Unlock()
	ch := make(chan string, buf)
	s.channels = append(s.channels, ch)
	return ch
}

func (s *subscriberSet) addCrash(buf int) chan CrashEvent {
	s.mu.Lock()
	defer s.mu.Unlock()
	ch := make(chan CrashEvent, buf)
	s.crashChs = append(s.crashChs, ch)
	return ch
}

func (s *subscriberSet) remove(ch chan string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i, c := range s.channels {
		if c == ch {
			s.channels = append(s.channels[:i], s.channels[i+1:]...)
			close(c)
			return
		}
	}
}

func (s *subscriberSet) removeCrash(ch chan CrashEvent) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for i, c := range s.crashChs {
		if c == ch {
			s.crashChs = append(s.crashChs[:i], s.crashChs[i+1:]...)
			close(c)
			return
		}
	}
}

// broadcast delivers one line to every subscriber, dropping the oldest
// buffered line on each channel that can't accept.
func (s *subscriberSet) broadcast(line string) {
	s.mu.Lock()
	subs := make([]chan string, len(s.channels))
	copy(subs, s.channels)
	s.mu.Unlock()

	for _, ch := range subs {
		select {
		case ch <- line:
		default:
			// Drop oldest.
			select {
			case <-ch:
			default:
			}
			// Try once more.
			select {
			case ch <- line:
			default:
				// Consumer is really slow; drop this line for them.
			}
		}
	}
}

// broadcastCrash delivers one CrashEvent to every crash subscriber.
// Crashes are sparse so we use a simple non-blocking send; if the
// buffer is full the consumer misses this event (rare given cap=64).
func (s *subscriberSet) broadcastCrash(ev CrashEvent) {
	s.mu.Lock()
	subs := make([]chan CrashEvent, len(s.crashChs))
	copy(subs, s.crashChs)
	s.mu.Unlock()

	for _, ch := range subs {
		select {
		case ch <- ev:
		default:
		}
	}
}

func (s *subscriberSet) closeAll() {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, ch := range s.channels {
		close(ch)
	}
	s.channels = nil
	for _, ch := range s.crashChs {
		close(ch)
	}
	s.crashChs = nil
}

// =====================================================================
// Compile-time interface check: ensure unused imports don't sneak in.
// =====================================================================

var _ exec.Cmd // used in adbManagerSpawn via *exec.Cmd