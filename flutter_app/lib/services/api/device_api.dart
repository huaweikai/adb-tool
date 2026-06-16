// Device discovery + per-device info / status / screenshot.
import 'dart:convert';

import 'package:adb_tool/services/api_client.dart';
import 'package:adb_tool/models/device.dart';
import 'package:adb_tool/models/device_status.dart';
import 'package:dio/dio.dart';

mixin DeviceApi on ApiBase {
  Future<List<Device>> getDevices() async {
    final resp = await dio.get('/api/devices');
    if (!isOk(resp)) {
      throw Exception(errorMessage(resp));
    }
    final list = asList(responseData(resp));
    return list.map((e) => Device.fromJson(asMap(e))).toList();
  }

  Future<List<String>> getRunningPackages(String serial) async {
    final resp = await dio.get(
      '/api/running-packages',
      queryParameters: {'serial': serial},
    );
    if (!isOk(resp)) return [];
    final data = responseMap(resp);
    final list = data['packages'] as List? ?? [];
    return list.map((e) => e.toString()).toList();
  }

  Future<String?> getPackagePid(String serial, String package) async {
    final resp = await dio.get(
      '/api/package-pid',
      queryParameters: {'serial': serial, 'package': package},
    );
    if (!isOk(resp)) return null;
    final data = responseMap(resp);
    final pid = data['pid'] as String?;
    return (pid != null && pid.isNotEmpty) ? pid : null;
  }

  Future<bool> clearLogcat(String serial) async {
    final resp = await dio.get(
      '/api/clear',
      queryParameters: {'serial': serial},
    );
    return isOk(resp);
  }

  Future<bool> isReady() async {
    try {
      final resp =
          await dio.get('/api/adb-path').timeout(const Duration(seconds: 2));
      return isOk(resp);
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getServerIdentity() async {
    try {
      final resp =
          await dio.get('/api/identify').timeout(const Duration(seconds: 2));
      if (!isOk(resp)) return null;
      return responseMap(resp);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> getDeviceDetail(String serial) async {
    final resp = await dio.get(
      '/api/device-detail',
      queryParameters: {'serial': serial},
    );
    throwIfNotOk(resp);
    final data = responseMap(resp);
    final props = asMap(data['props']);
    return props.map((k, v) => MapEntry(k, v.toString()));
  }

  Future<DeviceStatus> getDeviceStatus(String serial) async {
    final resp = await dio.get(
      '/api/device-status',
      queryParameters: {'serial': serial},
    );
    throwIfNotOk(resp);
    final data = responseMap(resp);
    return DeviceStatus.fromJson(asMap(data['status']));
  }

  Future<String?> takeScreenshot(String serial) async {
    final resp = await dio.get<List<int>>(
      '/api/screenshot',
      queryParameters: {'serial': serial},
      options: Options(responseType: ResponseType.bytes),
    );
    if (!isOk(resp)) return null;
    return base64Encode(resp.data ?? []);
  }
}
