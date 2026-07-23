import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide settings that must be available *before* the dependency
/// graph is built (the backend port feeds both [ApiClient]'s base URL
/// and [ServerLauncher]).
///
/// Only the backend listen port lives here for now. It is persisted via
/// `shared_preferences` (independent of the drift DB, so it can be read
/// in `main()` before `setupDependencies()` runs) and defaults to 9876
/// to match the Go backend's `server.DefaultListenAddr`.
class AppSettings extends ChangeNotifier {
  static const int defaultBackendPort = 9876;
  static const String _portKey = 'backend_port';
  static const String _autoStartKey = 'auto_start_backend';

  int _backendPort;
  bool _autoStartBackend = true;

  AppSettings({int backendPort = defaultBackendPort})
      : _backendPort = _clampPort(backendPort);

  int get backendPort => _backendPort;

  bool get autoStartBackend => _autoStartBackend;

  /// HTTP base URL the Flutter app uses to reach the local backend.
  String get baseUrl => 'http://127.0.0.1:$_backendPort';

  /// WebSocket URL for the device-list stream.
  String get wsUrl => 'ws://127.0.0.1:$_backendPort/ws/devices';

  static int _clampPort(int port) {
    if (port < 1 || port > 65535) return defaultBackendPort;
    return port;
  }

  /// Load persisted settings. Falls back to [defaultBackendPort] and
  /// auto-start-on-launch when nothing has been saved yet.
  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final port = prefs.getInt(_portKey) ?? defaultBackendPort;
    final autoStart = prefs.getBool(_autoStartKey);
    final settings = AppSettings(backendPort: port);
    settings._autoStartBackend = autoStart ?? true;
    return settings;
  }

  /// Persist a new backend port. Out-of-range values are clamped to the
  /// default. No-op (no notify) when the value is unchanged.
  Future<void> setPort(int port) async {
    final clamped = _clampPort(port);
    if (clamped == _backendPort) return;
    _backendPort = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_portKey, clamped);
    notifyListeners();
  }

  /// Persist the auto-start-backend-on-launch preference.
  Future<void> setAutoStartBackend(bool value) async {
    if (value == _autoStartBackend) return;
    _autoStartBackend = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoStartKey, value);
    notifyListeners();
  }
}
