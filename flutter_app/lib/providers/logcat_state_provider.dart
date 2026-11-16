import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/device.dart';
import '../services/api_client.dart';
import '../services/log_stream.dart';
import 'device_provider.dart';

/// One retained log occurrence. Identical log messages still have distinct IDs.
class LogcatLine {
  LogcatLine(this.id, this.entry)
      : columns = _columns(entry.raw),
        estimatedBytes = 192 + 4 * entry.raw.length;

  final int id;
  final LogEntry entry;
  final int columns;
  final int estimatedBytes;

  static int _columns(String text) {
    var columns = text.length;
    for (var i = 0; i < text.length; i++) {
      final unit = text.codeUnitAt(i);
      if (unit > 0x7f) columns++;
      if (unit == 9) columns += 7;
    }
    return columns;
  }
}

/// An indexed FIFO with constant-time lookup and amortized constant-time
/// updates to the longest line, used by the horizontal viewport.
class LogcatLines {
  final ListQueue<LogcatLine> _lines = ListQueue();
  final ListQueue<LogcatLine> _widest = ListQueue();
  int _removed = 0;

  int get removed => _removed;
  int get length => _lines.length;
  int get widestColumns => _widest.isEmpty ? 0 : _widest.first.columns;
  LogcatLine operator [](int index) => _lines.elementAt(index);

  void _add(LogcatLine line) {
    _lines.addLast(line);
    while (_widest.isNotEmpty && _widest.last.columns <= line.columns) {
      _widest.removeLast();
    }
    _widest.addLast(line);
  }

  void _removeFirst() {
    final line = _lines.removeFirst();
    _removed++;
    if (identical(line, _widest.first)) _widest.removeFirst();
  }

  void _clear() {
    _lines.clear();
    _widest.clear();
  }

  bool containsId(int id) {
    final index = indexAfter(id) - 1;
    return index >= 0 && this[index].id == id;
  }

  /// Find the boundary after [id], even if that line was filtered or evicted.
  int indexAfter(int id) {
    var low = 0;
    var high = length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (this[mid].id <= id) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  LogcatLines snapshot() => LogcatLines()
    .._lines.addAll(_lines)
    .._widest.addAll(_widest)
    .._removed = _removed;
}

/// Per-device log history, filter and stream state.
class LogcatDeviceState {
  LogcatDeviceState({
    required this.serial,
    int historyLimit = defaultHistoryLines,
    bool wrap = false,
  })  : _historyLimit = historyLimit,
        softWrap = ValueNotifier(wrap) {
    followLatest.addListener(() => unseenRows.value = 0);
  }

  static const historyOptions = [5000, 20000, 50000, 100000];
  static const defaultHistoryLines = 20000;
  static const _byteBudget = 32 * 1024 * 1024;

  final String serial;
  final _entries = ListQueue<LogcatLine>();
  final displayed = LogcatLines();
  final _pending = ListQueue<LogcatLine>();
  int _historyLimit;
  int _pendingBytes = 0;
  int _historyBytes = 0;
  int _evicted = 0;
  int _nextId = 0;
  int _displayedVersion = 0;
  int _filterRevision = 0;
  int? _pauseAtId;

  int get displayedVersion => _displayedVersion;
  int get filterRevision => _filterRevision;
  int get historyLimit => _historyLimit;
  int get evictedRows => _evicted;

  final followLatest = ValueNotifier(true);
  final ValueNotifier<bool> softWrap;
  final unseenRows = ValueNotifier(0);
  int? reviewAfterId;

  LogFilter filter = LogFilter();
  LogFilter _appliedFilter = LogFilter();
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

  void enqueue(Iterable<LogEntry> batch) {
    for (final entry in batch) {
      final line = LogcatLine(_nextId++, entry);
      _pending.addLast(line);
      _pendingBytes += line.estimatedBytes;
      _trimPending();
    }
  }

  void _trimPending() {
    while (_pending.length > _historyLimit || _pendingBytes > _byteBudget) {
      _pendingBytes -= _pending.removeFirst().estimatedBytes;
      _evicted++;
    }
  }

  void flushPending() {
    final previousLength = displayed.length;
    var appended = 0;
    while (_pending.isNotEmpty) {
      final line = _pending.removeFirst();
      _entries.addLast(line);
      _historyBytes += line.estimatedBytes;
      if (!paused && line.entry.matchesFilter(_appliedFilter)) {
        displayed._add(line);
        appended++;
      }
    }
    _pendingBytes = 0;
    final removed = _trimHistory();
    if (displayed.length != previousLength || appended > 0 || removed) {
      _displayedVersion++;
    }
    if (!followLatest.value && appended > 0) {
      unseenRows.value += appended;
    }
  }

  bool _trimHistory() {
    var changed = false;
    while (_entries.length > _historyLimit || _historyBytes > _byteBudget) {
      final oldest = _entries.removeFirst();
      _historyBytes -= oldest.estimatedBytes;
      _evicted++;
      if (!paused && displayed.length > 0 && identical(displayed[0], oldest)) {
        displayed._removeFirst();
        changed = true;
      }
    }
    return changed;
  }

  void setHistoryLimit(int limit) {
    _historyLimit = limit;
    _trimPending();
    if (_trimHistory()) _displayedVersion++;
    if (paused) refreshDisplayed();
  }

  void refreshDisplayed() {
    _appliedFilter = filter.copy();
    displayed._clear();
    for (final line in _entries) {
      if (paused && line.id >= _pauseAtId!) break;
      if (line.entry.matchesFilter(_appliedFilter)) displayed._add(line);
    }
    unseenRows.value = 0;
    _filterRevision++;
    _displayedVersion++;
  }

  void pausePresentation() {
    flushPending();
    _pauseAtId = _nextId;
    paused = true;
  }

  void resumePresentation() {
    flushPending();
    paused = false;
    _pauseAtId = null;
    refreshDisplayed();
  }

  void clearBuffers() {
    _entries.clear();
    displayed._clear();
    _pending.clear();
    _pendingBytes = 0;
    _historyBytes = 0;
    _evicted = 0;
    unseenRows.value = 0;
    _filterRevision++;
    _displayedVersion++;
  }

  bool get hasLogs => _entries.isNotEmpty || _pending.isNotEmpty;
}

/// App-wide logcat state. Holds a per-device [LogcatDeviceState] so
/// switching devices preserves entries, filter, scroll, and pause state.
///
/// The `serial` argument on every public method is the device's **stable
/// identity** (ro.serialno) — the same value carried in `DeviceSerialScope`.
/// Keys states by stable identity so a wireless reconnect (which churns
/// the adb address) doesn't lose the user's filter / pause / scroll
/// state.
///
/// Incoming batches are merged on demand at a bounded rate per device.
class LogcatStateProvider extends ChangeNotifier {
  LogcatStateProvider(this._svc, this._api, this._deviceProvider,
      {SharedPreferences? preferences})
      : _preferences = preferences {
    final savedLimit = preferences?.getInt(_historyLimitKey);
    if (LogcatDeviceState.historyOptions.contains(savedLimit)) {
      _historyLimit = savedLimit!;
    }
    _softWrap = preferences?.getBool(_wrapKey) ?? false;
    // When a device goes offline, any in-flight local recording is dead —
    // the adb logcat subprocess on the host lost its upstream pipe. Best-
    // effort stop so the UI state doesn't get stuck in "recording" limbo
    // until the user manually presses Stop. The backend's stopLocalRecording
    // call is fire-and-forget here (we're already past the point of caring
    // about the result); the OS will reap the subprocess anyway.
    _offlineSub = _deviceProvider.onDeviceOffline.listen((event) {
      // The state map is keyed by stable identity; the offline event
      // carries both the disappearing adb-serial AND the device's
      // ro.serialno, so we use the latter for the lookup.
      final stable = event.hardwareSerial;
      if (stable == null || stable.isEmpty) {
        // No stable identity (e.g. backend couldn't read props). We
        // can't map the event back to a state key, so skip the
        // best-effort cleanup. The user can still stop the recording
        // manually.
        return;
      }
      debugPrint(
          '[LogcatStateProvider] device offline: $stable — stopping recording');
      final wasRecording = stateFor(stable).recording != null;
      stopRecordingIfActive(stable);
      if (wasRecording && !_recordingInterrupted.isClosed) {
        _recordingInterrupted.add(stable);
      }
    });
  }

  final LogStreamService _svc;
  final ApiClient _api;
  final DeviceProvider _deviceProvider;
  final Map<String, LogcatDeviceState> _states = {};
  final Map<String, StreamSubscription<List<LogEntry>>> _logSubs = {};
  final Map<String, StreamSubscription<bool>> _connSubs = {};
  StreamSubscription<DeviceOfflineEvent>? _offlineSub;
  // Coalesce text edits so the retained history is filtered once per query.
  final Map<String, Timer> _filterDebounce = {};
  final Map<String, Timer> _batchTimers = {};
  static const _historyLimitKey = 'logcat.historyLines';
  static const _wrapKey = 'logcat.softWrap';
  final SharedPreferences? _preferences;
  int _historyLimit = LogcatDeviceState.defaultHistoryLines;
  bool _softWrap = false;

  void setHistoryLimit(int limit) {
    if (!LogcatDeviceState.historyOptions.contains(limit)) return;
    _historyLimit = limit;
    final preferences = _preferences;
    if (preferences != null) {
      unawaited(preferences.setInt(_historyLimitKey, limit));
    }
    for (final state in _states.values) {
      state.setHistoryLimit(limit);
    }
    _notify();
  }

  void setSoftWrap(bool enabled) {
    _softWrap = enabled;
    final preferences = _preferences;
    if (preferences != null) unawaited(preferences.setBool(_wrapKey, enabled));
    for (final state in _states.values) {
      state.softWrap.value = enabled;
    }
  }

  /// Emits the serial whose local logcat recording was force-stopped
  /// because its target device went offline. UI subscribes to show
  /// "录制已结束（设备离线）" instead of the normal "save to file" flow
  /// — there's no point prompting the user to save an incomplete log
  /// pulled from a dead subprocess.
  final _recordingInterrupted = StreamController<String>.broadcast();
  Stream<String> get onRecordingInterrupted => _recordingInterrupted.stream;

  bool _disposed = false;

  /// Get-or-create the state for a device. Safe to call repeatedly.
  /// The [serial] is the device's stable identity (ro.serialno) so
  /// state survives wireless reconnects.
  LogcatDeviceState stateFor(String serial) => _states.putIfAbsent(
        serial,
        () => LogcatDeviceState(
          serial: serial,
          historyLimit: _historyLimit,
          wrap: _softWrap,
        ),
      );

  /// True if a channel has been opened for the device (whether or not
  /// it is currently streaming).
  bool hasChannel(String serial) => _svc.isConnected(serial);

  /// Open a streaming channel for the device, wired up to flush into
  /// the per-device state. Idempotent: calling twice is a no-op.
  void startStream(String serial) {
    final state = stateFor(serial);
    if (state.streaming) return;
    state.userStopped = false;
    state.wsConnected = false;
    _svc.connect(serial);
    state.streaming = true;
    _wireSubscriptions(serial);
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
    state.wsConnected = false;
    _batchTimers.remove(serial)?.cancel();
    if (state.paused) {
      state.resumePresentation();
    } else {
      state.flushPending();
    }
    _logSubs.remove(serial)?.cancel();
    _connSubs.remove(serial)?.cancel();
    _svc.stop(serial);
    _notify();
  }

  void updateFilter(String serial, LogFilter filter) {
    _filterDebounce.remove(serial)?.cancel();
    final state = stateFor(serial);
    state.filter = filter;
    state.refreshDisplayed();
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
    _filterDebounce[serial]?.cancel();
    _filterDebounce[serial] = Timer(const Duration(milliseconds: 200), () {
      _filterDebounce.remove(serial);
      if (_disposed) return;
      state.refreshDisplayed();
      _notify();
    });
  }

  /// Freeze the visible document while capture continues into history.
  void pauseStream(String serial) {
    final state = stateFor(serial);
    if (!state.streaming || state.paused) return;
    state.pausePresentation();
    _notify();
  }

  void resumeStream(String serial) {
    final state = stateFor(serial);
    if (!state.streaming || !state.paused) return;
    state.resumePresentation();
    _notify();
  }

  /// Wipe the entries buffer for the device without touching the stream.
  /// Use for the user-facing "clear" button — entries vanish but new
  /// lines keep arriving if streaming is on. Calls the backend `clear`
  /// action so the server-side logcat ring is also reset.
  void clearBuffers(String serial) {
    final state = stateFor(serial);
    state.clearBuffers();
    if (state.streaming && state.wsConnected) {
      _svc.clear(serial);
    } else {
      _svc.resetCursor(serial);
      unawaited(_api.clearLogcat(serial));
    }
    _notify();
  }

  void setPackagePid(String serial, String? pid, {bool clearPackage = true}) {
    _filterDebounce.remove(serial)?.cancel();
    final state = stateFor(serial);
    state.packagePid = pid;
    state.filter.packagePid = pid ?? '';
    if (pid == null && clearPackage) state.filter.packageName = '';
    state.refreshDisplayed();
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

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  /// Wire up stream and connection-state subscriptions for [serial].
  void _wireSubscriptions(String serial) {
    final state = stateFor(serial);
    _logSubs[serial]?.cancel();
    var lastEvicted = state.evictedRows;
    _logSubs[serial] = _svc.streamFor(serial).listen((batch) {
      if (batch.isEmpty) return;
      state.enqueue(batch);
      _batchTimers[serial] ??= Timer(const Duration(milliseconds: 80), () {
        _batchTimers.remove(serial);
        final previousVersion = state.displayedVersion;
        final hadLogs = state._entries.isNotEmpty;
        state.flushPending();
        final evicted = state.evictedRows;
        if (state.displayedVersion != previousVersion ||
            evicted != lastEvicted ||
            state.hasLogs != hadLogs) {
          lastEvicted = evicted;
          _notify();
        }
      });
    });
    _connSubs[serial]?.cancel();
    _connSubs[serial] = _svc.connectionStateFor(serial).listen((connected) {
      state.wsConnected = connected;
      _notify();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _offlineSub?.cancel();
    _recordingInterrupted.close();
    for (final s in _logSubs.values) {
      s.cancel();
    }
    for (final s in _connSubs.values) {
      s.cancel();
    }
    for (final t in _filterDebounce.values) {
      t.cancel();
    }
    for (final timer in _batchTimers.values) {
      timer.cancel();
    }
    _batchTimers.clear();
    for (final state in _states.values) {
      state.recording?.dispose();
      state.followLatest.dispose();
      state.softWrap.dispose();
      state.unseenRows.dispose();
    }
    _logSubs.clear();
    _connSubs.clear();
    _filterDebounce.clear();
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
