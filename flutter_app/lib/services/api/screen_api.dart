// Screen recording control: start / stop / status / pull video / show_touches.
import 'package:adb_tool/services/api_client.dart';
import 'package:dio/dio.dart';

mixin ScreenApi on ApiBase {
  Future<Map<String, dynamic>> screenRecordAction(
      String serial, String action) async {
    final resp = await dio.get(
      '/api/screen-record',
      queryParameters: deviceQueryParameters(serial, {'action': action}),
    );
    throwIfNotOk(resp);
    return responseMap(resp);
  }

  Future<Map<String, dynamic>> screenRecordStatus() async {
    final resp = await dio.get(
      '/api/screen-record',
      queryParameters: {'action': 'status'},
    );
    throwIfNotOk(resp);
    return responseMap(resp);
  }

  Future<List<int>> pullRecordedVideo(String serial) async {
    final resp = await dio.get<List<int>>(
      '/api/screen-record-video',
      queryParameters: deviceQueryParameters(serial),
      options: Options(responseType: ResponseType.bytes),
    );
    if (!isOk(resp)) {
      throw Exception('pull video failed: ${resp.statusCode}');
    }
    return resp.data ?? [];
  }

  /// Toggle the Android "show touches" developer setting on a device.
  /// Used by the screen-record flow so the recording shows a visible dot
  /// wherever the user taps. Returns true on success.
  Future<bool> setShowTouches(String serial, bool enabled) async {
    final resp = await dio.post(
      '/api/adb-exec',
      queryParameters: deviceQueryParameters(serial),
      data: {
        'args': [
          'shell',
          'settings',
          'put',
          'system',
          'show_touches',
          enabled ? '1' : '0',
        ],
      },
      options: Options(contentType: Headers.jsonContentType),
    );
    if (!isOk(resp)) return false;
    final data = responseMap(resp);
    return data['ok'] == true;
  }
}
