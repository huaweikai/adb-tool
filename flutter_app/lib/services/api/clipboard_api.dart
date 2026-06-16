// Clipboard helper: check / install / send / uninstall.
import 'package:adb_tool/services/api_client.dart';
import 'package:dio/dio.dart';

mixin ClipboardApi on ApiBase {
  Future<bool> checkClipboardInstalled(String serial) async {
    final resp = await dio.get(
      '/api/clipboard-check',
      queryParameters: {'serial': serial},
    );
    throwIfNotOk(resp);
    final data = responseMap(resp);
    return data['installed'] == true;
  }

  Future<bool> installClipboardHelper(String serial) async {
    final resp = await dio.post(
      '/api/clipboard-install',
      queryParameters: {'serial': serial},
    );
    throwIfNotOk(resp);
    return true;
  }

  Future<bool> sendClipboard(String serial, String text) async {
    final resp = await dio.post(
      '/api/clipboard-send',
      queryParameters: {'serial': serial},
      data: {'text': text},
      options: Options(contentType: Headers.jsonContentType),
    );
    throwIfNotOk(resp);
    return true;
  }

  Future<bool> uninstallClipboardHelper(String serial) async {
    final resp = await dio.post(
      '/api/clipboard-uninstall',
      queryParameters: {'serial': serial},
    );
    throwIfNotOk(resp);
    return true;
  }
}
