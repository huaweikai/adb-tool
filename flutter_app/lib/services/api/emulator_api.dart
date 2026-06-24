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
