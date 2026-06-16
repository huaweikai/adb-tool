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
}
