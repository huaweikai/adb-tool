import 'package:flutter/material.dart';
import '../models/device.dart';
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
  List<Device> _devices = [];
  bool _online = true;
  String? _activeSerial;
  Future<void>? _refreshing;

  List<Device> get devices => _devices;
  bool get online => _online;
  String? get activeSerial => _activeSerial;

  void select(String? serial) {
    if (_activeSerial != serial) {
      _activeSerial = serial;
      notifyListeners();
    }
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
    try {
      final devices = await api.getDevices();
      _devices = devices;
      _online = true;
      if (_activeSerial != null &&
          !devices.any((d) => d.serial == _activeSerial)) {
        _activeSerial = null;
      }
      notifyListeners();
    } catch (_) {
      _online = false;
      _devices = [];
      _activeSerial = null;
      notifyListeners();
    }
  }
}
