import 'dart:async';
import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/database.dart';
import '../services/api_client.dart';

class DeviceSerialScope {
  final String? serial;
  const DeviceSerialScope(this.serial);
}

class DeviceScreenActiveScope {
  final bool active;
  const DeviceScreenActiveScope(this.active);
}

class DeviceProvider extends ChangeNotifier {
  List<Device> _onlineDevices = [];
  List<SavedDevice> _savedDevices = [];
  bool _online = true;
  String? _activeSerial;
  DateTime? _lastSuccessfulRefresh;

  StreamSubscription<List<SavedDevice>>? _savedDevicesSub;
  AppDatabase? _db;

  Future<void>? _refreshing;

  List<Device> get devices => _onlineDevices;
  List<SavedDevice> get savedDevices => _savedDevices;
  bool get online => _online;
  String? get activeSerial => _activeSerial;
  DateTime? get lastSuccessfulRefresh => _lastSuccessfulRefresh;

  AppDatabase get db {
    _db ??= AppDatabase();
    return _db!;
  }

  DeviceProvider({AppDatabase? db}) {
    if (db != null) _db = db;
    _init();
  }

  Future<void> _init() async {
    // Watch saved devices for changes - auto-updates when DB changes
    _savedDevicesSub = db.watchAllSavedDevices().listen((devices) {
      _savedDevices = devices;
      notifyListeners();
    });
  }

  /// Check if a device is currently connected
  bool isDeviceConnected(String serial) {
    return _onlineDevices.any((d) => d.serial == serial && d.isOnline);
  }

  void select(String? serial) {
    if (_activeSerial == serial) return;
    _activeSerial = serial;
    db.updateAppState(activeSerial: serial);
    notifyListeners();
  }

  /// Add or update a device in the saved list
  Future<void> _saveDevice(Device device) async {
    await db.upsertSavedDevice(
      serial: device.serial,
      model: device.model,
      brand: device.brand,
      sdk: device.sdk,
      isConnected: device.isOnline,
    );
  }

  /// Remove a device from saved list
  Future<void> removeDevice(String serial) async {
    await db.deleteSavedDevice(serial);
    
    // Clear selection if this was the active device
    if (_activeSerial == serial) {
      _activeSerial = null;
      await db.updateAppState(activeSerial: null);
    }
    
    notifyListeners();
  }

  Future<void> refresh(ApiClient api) {
    final running = _refreshing;
    if (running != null) return running;

    final future = _refresh(api);
    _refreshing = future;
    return future.whenComplete(() {
      if (identical(_refreshing, future)) {
        _refreshing = null;
      }
    });
  }

  Future<void> _refresh(ApiClient api) async {
    debugPrint('[DeviceProvider] _refresh start');
    try {
      final ready = await api.isReady();
      debugPrint('[DeviceProvider] isReady() -> $ready');
      if (!ready) {
        debugPrint('[DeviceProvider] isReady returned false -> markOffline');
        _markOffline();
        return;
      }

      debugPrint('[DeviceProvider] calling getDevices()...');
      final devices = await api.getDevices();
      debugPrint('[DeviceProvider] getDevices() -> ${devices.length} devices');

      // Update online devices
      _onlineDevices = devices;
      _online = true;
      _lastSuccessfulRefresh = DateTime.now();
      
      // Update saved devices connection status
      final onlineSerials = devices
          .where((d) => d.isOnline)
          .map((d) => d.serial)
          .toSet();
      
      await db.updateAllDevicesConnection(onlineSerials);
      
      // Also save any new devices that are connected
      for (final device in devices) {
        if (device.isOnline && !_savedDevices.any((d) => d.serial == device.serial)) {
          await _saveDevice(device);
        }
      }
      
      // Update last successful refresh time
      await db.updateAppState(lastSuccessfulRefresh: _lastSuccessfulRefresh);
      
      notifyListeners();
    } catch (e, st) {
      debugPrint('[DeviceProvider] _refresh EXCEPTION: $e');
      debugPrint('[DeviceProvider] STACK: $st');
      _markOffline();
    }
  }

  void _markOffline() {
    debugPrint('[DeviceProvider] _markOffline() called');
    _online = false;
    _onlineDevices = [];
    _lastSuccessfulRefresh = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _savedDevicesSub?.cancel();
    _db?.close();
    super.dispose();
  }
}
