import 'package:adb_tool/db/database.dart';
import 'package:adb_tool/i18n.dart';
import 'package:adb_tool/models/test_session.dart';
import 'package:adb_tool/providers/device_provider.dart';
import 'package:adb_tool/providers/test_config_provider.dart';
import 'package:adb_tool/providers/test_session_provider.dart';
import 'package:adb_tool/screens/test_session/test_session_hub_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('refreshes test session hub when device serial changes',
      (tester) async {
    setLang('en');
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final sessionProvider = TestSessionProvider(db: db);
    final testConfigProvider = TestConfigProvider();

    addTearDown(() async {
      sessionProvider.dispose();
      testConfigProvider.dispose();
      await db.close();
    });

    await db.into(db.savedDevices).insert(SavedDevicesCompanion.insert(
          serial: 'device-a',
          model: 'Device A',
          brand: 'brand',
          sdk: '35',
          isConnected: true,
          firstSeenAt: DateTime(2026),
        ));
    await db.into(db.savedDevices).insert(SavedDevicesCompanion.insert(
          serial: 'device-b',
          model: 'Device B',
          brand: 'brand',
          sdk: '35',
          isConnected: false,
          firstSeenAt: DateTime(2026),
        ));
    await db.into(db.testSessions).insert(TestSessionsCompanion.insert(
          id: 'session-a',
          name: 'A history session',
          type: 'Smoke',
          status: TestSessionStatus.finished,
          startedAt: DateTime(2026, 1, 1, 10),
          endedAt: Value(DateTime(2026, 1, 1, 11)),
          deviceSerial: 'device-a',
        ));

    Future<void> pumpHub(String serial) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppDatabase>.value(value: db),
            ChangeNotifierProvider<TestSessionProvider>.value(
                value: sessionProvider),
            ChangeNotifierProvider<TestConfigProvider>.value(
                value: testConfigProvider),
            Provider<DeviceSerialScope>.value(value: DeviceSerialScope(serial)),
          ],
          child: const MaterialApp(home: TestSessionHubScreen()),
        ),
      );
      await tester.pump();
    }

    await pumpHub('device-a');
    expect(find.text('A history session'), findsOneWidget);

    await pumpHub('device-b');
    expect(find.text('A history session'), findsNothing);
    expect(find.text('No history sessions'), findsOneWidget);
  });
}
