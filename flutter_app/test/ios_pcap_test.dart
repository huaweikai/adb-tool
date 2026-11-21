import 'package:adb_tool/i18n.dart';
import 'package:adb_tool/providers/device_provider.dart';
import 'package:adb_tool/screens/ios_pcap_screen.dart';
import 'package:adb_tool/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  test('IosPcapStatus.fromJson parses capture data properly', () {
    final status = IosPcapStatus.fromJson({
      'status': 'capturing',
      'active': true,
      'filePath': '/tmp/test.pcapng',
      'packets': 1234,
      'bytes': 567890,
      'duration': 12.5,
      'startTime': '2026-11-21T12:00:00Z',
      'process': 'Safari',
      'interface': 'en0',
    });

    expect(status.status, 'capturing');
    expect(status.active, isTrue);
    expect(status.isCapturing, isTrue);
    expect(status.filePath, '/tmp/test.pcapng');
    expect(status.packets, 1234);
    expect(status.bytes, 567890);
    expect(status.duration, 12.5);
    expect(status.process, 'Safari');
    expect(status.interface, 'en0');
  });

  testWidgets('IosPcapScreen displays offline state when disconnected',
      (tester) async {
    final prevLang = currentLang;
    setLang('en');
    addTearDown(() => setLang(prevLang));

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<DeviceProvider>(create: (_) => _MockDeviceProvider(false)),
        Provider<DeviceSerialScope>.value(
            value: const DeviceSerialScope('ios:PHONE-A')),
        Provider<ApiClient>.value(value: ApiClient('http://127.0.0.1:9876')),
      ],
      child: const MaterialApp(home: IosPcapScreen()),
    ));
    await tester.pump();

    expect(find.text('iPhone is offline or disconnected'), findsOneWidget);
  });

  testWidgets('IosPcapScreen displays dashboard and controls when connected',
      (tester) async {
    final prevLang = currentLang;
    setLang('en');
    addTearDown(() => setLang(prevLang));

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<DeviceProvider>(create: (_) => _MockDeviceProvider(true)),
        Provider<DeviceSerialScope>.value(
            value: const DeviceSerialScope('ios:PHONE-A')),
        Provider<ApiClient>.value(value: ApiClient('http://127.0.0.1:9876')),
      ],
      child: const MaterialApp(home: IosPcapScreen()),
    ));
    await tester.pump();

    expect(find.text('Packet Capture (PCAP)'), findsOneWidget);
    expect(find.text('Start Capture'), findsOneWidget);
    expect(find.text('Capture Filters (Optional)'), findsOneWidget);
  });
}

class _MockDeviceProvider extends ChangeNotifier implements DeviceProvider {
  final bool connected;
  _MockDeviceProvider(this.connected);

  @override
  bool isDeviceConnected(String? stableSerial) => connected && stableSerial == 'ios:PHONE-A';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
