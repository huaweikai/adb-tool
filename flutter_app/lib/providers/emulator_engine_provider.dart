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

class EmulatorEngineProvider extends ChangeNotifier {
  final ApiClient _api;

  EmulatorEngineConfig _config = EmulatorEngineConfig.empty();
  EmulatorEngineStatus? _serverStatus;
  EngineValidationState _validationState = EngineValidationState.unknown;
  String? _errorMessage;

  StreamSubscription? _statusPoller;

  EmulatorEngineProvider({required ApiClient api}) : _api = api;

  EmulatorEngineConfig get config => _config;
  EmulatorEngineStatus? get serverStatus => _serverStatus;
  EngineValidationState get validationState => _validationState;
  String? get errorMessage => _errorMessage;

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
