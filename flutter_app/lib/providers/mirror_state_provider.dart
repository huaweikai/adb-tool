// Mirror state — owns scrcpy subprocess lifecycle for the screen-mirror UI.
//
// This provider tracks scrcpy mirror status per-device (keyed by stable
// serial / ro.serialno) so simultaneous mirroring of multiple devices
// works correctly. Each device's ScreenMirrorScreen gets its own poll
// timer; this provider stores results keyed by serial so polls from
// different device screens don't fight over a single _status field.
//
// Elapsed time: a 1s local ticker provides smooth display updates. The
// 2s backend poll only checks liveness (running/stopped) and calibrates
// the local start time to correct clock drift.
//
// The provider also subscribes to DeviceProvider.onDeviceOffline and
// auto-stops the scrcpy on the device that went offline.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/scrcpy_options.dart';
import '../services/api_client.dart';
import 'device_provider.dart';

class MirrorStateProvider extends ChangeNotifier {
  MirrorStateProvider(this._api, this._deviceProvider) {
    _offlineSub = _deviceProvider.onDeviceOffline.listen(_onDeviceOffline);
  }

  final ApiClient _api;
  final DeviceProvider _deviceProvider;
  StreamSubscription<DeviceOfflineEvent>? _offlineSub;

  /// Per-device scrcpy subprocess status. Key is ro.serialno (stable
  /// identity). Devices not in the map are treated as stopped.
  final Map<String, ScrcpyStatus> _statusMap = {};

  /// Per-device wall-clock start time, used for local elapsed display.
  /// Calibrated by the first successful backend status poll.
  final Map<String, DateTime> _startedAt = {};

  /// 1s tick for smooth elapsed display. Started when first device
  /// begins mirroring, stopped when none remain.
  Timer? _elapsedTimer;
  bool _tickerRunning = false;

  /// Per-device busy flag. True while a start/stop round-trip is in
  /// flight for that device.
  final Set<String> _busySerials = {};

  /// Returns the cached status for [serial], or [ScrcpyStatus.stopped].
  ScrcpyStatus statusFor(String serial) =>
      _statusMap[serial] ?? ScrcpyStatus.stopped;

  /// Locally calculated elapsed seconds for a running device.
  int elapsedFor(String serial) {
    final at = _startedAt[serial];
    if (at == null) return 0;
    return DateTime.now().difference(at).inSeconds;
  }

  /// True if a start/stop round-trip is in flight for [serial].
  bool isBusy(String serial) => _busySerials.contains(serial);

  /// True iff a mirror scrcpy is running on the given device.
  bool isOurs(String stable) => statusFor(stable).running;

  void _ensureTicker() {
    if (_tickerRunning) return;
    _tickerRunning = true;
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  void _stopTickerIfIdle() {
    if (_statusMap.isNotEmpty) return;
    _tickerRunning = false;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  /// When a device goes offline, stop its scrcpy and clear its state.
  void _onDeviceOffline(DeviceOfflineEvent event) {
    final offline = event.hardwareSerial;
    if (offline == null || offline.isEmpty) return;
    final st = _statusMap[offline];
    if (st == null || !st.running) return;

    debugPrint(
        '[MirrorStateProvider] device offline: $offline — stopping scrcpy');
    unawaited(_api.stopScrcpy(offline).catchError((Object e) {
      debugPrint('[MirrorStateProvider] offline-stop error (ignored): $e');
      return <String, dynamic>{'status': 'error'};
    }));
    _statusMap.remove(offline);
    _startedAt.remove(offline);
    _stopTickerIfIdle();
    notifyListeners();
  }

  /// Poll the backend for scrcpy liveness on [serial]. Calibrates the
  /// local start time on first successful response. Only notifies on
  /// running→stopped transitions (not on elapsed changes).
  Future<void> refresh(String serial) async {
    try {
      final next = await _api.scrcpyStatus(serial: serial);
      final prev = _statusMap[serial];
      if (!next.running) {
        if (prev != null && prev.running) {
          _statusMap.remove(serial);
          _startedAt.remove(serial);
          _stopTickerIfIdle();
          notifyListeners();
        }
        return;
      }
      // Running: calibrate local clock from backend elapsed.
      final cal = DateTime.now().subtract(Duration(seconds: next.elapsedSeconds));
      _startedAt[serial] = cal;
      if (prev == null || !prev.running) {
        // Transition: stopped → running. Notify for UI state change.
        _statusMap[serial] = next;
        _ensureTicker();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[MirrorStateProvider] refresh error (ignored): $e');
    }
  }

  /// Start scrcpy on [serial] with [options]. Sets busy flag, starts
  /// the subprocess via backend, then refreshes status. Surfaced errors
  /// are rethrown so the screen can show a snackbar.
  Future<void> start(String serial, ScrcpyOptions options) async {
    if (_busySerials.contains(serial)) return;
    _busySerials.add(serial);
    notifyListeners();
    try {
      await _api.startScrcpy(serial, options: options);
      await refresh(serial);
      if (!statusFor(serial).running) {
        _startedAt[serial] = DateTime.now();
        _statusMap[serial] = ScrcpyStatus(
          running: true,
          serial: serial,
          pid: 0,
          elapsedSeconds: 0,
        );
        _ensureTicker();
        notifyListeners();
      }
    } finally {
      _busySerials.remove(serial);
      notifyListeners();
    }
  }

  /// Stop scrcpy on [serial]. No-op if nothing is running.
  Future<void> stop(String serial) async {
    if (_busySerials.contains(serial)) return;
    _busySerials.add(serial);
    notifyListeners();
    try {
      await _api.stopScrcpy(serial);
      _statusMap.remove(serial);
      _startedAt.remove(serial);
      _stopTickerIfIdle();
    } finally {
      _busySerials.remove(serial);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _offlineSub?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }
}
