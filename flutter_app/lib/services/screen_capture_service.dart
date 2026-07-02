// Global screen-capture service. Wraps the ADB endpoints with a single
// stateless API that mixins can use. Has no UI dependencies — the
// `onScreenshotSaved` / `onVideoSaved` callbacks are provided by the
// caller (mixin / state) so this stays composable.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'api_client.dart';

class ScreenCaptureService {
  final ApiClient _api;
  ScreenCaptureService(this._api);

  /// Pull a PNG screenshot from the device. Returns null on failure.
  /// Decodes the base64 envelope the backend returns.
  Future<Uint8List?> takeScreenshotBytes(String serial) async {
    final b64 = await _api.takeScreenshot(serial);
    if (b64 == null) return null;
    return base64Decode(b64);
  }

  /// Tell the device to start screen recording. The recording is owned
  /// by adb's `screenrecord` process on the device side.
  Future<void> startScreenRecord(String serial) async {
    await _api.screenRecordAction(serial, 'start');
  }

  /// Stop recording, pull the resulting MP4 off the device. Returns the
  /// raw bytes — caller is responsible for persisting.
  Future<Uint8List> stopScreenRecordAndPull(String serial) async {
    await _api.screenRecordAction(serial, 'stop');
    final bytes = await _api.pullRecordedVideo(serial);
    return Uint8List.fromList(bytes);
  }

  // ── Scrcpy windowless recording path ──────────────────────────────
  //
  // The recording runs in a separate scrcpy subprocess
  // (`--no-window --record=<path>`); scrcpy itself writes the MP4
  // directly to the host filesystem, so on stop we just read the
  // resulting file — no `adb pull` round trip.

  /// Start a scrcpy windowless recording. [outputPath] is the fully
  /// qualified host file path scrcpy will write to; the caller is
  /// responsible for picking a filename (the recording settings page
  /// pins the directory, this picks the timestamp suffix).
  ///
  /// Throws [ScrcpyRecordBusyException] when the backend refuses
  /// with 409. The capture mixin layer surfaces that as a confirm
  /// dialog and re-calls with force=true if the user agrees.
  Future<String> startScrcpyRecording(
    String serial,
    String outputPath, {
    bool force = false,
  }) async {
    final resp = await _api.startScrcpyRecording(serial, outputPath,
        force: force);
    return (resp['outputPath'] as String?) ?? outputPath;
  }

  /// Stop the scrcpy recording subprocess. No-op if nothing is
  /// running. The output file is already on disk at this point
  /// (scrcpy finalizes the muxer on graceful shutdown).
  Future<void> stopScrcpyRecording() async {
    await _api.stopScrcpyRecording();
  }

  /// Read a finished recording off the host disk. Used by the capture
  /// mixin's stop path — the file is at [path] because that's what
  /// the user got back from [startScrcpyRecording]. Returns the raw
  /// bytes (same contract as [stopScreenRecordAndPull] so the caller's
  /// onVideoSaved path doesn't need to branch on recording method).
  Future<Uint8List> readScrcpyRecording(String path) async {
    final file = File(path);
    return Uint8List.fromList(await file.readAsBytes());
  }
}
