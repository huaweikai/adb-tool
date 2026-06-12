import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/device.dart';

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
}
