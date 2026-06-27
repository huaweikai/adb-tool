// Emulator engine API - validate and configure Android SDK emulator.
import 'package:adb_tool/services/api_client.dart';

mixin EmulatorApi on ApiBase {
  /// Get current emulator engine status (paths, versions, validation state).
  Future<EmulatorEngineStatus> getEngineStatus() async {
    final response = await dio.get('/api/emulator/engine/status');
    // Fix (code-review B10): validate the envelope before parsing. Without
    // this, a `{ok:false, error:"…"}` body is silently parsed as a default
    // EmulatorEngineStatus and the user sees a misleading "no SDK" state
    // instead of the real backend error.
    if (!isOk(response)) throw Exception(errorMessage(response));
    return EmulatorEngineStatus.fromJson(responseMap(response));
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
    if (!isOk(response)) throw Exception(errorMessage(response));
    return EmulatorEngineStatus.fromJson(responseMap(response));
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
    if (!isOk(response)) throw Exception(errorMessage(response));
    return EmulatorEngineStatus.fromJson(responseMap(response));
  }

  /// Detect SDKs on the system.
  Future<List<SDKDetectResult>> detectSDKs() async {
    final response = await dio.get('/api/emulator/sdk/detect');
    if (!isOk(response)) throw Exception(errorMessage(response));
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
    if (!isOk(response)) throw Exception(errorMessage(response));
    return EmulatorEngineStatus.fromJson(responseMap(response));
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
    if (!isOk(response)) throw Exception(errorMessage(response));
    return SDKDownloadResult.fromJson(responseMap(response));
  }

  /// Check download progress.
  Future<SDKDownloadResult> checkDownloadProgress(String id) async {
    final response = await dio.get(
      '/api/emulator/download/progress',
      queryParameters: {'id': id},
    );
    if (!isOk(response)) throw Exception(errorMessage(response));
    return SDKDownloadResult.fromJson(responseMap(response));
  }

  /// Start an sdkmanager-driven install of one or more packages (e.g.
  /// `["emulator"]` or `["emulator", "platform-tools",
  /// "system-images;android-33;google_apis_playstore;arm64-v8a"]`).
  /// Returns immediately with a job ID — poll [getInstallStatus] for
  /// progress.
  Future<SDKInstallJob> installPackages(List<String> packages) async {
    final response = await dio.post(
      '/api/emulator/sdk/install',
      data: {'packages': packages},
    );
    if (!isOk(response)) throw Exception(errorMessage(response));
    return SDKInstallJob.fromJson(responseMap(response));
  }

  /// Poll an in-flight install job's status.
  Future<SDKInstallJob> getInstallStatus(String id) async {
    final response = await dio.get(
      '/api/emulator/sdk/install/status',
      queryParameters: {'id': id},
    );
    if (!isOk(response)) throw Exception(errorMessage(response));
    return SDKInstallJob.fromJson(responseMap(response));
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
      path: json['path'] as String? ?? '',
      name: json['name'] as String? ?? '',
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
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
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
  final String? selectedSDKPath;
  final bool selectedSDKInvalid;

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
    this.selectedSDKPath,
    this.selectedSDKInvalid = false,
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
      lastVerified: _parseNullableDate(json['lastVerified']),
      hasSDK: json['hasSDK'] as bool? ?? false,
      selectedSDKPath: json['selectedSDKPath'] as String?,
      selectedSDKInvalid: json['selectedSDKInvalid'] as bool? ?? false,
    );
  }
}

/// Progress of an sdkmanager-driven install job.
class SDKInstallJob {
  final String id;
  final List<String> packages;
  final String status; // pending, running, completed, error
  final double progress;
  final String message;
  final List<String> outputTail;
  final String? error;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  const SDKInstallJob({
    required this.id,
    required this.packages,
    required this.status,
    required this.progress,
    required this.message,
    this.outputTail = const [],
    this.error,
    this.startedAt,
    this.finishedAt,
  });

  factory SDKInstallJob.fromJson(Map<String, dynamic> json) {
    return SDKInstallJob(
      id: json['id'] as String? ?? '',
      packages: (json['packages'] as List?)
              ?.map((e) => e as String? ?? '')
              .where((s) => s.isNotEmpty)
              .toList() ??
          const [],
      status: json['status'] as String? ?? 'pending',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      message: json['message'] as String? ?? '',
      outputTail: (json['outputTail'] as List?)
              ?.map((e) => e as String? ?? '')
              .toList() ??
          const [],
      error: json['error'] as String?,
      startedAt: _parseNullableDate(json['startedAt']),
      finishedAt: _parseNullableDate(json['finishedAt']),
    );
  }

  bool get isRunning => status == 'pending' || status == 'running';
  bool get isDone => status == 'completed' || status == 'error';
}

/// Parses a backend timestamp into a [DateTime] without throwing when the
/// field is missing, null, or not a string. Centralizes what used to be
/// `json['foo'] != null ? DateTime.tryParse(json['foo'] as String) : null`
/// at three different call sites (m8 review item: avoid `as String` casts
/// that blow up on unexpected wire types).
DateTime? _parseNullableDate(Object? raw) {
  if (raw is! String) return null;
  return DateTime.tryParse(raw);
}
