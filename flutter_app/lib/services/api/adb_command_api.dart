// Generic ADB command exec — used by the ADB command screen for arbitrary
// adb -s <serial> <args...> calls. See C.3 in the optimization proposal
// for a future dangerous-command guard.
import 'package:adb_tool/services/api_client.dart';
import 'package:dio/dio.dart';

mixin AdbCommandApi on ApiBase {
  Future<AdbCommandResult> executeAdbCommand(
      String serial, List<String> args) async {
    final resp = await dio.post(
      '/api/adb-exec',
      queryParameters: {'serial': serial},
      data: {'args': args},
      options: Options(contentType: Headers.jsonContentType),
    );
    return adbCommandResult(responseMap(resp));
  }
}
