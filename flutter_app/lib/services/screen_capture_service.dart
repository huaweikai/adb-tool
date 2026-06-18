// Global screen-capture service. Wraps the ADB endpoints with a single
// stateless API that mixins can use. Has no UI dependencies — the
// `onScreenshotSaved` / `onVideoSaved` callbacks are provided by the
// caller (mixin / state) so this stays composable.
import 'dart:convert';
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
}
