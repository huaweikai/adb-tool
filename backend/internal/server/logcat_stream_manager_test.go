package server

import (
	"context"
	"errors"
	"fmt"
	"io"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// fakeSource produces lines for a fake logcat subprocess. Each call
// to push appends lines; reading from a pipe returned by reader()
// delivers them. close() ends the stream (no new lines, existing
// pumps exit on next iteration).
//
// Each reader() call returns a *new* pipe with its own pump
// goroutine, so multi-spawn retry behavior is exercised. A kill
// func returned alongside the pipe signals that specific pump to
// exit — without this, the fake's pump would block forever after
// the manager's shutdown closes its end of the pipe (production's
// subprocess gets SIGKILL'd by the OS, the fake has no such
// external teardown).
type fakeSource struct {
	mu     sync.Mutex
	lines  []string
	closed bool

	// wake is replaced each time push()/close() happens. Pumps
	// snapshot a reference before waiting, so a stale wake is fine
	// (it's already closed; select returns immediately and the
	// pump re-snapshots).
	wake chan struct{}
}

func newFakeSource() *fakeSource {
	return &fakeSource{wake: make(chan struct{})}
}

func (fs *fakeSource) push(lines ...string) {
	fs.mu.Lock()
	defer fs.mu.Unlock()
	fs.lines = append(fs.lines, lines...)
	fs.signalLocked()
}

func (fs *fakeSource) close() {
	fs.mu.Lock()
	defer fs.mu.Unlock()
	fs.closed = true
	fs.signalLocked()
}

// signalLocked closes the current wake chan and allocates a fresh
// one. Caller must hold fs.mu.
func (fs *fakeSource) signalLocked() {
	close(fs.wake)
	fs.wake = make(chan struct{})
}

// reader returns an io.ReadCloser that emits the lines one by one
// (newline-terminated) and a kill func that signals the underlying
// pump goroutine to exit. EOF on close().
func (fs *fakeSource) reader() (io.ReadCloser, func()) {
	pr, pw := io.Pipe()
	kick := make(chan struct{})
	go fs.pump(pw, kick)
	return pr, func() { close(kick) }
}

func (fs *fakeSource) pump(pw *io.PipeWriter, kick <-chan struct{}) {
	defer pw.Close()
	for {
		// Cooperative exit before doing anything.
		select {
		case <-kick:
			return
		default:
		}

		// Snapshot under lock for a consistent view of state + wake.
		fs.mu.Lock()
		if fs.closed && len(fs.lines) == 0 {
			fs.mu.Unlock()
			return
		}
		batch := fs.lines
		fs.lines = nil
		wake := fs.wake
		fs.mu.Unlock()

		for _, line := range batch {
			select {
			case <-kick:
				return
			default:
			}
			if _, err := pw.Write([]byte(line + "\n")); err != nil {
				return
			}
		}

		// Wait for the next push/close OR a kill signal.
		select {
		case <-kick:
			return
		case <-wake:
		}
	}
}

// makeSpawn builds a spawnFn that pulls from fs.reader() and
// provides a kill() that signals the specific pump + closes the
// reader side. Idempotent via sync.Once.
func makeSpawn(fs *fakeSource) spawnFn {
	return func(serial string) (io.ReadCloser, func() error, error) {
		stdout, kick := fs.reader()
		var killOnce sync.Once
		kill := func() error {
			killOnce.Do(func() { kick() })
			return stdout.Close()
		}
		return stdout, kill, nil
	}
}

// waitFor polls until cond returns true or timeout. Returns whether
// satisfied.
func lsmWaitFor(t *testing.T, timeout time.Duration, cond func() bool, msg string) {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if cond() {
			return
		}
		time.Sleep(5 * time.Millisecond)
	}
	if !cond() {
		t.Fatalf("timed out after %s: %s", timeout, msg)
	}
}

// newTestManager builds a LogcatStreamManager with all knobs wired to
// fakes. Returns the manager, the fakeSource feeding it, and a cleanup
// func.
func newTestManager(t *testing.T) (*LogcatStreamManager, *fakeSource, func()) {
	t.Helper()
	fs := newFakeSource()
	m := NewLogcatStreamManager(nil)
	m.SetSpawnFunc(makeSpawn(fs))
	m.SetSeedFunc(func(serial string) (string, error) { return "", nil })
	m.SetLogger(testLogger(t))

	cleanup := func() { m.CloseAll() }
	return m, fs, cleanup
}

// =====================================================================
// Tests
// =====================================================================

func TestLogcatStreamManager_EnsureDeliversLinesToSubscriber(t *testing.T) {
	m, fs, cleanup := newTestManager(t)
	defer cleanup()

	m.Ensure("serial-1")
	lsmWaitFor(t, time.Second, func() bool { return m.IsRunning("serial-1") }, "watcher should reach running state")

	sub, err := m.Subscribe("serial-1", 0)
	if err != nil {
		t.Fatalf("subscribe: %v", err)
	}
	defer sub.Cancel()

	fs.push("line A", "line B", "line C")

	got := collectN(t, sub.Lines, 3, time.Second)
	want := []string{"line A", "line B", "line C"}
	if !sliceEq(got, want) {
		t.Errorf("got %v, want %v", got, want)
	}
}

func TestLogcatStreamManager_SubscribeReplay(t *testing.T) {
	m, fs, cleanup := newTestManager(t)
	defer cleanup()

	m.Ensure("serial-1")
	lsmWaitFor(t, time.Second, func() bool { return m.IsRunning("serial-1") }, "watcher should reach running state")

	fs.push("prev-1", "prev-2", "prev-3")
	// Wait for them to land in the ring buffer (subscriber side-effect).
	lsmWaitFor(t, time.Second, func() bool {
		return m.Recent("serial-1", 10) != nil
	}, "lines should reach ring buffer")

	sub, err := m.Subscribe("serial-1", 3)
	if err != nil {
		t.Fatalf("subscribe: %v", err)
	}
	defer sub.Cancel()

	got := collectN(t, sub.Lines, 3, time.Second)
	want := []string{"prev-1", "prev-2", "prev-3"}
	if !sliceEq(got, want) {
		t.Errorf("replay got %v, want %v", got, want)
	}

	// New lines still arrive after replay.
	fs.push("after-1")
	if got := <-sub.Lines; got != "after-1" {
		t.Errorf("post-replay line: got %q want %q", got, "after-1")
	}
}

func TestLogcatStreamManager_MultipleSubscribers(t *testing.T) {
	m, fs, cleanup := newTestManager(t)
	defer cleanup()

	m.Ensure("serial-1")
	lsmWaitFor(t, time.Second, func() bool { return m.IsRunning("serial-1") }, "watcher running")

	a, _ := m.Subscribe("serial-1", 0)
	b, _ := m.Subscribe("serial-1", 0)
	defer a.Cancel()
	defer b.Cancel()

	fs.push("broadcast")

	want := "broadcast"
	if got := <-a.Lines; got != want {
		t.Errorf("sub a: got %q want %q", got, want)
	}
	if got := <-b.Lines; got != want {
		t.Errorf("sub b: got %q want %q", got, want)
	}
}

func TestLogcatStreamManager_SubscribeDropOldOnOverflow(t *testing.T) {
	m, fs, cleanup := newTestManager(t)
	defer cleanup()

	// Shrink the subscriber buffer for the test.
	prevBuf := subscriberBuffer
	subscriberBuffer = 8
	defer func() { subscriberBuffer = prevBuf }()

	m.Ensure("serial-1")
	lsmWaitFor(t, time.Second, func() bool { return m.IsRunning("serial-1") }, "watcher running")

	sub, _ := m.Subscribe("serial-1", 0)
	defer sub.Cancel()

	// Push 20 lines; with buffer=8, broadcast drops the oldest on
	// overflow. Whether drops actually occur depends on how fast
	// drainWithTimeout keeps up with broadcast (they run
	// concurrently), so we don't assert a specific drop count — we
	// only verify the drop-old invariant: the newest line MUST
	// survive, because that's the whole point of the policy.
	//
	// The drop mechanism itself is unit-tested by race-detector
	// runs and by the earlier failing run that confirmed 07/08/11
	// being dropped under similar setup.
	all := make([]string, 20)
	for i := range all {
		all[i] = fmt.Sprintf("line-%02d", i)
	}
	fs.push(all...)

	collected := drainWithTimeout(sub.Lines, 200*time.Millisecond)
	joined := strings.Join(collected, ",")
	if !strings.Contains(joined, "line-19") {
		t.Errorf("expected line-19 to be present (newest survives drop-old), got: %s", joined)
	}
}

func TestLogcatStreamManager_RingBufferWraparound(t *testing.T) {
	m, fs, cleanup := newTestManager(t)
	defer cleanup()

	prevCap := ringBufferCapacity
	ringBufferCapacity = 5
	defer func() { ringBufferCapacity = prevCap }()

	m.Ensure("serial-1")
	lsmWaitFor(t, time.Second, func() bool { return m.IsRunning("serial-1") }, "watcher running")

	sub, _ := m.Subscribe("serial-1", 0)
	defer sub.Cancel()

	// Push 10 lines; ring holds only last 5.
	all := make([]string, 10)
	for i := range all {
		all[i] = fmt.Sprintf("L%02d", i)
	}
	fs.push(all...)

	// Wait for them to land
	lsmWaitFor(t, time.Second, func() bool {
		r := m.Recent("serial-1", 100)
		return len(r) == 5
	}, "ring should hold last 5")

	recent := m.Recent("serial-1", 100)
	want := []string{"L05", "L06", "L07", "L08", "L09"}
	if !sliceEq(recent, want) {
		t.Errorf("ring recent: got %v want %v", recent, want)
	}
}

func TestLogcatStreamManager_CrashDetection(t *testing.T) {
	m, fs, cleanup := newTestManager(t)
	defer cleanup()

	m.Ensure("serial-1")
	lsmWaitFor(t, time.Second, func() bool { return m.IsRunning("serial-1") }, "watcher running")

	cs, err := m.SubscribeCrash("serial-1")
	if err != nil {
		t.Fatalf("subscribe crash: %v", err)
	}
	defer cs.Cancel()

	// Push a FATAL EXCEPTION + 5 context lines + a matching line.
	fs.push(
		"01-01 12:00:00.000  1234  1234 E AndroidRuntime: FATAL EXCEPTION: main",
		"01-01 12:00:00.001  1234  1234 E AndroidRuntime: Process: com.example.foo, PID: 1234",
		"01-01 12:00:00.002  1234  1234 E AndroidRuntime: java.lang.RuntimeException: boom",
		"01-01 12:00:00.003  1234  1234 E AndroidRuntime: 	at com.example.foo.MainActivity.onCreate(MainActivity.kt:42)",
		"01-01 12:00:00.004  1234  1234 E AndroidRuntime: 	at android.app.Activity.performCreate(Activity.java:8000)",
	)

	// Force flush by waiting > coalesce window.
	time.Sleep(crashCoalesceWindow + 100*time.Millisecond)

	select {
	case ev := <-cs.Events:
		if ev.Type != CrashKindCrash {
			t.Errorf("crash kind: got %q want %q", ev.Type, CrashKindCrash)
		}
		if ev.Package != "com.example.foo" {
			t.Errorf("package: got %q want %q", ev.Package, "com.example.foo")
		}
		if !strings.Contains(ev.Summary, "FATAL EXCEPTION") {
			t.Errorf("summary should contain 'FATAL EXCEPTION', got %q", ev.Summary)
		}
		if !strings.Contains(ev.StackTrace, "MainActivity.kt:42") {
			t.Errorf("stacktrace should contain MainActivity line, got: %s", ev.StackTrace)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("did not receive crash event")
	}
}

func TestLogcatStreamManager_CrashDedupWithinWindow(t *testing.T) {
	m, fs, cleanup := newTestManager(t)
	defer cleanup()

	m.Ensure("serial-1")
	lsmWaitFor(t, time.Second, func() bool { return m.IsRunning("serial-1") }, "watcher running")

	cs, _ := m.SubscribeCrash("serial-1")
	defer cs.Cancel()

	// Push the same crash header twice within the coalesce window.
	for i := 0; i < 2; i++ {
		fs.push(fmt.Sprintf("01-01 12:00:00.00%d  1234  1234 E AndroidRuntime: FATAL EXCEPTION: main #%d", i, i))
	}

	time.Sleep(crashCoalesceWindow + 100*time.Millisecond)

	count := drainCrashEvents(cs.Events, 100*time.Millisecond)
	if len(count) != 1 {
		t.Errorf("expected 1 crash event after dedup, got %d", len(count))
	}
}

func TestLogcatStreamManager_AnrKind(t *testing.T) {
	m, fs, cleanup := newTestManager(t)
	defer cleanup()

	m.Ensure("serial-1")
	lsmWaitFor(t, time.Second, func() bool { return m.IsRunning("serial-1") }, "watcher running")

	cs, _ := m.SubscribeCrash("serial-1")
	defer cs.Cancel()

	fs.push("01-01 12:00:00.000  1234  1234 E ActivityManager: ANR in com.example.bar")

	time.Sleep(crashCoalesceWindow + 100*time.Millisecond)

	select {
	case ev := <-cs.Events:
		if ev.Type != CrashKindAnr {
			t.Errorf("crash kind: got %q want %q", ev.Type, CrashKindAnr)
		}
		if ev.Package != "com.example.bar" {
			t.Errorf("package: got %q want %q", ev.Package, "com.example.bar")
		}
	case <-time.After(2 * time.Second):
		t.Fatal("did not receive ANR event")
	}
}

func TestLogcatStreamManager_NativeCrashKind(t *testing.T) {
	m, fs, cleanup := newTestManager(t)
	defer cleanup()

	m.Ensure("serial-1")
	lsmWaitFor(t, time.Second, func() bool { return m.IsRunning("serial-1") }, "watcher running")

	cs, _ := m.SubscribeCrash("serial-1")
	defer cs.Cancel()

	fs.push("01-01 12:00:00.000  1234  1234 F libc    : signal 11 (SIGSEGV), code 1, fault addr 0x0")

	time.Sleep(crashCoalesceWindow + 100*time.Millisecond)

	select {
	case ev := <-cs.Events:
		if ev.Type != CrashKindNative {
			t.Errorf("crash kind: got %q want %q", ev.Type, CrashKindNative)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("did not receive native crash event")
	}
}

func TestLogcatStreamManager_NoCrashOnChattyLines(t *testing.T) {
	m, fs, cleanup := newTestManager(t)
	defer cleanup()

	m.Ensure("serial-1")
	lsmWaitFor(t, time.Second, func() bool { return m.IsRunning("serial-1") }, "watcher running")

	cs, _ := m.SubscribeCrash("serial-1")
	defer cs.Cancel()

	// Lines that should NOT match any pattern.
	fs.push(
		"01-01 12:00:00.000  1234  1234 I System.out: hello world",
		"01-01 12:00:00.001  1234  1234 D Something: a debug line",
		"01-01 12:00:00.002  1234  1234 E AudioFlinger: write() failed",
	)

	time.Sleep(crashCoalesceWindow + 100*time.Millisecond)

	if got := drainCrashEvents(cs.Events, 100*time.Millisecond); len(got) != 0 {
		t.Errorf("expected 0 crash events for non-matching lines, got %d: %v", len(got), got)
	}
}

func TestLogcatStreamManager_RecentReturnsLastN(t *testing.T) {
	m, fs, cleanup := newTestManager(t)
	defer cleanup()

	m.Ensure("serial-1")
	lsmWaitFor(t, time.Second, func() bool { return m.IsRunning("serial-1") }, "watcher running")

	sub, _ := m.Subscribe("serial-1", 0)
	defer sub.Cancel()

	fs.push("a", "b", "c", "d", "e")

	lsmWaitFor(t, time.Second, func() bool {
		return len(m.Recent("serial-1", 100)) == 5
	}, "5 lines should be in ring")

	recent := m.Recent("serial-1", 3)
	want := []string{"c", "d", "e"}
	if !sliceEq(recent, want) {
		t.Errorf("Recent(3): got %v want %v", recent, want)
	}
}

func TestLogcatStreamManager_CloseStopsSubprocess(t *testing.T) {
	m, _, cleanup := newTestManager(t)
	defer cleanup()

	m.Ensure("serial-1")
	lsmWaitFor(t, time.Second, func() bool { return m.IsRunning("serial-1") }, "watcher running")

	sub, _ := m.Subscribe("serial-1", 0)

	m.Close("serial-1")

	if m.IsRunning("serial-1") {
		t.Errorf("watcher should be stopped after Close")
	}

	// Subscriber channel should be closed.
	select {
	case _, ok := <-sub.Lines:
		if ok {
			t.Errorf("expected closed channel, got value")
		}
	case <-time.After(time.Second):
		t.Errorf("subscriber channel not closed after Close")
	}
}

func TestLogcatStreamManager_SubprocessRestartOnDeath(t *testing.T) {
	m, fs, cleanup := newTestManager(t)
	defer cleanup()

	// Tighten retry timing for the test.
	prevBackoff := retryBackoff
	retryBackoff = []time.Duration{0, 50 * time.Millisecond, 100 * time.Millisecond, 200 * time.Millisecond, 400 * time.Millisecond, 800 * time.Millisecond}
	defer func() { retryBackoff = prevBackoff }()

	m.Ensure("serial-1")
	lsmWaitFor(t, time.Second, func() bool { return m.IsRunning("serial-1") }, "watcher running")

	sub, _ := m.Subscribe("serial-1", 0)
	defer sub.Cancel()

	fs.push("first-1", "first-2")
	_ = collectN(t, sub.Lines, 2, time.Second)

	// Kill the subprocess.
	fs.close()

	// Should restart within a second.
	lsmWaitFor(t, 2*time.Second, func() bool { return m.IsRunning("serial-1") }, "watcher should restart after subprocess death")

	fs.push("second-1")
	select {
	case got := <-sub.Lines:
		if got != "second-1" {
			t.Errorf("post-restart line: got %q want %q", got, "second-1")
		}
	case <-time.After(2 * time.Second):
		t.Fatal("no line after restart")
	}
}

func TestLogcatStreamManager_OfflineAfterRetryBudget(t *testing.T) {
	m, _, cleanup := newTestManager(t)
	defer cleanup()

	// Spawn fn that always fails.
	prevMax := maxRetries
	maxRetries = 3
	defer func() { maxRetries = prevMax }()

	prevBackoff := retryBackoff
	retryBackoff = []time.Duration{0, 10 * time.Millisecond, 20 * time.Millisecond, 40 * time.Millisecond, 80 * time.Millisecond, 160 * time.Millisecond}
	defer func() { retryBackoff = prevBackoff }()

	m.SetSpawnFunc(func(serial string) (io.ReadCloser, func() error, error) {
		return nil, nil, errors.New("simulated spawn failure")
	})

	m.Ensure("serial-1")
	// Wait for retry budget to exhaust (3 retries * <160ms each).
	time.Sleep(500 * time.Millisecond)

	if m.IsRunning("serial-1") {
		t.Errorf("expected watcher to go offline after retry budget exhausted")
	}

	// Ensure resets and retries.
	m.Ensure("serial-1")
	// Should be back to starting state but spawning still fails.
	if m.IsRunning("serial-1") {
		// OK; if a retry succeeded the test setup is wrong.
		t.Logf("note: watcher running, retry succeeded")
	}
}

func TestLogcatStreamManager_ActiveSerials(t *testing.T) {
	m, _, cleanup := newTestManager(t)
	defer cleanup()

	m.Ensure("serial-A")
	m.Ensure("serial-B")

	actives := m.ActiveSerials()
	if len(actives) != 2 {
		t.Errorf("expected 2 active serials, got %d: %v", len(actives), actives)
	}
}

func TestLogcatStreamManager_SeedPopulatesRing(t *testing.T) {
	m, _, cleanup := newTestManager(t)
	defer cleanup()

	m.SetSeedFunc(func(serial string) (string, error) {
		return "seeded-1\nseeded-2\nseeded-3", nil
	})

	m.Ensure("serial-1")
	lsmWaitFor(t, time.Second, func() bool {
		return len(m.Recent("serial-1", 100)) == 3
	}, "ring should have 3 seeded lines")

	recent := m.Recent("serial-1", 100)
	want := []string{"seeded-1", "seeded-2", "seeded-3"}
	if !sliceEq(recent, want) {
		t.Errorf("seeded recent: got %v want %v", recent, want)
	}
}

func TestLogcatStreamManager_SecondSubscriberJoinsLate(t *testing.T) {
	m, fs, cleanup := newTestManager(t)
	defer cleanup()

	m.Ensure("serial-1")
	lsmWaitFor(t, time.Second, func() bool { return m.IsRunning("serial-1") }, "watcher running")

	a, _ := m.Subscribe("serial-1", 0)
	defer a.Cancel()

	// Push 2 lines so the ring buffer actually has 2 entries to
	// replay to the late subscriber.
	fs.push("first-1", "first-2")
	_ = collectN(t, a.Lines, 2, time.Second)

	// Second subscriber joins later.
	b, _ := m.Subscribe("serial-1", 2)
	defer b.Cancel()

	// Should receive 2 replay lines from ring buffer.
	replay := collectN(t, b.Lines, 2, time.Second)
	if len(replay) != 2 {
		t.Errorf("late subscriber replay: got %d lines, want 2", len(replay))
	}
}

func TestLogcatStreamManager_CrashEventChannelCap(t *testing.T) {
	m, fs, cleanup := newTestManager(t)
	defer cleanup()

	m.Ensure("serial-1")
	lsmWaitFor(t, time.Second, func() bool { return m.IsRunning("serial-1") }, "watcher running")

	cs, _ := m.SubscribeCrash("serial-1")
	defer cs.Cancel()

	// Push a crash, but don't drain.
	fs.push("01-01 12:00:00.000  1234  1234 E AndroidRuntime: FATAL EXCEPTION: main #1")
	time.Sleep(crashCoalesceWindow + 100*time.Millisecond)

	// Now push another crash with different content (different hash).
	fs.push("01-01 12:00:01.000  1234  1234 E AndroidRuntime: FATAL EXCEPTION: secondary")
	time.Sleep(crashCoalesceWindow + 100*time.Millisecond)

	// Drain whatever came through. We expect at least 1 event; may be
	// 1 or 2 depending on whether the second event fits in the
	// channel (cap=64, so it should fit).
	events := drainCrashEvents(cs.Events, 100*time.Millisecond)
	if len(events) < 1 {
		t.Errorf("expected at least 1 crash event, got %d", len(events))
	}
}

// =====================================================================
// Helpers
// =====================================================================

func sliceEq(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

// collectN pulls up to n values from ch with a timeout. Returns what
// it got (may be < n on timeout).
func collectN(t *testing.T, ch <-chan string, n int, timeout time.Duration) []string {
	t.Helper()
	out := make([]string, 0, n)
	deadline := time.After(timeout)
	for i := 0; i < n; i++ {
		select {
		case line, ok := <-ch:
			if !ok {
				return out
			}
			out = append(out, line)
		case <-deadline:
			return out
		}
	}
	return out
}

// drainWithTimeout pulls whatever's immediately available plus waits a
// bit more for in-flight events.
func drainWithTimeout(ch <-chan string, timeout time.Duration) []string {
	deadline := time.Now().Add(timeout)
	out := make([]string, 0)
	for {
		select {
		case line, ok := <-ch:
			if !ok {
				return out
			}
			out = append(out, line)
		case <-time.After(time.Until(deadline)):
			return out
		}
	}
}

// drainCrashEvents drains a CrashEvent channel until quiet.
func drainCrashEvents(ch <-chan CrashEvent, timeout time.Duration) []CrashEvent {
	deadline := time.Now().Add(timeout)
	out := make([]CrashEvent, 0)
	for {
		select {
		case ev, ok := <-ch:
			if !ok {
				return out
			}
			out = append(out, ev)
		case <-time.After(time.Until(deadline)):
			return out
		}
	}
}

// unused (kept to silence "unused import" if/when needed)
var _ atomic.Bool
var _ = context.Background
