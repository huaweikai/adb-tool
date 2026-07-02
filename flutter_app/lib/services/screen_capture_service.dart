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
  //
  // The destination path is owned by the backend
  // (`~/.adb-tool/scrcpy_recordings/`, see ScrcpyRecordingSandboxDir
  // in adb_scrcpy_record.go). The Flutter side gets the path back
  // from the start response and reuses it on stop.

  /// Start a scrcpy windowless recording. Returns the host output
  /// path the backend picked — the caller should remember it for the
  /// stop path (read it back, then move or delete the file).
  ///
  /// Throws [ScrcpyRecordBusyException] when the backend refuses
  /// with 409. The capture mixin layer surfaces that as a confirm
  /// dialog and re-calls with force=true if the user agrees.
  Future<String> startScrcpyRecording(
    String serial, {
    bool force = false,
  }) async {
    return _api.startScrcpyRecording(serial, force: force);
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

  /// Delete a finished recording off the host disk. The capture
  /// mixin's stop path calls this after the user has saved the file
  /// (file_browser flow) or after the test-session provider has
  /// ingested it (test_session flow). Idempotent: a missing file is
  /// not an error.
  Future<void> discardScrcpyRecording(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
