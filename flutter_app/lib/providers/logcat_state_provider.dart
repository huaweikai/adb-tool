import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/device.dart';
import '../services/log_stream.dart';

/// Per-device UI state for the logcat screen.
///
/// One instance per device serial. Created lazily on first access via
/// [stateFor]. Entries, filter, and streaming state persist across
/// screen rebuilds and across switching to other devices — switching
/// away from device A and back leaves A's state untouched.
///
/// This class is intentionally NOT a [ChangeNotifier] on its own; the
/// outer [LogcatStateProvider] notifies listeners once per batched
/// update so consumers don't get spammed when a stream batch lands.
class LogcatDeviceState {
  LogcatDeviceState({required this.serial});

  final String serial;

  /// Raw incoming entries — capped at [_maxEntries] via FIFO eviction.
  final List<LogEntry> entries = [];

  /// Filtered view of [entries] — what the ListView actually renders.
  final List<LogEntry> displayed = [];

  /// Entries received from the stream but not yet merged into [entries].
  /// Batched flush keeps the rebuild rate bounded.
  final List<LogEntry> pending = [];

  LogFilter filter = LogFilter();
  bool streaming = false;
  bool paused = false;
  bool wsConnected = false;
  String? packagePid;

  /// True iff the user explicitly pressed Stop on this device's stream.
  /// Drives the screen's auto-start-on-mount: don't auto-restart a
  /// stream the user intentionally stopped. Switching to a different
  /// device gets a fresh state (userStopped=false) and will auto-start.
  bool userStopped = false;

  /// Cap on retained raw entries. Older entries are evicted FIFO; the
  /// displayed view is also pruned so highlighted background stays
  /// consistent.
  static const _maxEntries = 5000;

  /// Merge pending entries into entries + displayed, applying the FIFO
  /// cap and refreshing the displayed view from the current filter.
  void flushPending() {
    if (pending.isEmpty) return;
    final batch = List<LogEntry>.from(pending);
    pending.clear();
    entries.addAll(batch);
    displayed.addAll(batch.where((e) => e.matchesFilter(filter)));
    if (entries.length > _maxEntries) {
      final extra = entries.length - _maxEntries;
      final removed = entries.sublist(0, extra);
      entries.removeRange(0, extra);
      for (final entry in removed) {
        final idx = displayed.indexOf(entry);
        if (idx >= 0) displayed.removeAt(idx);
      }
    }
  }

  /// Re-filter the displayed view against the current filter.
  void refreshDisplayed() {
    displayed
      ..clear()
      ..addAll(entries.where((e) => e.matchesFilter(filter)));
  }

  /// Wipe both the raw and displayed buffers (e.g. user clicked "clear").
  void clearBuffers() {
    entries.clear();
    displayed.clear();
    pending.clear();
  }

  /// True if there is anything to render or display in the status bar.
  bool get hasLogs => entries.isNotEmpty || displayed.isNotEmpty || pending.isNotEmpty;
}

/// App-wide logcat state. Holds a per-device [LogcatDeviceState] so
/// switching devices preserves entries, filter, scroll, and pause state.
///
/// Notifications are debounced: a stream batch of N entries triggers at
/// most one [notifyListeners] per frame, so a flood of log lines doesn't
/// thrash the widget tree.
class LogcatStateProvider extends ChangeNotifier {
  LogcatStateProvider(this._svc);

  final LogStreamService _svc;
  final Map<String, LogcatDeviceState> _states = {};
  final Map<String, StreamSubscription<List<LogEntry>>> _logSubs = {};
  final Map<String, StreamSubscription<bool>> _connSubs = {};

  bool _disposed = false;

  /// Get-or-create the state for a device. Safe to call repeatedly.
  LogcatDeviceState stateFor(String serial) =>
      _states.putIfAbsent(serial, () => LogcatDeviceState(serial: serial));

  /// True if a channel has been opened for the device (whether or not
  /// it is currently streaming).
  bool hasChannel(String serial) => _svc.isConnected(serial);

  /// Open a streaming channel for the device, wired up to flush into
  /// the per-device state. Idempotent: calling twice is a no-op.
  void startStream(String serial) {
    final state = stateFor(serial);
    if (state.streaming) return;
    state.userStopped = false;
    _svc.connect(serial, state.filter);
    state.streaming = true;

    _logSubs[serial]?.cancel();
    _logSubs[serial] = _svc.streamFor(serial).listen((batch) {
      if (batch.isEmpty) return;
      state.pending.addAll(batch);
      // Coalesce: flush immediately if we hit the burst threshold,
      // otherwise the periodic flush timer in the screen handles it.
      if (state.pending.length >= 300) {
        _flush(serial);
      }
    });

    _connSubs[serial]?.cancel();
    _connSubs[serial] = _svc.connectionStateFor(serial).listen((connected) {
      state.wsConnected = connected;
      _notify();
    });

    _notify();
  }

  /// Stop streaming for the device. Tears down the WS channel and the
  /// stream subscriptions; entries are KEPT in memory so switching back
  /// shows the last seen log without re-fetching. Marks `userStopped`
  /// so the screen's auto-start logic won't quietly restart it.
  void stopStream(String serial) {
    final state = stateFor(serial);
    state.userStopped = true;
    state.streaming = false;
    state.paused = false;
    _flush(serial); // drain pending into entries before tearing down
    _logSubs.remove(serial)?.cancel();
    _connSubs.remove(serial)?.cancel();
    _svc.stop(serial);
    _notify();
  }

  /// Apply a new filter to the device's stream and refresh the
  /// displayed view. Does NOT restart the channel — just sends
  /// `filter` over the existing WS.
  void updateFilter(String serial, LogFilter filter) {
    final state = stateFor(serial);
    state.filter = filter;
    state.refreshDisplayed();
    if (state.streaming) {
      _svc.updateFilter(serial, filter);
    }
    _notify();
  }

  /// Incrementally update one or more filter fields and refresh the
  /// displayed view. Use this for per-keystroke onChange handlers —
  /// passing only the changed field avoids rebuilding an entire
  /// LogFilter object and prevents accidentally clobbering fields
  /// the user hasn't touched yet.
  void updateField(
    String serial, {
    String? tag,
    String? keyword,
    String? packageName,
    String? priority,
    String? packagePid,
  }) {
    final state = stateFor(serial);
    if (tag != null) state.filter.tag = tag;
    if (keyword != null) state.filter.keyword = keyword;
    if (packageName != null) state.filter.packageName = packageName;
    if (priority != null) state.filter.priority = priority;
    if (packagePid != null) state.filter.packagePid = packagePid;
    state.refreshDisplayed();
    if (state.streaming) {
      _svc.updateFilter(serial, state.filter);
    }
    _notify();
  }

  /// Stop streaming for the device, but keep its entries in memory so
  /// switching back shows the last seen log without re-fetching.
  void pauseStream(String serial) {
    final state = stateFor(serial);
    if (!state.streaming) return;
    _svc.pause(serial);
    state.paused = true;
    _notify();
  }

  void resumeStream(String serial) {
    final state = stateFor(serial);
    if (!state.streaming) return;
    _svc.resume(serial);
    state.paused = false;
    _notify();
  }

  /// Wipe the entries buffer for the device without touching the stream.
  /// Use for the user-facing "clear" button — entries vanish but new
  /// lines keep arriving if streaming is on. Calls the backend `clear`
  /// action so the server-side logcat ring is also reset.
  void clearBuffers(String serial) {
    final state = stateFor(serial);
    state.clearBuffers();
    if (state.streaming) {
      _svc.clear(serial);
    }
    _notify();
  }

  /// Periodic flush (called by the screen's flush timer) to drain
  /// pending entries into the visible list.
  void flushPending(String serial) {
    _flush(serial);
  }

  /// Update the resolved PID for a package filter; forces a notify so
  /// the status bar refreshes.
  void setPackagePid(String serial, String? pid) {
    final state = stateFor(serial);
    state.packagePid = pid;
    _notify();
  }

  void _flush(String serial) {
    final state = _states[serial];
    if (state == null || state.pending.isEmpty) return;
    state.flushPending();
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _logSubs.values) {
      s.cancel();
    }
    for (final s in _connSubs.values) {
      s.cancel();
    }
    _logSubs.clear();
    _connSubs.clear();
    _states.clear();
    super.dispose();
  }
}