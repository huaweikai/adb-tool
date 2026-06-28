import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/device.dart';
import '../services/api_client.dart';
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
  ///
  /// Backed by two structures:
  ///   * [_displayedList] — preserves insertion order, fed to ListView.
  ///   * [_displayedSet]  — identity Set for O(1) presence checks during
  ///     FIFO eviction. With List-only, evicting K entries used to cost
  ///     O(K*N) (indexOf + removeAt for each); with the Set it's O(K) +
  ///     a single O(N) rebuild of the list when anything actually moved.
  ///
  /// [displayed] returns a fresh List snapshot on every access so that
  /// Selector consumers (the log list widget) see a new identity on
  /// every flush and rebuild — without this they'd compare identical
  /// lists and skip the rebuild entirely.
  final List<LogEntry> _displayedList = [];
  final Set<LogEntry> _displayedSet = Set<LogEntry>.identity();
  List<LogEntry> get displayed => List<LogEntry>.of(_displayedList);

  /// Entries received from the stream but not yet merged into [entries].
  /// Batched flush keeps the rebuild rate bounded.
  final List<LogEntry> pending = [];

  LogFilter filter = LogFilter();
  bool streaming = false;
  bool paused = false;
  bool wsConnected = false;
  String? packagePid;

  /// Backend-owned recording in progress for this device. null = not
  /// recording. Set/cleared by [LogcatStateProvider.startRecording] /
  /// [LogcatStateProvider.stopRecording].
  RecordingState? recording;

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
    for (final e in batch) {
      if (e.matchesFilter(filter) && _displayedSet.add(e)) {
        _displayedList.add(e);
      }
    }
    if (entries.length > _maxEntries) {
      final extra = entries.length - _maxEntries;
      final removed = entries.sublist(0, extra);
      entries.removeRange(0, extra);
      var dirty = false;
      for (final entry in removed) {
        if (_displayedSet.remove(entry)) dirty = true;
      }
      if (dirty) {
        // Single O(n) rebuild of the ordered list from the Set. Only
        // pays this cost when at least one evicted entry was visible.
        _displayedList
          ..clear()
          ..addAll(_displayedSet);
      }
    }
  }

  /// Re-filter the displayed view against the current filter.
  void refreshDisplayed() {
    _displayedSet.clear();
    for (final e in entries) {
      if (e.matchesFilter(filter)) _displayedSet.add(e);
    }
    _displayedList
      ..clear()
      ..addAll(_displayedSet);
  }

  /// Wipe both the raw and displayed buffers (e.g. user clicked "clear").
  void clearBuffers() {
    entries.clear();
    _displayedList.clear();
    _displayedSet.clear();
    pending.clear();
  }

  /// True if there is anything to render or display in the status bar.
  bool get hasLogs =>
      entries.isNotEmpty || _displayedList.isNotEmpty || pending.isNotEmpty;
}

/// App-wide logcat state. Holds a per-device [LogcatDeviceState] so
/// switching devices preserves entries, filter, scroll, and pause state.
///
/// Notifications are debounced: a stream batch of N entries triggers at
/// most one [notifyListeners] per frame, so a flood of log lines doesn't
/// thrash the widget tree.
class LogcatStateProvider extends ChangeNotifier {
  LogcatStateProvider(this._svc, this._api);

  final LogStreamService _svc;
  final ApiClient _api;
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
  /// the status bar refreshes, and ALSO propagates the new pid to the
  /// filter + backend + displayed view.
  ///
  /// Without this, setting the pid after [updateField] would only
  /// update the status-bar cosmetic state — the LogFilter's packagePid
  /// would stay empty so [LogEntry.matchesFilter] would still let every
  /// buffered entry through (the backend wouldn't re-filter the
  /// already-buffered batch either).
  void setPackagePid(String serial, String? pid) {
    final state = stateFor(serial);
    state.packagePid = pid;
    state.filter.packagePid = pid ?? '';
    state.refreshDisplayed();
    if (state.streaming) {
      _svc.updateFilter(serial, state.filter);
    }
    _notify();
  }

  /// Start a per-device "save-to-local" recording. The backend launches
  /// `adb logcat -T now` as a subprocess writing to a temp file; this
  /// method returns once that subprocess is alive and the file is open.
  ///
  /// Idempotent: a no-op if the device is already recording.
  /// Errors are surfaced via rethrow — the caller (toolbar) decides how
  /// to display them.
  Future<void> startRecording(String serial) async {
    final state = stateFor(serial);
    if (state.recording != null) return; // already recording
    final pkg = state.filter.packageName;
    final resp = await _api.startLocalRecording(serial, packageName: pkg);
    final path = resp['path']?.toString() ?? '';
    if (path.isEmpty) {
      throw Exception('backend returned empty recording path');
    }
    state.recording = RecordingState(
      serial: serial,
      startedAt: DateTime.now(),
      tempPath: path,
      onTick: _notify,
    );
    _notify();
  }

  /// Stop the recording for `serial` and return the temp file path so
  /// the caller can hand it to the save dialog. Returns null if no
  /// recording was active.
  ///
  /// Backend errors are rethrown. Always clears the local recording
  /// state, even on error, so the UI doesn't get stuck in "stopping"
  /// limbo.
  Future<RecordingResult?> stopRecording(String serial) async {
    final state = stateFor(serial);
    final rec = state.recording;
    if (rec == null) return null;
    try {
      final resp = await _api.stopLocalRecording(serial);
      final path = resp['path']?.toString() ?? '';
      final bytes = (resp['bytes'] as num?)?.toInt() ?? 0;
      return RecordingResult(path: path, bytes: bytes);
    } finally {
      rec.dispose();
      state.recording = null;
      _notify();
    }
  }

  /// True iff this device currently has an active recording.
  bool isRecording(String serial) => stateFor(serial).recording != null;

  /// Best-effort cleanup of a recording on dispose / device-gone. We
  /// fire-and-forget the backend call — no point in awaiting at
  /// shutdown, the OS will reap the subprocess.
  void stopRecordingIfActive(String serial) {
    final state = stateFor(serial);
    if (state.recording == null) return;
    state.recording!.dispose();
    state.recording = null;
    // unawaited — see comment above.
    // ignore: discarded_futures
    _api.stopLocalRecording(serial);
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
    for (final state in _states.values) {
      state.recording?.dispose();
    }
    _logSubs.clear();
    _connSubs.clear();
    _states.clear();
    super.dispose();
  }
}

/// Per-device recording state. Owns a 1-second ticker that nudges the
/// provider so the toolbar's elapsed-time pill updates without needing
/// the rest of the widget tree to subscribe to anything else.
class RecordingState {
  RecordingState({
    required this.serial,
    required this.startedAt,
    required this.tempPath,
    required this.onTick,
  }) {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => onTick());
  }

  final String serial;
  final DateTime startedAt;
  final String tempPath;
  final VoidCallback onTick;
  Timer? _ticker;

  /// Elapsed wall-clock time, second-precision (UI doesn't need finer).
  Duration get elapsed {
    final now = DateTime.now();
    return now.difference(startedAt);
  }

  /// MM:SS formatter for the toolbar pill. Caps at 99:59 to keep the
  /// button width stable for long recordings.
  String get formattedElapsed {
    final total = elapsed.inSeconds;
    final m = (total ~/ 60).clamp(0, 99);
    final s = total % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void dispose() {
    _ticker?.cancel();
    _ticker = null;
  }
}

/// Returned by [LogcatStateProvider.stopRecording]. Carries everything
/// the toolbar needs to prompt the user for a save location.
class RecordingResult {
  const RecordingResult({required this.path, required this.bytes});
  final String path;
  final int bytes;
}