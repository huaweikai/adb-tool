// Logcat recent-snapshot fetch + session-bound logcat start/stop.
import 'package:adb_tool/services/api_client.dart';
import 'package:dio/dio.dart';

mixin LogcatApi on ApiBase {
  Future<String> getRecentLogcat(String serial, {int lines = 1000}) async {
    final resp = await dio.get(
      '/api/logcat-recent',
      queryParameters: {'serial': serial, 'lines': lines},
    );
    throwIfNotOk(resp);
    final data = responseMap(resp);
    return data['content']?.toString() ?? '';
  }

  Future<Map<String, dynamic>> sessionLogcatAction(
    String action, {
    required String serial,
    required String sessionDir,
    String packageName = '',
  }) async {
    final resp = await dio.post(
      '/api/session-logcat',
      data: {
        'action': action,
        'serial': serial,
        'sessionDir': sessionDir,
        'packageName': packageName,
      },
      options: Options(contentType: Headers.jsonContentType),
    );
    throwIfNotOk(resp);
    return responseMap(resp);
  }

  /// Start a per-device logcat recording that writes to a backend-owned
  /// temp file (NOT a test session dir). Returns the file path being
  /// written — keep it around so [stopLocalRecording] can report it back
  /// to the user via a file_selector save dialog.
  Future<Map<String, dynamic>> startLocalRecording(
    String serial, {
    String packageName = '',
  }) async {
    final resp = await dio.post(
      '/api/local-recording',
      data: {
        'action': 'start',
        'serial': serial,
        'packageName': packageName,
      },
      options: Options(contentType: Headers.jsonContentType),
    );
    throwIfNotOk(resp);
    return responseMap(resp);
  }

  /// Stop the per-device recording started by [startLocalRecording].
  /// Returns a map with `path` (the temp file, ready to be copied to a
  /// user-chosen location) and `bytes` (final size). If no recording is
  /// active for the serial the backend still returns ok with empty path.
  Future<Map<String, dynamic>> stopLocalRecording(String serial) async {
    final resp = await dio.post(
      '/api/local-recording',
      data: {
        'action': 'stop',
        'serial': serial,
      },
      options: Options(contentType: Headers.jsonContentType),
    );
    throwIfNotOk(resp);
    return responseMap(resp);
  }
}
