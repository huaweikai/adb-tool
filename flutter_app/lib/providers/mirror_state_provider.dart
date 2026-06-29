// Mirror state — owns scrcpy subprocess lifecycle for the screen-mirror UI.
//
// Before this provider existed, ScreenMirrorScreen held `_status` and
// `_busy` locally and called ApiClient directly. That worked for the
// single-device-at-a-time happy path but had two gaps:
//
//   1. If the device that scrcpy is attached to disappears (USB unplugged,
//      WiFi drop), nothing on the Flutter side reacts — scrcpy's own
//      window will eventually close, but the UI shows "running" until the
//      next 2-second poll lands and discovers the subprocess is gone.
//
//   2. The user can fire a stop/start on a device that's no longer
//      connected. The backend adb call will fail, but the error path is
//      noisier than just intercepting it here.
//
// This provider subscribes to DeviceProvider.onDeviceOffline and force-
// stops the running scrcpy if its serial disappears. The backend's
// stopScrcpy is a no-op when nothing's running, so calling it
// defensively is safe. On the way back we update local status so the
// screen mirror UI flips to "stopped" within the same frame the device
// status dot turns red.
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

  /// Last known scrcpy subprocess status. Defaults to "stopped"; the
  /// screen fetches the real value on mount and on every poll tick.
  ScrcpyStatus _status = ScrcpyStatus.stopped;
  ScrcpyStatus get status => _status;

  /// Stable identity (ro.serialno) of the device we last asked the
  /// backend to start scrcpy against. Drives [isOurs] — the
  /// screen-mirror UI uses this to decide whether a running scrcpy
  /// "belongs" to the active device. Survives wireless reconnects
  /// because stable identity is independent of the transient adb
  /// address.
  String? _activeStable;

  /// True while a start/stop round-trip is in flight. Disables both
  /// buttons so a panicky double-click can't fire two requests.
  bool _busy = false;
  bool get busy => _busy;

  /// True iff the running scrcpy was started against the given
  /// [stable] identity. The screen asks "is this ours?" with the
  /// active device's stable identity and the provider hides the
  /// backend's adb-serial bookkeeping.
  bool isOurs(String stable) => _activeStable == stable;

  /// When the device scrcpy was running against goes offline, fire a
  /// single stop request to the backend (idempotent if scrcpy
  /// already died on its own) and immediately flip local state to
  /// stopped so the UI doesn't have to wait for the next poll cycle.
  void _onDeviceOffline(DeviceOfflineEvent event) {
    final running = _status.running;
    if (!running) return;
    final offline = event.hardwareSerial;
    if (offline == null || offline.isEmpty) return;
    if (_activeStable != offline) return;
    debugPrint(
        '[MirrorStateProvider] device offline: $offline — stopping scrcpy');
    // No await — fire and forget. The backend stop is idempotent and
    // any error is logged by the underlying dio call. We MUST update
    // local state synchronously so the UI repaints now.
    unawaited(_api.stopScrcpy().catchError((Object e) {
      debugPrint('[MirrorStateProvider] offline-stop error (ignored): $e');
      return <String, dynamic>{'status': 'error'};
    }));
    _status = ScrcpyStatus.stopped;
    _activeStable = null;
    notifyListeners();
  }

  /// Poll the backend for current scrcpy state. Cheap (status endpoint
  /// is a struct lookup), so the screen can call this on a 2s timer.
  /// Errors are swallowed — network blips shouldn't flicker the UI.
  Future<void> refresh() async {
    try {
      final next = await _api.scrcpyStatus();
      if (next.running == _status.running &&
          next.serial == _status.serial &&
          next.pid == _status.pid) {
        // Only notify when something actually changed — keeps the
        // elapsed-time pill from rebuilding the screen 30×/min when
        // nothing else moved.
        return;
      }
      _status = next;
      notifyListeners();
    } catch (e) {
      debugPrint('[MirrorStateProvider] refresh error (ignored): $e');
    }
  }

  /// Refresh with a specific stable identity filter — used on screen
  /// mount so a fresh tab doesn't show "running" from a previous
  /// device's session. The serial is the device's ro.serialno
  /// (stable identity); ApiClient resolves it to the current adb
  /// address internally.
  Future<void> refreshForSerial(String stable) async {
    _activeStable = stable;
    try {
      final next = await _api.scrcpyStatus(serial: stable);
      _status = next;
      notifyListeners();
    } catch (e) {
      debugPrint('[MirrorStateProvider] refreshForSerial error (ignored): $e');
    }
  }

  /// Start scrcpy against the device identified by [stable]
  /// (ro.serialno) with the given options. Surfaces backend errors
  /// via rethrow so the screen can show a snackbar with the actual
  /// adb failure message. Always clears `_busy` in finally so the
  /// buttons don't get stuck disabled.
  Future<void> start(String stable, ScrcpyOptions options) async {
    if (_busy) return;
    _busy = true;
    _activeStable = stable;
    notifyListeners();
    try {
      await _api.startScrcpy(stable, options: options);
      await refresh();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Stop the running scrcpy. No-op if nothing's running. Same
  /// rethrow + finally contract as [start].
  Future<void> stop() async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      await _api.stopScrcpy();
      _status = ScrcpyStatus.stopped;
      _activeStable = null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _offlineSub?.cancel();
    super.dispose();
  }
}
