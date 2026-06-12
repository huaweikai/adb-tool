import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/device.dart';
import '../models/file_item.dart';
import '../models/app_package.dart';

class ApiClient {
  final String baseUrl;

  ApiClient(this.baseUrl);

  Future<List<Device>> getDevices() async {
    final resp = await http.get(Uri.parse('$baseUrl/api/devices'));
    if (resp.statusCode != 200) return [];
    final list = json.decode(resp.body) as List;
    return list.map((e) => Device.fromJson(e)).toList();
  }

  Future<List<String>> getRunningPackages(String serial) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/api/running-packages?serial=$serial'),
    );
    if (resp.statusCode != 200) return [];
    final data = json.decode(resp.body);
    final list = data['packages'] as List? ?? [];
    return list.map((e) => e.toString()).toList();
  }

  Future<String?> getPackagePid(String serial, String package) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/api/package-pid?serial=$serial&package=$package'),
    );
    if (resp.statusCode != 200) return null;
    final data = json.decode(resp.body);
    final pid = data['pid'] as String?;
    return (pid != null && pid.isNotEmpty) ? pid : null;
  }

  Future<bool> clearLogcat(String serial) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/api/clear?serial=$serial'),
    );
    return resp.statusCode == 200;
  }

  Future<bool> isReady() async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/adb-path'))
          .timeout(const Duration(seconds: 2));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<FileItem>> listFiles(String serial, String path) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/api/files?serial=$serial&path=${Uri.encodeComponent(path)}'),
    );
    if (resp.statusCode != 200) {
      final body = resp.body.isNotEmpty ? resp.body : 'HTTP ${resp.statusCode}';
      throw Exception(body);
    }
    final data = json.decode(resp.body);
    final list = data['files'] as List? ?? [];
    return list.map((e) => FileItem.fromJson(e)).toList();
  }

  Future<String> readFile(String serial, String path) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/api/file-content?serial=$serial&path=${Uri.encodeComponent(path)}'),
    );
    if (resp.statusCode != 200) throw Exception(resp.body);
    final data = json.decode(resp.body);
    return data['content'] ?? '';
  }

  Future<List<AppPackage>> getInstalledPackages(String serial) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/api/packages?serial=$serial'),
    );
    if (resp.statusCode != 200) throw Exception(resp.body);
    final data = json.decode(resp.body);
    final list = data['packages'] as List? ?? [];
    return list.map((e) => AppPackage.fromJson(e)).toList();
  }

  Future<Map<String, String>> getDeviceDetail(String serial) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/api/device-detail?serial=$serial'),
    );
    if (resp.statusCode != 200) throw Exception(resp.body);
    final data = json.decode(resp.body);
    final props = data['props'] as Map<String, dynamic>? ?? {};
    return props.map((k, v) => MapEntry(k, v.toString()));
  }

  Future<String?> takeScreenshot(String serial) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/api/screenshot?serial=$serial'),
    );
    if (resp.statusCode != 200) return null;
    return base64Encode(resp.bodyBytes);
  }

  Future<bool> uninstallPackage(String serial, String packageName) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/api/uninstall-package?serial=$serial&package=$packageName'),
    );
    if (resp.statusCode != 200) throw Exception(resp.body);
    return true;
  }

  Future<String> readFileContent(String serial, String path) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/api/file-content?serial=$serial&path=${Uri.encodeComponent(path)}'),
    );
    if (resp.statusCode != 200) throw Exception(resp.body);
    final data = json.decode(resp.body);
    return data['content'] ?? '';
  }

  Future<List<int>> pullFile(String serial, String path) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/api/pull-file?serial=$serial&path=${Uri.encodeComponent(path)}'),
    );
    if (resp.statusCode != 200) throw Exception('pull failed: ${resp.statusCode}');
    return resp.bodyBytes.toList();
  }

  Future<bool> pushFile(String serial, String path, List<int> bytes) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/api/push-file?serial=$serial&path=${Uri.encodeComponent(path)}'),
      body: bytes,
      headers: {'Content-Type': 'application/octet-stream'},
    );
    if (resp.statusCode != 200) throw Exception(resp.body);
    return true;
  }
}
