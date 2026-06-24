// Emulator engine configuration provider.
// Manages Android SDK emulator path detection, validation, and status.
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/emulator_engine.dart';
import '../services/api_client.dart';

enum EngineValidationState {
  unknown,
  validating,
  valid,
  invalid,
  error,
}

/// Represents a detected Android SDK on the system.
class DetectedSDK {
  final String path;
  final String name;
  final bool hasEmulator;
  final bool hasAvdmanager;
  final bool hasJava;
  final String? version;

  DetectedSDK({
    required this.path,
    required this.name,
    required this.hasEmulator,
    required this.hasAvdmanager,
    required this.hasJava,
    this.version,
  });

  factory DetectedSDK.fromJson(Map<String, dynamic> json) {
    return DetectedSDK(
      path: json['path'] as String,
      name: json['name'] as String,
      hasEmulator: json['hasEmulator'] as bool? ?? false,
      hasAvdmanager: json['hasAvdmanager'] as bool? ?? false,
      hasJava: json['hasJava'] as bool? ?? false,
      version: json['version'] as String?,
    );
  }
}

/// Represents an SDK download.
class SDKDownload {
  final String id;
  final String status;
  final double progress;

  SDKDownload({
    required this.id,
    required this.status,
    required this.progress,
  });

  factory SDKDownload.fromJson(Map<String, dynamic> json) {
    return SDKDownload(
      id: json['id'] as String,
      status: json['status'] as String,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class EmulatorEngineProvider extends ChangeNotifier {
  final ApiClient _api;

  EmulatorEngineConfig _config = EmulatorEngineConfig.empty();
  EmulatorEngineStatus? _serverStatus;
  EngineValidationState _validationState = EngineValidationState.unknown;
  String? _errorMessage;
  List<DetectedSDK> _detectedSDKs = [];
  SDKDownload? _currentDownload;
  bool _isDetecting = false;
  bool _isDownloading = false;

  StreamSubscription? _statusPoller;

  EmulatorEngineProvider({required ApiClient api}) : _api = api;

  EmulatorEngineConfig get config => _config;
  EmulatorEngineStatus? get serverStatus => _serverStatus;
  EngineValidationState get validationState => _validationState;
  String? get errorMessage => _errorMessage;
  List<DetectedSDK> get detectedSDKs => _detectedSDKs;
  SDKDownload? get currentDownload => _currentDownload;
  bool get isDetecting => _isDetecting;
  bool get isDownloading => _isDownloading;

  bool get isValid =>
      _serverStatus?.isValid == true || _config.isValid;

  bool get isReady => isValid;

  /// Start polling server status periodically
  void startPolling({Duration interval = const Duration(seconds: 5)}) {
    _statusPoller?.cancel();
    _statusPoller = Stream.periodic(interval).listen((_) => refreshStatus());
  }

  void stopPolling() {
    _statusPoller?.cancel();
    _statusPoller = null;
  }

  /// Detect SDKs on the system
  Future<List<DetectedSDK>> detectSDKs() async {
    _isDetecting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.dio.get('/api/emulator/sdk/detect');
      final sdks = (response.data['sdks'] as List?)
              ?.map((e) => DetectedSDK.fromJson(e))
              .toList() ??
          [];
      _detectedSDKs = sdks;
      notifyListeners();
      return sdks;
    } catch (e) {
      debugPrint('[EmulatorEngineProvider] detectSDKs error: $e');
      _errorMessage = '检测失败: $e';
      notifyListeners();
      return [];
    } finally {
      _isDetecting = false;
      notifyListeners();
    }
  }

  /// Use a detected SDK path
  Future<void> useSDK(String sdkPath) async {
    _validationState = EngineValidationState.validating;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.dio.post('/api/emulator/sdk/use', data: {
        'sdkPath': sdkPath,
      });

      final status = EmulatorEngineStatus.fromJson(response.data);
      _serverStatus = status;
      _updateConfigFromStatus(status);

      if (status.isValid) {
        _validationState = EngineValidationState.valid;
      } else {
        _validationState = EngineValidationState.invalid;
        _errorMessage = status.error ?? 'SDK 验证失败';
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[EmulatorEngineProvider] useSDK error: $e');
      _validationState = EngineValidationState.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Download SDK from URL
  Future<void> downloadSDK({
    required String url,
    required String id,
    required String name,
    String? sha256,
  }) async {
    _isDownloading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.dio.post('/api/emulator/sdk/download', data: {
        'url': url,
        'id': id,
        'name': name,
        if (sha256 != null) 'sha256': sha256,
      });

      _currentDownload = SDKDownload.fromJson(response.data);
      notifyListeners();
    } catch (e) {
      debugPrint('[EmulatorEngineProvider] downloadSDK error: $e');
      _errorMessage = '下载失败: $e';
      notifyListeners();
    }
  }

  /// Check download progress
  Future<void> checkDownloadProgress(String id) async {
    try {
      final response =
          await _api.dio.get('/api/emulator/download/progress', queryParameters: {'id': id});
      _currentDownload = SDKDownload.fromJson(response.data);
      notifyListeners();

      // If completed, refresh status
      if (_currentDownload?.status == 'completed') {
        await refreshStatus();
      }
    } catch (e) {
      debugPrint('[EmulatorEngineProvider] checkDownloadProgress error: $e');
    }
  }

  /// Refresh engine status from backend
  Future<void> refreshStatus() async {
    try {
      final status = await _api.getEngineStatus();
      _serverStatus = status;
      _updateConfigFromStatus(status);
      _validationState = status.isValid
          ? EngineValidationState.valid
          : EngineValidationState.invalid;
      _errorMessage = status.error;
      notifyListeners();
    } catch (e) {
      debugPrint('[EmulatorEngineProvider] refreshStatus error: $e');
      _validationState = EngineValidationState.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Validate emulator path (either androidHome or emulatorPath)
  Future<void> validate({
    String? androidHome,
    String? emulatorPath,
  }) async {
    _validationState = EngineValidationState.validating;
    _errorMessage = null;
    notifyListeners();

    try {
      final status = await _api.validateEngine(
        androidHome: androidHome,
        emulatorPath: emulatorPath,
      );
      _serverStatus = status;
      _updateConfigFromStatus(status);

      if (status.isValid) {
        _validationState = EngineValidationState.valid;
      } else {
        _validationState = EngineValidationState.invalid;
        _errorMessage = status.error ?? 'Emulator validation failed';
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[EmulatorEngineProvider] validate error: $e');
      _validationState = EngineValidationState.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Update engine configuration
  Future<void> updateConfig({
    String? androidHome,
    String? emulatorPath,
  }) async {
    try {
      final status = await _api.updateEngineConfig(
        androidHome: androidHome,
        emulatorPath: emulatorPath,
      );
      _serverStatus = status;
      _updateConfigFromStatus(status);

      if (status.isValid) {
        _validationState = EngineValidationState.valid;
      } else {
        _validationState = EngineValidationState.invalid;
        _errorMessage = status.error;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[EmulatorEngineProvider] updateConfig error: $e');
      _validationState = EngineValidationState.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void _updateConfigFromStatus(EmulatorEngineStatus status) {
    _config = EmulatorEngineConfig(
      id: 'default',
      androidHome: status.androidHome,
      emulatorPath: status.emulatorPath ?? '',
      avdmanagerPath: status.avdmanagerPath,
      sdkmanagerPath: status.sdkmanagerPath,
      javaPath: status.javaPath,
      javaVersion: status.javaVersion,
      emulatorVersion: status.emulatorVersion,
      isValid: status.isValid,
      toolchainReady: status.toolchainReady,
      lastVerified: status.lastVerified,
    );
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
