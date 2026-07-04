// Mirror state — owns scrcpy subprocess lifecycle for the screen-mirror UI.
//
// This provider tracks scrcpy mirror status per-device (keyed by stable
// serial / ro.serialno) so simultaneous mirroring of multiple devices
// works correctly. Each device's ScreenMirrorScreen gets its own poll
// timer; this provider stores results keyed by serial so polls from
// different device screens don't fight over a single _status field.
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

  /// Per-device busy flag. True while a start/stop round-trip is in
  /// flight for that device.
  final Set<String> _busySerials = {};

  /// Returns the cached status for [serial], or [ScrcpyStatus.stopped].
  ScrcpyStatus statusFor(String serial) =>
      _statusMap[serial] ?? ScrcpyStatus.stopped;

  /// True if a start/stop round-trip is in flight for [serial].
  bool isBusy(String serial) => _busySerials.contains(serial);

  /// True iff a mirror scrcpy is running on the given device.
  bool isOurs(String stable) => statusFor(stable).running;

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
    notifyListeners();
  }

  /// Poll the backend for scrcpy state on [serial]. Only notifies if
  /// the state changed. Errors are swallowed.
  Future<void> refresh(String serial) async {
    try {
      final next = await _api.scrcpyStatus(serial: serial);
      final prev = _statusMap[serial];
      if (prev != null &&
          prev.running == next.running &&
          prev.serial == next.serial &&
          prev.pid == next.pid &&
          prev.elapsedSeconds == next.elapsedSeconds) {
        return;
      }
      if (next.running) {
        _statusMap[serial] = next;
      } else {
        _statusMap.remove(serial);
      }
      notifyListeners();
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
        _statusMap[serial] = ScrcpyStatus(
          running: true,
          serial: serial,
          pid: 0,
          elapsedSeconds: 0,
        );
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
    } finally {
      _busySerials.remove(serial);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _offlineSub?.cancel();
    super.dispose();
  }
}
