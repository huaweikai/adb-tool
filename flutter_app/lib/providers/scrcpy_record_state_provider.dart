// State for the windowless scrcpy recording subprocess. Mirrors
// `MirrorStateProvider` in shape — both manage a single scrcpy
// subprocess with a 2s poll — and crucially the capture mixin
// (file-browser / test-session) drives start/stop THROUGH this
// provider rather than calling the service layer directly, so the
// mirror page's "scrcpy is busy" banner updates synchronously
// instead of waiting for the next 2s poll.
//
// The two subprocesses (mirror + recording) are mutually exclusive
// on the same device: scrcpy holds the adb connection, and a second
// scrcpy would fail with "device already in use" or steal the
// connection. Keeping them as separate providers makes the conflict
// visible at the type level; the mirror page reads both to render
// the recording badge and disable the start-mirror button.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/api_client.dart';

class ScrcpyRecordStateProvider extends ChangeNotifier {
  ScrcpyRecordStateProvider(this._api);

  final ApiClient _api;

  ScrcpyRecordStatus _status = ScrcpyRecordStatus.stopped;
  ScrcpyRecordStatus get status => _status;

  /// Start a windowless scrcpy recording against the device with the
  /// given stable serial. Pass [force]=true to gracefully kill an
  /// in-flight mirror session before starting the recording.
  ///
  /// Returns the host output path the backend picked (under
  /// `~/.adb-tool/scrcpy_recordings/`). The caller should remember
  /// it for the stop path.
  ///
  /// Throws [ScrcpyRecordBusyException] on 409. The caller is
  /// expected to surface a confirm dialog and re-call with
  /// force=true if the user agrees.
  ///
  /// On success, refreshes the local status synchronously and
  /// notifies listeners — so the mirror page's "recording in
  /// progress" banner appears immediately, not on the next 2s poll.
  Future<String> start(String stableSerial, {bool force = false}) async {
    final path = await _api.startScrcpyRecording(stableSerial, force: force);
    await refresh();
    return path;
  }

  /// Stop the running recording subprocess. No-op if nothing is
  /// recording. Notifies listeners on success so the mirror page's
  /// "recording" banner clears immediately.
  Future<void> stop() async {
    await _api.stopScrcpyRecording();
    _status = ScrcpyRecordStatus.stopped;
    notifyListeners();
  }

  /// Poll the backend. Errors are swallowed — network blips shouldn't
  /// flicker the UI. Only notifies on change so the elapsed-seconds
  /// pill doesn't rebuild the screen 30×/min when nothing else moved.
  Future<void> refresh() async {
    try {
      final next = await _api.scrcpyRecordingStatus();
      if (next.running == _status.running &&
          next.serial == _status.serial &&
          next.outputPath == _status.outputPath &&
          next.pid == _status.pid) {
        return;
      }
      _status = next;
      notifyListeners();
    } catch (e) {
      debugPrint('[ScrcpyRecordStateProvider] refresh error (ignored): $e');
    }
  }
}
