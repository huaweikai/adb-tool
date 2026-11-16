import 'package:adb_tool/models/device.dart';
import 'package:adb_tool/screens/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy device payload keeps the Android pages and screenshot', () {
    final device = Device.fromJson({'serial': 'adb123', 'state': 'device'});

    expect(device.platform, 'android');
    expect(device.capabilities, contains(DeviceCapability.screenshot));
    expect(NavItem.availableTo(device.capabilities),
        NavItem.values.where((item) => item != NavItem.crashReports));
  });

  test('explicit capability list limits navigation and ignores unknown names',
      () {
    final device = Device.fromJson({
      'platform': 'ios',
      'capabilities': ['files', 'screenshot', 'unrecognized'],
    });

    expect(device.capabilities,
        {DeviceCapability.files, DeviceCapability.screenshot});
    expect(NavItem.availableTo(device.capabilities), [NavItem.files]);
  });

  test('an explicit empty list disables all device entries', () {
    final device = Device.fromJson({
      'platform': 'android',
      'capabilities': <String>[],
    });

    expect(device.capabilities, isEmpty);
    expect(NavItem.availableTo(device.capabilities), isEmpty);
  });
}
