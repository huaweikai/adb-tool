// Mixin for per-device screens that auto-reload data when the device
// transitions from offline to online. Screens that load data once in
// initState and have no poll timer can add this to automatically
// re-fetch when the device comes back.
//
// Usage:
//   1. Add `with DeviceReconnectMixin` to the State class
//   2. Implement `reconnectSerial` (usually returns context.read<DeviceSerialScope>().serial)
//   3. Implement `onDeviceReconnected()` to reload data
//
// The mixin hooks into initState / dispose via super chain — existing
// initState / dispose overrides that call super.* will chain through
// this mixin automatically.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/device_provider.dart';

mixin DeviceReconnectMixin<T extends StatefulWidget> on State<T> {
  bool _dmWasConnected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _dmWasConnected = context
          .read<DeviceProvider>()
          .isDeviceConnected(reconnectSerial ?? '');
      context.read<DeviceProvider>().addListener(_dmOnDeviceChange);
    });
  }

  /// The stable device serial for the screen this mixin is attached to.
  /// Usually returns `context.read<DeviceSerialScope>().serial`.
  String? get reconnectSerial;

  /// Called when the device transitions from offline to online.
  /// The screen should reload its data here.
  void onDeviceReconnected();

  void _dmOnDeviceChange() {
    if (!mounted) return;
    final s = reconnectSerial;
    if (s == null) return;
    final dp = context.read<DeviceProvider>();
    final connected = dp.isDeviceConnected(s);
    if (connected && !_dmWasConnected) {
      onDeviceReconnected();
    }
    _dmWasConnected = connected;
  }

  @override
  void dispose() {
    context.read<DeviceProvider>().removeListener(_dmOnDeviceChange);
    super.dispose();
  }
}
