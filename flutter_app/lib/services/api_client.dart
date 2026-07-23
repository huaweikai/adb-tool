// Public entry point for the HTTP client.
//
// Architecture:
//
//   abstract class ApiBase           <- shared Dio + private response helpers
//   class ApiClient = ApiBase       <- concrete facade
//                       with DeviceApi, FileApi, ...   (domain mixins)
//
// The mixins live in lib/services/api/*.dart and `on ApiBase`, so they
// can call the shared `dio`, `isOk`, `responseMap`, etc. without needing
// any part-of gymnastics.
//
// Adding a new API group:
//   1. Create lib/services/api/<domain>_api.dart with
//        import 'package:adb_tool/services/api_client.dart';
//        mixin <Domain>Api on ApiBase { ... }
//   2. Add it to the `with` list on the `ApiClient` typedef below.

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../providers/device_provider.dart';
import 'api/device_api.dart';
import 'api/file_api.dart';
import 'api/packages_api.dart';
import 'api/logcat_api.dart';
import 'api/screen_api.dart';
import 'api/scrcpy_api.dart';
import 'api/wireless_api.dart';
import 'api/clipboard_api.dart';
import 'api/adb_command_api.dart';
import 'api/backend_log_api.dart';
import 'api/emulator_api.dart';
import 'api/emulator_java_api.dart';
import 'api/emulator_image_api.dart';
import 'api/cleanup_api.dart';
import 'api/view_hierarchy_api.dart';

export 'api/device_api.dart' show DeviceApi;
export 'api/file_api.dart' show FileApi;
export 'api/packages_api.dart' show PackagesApi;
export 'api/logcat_api.dart' show LogcatApi;
export 'api/screen_api.dart' show ScreenApi;
export 'api/scrcpy_api.dart'
    show ScrcpyApi, ScrcpyStatus, ScrcpyRecordStatus, ScrcpyRecordBusyException;
export 'api/wireless_api.dart' show WirelessApi;
export 'api/clipboard_api.dart' show ClipboardApi;
export 'api/adb_command_api.dart' show AdbCommandApi;
export 'api/backend_log_api.dart' show BackendLogApi;
export 'api/emulator_api.dart'
    show
        EmulatorApi,
        EmulatorEngineStatus,
        SDKDetectResult,
        SDKDownloadResult,
        SDKInstallJob;
export 'api/emulator_java_api.dart'
    show
        EmulatorJavaApi,
        JavaRuntimeStatus,
        JavaRuntimeInfo,
        JavaRuntimeList,
        JavaSelectionResult,
        JavaValidationResult,
        JavaDownloadResult,
        JavaDownloadProgress,
        DownloadInfo;
export 'api/emulator_image_api.dart'
    show EmulatorImageApi, SystemImage, SystemImageStatus, ImageDownloadResult;
export 'api/cleanup_api.dart'
    show CleanupApi, CacheCleanupResult, CacheCleanupEntry;
export 'api/view_hierarchy_api.dart' show ViewHierarchyApi;

// ===== Public value types shared across domains =====

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

class WirelessAdbDevice {
  final String name;
  final String host;
  final String pairPort;
  final String connectPort;
  final String pairAddress;
  final String address;
  final String source;

  WirelessAdbDevice({
    required this.name,
    required this.host,
    required this.pairPort,
    required this.connectPort,
    required this.pairAddress,
    required this.address,
    required this.source,
  });

  factory WirelessAdbDevice.fromJson(Map<String, dynamic> json) {
    return WirelessAdbDevice(
      name: json['name']?.toString() ?? '',
      host: json['host']?.toString() ?? '',
      pairPort: json['pairPort']?.toString() ?? '',
      connectPort: json['connectPort']?.toString() ?? '',
      pairAddress: json['pairAddress']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
    );
  }
}

// ===== File-transfer progress plumbing =====

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

class DeviceOfflineException implements Exception {
  final String stableSerial;

  const DeviceOfflineException(this.stableSerial);

  @override
  String toString() => 'DeviceOfflineException: $stableSerial is not online';
}

// ===== Shared base class for all API mixins =====

/// ApiBase owns the Dio instance plus the response-envelope helpers
/// (`isOk`, `responseMap`, `_asMap`, etc.) that every domain mixin relies on.
///
/// All public members here are part of the mixin contract; they are not
/// intended to be called directly by application code — use ApiClient.
abstract class ApiBase {
  String baseUrl;
  final Dio dio;
  final DeviceProvider? deviceProvider;

  ApiBase(this.baseUrl, {Dio? dio, this.deviceProvider})
      : dio = (dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 120),
                validateStatus: (_) => true,
              ),
            ))..interceptors.add(InterceptorsWrapper(
          onRequest: (options, handler) {
            final provider = deviceProvider;
            if (provider == null) {
              handler.next(options);
              return;
            }
            // Resolve serial in query params
            final querySerial = options.queryParameters['serial'];
            if (querySerial is String && querySerial.isNotEmpty) {
              final resolved = provider.onlineAddressFor(querySerial);
              if (resolved == null || resolved.isEmpty) {
                handler.reject(DioException(
                  requestOptions: options,
                  error: DeviceOfflineException(querySerial),
                  type: DioExceptionType.unknown,
                ));
                return;
              }
              options.queryParameters['serial'] = resolved;
            }
            // Resolve serial in JSON body
            if (options.data is Map<String, dynamic>) {
              final body = options.data as Map<String, dynamic>;
              final bodySerial = body['serial'];
              if (bodySerial is String && bodySerial.isNotEmpty) {
                final resolved = provider.onlineAddressFor(bodySerial);
                if (resolved == null || resolved.isEmpty) {
                  handler.reject(DioException(
                    requestOptions: options,
                    error: DeviceOfflineException(bodySerial),
                    type: DioExceptionType.unknown,
                  ));
                  return;
                }
                body['serial'] = resolved;
              }
            }
            handler.next(options);
          },
        ));

  Map<String, dynamic> deviceQueryParameters(
    String stableSerial, [
    Map<String, dynamic> extra = const {},
  ]) {
    return {'serial': stableSerial, ...extra};
  }

  /// Update the backend base URL at runtime — used when the user changes
  /// the listen port in the launch-page settings. Updates both the cached
  /// field and the underlying Dio instance so every domain mixin (which
  /// issue relative-path requests) picks up the new host:port.
  void updateBaseUrl(String value) {
    baseUrl = value;
    dio.options.baseUrl = value;
  }

  /// Probe the backend's identify endpoint.
  ///
  /// Returns the identify payload (`{name, pid, started}`) when the
  /// backend is reachable and reports itself as `adb-tool`, or `null`
  /// on any error / wrong identity. Used by the settings page to show
  /// a live backend (bridge) status without throwing.
  Future<Map<String, dynamic>?> tryIdentify() async {
    try {
      final resp = await dio.get('/api/identify');
      if (resp.statusCode != 200) return null;
      final body = asMap(resp.data);
      if (_isEnvelope(body)) {
        if (body['ok'] != true) return null;
        final data = asMap(body['data']);
        if (data['name'] != 'adb-tool') return null;
        return data;
      }
      if (body['name'] == 'adb-tool') return body;
      return null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> deviceBodyParameters(
    String stableSerial, [
    Map<String, dynamic> extra = const {},
  ]) {
    return {'serial': stableSerial, ...extra};
  }

  AdbCommandResult adbCommandResult(Map<String, dynamic> data) {
    return AdbCommandResult(
      ok: data['ok'] == true,
      output: data['output']?.toString() ?? '',
      error: data['error']?.toString() ?? '',
    );
  }

  void throwIfNotOk(Response response) {
    if (isOk(response)) return;
    throw Exception(errorMessage(response));
  }

  bool isOk(Response response) {
    if (response.statusCode != 200) return false;
    final body = asMap(response.data);
    if (_isEnvelope(body)) return body['ok'] == true;
    return true;
  }

  dynamic responseData(Response response) {
    final body = asMap(response.data);
    if (_isEnvelope(body)) return body['data'];
    return response.data;
  }

  Map<String, dynamic> responseMap(Response response) {
    final body = asMap(response.data);
    final data = asMap(responseData(response));
    if (_isEnvelope(body) && body['ok'] != true && !data.containsKey('error')) {
      final error = body['error']?.toString() ?? '';
      if (error.isNotEmpty) data['error'] = error;
    }
    return data;
  }

  bool _isEnvelope(Map<String, dynamic> data) {
    return data.containsKey('ok') && data.containsKey('data');
  }

  String errorMessage(Response response) {
    final data = response.data;
    final body = asMap(data);
    if (_isEnvelope(body)) {
      final error = body['error']?.toString() ?? '';
      if (error.isNotEmpty) return error;
      return 'HTTP ${response.statusCode}';
    }
    if (body.isNotEmpty) {
      return body['error']?.toString() ??
          body['message']?.toString() ??
          '$body';
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

  Map<String, dynamic> asMap(dynamic data) {
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

  List<dynamic> asList(dynamic data) {
    if (data is List) return data;
    if (data is String && data.isNotEmpty) {
      final decoded = json.decode(data);
      if (decoded is List) return decoded;
    }
    return <dynamic>[];
  }

  bool isCancelError(DioException error) {
    return error.type == DioExceptionType.cancel ||
        error.error is TransferCanceledException;
  }

  /// Streams a local file to the backend as an octet-stream body with progress
  /// reporting. Shared by FileApi.pushLocalFile and PackagesApi.installLocalPackage.
  ///
  /// NOTE: callers from mixins should use `this.postLocalFile(...)` to force
  /// Dart's full lookup chain (Dart 3 sometimes resolves a bare name to the
  /// mixin scope only and misses the host class).
  Future<Map<String, dynamic>> postLocalFile(
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
      final response = await dio.post(
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
      if (!isOk(response)) {
        throw Exception(errorMessage(response));
      }
      onProgress?.call(TransferProgress(total, total));
      return responseMap(response);
    } on DioException catch (e) {
      if (isCancelError(e)) throw TransferCanceledException();
      rethrow;
    }
  }
}

// ===== Concrete facade — composed of all domain mixins =====

/// Application code should only depend on `ApiClient`. The mixin types are
/// re-exported above only so Dart can resolve the `with` clause.
class ApiClient = ApiBase
    with
        DeviceApi,
        FileApi,
        PackagesApi,
        LogcatApi,
        ScreenApi,
        ScrcpyApi,
        WirelessApi,
        ClipboardApi,
        AdbCommandApi,
        BackendLogApi,
        EmulatorApi,
        EmulatorJavaApi,
        EmulatorImageApi,
        CleanupApi,
        ViewHierarchyApi;
