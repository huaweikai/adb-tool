// Emulator engine configuration provider.
// Manages Android SDK emulator path detection, validation, and status.
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../db/database.dart';
import '../models/emulator_engine.dart';
import '../services/api_client.dart';

enum EngineValidationState {
  unknown,
  validating,
  valid,
  invalid,
  error,
}

class EmulatorEngineProvider extends ChangeNotifier {
  final ApiClient _api;
  final AppDatabase? _db;

  EmulatorEngineConfig _config = EmulatorEngineConfig.empty();
  EmulatorEngineStatus? _serverStatus;
  EngineValidationState _validationState = EngineValidationState.unknown;
  String? _errorMessage;
  List<SDKDetectResult> _detectedSDKs = [];
  SDKDownloadResult? _currentDownload;
  bool _isDetecting = false;
  bool _isDownloading = false;

  StreamSubscription? _statusPoller;

  EmulatorEngineProvider({required ApiClient api, AppDatabase? db})
      : _api = api,
        _db = db;

  EmulatorEngineConfig get config => _config;
  EmulatorEngineStatus? get serverStatus => _serverStatus;
  EngineValidationState get validationState => _validationState;
  String? get errorMessage => _errorMessage;
  List<SDKDetectResult> get detectedSDKs => _detectedSDKs;
  SDKDownloadResult? get currentDownload => _currentDownload;
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
  Future<List<SDKDetectResult>> detectSDKs() async {
    _isDetecting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _detectedSDKs = await _api.detectSDKs();
      notifyListeners();
      return _detectedSDKs;
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
      final status = await _api.useSDK(sdkPath);
      _serverStatus = status;
      _updateConfigFromStatus(status);

      // Persist to local DB
      await _db?.appStatesDao.updateAppState(selectedSDKPath: sdkPath);

      if (status.isValid) {
        _validationState = EngineValidationState.valid;
      } else {
        _validationState = EngineValidationState.invalid;
        _errorMessage = status.error?.isNotEmpty == true ? status.error : 'SDK 验证失败';
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[EmulatorEngineProvider] useSDK error: $e');
      _validationState = EngineValidationState.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Restore the previously selected SDK path from local DB.
  /// Call this on app startup after backend is ready.
  Future<bool> restoreFromDB() async {
    if (_db == null) return false;

    final savedPath = await _db!.appStatesDao.getSelectedSDKPath();
    if (savedPath == null || savedPath.isEmpty) return false;

    debugPrint('[EmulatorEngineProvider] Restoring SDK path from DB: $savedPath');
    await useSDK(savedPath);
    return true;
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
      _currentDownload = await _api.downloadSDK(
        url: url,
        id: id,
        name: name,
        sha256: sha256,
      );
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
      _currentDownload = await _api.checkDownloadProgress(id);
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
      _serverStatus = await _api.getEngineStatus();
      _updateConfigFromStatus(_serverStatus!);
      _validationState = _serverStatus!.isValid
          ? EngineValidationState.valid
          : EngineValidationState.invalid;
      _errorMessage = _serverStatus!.error?.isNotEmpty == true ? _serverStatus!.error : null;
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
      _serverStatus = await _api.validateEngine(
        androidHome: androidHome,
        emulatorPath: emulatorPath,
      );
      _updateConfigFromStatus(_serverStatus!);

      if (_serverStatus!.isValid) {
        _validationState = EngineValidationState.valid;
      } else {
        _validationState = EngineValidationState.invalid;
        _errorMessage = _serverStatus!.error?.isNotEmpty == true ? _serverStatus!.error : null;
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
      _serverStatus = await _api.updateEngineConfig(
        androidHome: androidHome,
        emulatorPath: emulatorPath,
      );
      _updateConfigFromStatus(_serverStatus!);

      if (_serverStatus!.isValid) {
        _validationState = EngineValidationState.valid;
      } else {
        _validationState = EngineValidationState.invalid;
        _errorMessage = _serverStatus!.error;
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
