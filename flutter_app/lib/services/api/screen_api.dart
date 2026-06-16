// Screen recording control: start / stop / status / pull video.
import 'package:adb_tool/services/api_client.dart';
import 'package:dio/dio.dart';

mixin ScreenApi on ApiBase {
  Future<Map<String, dynamic>> screenRecordAction(
      String serial, String action) async {
    final resp = await dio.get(
      '/api/screen-record',
      queryParameters: {'serial': serial, 'action': action},
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
      queryParameters: {'serial': serial},
      options: Options(responseType: ResponseType.bytes),
    );
    if (!isOk(resp)) {
      throw Exception('pull video failed: ${resp.statusCode}');
    }
    return resp.data ?? [];
  }
}
