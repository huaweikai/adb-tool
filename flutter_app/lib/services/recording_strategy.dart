// Recording strategy — encapsulates the backend-specific logic for
// starting/stopping/cleaning up a screen recording. The mixin layer
// handles DB state + UI callbacks; the strategy handles subprocess
// lifecycle. Adding a new recording method only requires a new
// implementation of this interface — no changes to the mixins.
//
// Both ADB and scrcpy now save the recording to the host filesystem.
// stop() returns the file path; the mixin reads bytes from disk on
// demand. This avoids loading large files entirely into memory.
//
// Contracts:
//   - start():  start the subprocess. Scrcpy may throw ScrcpyRecordBusyException.
//   - stop():   stop the subprocess, return host file path (null on failure).
//   - cleanup(): post-stop side effects (best-effort, idempotent).

import 'dart:io';

import '../providers/recording_settings_provider.dart';
import '../providers/scrcpy_record_state_provider.dart';
import '../services/api_client.dart';
import '../services/screen_capture_service.dart';

abstract class RecordingStrategy {
  String? _outputPath;
  String? get outputPath => _outputPath;

  /// Factory: returns the strategy for [method]. All dependencies are
  /// injected; strategies pick what they need.
  static RecordingStrategy create(
    ScreenRecordMethod method, {
    required String serial,
    required ApiClient api,
    required ScreenCaptureService capture,
    required ScrcpyRecordStateProvider recordState,
  }) {
    switch (method) {
      case ScreenRecordMethod.adb:
        return AdbRecordingStrategy(serial, api);
      case ScreenRecordMethod.scrcpy:
        return ScrcpyRecordingStrategy(serial, recordState, capture);
    }
  }

  /// Start the recording subprocess. [force] is used by scrcpy to
  /// preempt a conflicting mirror session.
  Future<void> start({bool force = false});

  /// Stop the subprocess and return the host file path of the recording.
  /// Returns null on failure.
  Future<String?> stop();

  /// Post-stop cleanup of side effects. ADB: turn off show_touches.
  /// Scrcpy: delete sandbox file. Safe to call multiple times.
  Future<void> cleanup();
}

class AdbRecordingStrategy extends RecordingStrategy {
  final String _serial;
  final ApiClient _api;

  AdbRecordingStrategy(String serial, ApiClient api)
      : _serial = serial,
        _api = api;

  @override
  Future<void> start({bool force = false}) async {
    try {
      await _api.setShowTouches(_serial, true);
    } catch (_) {}
    await _api.screenRecordAction(_serial, 'start');
  }

  @override
  Future<String?> stop() async {
    final resp = await _api.screenRecordAction(_serial, 'stop');
    final path = resp['path'] as String?;
    if (path != null && path.isNotEmpty) {
      _outputPath = path;
      return path;
    }
    return null;
  }

  @override
  Future<void> cleanup() async {
    try {
      await _api.setShowTouches(_serial, false);
    } catch (_) {}
    final path = _outputPath;
    if (path != null) {
      try { await File(path).delete(); } catch (_) {}
    }
    _outputPath = null;
  }
}

class ScrcpyRecordingStrategy extends RecordingStrategy {
  final String _serial;
  final ScrcpyRecordStateProvider _recordState;
  final ScreenCaptureService _capture;

  ScrcpyRecordingStrategy(
    String serial,
    ScrcpyRecordStateProvider recordState,
    ScreenCaptureService capture,
  )   : _serial = serial,
        _recordState = recordState,
        _capture = capture;

  @override
  Future<void> start({bool force = false}) async {
    final path = await _recordState.start(_serial, force: force);
    _outputPath = path.isEmpty ? null : path;
  }

  @override
  Future<String?> stop() async {
    await _capture.stopScrcpyRecording(_serial);
    return _outputPath;
  }

  @override
  Future<void> cleanup() async {
    final path = _outputPath;
    if (path != null) {
      try {
        await _capture.discardScrcpyRecording(path);
      } catch (_) {}
    }
    _outputPath = null;
  }
}
