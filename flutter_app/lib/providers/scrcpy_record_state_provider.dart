// State for the windowless scrcpy recording subprocess. Mirrors
// `MirrorStateProvider` in shape — both manage a single scrcpy
// subprocess with a 2s poll — but kept separate because the two
// subprocesses are mutually exclusive on the same device and a
// shared provider would muddy the "which scrcpy owns this device?"
// question. The mirror page reads both providers to render the
// "recording in progress" badge and disable the start-mirror button
// when a recording is in flight on the active device.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/api_client.dart';

class ScrcpyRecordStateProvider extends ChangeNotifier {
  ScrcpyRecordStateProvider(this._api);

  final ApiClient _api;

  ScrcpyRecordStatus _status = ScrcpyRecordStatus.stopped;
  ScrcpyRecordStatus get status => _status;

  bool _busy = false;
  bool get busy => _busy;

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

  /// Start a recording against the given device. The capture mixin
  /// layer is responsible for picking the output path (typically
  /// `RecordingSettingsProvider.outputDir` + a fresh filename) and
  /// for handling the conflict-confirm dialog before calling this.
  ///
  /// Returns the response map on success. Re-throws backend errors
  /// (other than 409, which the caller is expected to have dealt
  /// with already) so the caller can show a snackbar with the actual
  /// error.
  Future<Map<String, dynamic>> start(
      String stableSerial, String outputPath) async {
    if (_busy) return {};
    _busy = true;
    notifyListeners();
    try {
      final resp = await _api.startScrcpyRecording(stableSerial, outputPath);
      await refresh();
      return resp;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Stop the running recording. No-op if nothing is recording.
  Future<void> stop() async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      await _api.stopScrcpyRecording();
      _status = ScrcpyRecordStatus.stopped;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
