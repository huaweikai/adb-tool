// Regression test for the saved_devices FK crash:
//
//   FOREIGN KEY constraint failed (787) when removing a device that had
//   test_sessions referencing it.
//
// Reproduces the original bug (assertion-style) and verifies the fix
// cascades sessions out before deleting the device.
import 'package:adb_tool/db/database.dart';
import 'package:adb_tool/models/test_session.dart';
import 'package:adb_tool/providers/device_provider.dart';
import 'package:adb_tool/providers/test_session_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('removeDevice cascades sessions for that device', () async {
    // Seed: one device + one session that references it.
    await db.savedDevicesDao.upsertSavedDevice(
      serial: '192.168.31.141:33729',
      model: 'Pixel-Test',
      brand: 'Google',
      sdk: '34',
      isConnected: false,
    );
    await db.testSessionsDao.insertSession(
      TestSessionsCompanion.insert(
        id: 'sess-1',
        name: 'regression test',
        type: 'manual',
        status: TestSessionStatus.finished,
        startedAt: DateTime(2026, 1, 1),
        deviceSerial: '192.168.31.141:33729',
      ),
    );

    // Sanity: session is there, device is there.
    expect(
      await db.testSessionsDao.watchSessionsForDevice(
        '192.168.31.141:33729',
      ).first,
      isNotEmpty,
      reason: 'precondition: session should exist',
    );
    expect(
      await db.savedDevicesDao.getSavedDeviceBySerial(
        '192.168.31.141:33729',
      ),
      isNotNull,
      reason: 'precondition: device should exist',
    );

    // ACT: removeDevice must NOT throw FK 787.
    await db.savedDevicesDao.deleteSavedDevice('192.168.31.141:33729');

    // POSTCONDITION: both rows gone (session cascaded by FK on the
    // test_sessions family tables, then device removed by the
    // transaction).
    expect(
      await db.savedDevicesDao.getSavedDeviceBySerial(
        '192.168.31.141:33729',
      ),
      isNull,
      reason: 'device row should be deleted',
    );
    expect(
      await db.testSessionsDao.watchSessionsForDevice(
        '192.168.31.141:33729',
      ).first,
      isEmpty,
      reason: 'session should be cascaded out by FK on child tables',
    );
  });

  test('removeDevice works for device with NO sessions (smoke)',
      () async {
    await db.savedDevicesDao.upsertSavedDevice(
      serial: 'plain-serial',
      model: 'M',
      brand: 'B',
      sdk: '34',
      isConnected: false,
    );

    await db.savedDevicesDao.deleteSavedDevice('plain-serial');

    expect(
      await db.savedDevicesDao.getSavedDeviceBySerial('plain-serial'),
      isNull,
    );
  });

  test('removing an offline iPhone preserves the active Android session',
      () async {
    const android = 'device-a';
    const iphone = 'ios:PHONE-A';
    const sessionId = 'android-session';
    await db.savedDevicesDao.upsertSavedDevice(
      serial: android,
      model: 'Android phone',
      brand: 'Google',
      sdk: '35',
      isConnected: true,
    );
    await db.savedDevicesDao.upsertSavedDevice(
      serial: iphone,
      model: 'iPhone',
      brand: 'Apple',
      sdk: '',
      isConnected: false,
    );
    await db.testSessionsDao.insertSession(TestSessionsCompanion.insert(
      id: sessionId,
      name: 'Android smoke test',
      type: 'manual',
      status: TestSessionStatus.running,
      startedAt: DateTime(2026),
      deviceSerial: android,
    ));

    final devices = DeviceProvider(db: db);
    final sessions = TestSessionProvider(db: db);
    addTearDown(devices.dispose);
    addTearDown(sessions.dispose);
    await sessions.loadHistoricalSession(sessionId);
    expect(sessions.hasRunningSession, isTrue);

    await sessions.finishRunningSessionForDevice(iphone);
    expect(await devices.removeDevice(iphone), isTrue);

    expect(await db.savedDevicesDao.getSavedDeviceBySerial(iphone), isNull);
    final remaining = await db.testSessionsDao.findSessionById(sessionId);
    expect(remaining?.status, TestSessionStatus.running);
    expect(sessions.currentSession?.id, sessionId);
  });
}
