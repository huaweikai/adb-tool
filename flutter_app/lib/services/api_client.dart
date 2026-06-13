import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/device.dart';
import '../models/file_item.dart';
import '../models/app_package.dart';

class AdbCommandResult {
  final bool ok;
  final String output;
  final String error;

  AdbCommandResult({
    required this.ok,
    required this.output,
    required this.error,
  });
}

class TransferProgress {
  final int sent;
  final int total;

  const TransferProgress(this.sent, this.total);

  double? get ratio => total > 0 ? sent / total : null;
}

typedef TransferProgressCallback = void Function(TransferProgress progress);

class TransferCanceledException implements Exception {
  @override
  String toString() => '操作已取消';
}

class TransferCancelToken {
  bool _canceled = false;
  http.Client? _client;

  bool get canceled => _canceled;

  void bind(http.Client client) {
    _client = client;
    if (_canceled) client.close();
  }

  void cancel() {
    if (_canceled) return;
    _canceled = true;
    _client?.close();
  }

  void throwIfCanceled() {
    if (_canceled) throw TransferCanceledException();
  }
}

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

  Future<AdbCommandResult> executeAdbCommand(
      String serial, List<String> args) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/api/adb-exec?serial=$serial'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'args': args}),
    );
    final data = json.decode(resp.body);
    return AdbCommandResult(
      ok: data['ok'] == true,
      output: data['output']?.toString() ?? '',
      error: data['error']?.toString() ?? '',
    );
  }

  Future<AdbCommandResult> pairWirelessAdb(String address, String code) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/api/adb-wireless-pair'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'address': address, 'code': code}),
    );
    final data = json.decode(resp.body);
    return AdbCommandResult(
      ok: data['ok'] == true,
      output: data['output']?.toString() ?? '',
      error: data['error']?.toString() ?? '',
    );
  }

  Future<AdbCommandResult> connectWirelessAdb(String address) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/api/adb-wireless-connect'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'address': address}),
    );
    final data = json.decode(resp.body);
    return AdbCommandResult(
      ok: data['ok'] == true,
      output: data['output']?.toString() ?? '',
      error: data['error']?.toString() ?? '',
    );
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
      Uri.parse(
          '$baseUrl/api/files?serial=$serial&path=${Uri.encodeComponent(path)}'),
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
      Uri.parse(
          '$baseUrl/api/file-content?serial=$serial&path=${Uri.encodeComponent(path)}'),
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
      Uri.parse(
          '$baseUrl/api/uninstall-package?serial=$serial&package=$packageName'),
    );
    if (resp.statusCode != 200) throw Exception(resp.body);
    return true;
  }

  Future<String> installPackage(String serial, List<int> apkBytes) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/api/install-package?serial=$serial'),
      body: apkBytes,
      headers: {'Content-Type': 'application/octet-stream'},
    );
    final data = json.decode(resp.body);
    if (resp.statusCode != 200) {
      throw Exception(data['error'] ?? '安装失败');
    }
    return data['status'] ?? 'ok';
  }

  Future<String> installLocalPackage(
    String serial,
    String apkPath, {
    TransferProgressCallback? onProgress,
    TransferCancelToken? cancelToken,
  }) async {
    final body = await _postLocalFile(
      Uri.parse('$baseUrl/api/install-package?serial=$serial'),
      apkPath,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    final data = json.decode(body);
    return data['status'] ?? 'ok';
  }

  Future<String> readFileContent(String serial, String path) async {
    final resp = await http.get(
      Uri.parse(
          '$baseUrl/api/file-content?serial=$serial&path=${Uri.encodeComponent(path)}'),
    );
    if (resp.statusCode != 200) throw Exception(resp.body);
    final data = json.decode(resp.body);
    return data['content'] ?? '';
  }

  Future<List<int>> pullFile(String serial, String path) async {
    final resp = await http.get(
      Uri.parse(
          '$baseUrl/api/pull-file?serial=$serial&path=${Uri.encodeComponent(path)}'),
    );
    if (resp.statusCode != 200)
      throw Exception('pull failed: ${resp.statusCode}');
    return resp.bodyBytes.toList();
  }

  Future<void> downloadFileToPath(
    String serial,
    String remotePath,
    String localPath, {
    int totalBytes = 0,
    TransferProgressCallback? onProgress,
    TransferCancelToken? cancelToken,
  }) async {
    final client = http.Client();
    cancelToken?.bind(client);
    final request = http.Request(
      'GET',
      Uri.parse(
          '$baseUrl/api/pull-file?serial=$serial&path=${Uri.encodeComponent(remotePath)}'),
    );
    try {
      cancelToken?.throwIfCanceled();
      final response = await client.send(request);
      cancelToken?.throwIfCanceled();
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw Exception(
            body.isNotEmpty ? body : 'pull failed: ${response.statusCode}');
      }

      final file = File(localPath);
      final sink = file.openWrite();
      var received = 0;
      final expected =
          totalBytes > 0 ? totalBytes : response.contentLength ?? 0;
      try {
        await for (final chunk in response.stream) {
          cancelToken?.throwIfCanceled();
          received += chunk.length;
          sink.add(chunk);
          onProgress?.call(TransferProgress(received, expected));
        }
      } finally {
        await sink.close();
      }
      onProgress?.call(TransferProgress(received, expected));
    } finally {
      client.close();
    }
  }

  Future<bool> pushFile(String serial, String path, List<int> bytes) async {
    final resp = await http.post(
      Uri.parse(
          '$baseUrl/api/push-file?serial=$serial&path=${Uri.encodeComponent(path)}'),
      body: bytes,
      headers: {'Content-Type': 'application/octet-stream'},
    );
    if (resp.statusCode != 200) throw Exception(resp.body);
    return true;
  }

  Future<bool> pushLocalFile(
    String serial,
    String remotePath,
    String localPath, {
    TransferProgressCallback? onProgress,
    TransferCancelToken? cancelToken,
  }) async {
    await _postLocalFile(
      Uri.parse(
          '$baseUrl/api/push-file?serial=$serial&path=${Uri.encodeComponent(remotePath)}'),
      localPath,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    return true;
  }

  Future<String> _postLocalFile(
    Uri uri,
    String localPath, {
    TransferProgressCallback? onProgress,
    TransferCancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCanceled();
    final file = File(localPath);
    final total = await file.length();
    final request = http.StreamedRequest('POST', uri);
    request.headers['Content-Type'] = 'application/octet-stream';
    request.contentLength = total;

    var sent = 0;
    unawaited(() async {
      try {
        await for (final chunk in file.openRead()) {
          cancelToken?.throwIfCanceled();
          sent += chunk.length;
          request.sink.add(chunk);
          onProgress?.call(TransferProgress(sent, total));
        }
        await request.sink.close();
      } catch (e) {
        request.sink.addError(e);
        await request.sink.close();
      }
    }());

    final client = http.Client();
    cancelToken?.bind(client);
    try {
      cancelToken?.throwIfCanceled();
      final response = await client.send(request);
      cancelToken?.throwIfCanceled();
      final body = await response.stream.bytesToString();
      if (response.statusCode != 200) {
        var message = body;
        try {
          final data = json.decode(body);
          message = data['error']?.toString() ?? body;
        } catch (_) {}
        throw Exception(message);
      }
      onProgress?.call(TransferProgress(total, total));
      return body;
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> screenRecordAction(
      String serial, String action) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/api/screen-record?serial=$serial&action=$action'),
    );
    if (resp.statusCode != 200) throw Exception(resp.body);
    return json.decode(resp.body);
  }

  Future<Map<String, dynamic>> screenRecordStatus() async {
    final resp = await http.get(
      Uri.parse('$baseUrl/api/screen-record?action=status'),
    );
    if (resp.statusCode != 200) throw Exception(resp.body);
    return json.decode(resp.body);
  }

  Future<List<int>> pullRecordedVideo(String serial) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/api/screen-record-video?serial=$serial'),
    );
    if (resp.statusCode != 200)
      throw Exception('pull video failed: ${resp.statusCode}');
    return resp.bodyBytes.toList();
  }

  Future<bool> checkClipboardInstalled(String serial) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/api/clipboard-check?serial=$serial'),
    );
    if (resp.statusCode != 200) throw Exception(resp.body);
    final data = json.decode(resp.body);
    return data['installed'] == true;
  }

  Future<bool> installClipboardHelper(String serial) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/api/clipboard-install?serial=$serial'),
    );
    if (resp.statusCode != 200) {
      final data = json.decode(resp.body);
      throw Exception(data['error'] ?? resp.body);
    }
    return true;
  }

  Future<bool> sendClipboard(String serial, String text) async {
    final uri = Uri.parse('$baseUrl/api/clipboard-send')
        .replace(queryParameters: {'serial': serial, 'text': text});
    final resp = await http.post(uri);
    if (resp.statusCode != 200) {
      final data = json.decode(resp.body);
      throw Exception(data['error'] ?? resp.body);
    }
    return true;
  }

  Future<bool> uninstallClipboardHelper(String serial) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/api/clipboard-uninstall?serial=$serial'),
    );
    if (resp.statusCode != 200) {
      final data = json.decode(resp.body);
      throw Exception(data['error'] ?? resp.body);
    }
    return true;
  }
}
