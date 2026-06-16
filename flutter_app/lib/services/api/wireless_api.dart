// Wireless ADB: pair / connect / disconnect / scan.
import 'package:adb_tool/services/api_client.dart';
import 'package:dio/dio.dart';

mixin WirelessApi on ApiBase {
  Future<AdbCommandResult> pairWirelessAdb(String address, String code) async {
    final resp = await dio.post(
      '/api/adb-wireless-pair',
      data: {'address': address, 'code': code},
      options: Options(contentType: Headers.jsonContentType),
    );
    return adbCommandResult(responseMap(resp));
  }

  Future<AdbCommandResult> connectWirelessAdb(String address) async {
    final resp = await dio.post(
      '/api/adb-wireless-connect',
      data: {'address': address},
      options: Options(contentType: Headers.jsonContentType),
    );
    return adbCommandResult(responseMap(resp));
  }

  Future<AdbCommandResult> disconnectWirelessAdb(String serial) async {
    final resp = await dio.post(
      '/api/adb-wireless-disconnect',
      data: {'serial': serial},
      options: Options(contentType: Headers.jsonContentType),
    );
    return adbCommandResult(responseMap(resp));
  }

  Future<List<WirelessAdbDevice>> scanWirelessAdb() async {
    final resp = await dio.get('/api/adb-wireless-scan');
    throwIfNotOk(resp);
    final data = responseMap(resp);
    final list = data['devices'] as List? ?? [];
    return list.map((e) => WirelessAdbDevice.fromJson(asMap(e))).toList();
  }
}
