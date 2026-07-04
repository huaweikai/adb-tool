// State for the windowless scrcpy recording subprocess. Mirrors
// `MirrorStateProvider` in shape — per-device status, per-device
// polling. The capture mixin (file-browser / test-session) drives
// start/stop THROUGH this provider rather than calling the service
// layer directly, so the mirror page's "scrcpy is busy" banner
// updates synchronously instead of waiting for the next 2s poll.
//
// Per-device: different devices can record concurrently; same-device
// mirror + recording are mutually exclusive (the backend enforces
// this). The provider subscribes to DeviceProvider.onDeviceOffline
// so the UI clears the banner when the recording device disconnects.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/api_client.dart';
import 'device_provider.dart';

class ScrcpyRecordStateProvider extends ChangeNotifier {
  ScrcpyRecordStateProvider(this._api, this._deviceProvider) {
    _offlineSub = _deviceProvider.onDeviceOffline.listen(_onDeviceOffline);
  }

  final ApiClient _api;
  final DeviceProvider _deviceProvider;
  StreamSubscription<DeviceOfflineEvent>? _offlineSub;

  /// Per-device recording status. Key is ro.serialno (stable identity).
  final Map<String, ScrcpyRecordStatus> _statusMap = {};

  /// Returns the cached status for [serial], or [ScrcpyRecordStatus.stopped].
  ScrcpyRecordStatus statusFor(String serial) =>
      _statusMap[serial] ?? ScrcpyRecordStatus.stopped;

  /// Backward-compat getter: returns the first running entry, or stopped.
  ScrcpyRecordStatus get status {
    for (final st in _statusMap.values) {
      if (st.running) return st;
    }
    return ScrcpyRecordStatus.stopped;
  }

  /// Start a windowless scrcpy recording against the device with the
  /// given stable serial. Pass [force]=true to gracefully kill an
  /// in-flight mirror session before starting the recording.
  Future<String> start(String stableSerial, {bool force = false}) async {
    final path = await _api.startScrcpyRecording(stableSerial, force: force);
    await refresh(serial: stableSerial);
    return path;
  }

  /// Stop the running recording subprocess for the given device.
  Future<void> stop(String serial) async {
    await _api.stopScrcpyRecording(serial);
    _statusMap.remove(serial);
    notifyListeners();
  }

  /// Poll the backend for the given device. Pass [serial]="" to query
  /// the first running entry.
  Future<void> refresh({String? serial}) async {
    try {
      final next = await _api.scrcpyRecordingStatus(serial: serial);
      final key = serial ?? next.serial;
      if (key.isEmpty) return;

      final prev = _statusMap[key];
      if (prev != null &&
          prev.running == next.running &&
          prev.serial == next.serial &&
          prev.outputPath == next.outputPath &&
          prev.pid == next.pid) {
        return;
      }

      if (next.running) {
        _statusMap[key] = next;
      } else {
        _statusMap.remove(key);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[ScrcpyRecordStateProvider] refresh error (ignored): $e');
    }
  }

  void _onDeviceOffline(DeviceOfflineEvent event) {
    final offline = event.hardwareSerial;
    if (offline == null || offline.isEmpty) return;
    final st = _statusMap[offline];
    if (st == null || !st.running) return;
    debugPrint(
        '[ScrcpyRecordStateProvider] device offline: $offline — clearing recording state');
    _statusMap.remove(offline);
    notifyListeners();
  }

  @override
  void dispose() {
    _offlineSub?.cancel();
    super.dispose();
  }
}
