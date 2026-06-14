import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../models/app_package.dart';
import '../models/device.dart';
import '../models/file_item.dart';

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
  final CancelToken _cancelToken = CancelToken();

  bool get canceled => _canceled;
  CancelToken get dioToken => _cancelToken;

  void cancel() {
    if (_canceled) return;
    _canceled = true;
    if (!_cancelToken.isCancelled) {
      _cancelToken.cancel(TransferCanceledException());
    }
  }

  void throwIfCanceled() {
    if (_canceled) throw TransferCanceledException();
  }
}

class ApiClient {
  final String baseUrl;
  final Dio _dio;

  ApiClient(this.baseUrl, {Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 5),
                validateStatus: (_) => true,
              ),
            );

  Future<List<Device>> getDevices() async {
    final resp = await _dio.get('/api/devices');
    if (!_isOk(resp)) return [];
    final list = _asList(resp.data);
    return list.map((e) => Device.fromJson(_asMap(e))).toList();
  }

  Future<List<String>> getRunningPackages(String serial) async {
    final resp = await _dio.get(
      '/api/running-packages',
      queryParameters: {'serial': serial},
    );
    if (!_isOk(resp)) return [];
    final data = _asMap(resp.data);
    final list = data['packages'] as List? ?? [];
    return list.map((e) => e.toString()).toList();
  }

  Future<String?> getPackagePid(String serial, String package) async {
    final resp = await _dio.get(
      '/api/package-pid',
      queryParameters: {'serial': serial, 'package': package},
    );
    if (!_isOk(resp)) return null;
    final data = _asMap(resp.data);
    final pid = data['pid'] as String?;
    return (pid != null && pid.isNotEmpty) ? pid : null;
  }

  Future<bool> clearLogcat(String serial) async {
    final resp = await _dio.get(
      '/api/clear',
      queryParameters: {'serial': serial},
    );
    return _isOk(resp);
  }

  Future<AdbCommandResult> executeAdbCommand(
      String serial, List<String> args) async {
    final resp = await _dio.post(
      '/api/adb-exec',
      queryParameters: {'serial': serial},
      data: {'args': args},
      options: Options(contentType: Headers.jsonContentType),
    );
    final data = _asMap(resp.data);
    return _adbCommandResult(data);
  }

  Future<AdbCommandResult> pairWirelessAdb(String address, String code) async {
    final resp = await _dio.post(
      '/api/adb-wireless-pair',
      data: {'address': address, 'code': code},
      options: Options(contentType: Headers.jsonContentType),
    );
    return _adbCommandResult(_asMap(resp.data));
  }

  Future<AdbCommandResult> connectWirelessAdb(String address) async {
    final resp = await _dio.post(
      '/api/adb-wireless-connect',
      data: {'address': address},
      options: Options(contentType: Headers.jsonContentType),
    );
    return _adbCommandResult(_asMap(resp.data));
  }

  Future<AdbCommandResult> disconnectWirelessAdb(String serial) async {
    final resp = await _dio.post(
      '/api/adb-wireless-disconnect',
      data: {'serial': serial},
      options: Options(contentType: Headers.jsonContentType),
    );
    return _adbCommandResult(_asMap(resp.data));
  }

  Future<bool> isReady() async {
    try {
      final resp =
          await _dio.get('/api/adb-path').timeout(const Duration(seconds: 2));
      return _isOk(resp);
    } catch (_) {
      return false;
    }
  }

  Future<List<FileItem>> listFiles(String serial, String path) async {
    final resp = await _dio.get(
      '/api/files',
      queryParameters: {'serial': serial, 'path': path},
    );
    _throwIfNotOk(resp);
    final data = _asMap(resp.data);
    final list = data['files'] as List? ?? [];
    return list.map((e) => FileItem.fromJson(_asMap(e))).toList();
  }

  Future<String> readFile(String serial, String path) async {
    final resp = await _dio.get(
      '/api/file-content',
      queryParameters: {'serial': serial, 'path': path},
    );
    _throwIfNotOk(resp);
    final data = _asMap(resp.data);
    return data['content'] ?? '';
  }

  Future<List<AppPackage>> getInstalledPackages(String serial) async {
    final resp = await _dio.get(
      '/api/packages',
      queryParameters: {'serial': serial},
    );
    _throwIfNotOk(resp);
    final data = _asMap(resp.data);
    final list = data['packages'] as List? ?? [];
    return list.map((e) => AppPackage.fromJson(_asMap(e))).toList();
  }

  Future<Map<String, String>> getDeviceDetail(String serial) async {
    final resp = await _dio.get(
      '/api/device-detail',
      queryParameters: {'serial': serial},
    );
    _throwIfNotOk(resp);
    final data = _asMap(resp.data);
    final props = _asMap(data['props']);
    return props.map((k, v) => MapEntry(k, v.toString()));
  }

  Future<String?> takeScreenshot(String serial) async {
    final resp = await _dio.get<List<int>>(
      '/api/screenshot',
      queryParameters: {'serial': serial},
      options: Options(responseType: ResponseType.bytes),
    );
    if (!_isOk(resp)) return null;
    return base64Encode(resp.data ?? []);
  }

  Future<bool> uninstallPackage(String serial, String packageName) async {
    final resp = await _dio.post(
      '/api/uninstall-package',
      queryParameters: {'serial': serial, 'package': packageName},
    );
    _throwIfNotOk(resp);
    return true;
  }

  Future<String> installPackage(String serial, List<int> apkBytes) async {
    final resp = await _dio.post(
      '/api/install-package',
      queryParameters: {'serial': serial},
      data: apkBytes,
      options: Options(contentType: 'application/octet-stream'),
    );
    final data = _asMap(resp.data);
    if (!_isOk(resp)) {
      throw Exception(data['error'] ?? 'Install failed');
    }
    return data['status'] ?? 'ok';
  }

  Future<String> installLocalPackage(
    String serial,
    String apkPath, {
    TransferProgressCallback? onProgress,
    TransferCancelToken? cancelToken,
  }) async {
    final data = await _postLocalFile(
      '/api/install-package',
      apkPath,
      queryParameters: {'serial': serial},
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    return data['status'] ?? 'ok';
  }

  Future<String> readFileContent(String serial, String path) async {
    final resp = await _dio.get(
      '/api/file-content',
      queryParameters: {'serial': serial, 'path': path},
    );
    _throwIfNotOk(resp);
    final data = _asMap(resp.data);
    return data['content'] ?? '';
  }

  Future<bool> deleteFile(
    String serial,
    String path, {
    required bool recursive,
  }) async {
    final resp = await _dio.post(
      '/api/file-delete',
      queryParameters: {
        'serial': serial,
        'path': path,
        'recursive': recursive.toString(),
      },
    );
    _throwIfNotOk(resp);
    return true;
  }

  Future<bool> renameFile(String serial, String from, String to) async {
    final resp = await _dio.post(
      '/api/file-rename',
      queryParameters: {'serial': serial, 'from': from, 'to': to},
    );
    _throwIfNotOk(resp);
    return true;
  }

  Future<bool> createDirectory(String serial, String path) async {
    final resp = await _dio.post(
      '/api/file-mkdir',
      queryParameters: {'serial': serial, 'path': path},
    );
    _throwIfNotOk(resp);
    return true;
  }

  Future<bool> createFile(String serial, String path) async {
    final resp = await _dio.post(
      '/api/file-touch',
      queryParameters: {'serial': serial, 'path': path},
    );
    _throwIfNotOk(resp);
    return true;
  }

  Future<FileStat> statFile(String serial, String path) async {
    final resp = await _dio.get(
      '/api/file-stat',
      queryParameters: {'serial': serial, 'path': path},
    );
    _throwIfNotOk(resp);
    final data = _asMap(resp.data);
    return FileStat.fromJson(_asMap(data['stat']));
  }

  Future<List<int>> pullFile(String serial, String path) async {
    final resp = await _dio.get<List<int>>(
      '/api/pull-file',
      queryParameters: {'serial': serial, 'path': path},
      options: Options(responseType: ResponseType.bytes),
    );
    if (!_isOk(resp)) {
      throw Exception('pull failed: ${resp.statusCode}');
    }
    return resp.data ?? [];
  }

  Future<void> downloadFileToPath(
    String serial,
    String remotePath,
    String localPath, {
    int totalBytes = 0,
    TransferProgressCallback? onProgress,
    TransferCancelToken? cancelToken,
  }) async {
    try {
      cancelToken?.throwIfCanceled();
      final response = await _dio.download(
        '/api/pull-file',
        localPath,
        queryParameters: {'serial': serial, 'path': remotePath},
        cancelToken: cancelToken?.dioToken,
        onReceiveProgress: (received, total) {
          final expected = totalBytes > 0 ? totalBytes : total;
          onProgress?.call(TransferProgress(received, expected));
        },
      );
      cancelToken?.throwIfCanceled();
      if (!_isOk(response)) {
        final file = File(localPath);
        if (await file.exists()) await file.delete();
        throw Exception('pull failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (_isCancelError(e)) throw TransferCanceledException();
      rethrow;
    }
  }

  Future<bool> pushFile(String serial, String path, List<int> bytes) async {
    final resp = await _dio.post(
      '/api/push-file',
      queryParameters: {'serial': serial, 'path': path},
      data: bytes,
      options: Options(contentType: 'application/octet-stream'),
    );
    _throwIfNotOk(resp);
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
      '/api/push-file',
      localPath,
      queryParameters: {'serial': serial, 'path': remotePath},
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    return true;
  }

  Future<Map<String, dynamic>> _postLocalFile(
    String path,
    String localPath, {
    Map<String, dynamic>? queryParameters,
    TransferProgressCallback? onProgress,
    TransferCancelToken? cancelToken,
  }) async {
    try {
      cancelToken?.throwIfCanceled();
      final file = File(localPath);
      final total = await file.length();
      final response = await _dio.post(
        path,
        queryParameters: queryParameters,
        data: file.openRead(),
        cancelToken: cancelToken?.dioToken,
        options: Options(
          contentType: 'application/octet-stream',
          headers: {Headers.contentLengthHeader: total},
        ),
        onSendProgress: (sent, _) {
          onProgress?.call(TransferProgress(sent, total));
        },
      );
      cancelToken?.throwIfCanceled();
      if (!_isOk(response)) {
        throw Exception(_errorMessage(response));
      }
      onProgress?.call(TransferProgress(total, total));
      return _asMap(response.data);
    } on DioException catch (e) {
      if (_isCancelError(e)) throw TransferCanceledException();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> screenRecordAction(
      String serial, String action) async {
    final resp = await _dio.get(
      '/api/screen-record',
      queryParameters: {'serial': serial, 'action': action},
    );
    _throwIfNotOk(resp);
    return _asMap(resp.data);
  }

  Future<Map<String, dynamic>> screenRecordStatus() async {
    final resp = await _dio.get(
      '/api/screen-record',
      queryParameters: {'action': 'status'},
    );
    _throwIfNotOk(resp);
    return _asMap(resp.data);
  }

  Future<List<int>> pullRecordedVideo(String serial) async {
    final resp = await _dio.get<List<int>>(
      '/api/screen-record-video',
      queryParameters: {'serial': serial},
      options: Options(responseType: ResponseType.bytes),
    );
    if (!_isOk(resp)) {
      throw Exception('pull video failed: ${resp.statusCode}');
    }
    return resp.data ?? [];
  }

  Future<bool> checkClipboardInstalled(String serial) async {
    final resp = await _dio.get(
      '/api/clipboard-check',
      queryParameters: {'serial': serial},
    );
    _throwIfNotOk(resp);
    final data = _asMap(resp.data);
    return data['installed'] == true;
  }

  Future<bool> installClipboardHelper(String serial) async {
    final resp = await _dio.post(
      '/api/clipboard-install',
      queryParameters: {'serial': serial},
    );
    _throwIfNotOk(resp);
    return true;
  }

  Future<bool> sendClipboard(String serial, String text) async {
    final resp = await _dio.post(
      '/api/clipboard-send',
      queryParameters: {'serial': serial, 'text': text},
    );
    _throwIfNotOk(resp);
    return true;
  }

  Future<bool> uninstallClipboardHelper(String serial) async {
    final resp = await _dio.post(
      '/api/clipboard-uninstall',
      queryParameters: {'serial': serial},
    );
    _throwIfNotOk(resp);
    return true;
  }

  Future<List<Map<String, dynamic>>> getBackendLogs() async {
    final resp =
        await _dio.get('/api/backend-logs').timeout(const Duration(seconds: 3));
    if (!_isOk(resp)) return [];
    final data = _asMap(resp.data);
    final list = data['logs'] as List? ?? [];
    return list.map((e) => _asMap(e)).toList();
  }

  AdbCommandResult _adbCommandResult(Map<String, dynamic> data) {
    return AdbCommandResult(
      ok: data['ok'] == true,
      output: data['output']?.toString() ?? '',
      error: data['error']?.toString() ?? '',
    );
  }

  void _throwIfNotOk(Response response) {
    if (_isOk(response)) return;
    throw Exception(_errorMessage(response));
  }

  bool _isOk(Response response) => response.statusCode == 200;

  String _errorMessage(Response response) {
    final data = response.data;
    if (data is Map) {
      return data['error']?.toString() ??
          data['message']?.toString() ??
          '$data';
    }
    if (data is List<int>) {
      return utf8.decode(data, allowMalformed: true);
    }
    final text = data?.toString() ?? '';
    if (text.isEmpty) return 'HTTP ${response.statusCode}';
    try {
      final decoded = json.decode(text);
      if (decoded is Map) {
        return decoded['error']?.toString() ??
            decoded['message']?.toString() ??
            text;
      }
    } catch (_) {}
    return text;
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.map((k, v) => MapEntry(k.toString(), v));
    if (data is String && data.isNotEmpty) {
      final decoded = json.decode(data);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    }
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic data) {
    if (data is List) return data;
    if (data is String && data.isNotEmpty) {
      final decoded = json.decode(data);
      if (decoded is List) return decoded;
    }
    return <dynamic>[];
  }

  bool _isCancelError(DioException error) {
    return error.type == DioExceptionType.cancel ||
        error.error is TransferCanceledException;
  }
}
