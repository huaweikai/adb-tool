// Emulator engine API - validate and configure Android SDK emulator.
import 'package:adb_tool/services/api_client.dart';

mixin EmulatorApi on ApiBase {
  /// Get current emulator engine status (paths, versions, validation state).
  Future<EmulatorEngineStatus> getEngineStatus() async {
    final response = await dio.get('/api/emulator/engine/status');
    final data = responseMap(response);
    return EmulatorEngineStatus.fromJson(data);
  }

  /// Validate the given emulator path and return version info.
  Future<EmulatorEngineStatus> validateEngine({
    String? androidHome,
    String? emulatorPath,
  }) async {
    final response = await dio.post(
      '/api/emulator/engine/validate',
      data: {
        if (androidHome != null) 'androidHome': androidHome,
        if (emulatorPath != null) 'emulatorPath': emulatorPath,
      },
    );
    final data = responseMap(response);
    return EmulatorEngineStatus.fromJson(data);
  }

  /// Update emulator engine configuration.
  Future<EmulatorEngineStatus> updateEngineConfig({
    String? androidHome,
    String? emulatorPath,
  }) async {
    final response = await dio.put(
      '/api/emulator/engine/config',
      data: {
        if (androidHome != null) 'androidHome': androidHome,
        if (emulatorPath != null) 'emulatorPath': emulatorPath,
      },
    );
    final data = responseMap(response);
    return EmulatorEngineStatus.fromJson(data);
  }

  /// Detect SDKs on the system.
  Future<List<SDKDetectResult>> detectSDKs() async {
    final response = await dio.get('/api/emulator/sdk/detect');
    final data = responseMap(response);
    final sdkList = data['sdks'] as List? ?? [];
    return sdkList
        .map((e) => SDKDetectResult.fromJson(asMap(e)))
        .toList();
  }

  /// Use a detected SDK path.
  Future<EmulatorEngineStatus> useSDK(String sdkPath) async {
    final response = await dio.post(
      '/api/emulator/sdk/use',
      data: {'sdkPath': sdkPath},
    );
    final data = responseMap(response);
    return EmulatorEngineStatus.fromJson(data);
  }

  /// Download SDK from URL.
  Future<SDKDownloadResult> downloadSDK({
    required String url,
    required String id,
    required String name,
    String? sha256,
  }) async {
    final response = await dio.post(
      '/api/emulator/sdk/download',
      data: {
        'url': url,
        'id': id,
        'name': name,
        if (sha256 != null) 'sha256': sha256,
      },
    );
    final data = responseMap(response);
    return SDKDownloadResult.fromJson(data);
  }

  /// Check download progress.
  Future<SDKDownloadResult> checkDownloadProgress(String id) async {
    final response = await dio.get(
      '/api/emulator/download/progress',
      queryParameters: {'id': id},
    );
    final data = responseMap(response);
    return SDKDownloadResult.fromJson(data);
  }
}

/// Represents a detected Android SDK on the system.
class SDKDetectResult {
  final String path;
  final String name;
  final bool hasEmulator;
  final bool hasAvdmanager;
  final bool hasJava;
  final String? version;

  const SDKDetectResult({
    required this.path,
    required this.name,
    this.hasEmulator = false,
    this.hasAvdmanager = false,
    this.hasJava = false,
    this.version,
  });

  factory SDKDetectResult.fromJson(Map<String, dynamic> json) {
    return SDKDetectResult(
      path: json['path'] as String,
      name: json['name'] as String,
      hasEmulator: json['hasEmulator'] as bool? ?? false,
      hasAvdmanager: json['hasAvdmanager'] as bool? ?? false,
      hasJava: json['hasJava'] as bool? ?? false,
      version: json['version'] as String?,
    );
  }
}

/// SDK download result.
class SDKDownloadResult {
  final String id;
  final String status;
  final double progress;

  const SDKDownloadResult({
    required this.id,
    required this.status,
    this.progress = 0.0,
  });

  factory SDKDownloadResult.fromJson(Map<String, dynamic> json) {
    return SDKDownloadResult(
      id: json['id'] as String,
      status: json['status'] as String,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class EmulatorEngineStatus {
  final bool isValid;
  final String? sdkPath;
  final String? emulatorPath;
  final String? androidHome;
  final String? emulatorVersion;
  final String? avdmanagerPath;
  final String? sdkmanagerPath;
  final String? javaPath;
  final String? javaVersion;
  final bool toolchainReady;
  final String? error;
  final DateTime? lastVerified;
  final bool hasSDK;

  const EmulatorEngineStatus({
    this.isValid = false,
    this.sdkPath,
    this.emulatorPath,
    this.androidHome,
    this.emulatorVersion,
    this.avdmanagerPath,
    this.sdkmanagerPath,
    this.javaPath,
    this.javaVersion,
    this.toolchainReady = false,
    this.error,
    this.lastVerified,
    this.hasSDK = false,
  });

  factory EmulatorEngineStatus.fromJson(Map<String, dynamic> json) {
    return EmulatorEngineStatus(
      isValid: json['isValid'] as bool? ?? false,
      sdkPath: json['sdkPath'] as String?,
      emulatorPath: json['emulatorPath'] as String?,
      androidHome: json['androidHome'] as String?,
      emulatorVersion: json['emulatorVersion'] as String?,
      avdmanagerPath: json['avdmanagerPath'] as String?,
      sdkmanagerPath: json['sdkmanagerPath'] as String?,
      javaPath: json['javaPath'] as String?,
      javaVersion: json['javaVersion'] as String?,
      toolchainReady: json['toolchainReady'] as bool? ?? false,
      error: json['error'] as String?,
      lastVerified: json['lastVerified'] != null
          ? DateTime.tryParse(json['lastVerified'] as String)
          : null,
      hasSDK: json['hasSDK'] as bool? ?? false,
    );
  }
}
