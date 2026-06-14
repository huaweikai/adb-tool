import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/api_client.dart';

class DeviceSerialScope {
  final String? serial;

  const DeviceSerialScope(this.serial);
}

class DeviceProvider extends ChangeNotifier {
  List<Device> _devices = [];
  bool _online = true;
  String? _activeSerial;

  List<Device> get devices => _devices;
  bool get online => _online;
  String? get activeSerial => _activeSerial;

  void select(String? serial) {
    if (_activeSerial != serial) {
      _activeSerial = serial;
      notifyListeners();
    }
  }

  Future<void> refresh(ApiClient api) async {
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
