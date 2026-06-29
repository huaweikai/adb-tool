// Regression test for the v8→v9 identity split: a wireless device
// that reconnects on a different port (a new `ip:port`) must NOT
// create a new `saved_devices` row. The same physical device —
// same `ro.serialno` — keeps its existing row, and the row's
// `address` field is updated to reflect the new adb endpoint.
//
// Also covers the upgrade path for offline legacy rows: a wireless
// row whose PK is still the old adb-serial (because the device was
// offline when the migration ran) gets its PK renamed to
// `ro.serialno` on first reconnect, with the test_sessions /
// scrcpy_options FKs updated atomically.
//
// Known limitation: a wireless device that was offline at migration
// time AND whose next reconnect lands on a brand-new `ip:port`
// (router reboot, ADB port pool rotation, ...) has no signature left
// in the DB to match it back to its old row — the old row only
// carries the previous `ip:port` and a now-stale address. In that
// case the system creates a fresh stable row, and the old legacy
// row is left behind for the user to remove. Acceptable for now;
// a stronger match (model/brand/sdk fingerprint) would risk
// merging unrelated same-model devices.
import 'package:adb_tool/db/database.dart';
import 'package:adb_tool/models/device.dart';
import 'package:adb_tool/models/scrcpy_options.dart';
import 'package:adb_tool/models/test_session.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _hw = 'R5CT70AHPDR'; // ro.serialno — stable across reconnects

Device _device({
  required String adbSerial,
  String hardwareSerial = _hw,
  String state = 'device',
}) {
  return Device(
    serial: adbSerial,
    hardwareSerial: hardwareSerial,
    state: state,
    model: 'Pixel 6',
    brand: 'Google',
    sdk: '34',
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('renamePrimaryKey (wireless offline→online upgrade path)', () {
    test('renames PK from old adb-serial to ro.serialno, updates FKs '
        'in one transaction', () async {
      // Seed: a wireless device whose row predates the v8→v9 split —
      // its PK is the old adb-serial, no ro.serialno known yet.
      // Test session + scrcpy options already reference it.
      const oldAdbSerial = '192.168.31.141:11111';
      await db.savedDevicesDao.upsertSavedDevice(
        serial: oldAdbSerial,
        model: 'Pixel 6',
        brand: 'Google',
        sdk: '34',
        isConnected: false,
        address: oldAdbSerial,
      );
      await db.testSessionsDao.insertSession(
        TestSessionsCompanion.insert(
          id: 'sess-1',
          name: 'regression',
          type: 'manual',
          status: TestSessionStatus.finished,
          startedAt: DateTime(2026, 1, 1),
          deviceSerial: oldAdbSerial,
        ),
      );
      await db.scrcpyOptionsDao.upsert(
        oldAdbSerial,
        const ScrcpyOptions(maxSize: 1024),
      );

      // ACT: device comes back online on a new port with a real
      // ro.serialno. The reconcile path does the PK rename in
      // one transaction.
      const newAdbSerial = '192.168.31.141:22222';
      await db.savedDevicesDao.renamePrimaryKey(
        oldAdbSerial,
        _hw,
        newAddress: newAdbSerial,
      );

      // POSTCONDITIONS:
      // - Old PK is gone, new PK exists with the right address.
      expect(
        await db.savedDevicesDao.getSavedDeviceBySerial(oldAdbSerial),
        isNull,
        reason: 'old adb-serial PK should be gone',
      );
      final upgraded = await db.savedDevicesDao.getSavedDeviceBySerial(_hw);
      expect(upgraded, isNotNull);
      expect(upgraded!.address, newAdbSerial,
          reason: 'address should be the new ip:port');

      // - Test session now references the new PK (FK updated).
      final sessionsAfter =
          await db.testSessionsDao.watchSessionsForDevice(_hw).first;
      expect(sessionsAfter, hasLength(1),
          reason: 'test_session should follow the PK rename');
      // - And the old PK has no orphan sessions.
      final orphanSessions =
          await db.testSessionsDao.watchSessionsForDevice(oldAdbSerial).first;
      expect(orphanSessions, isEmpty,
          reason: 'old PK should not have any sessions left');

      // - Scrcpy options follow too (they're keyed on the same PK).
      final opts = await db.scrcpyOptionsDao.getBySerial(_hw);
      expect(opts, isNotNull, reason: 'scrcpy_options should follow rename');
      final orphanOpts =
          await db.scrcpyOptionsDao.getBySerial(oldAdbSerial);
      expect(orphanOpts, isNull,
          reason: 'scrcpy_options on old PK should be gone');
    });
  });

  group('getByAddress (legacy row lookup)', () {
    test('finds a legacy wireless row by its current ip:port', () async {
      const oldAdbSerial = '192.168.31.141:33333';
      await db.savedDevicesDao.upsertSavedDevice(
        serial: oldAdbSerial,
        model: 'Pixel 6',
        brand: 'Google',
        sdk: '34',
        isConnected: true,
        address: oldAdbSerial,
      );

      final found = await db.savedDevicesDao.getByAddress(oldAdbSerial);
      expect(found, isNotNull);
      expect(found!.serial, oldAdbSerial);
    });

    test('returns null for a brand-new adb-serial', () async {
      const fresh = '192.168.31.141:44444';
      final found = await db.savedDevicesDao.getByAddress(fresh);
      expect(found, isNull);
    });
  });

  group('address update (wireless port change, post-migration)', () {
    test('updating address does not create a new row', () async {
      // First connect: insert row keyed by ro.serialno.
      await db.savedDevicesDao.upsertSavedDevice(
        serial: _hw,
        model: 'Pixel 6',
        brand: 'Google',
        sdk: '34',
        isConnected: true,
        address: '192.168.31.141:11111',
      );

      // Wireless reconnects on a new port — DeviceProvider should
      // call updateAddress with the new ip:port, NOT insert a new row.
      await db.savedDevicesDao.updateAddress(
        _hw,
        '192.168.31.141:22222',
      );

      final all = await db.savedDevicesDao.getAllSavedDevices();
      expect(all, hasLength(1),
          reason: 'port change should not produce a new saved_device row');
      expect(all.first.address, '192.168.31.141:22222',
          reason: 'address column should be the new port');
      expect(all.first.serial, _hw,
          reason: 'PK should still be the hardware serial');
    });
  });

  group('end-to-end reconcile (DeviceProvider scenarios)', () {
    test('wireless device reconnects on new port: same row, '
        'updated address, no new row', () async {
      // The user is on the app, a wireless device is connected on
      // port 11111, has been saved.
      await db.savedDevicesDao.upsertSavedDevice(
        serial: _hw,
        model: 'Pixel 6',
        brand: 'Google',
        sdk: '34',
        isConnected: true,
        address: '192.168.31.141:11111',
      );

      // Simulate DeviceProvider._reconcileOnlineDevice's case-1
      // branch: backend reports the same ro.serialno, but a new
      // adb-serial (port changed). We expect the same row to
      // remain, with the new address.
      final device = _device(adbSerial: '192.168.31.141:22222');
      // Inline the case-1 logic (without coupling to the provider,
      // to keep this a pure DAO test):
      final existing = await db.savedDevicesDao.getSavedDeviceBySerial(_hw);
      expect(existing, isNotNull);
      if (existing!.address != device.serial) {
        await db.savedDevicesDao.updateAddress(_hw, device.serial);
      }

      final all = await db.savedDevicesDao.getAllSavedDevices();
      expect(all, hasLength(1));
      expect(all.first.address, '192.168.31.141:22222');
      expect(all.first.serial, _hw);
    });

    test('legacy wireless row is upgraded when the device reconnects '
        'on the same ip:port it had before (PK rename)', () async {
      // Offline wireless device from before the migration: PK is
      // the old adb-serial, no ro.serialno known yet.
      const oldAdbSerial = '192.168.31.141:55555';
      await db.savedDevicesDao.upsertSavedDevice(
        serial: oldAdbSerial,
        model: 'Pixel 6',
        brand: 'Google',
        sdk: '34',
        isConnected: false,
        address: oldAdbSerial,
      );

      // Now it comes online on the SAME adb-serial it had before
      // (so we can't tell from the new adb-serial that it's the
      // same device), but the backend now reports the real
      // ro.serialno. DeviceProvider's case-2 branch should look it
      // up by address, then PK-rename to ro.serialno.
      final device = _device(adbSerial: oldAdbSerial);
      final legacy = await db.savedDevicesDao.getByAddress(device.serial);
      expect(legacy, isNotNull, reason: 'precondition: legacy row exists');
      expect(legacy!.serial, oldAdbSerial);

      await db.savedDevicesDao.renamePrimaryKey(
        legacy.serial,
        _hw,
        newAddress: device.serial,
      );

      final all = await db.savedDevicesDao.getAllSavedDevices();
      expect(all, hasLength(1),
          reason: 'upgrade should not create a duplicate row');
      expect(all.first.serial, _hw,
          reason: 'PK should now be the hardware serial');
      expect(all.first.address, oldAdbSerial,
          reason: 'address should still be the adb-serial');
    });

    test('brand-new wireless device: one row created', () async {
      const newHw = 'NEWDEVSERIAL42';
      const newAdb = '10.0.0.5:5555';
      final device = _device(adbSerial: newAdb, hardwareSerial: newHw);

      // No match anywhere; case-3 path creates a new row.
      final byHw = await db.savedDevicesDao.getSavedDeviceBySerial(newHw);
      final byAddr = await db.savedDevicesDao.getByAddress(newAdb);
      expect(byHw, isNull);
      expect(byAddr, isNull);

      final newSerial = device.hardwareSerial.isNotEmpty
          ? device.hardwareSerial
          : device.serial;
      await db.savedDevicesDao.upsertSavedDevice(
        serial: newSerial,
        model: device.model,
        brand: device.brand,
        sdk: device.sdk,
        isConnected: device.isOnline,
        address: device.serial,
      );

      final all = await db.savedDevicesDao.getAllSavedDevices();
      expect(all, hasLength(1));
      expect(all.first.serial, newHw);
      expect(all.first.address, newAdb);
    });
  });
}
