// DAO for SavedDevices.
//
// Uses drift's @UseDao pattern: drift_dev generates `_$SavedDevicesDaoMixin`
// which exposes the table objects so we can call `select(savedDevices)`
// inside DAO methods without manual casts.
//
// Usage:
//   final db = AppDatabase();
//   db.savedDevicesDao.watchAllSavedDevices();
import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/saved_devices.dart';

part 'saved_devices_dao.g.dart';

@DriftAccessor(tables: [SavedDevices])
class SavedDevicesDao extends DatabaseAccessor<AppDatabase>
    with _$SavedDevicesDaoMixin {
  SavedDevicesDao(super.db);

  /// Watch all saved devices - auto-updates when data changes.
  Stream<List<SavedDevice>> watchAllSavedDevices() {
    return select(savedDevices).watch();
  }

  /// Get all saved devices (one-shot).
  Future<List<SavedDevice>> getAllSavedDevices() {
    return select(savedDevices).get();
  }

  /// Get a single device by serial.
  Future<SavedDevice?> getSavedDeviceBySerial(String serial) {
    return (select(savedDevices)..where((t) => t.serial.equals(serial)))
        .getSingleOrNull();
  }

  /// Insert or update a saved device. First-seen timestamp is only set on
  /// the initial insert; last-seen is refreshed on every call.
  ///
  /// [serial] is the stable identity (ro.serialno). [address] is the
  /// current adb address (ip:port for wireless, may be empty for USB or
  /// a brand-new device before the backend has reported props). When
  /// [address] is provided, both `serial` and `address` are stored /
  /// refreshed.
  Future<void> upsertSavedDevice({
    required String serial,
    required String model,
    required String brand,
    required String sdk,
    required bool isConnected,
    String? address,
  }) async {
    await into(savedDevices).insertOnConflictUpdate(
      SavedDevicesCompanion.insert(
        serial: serial,
        address: Value(address),
        model: model,
        brand: brand,
        sdk: sdk,
        isConnected: isConnected,
        firstSeenAt: DateTime.now(),
        lastSeenAt: Value(DateTime.now()),
      ),
    );
  }

  /// Look up a saved device by its current adb address (the
  /// `ip:port` style value `GET /api/devices` returns in the
  /// `serial` field). Used by the reconcile path to find a
  /// legacy row whose PK is still the old adb-serial — for
  /// wireless devices that predate the v8→v9 identity split,
  /// `saved_devices.serial` and `saved_devices.address` both
  /// point at the old `ip:port` until the device next reconnects
  /// and the PK is upgraded to ro.serialno.
  Future<SavedDevice?> getByAddress(String address) {
    return (select(savedDevices)..where((t) => t.address.equals(address)))
        .getSingleOrNull();
  }

  /// Update the adb address (ip:port) for a device row, without
  /// touching anything else. Called when a wireless device
  /// reconnects on a new port but its ro.serialno hasn't changed
  /// (the common case once the v8→v9 identity split is in effect
  /// — `serial` is already ro.serialno, only `address` needs
  /// refreshing).
  Future<void> updateAddress(String serial, String? address) async {
    await (update(savedDevices)..where((t) => t.serial.equals(serial))).write(
      SavedDevicesCompanion(
        address: Value(address),
        lastSeenAt: Value(DateTime.now()),
      ),
    );
  }

  /// Atomically rename a device's PK from [oldSerial] (the
  /// legacy adb-serial) to [newSerial] (the freshly-fetched
  /// ro.serialno), cascading the rename to every child table
  /// whose FK points at `saved_devices.serial`. SQLite doesn't
  /// auto-update FK references on a primary-key change, so we
  /// have to do it explicitly.
  ///
  /// On the v8→v9 migration path this is called when an
  /// offline wireless device comes back online for the first
  /// time: its old row has `serial = <old ip:port>`, the
  /// backend now reports `hardwareSerial = <real ro.serialno>`,
  /// and the reconcile logic needs the PK (and every
  /// `test_sessions.deviceSerial` / `scrcpy_options.serial`
  /// reference) to flip to the new stable identity in one go.
  ///
  /// All four writes run inside the same `transaction(...)` —
  /// if any step fails the whole rename rolls back and the
  /// row keeps its old identity. The trick: SQLite would
  /// raise FK 787 if we tried to UPDATE the parent's PK while
  /// the child rows still pointed at the old value (or
  /// vice-versa). The safe order is "add new → migrate
  /// children → drop old": insert the row under the new PK
  /// first, then UPDATE the child FKs to follow, then DELETE
  /// the legacy row. The DB-level UNIQUE index on the PK
  /// ensures we never have two rows with the same identity
  /// visible at the same time.
  Future<void> renamePrimaryKey(String oldSerial, String newSerial,
      {String? newAddress}) async {
    if (oldSerial == newSerial) return; // nothing to do
    await transaction(() async {
      // Step 1: read the legacy row so we can copy its
      // display fields onto the new row.
      final legacy = await (select(savedDevices)
            ..where((t) => t.serial.equals(oldSerial)))
          .getSingleOrNull();
      if (legacy == null) return; // nothing to rename

      // Step 2: insert a new row with the new PK, copying
      // display fields. The legacy row still exists with
      // its old PK — the unique PK index would have rejected
      // any direct UPDATE to oldSerial's PK to the same
      // value (it doesn't, but logically we want the new row
      // to be a clean copy under the new identity, not a
      // partial rewrite of the old one).
      await into(savedDevices).insert(
        SavedDevicesCompanion.insert(
          serial: newSerial,
          address: Value(newAddress ?? legacy.address),
          model: legacy.model,
          brand: legacy.brand,
          sdk: legacy.sdk,
          isConnected: legacy.isConnected,
          firstSeenAt: legacy.firstSeenAt,
          lastSeenAt: Value(DateTime.now()),
        ),
      );

      // Step 3: migrate the child FKs to follow the new
      // PK. Both child tables have `references(SavedDevices,
      // #serial)` declared on their `serial` / `deviceSerial`
      // column, so the new row satisfies them.
      await db.customStatement(
        'UPDATE test_sessions SET device_serial = ? WHERE device_serial = ?',
        [newSerial, oldSerial],
      );
      await db.customStatement(
        'UPDATE scrcpy_options SET serial = ? WHERE serial = ?',
        [newSerial, oldSerial],
      );

      // Step 4: drop the legacy row. Children have already
      // moved to the new PK, so this delete is clean.
      await (delete(savedDevices)..where((t) => t.serial.equals(oldSerial)))
          .go();
    });
  }

  /// Update connection status for a single device. When a device
  /// disconnects, any in-flight recording state is also cleared —
  /// the adb-side process is dead and we can't recover it.
  Future<void> updateDeviceConnection(String serial, bool connected) async {
    await (update(savedDevices)..where((t) => t.serial.equals(serial))).write(
      SavedDevicesCompanion(
        isConnected: Value(connected),
        lastSeenAt: Value(connected ? DateTime.now() : null),
      ),
    );
    if (!connected) {
      await clearScreenRecord(serial);
    }
  }

  /// Reconcile all stored devices with a fresh list of currently-online
  /// stable identities. Legacy rows keyed by adb serial also match the same
  /// value until they can be upgraded during online reconciliation.
  Future<void> updateAllDevicesConnection(Set<String> onlineSerials) async {
    final allDevices = await getAllSavedDevices();
    for (final device in allDevices) {
      final isOnline = onlineSerials.contains(device.serial);
      if (device.isConnected != isOnline) {
        await updateDeviceConnection(device.serial, isOnline);
      }
    }
  }

  /// Delete a saved device. Also drops:
  ///   - the device's scrcpy config (so we don't leave orphans in
  ///     `scrcpy_options_`)
  ///   - every test session for this device (so the saved_devices.serial
  ///     FK from test_sessions is satisfied)
  ///
  /// Both cascades are enforced at the app layer because drift_dev
  /// 2.34's parser can't express cross-table `references(...)` in the
  /// schema — see `tables/scrcpy_options.dart` and the comment on
  /// `TestSessions.deviceSerial`. Wrapped in a transaction so a
  /// failure in any step rolls everything back.
  Future<void> deleteSavedDevice(String serial) async {
    await transaction(() async {
      await db.scrcpyOptionsDao.deleteBySerial(serial);
      await db.testSessionsDao.deleteSessionsForDevice(serial);
      await (delete(savedDevices)..where((t) => t.serial.equals(serial))).go();
    });
  }

  // ===== Screen-recording state (per device) =============================
  //
  // The recording state lives on the device row so the file-browser and
  // test-session screens can both subscribe to a single `watchBySerial`
  // stream and stay in sync without an in-memory service. The
  // file-browser in particular often runs without an active test
  // session, so per-session state would not cover that case.

  /// Watch a single device row — emits whenever any column on that
  /// device changes (incl. the recording_* fields). Returns null
  /// when the device has never been seen.
  Stream<SavedDevice?> watchBySerial(String serial) {
    return (select(savedDevices)..where((t) => t.serial.equals(serial)))
        .watchSingleOrNull();
  }

  /// One-shot read for a single device. Useful from non-UI code paths
  /// that need to peek the recording state without subscribing.
  Future<SavedDevice?> getBySerial(String serial) {
    return (select(savedDevices)..where((t) => t.serial.equals(serial)))
        .getSingleOrNull();
  }

  /// Stamp the device as the owner of a new in-flight screen
  /// recording. Records the owner (file_browser / test_session) and
  /// the wall-clock start time so the UI can compute elapsed seconds
  /// without a per-second DB write. `isSaving` defaults to false.
  Future<void> setScreenRecord(
    String serial, {
    required String owner,
    required int startedAtMs,
  }) async {
    await (update(savedDevices)..where((t) => t.serial.equals(serial))).write(
      SavedDevicesCompanion(
        recordingOwner: Value(owner),
        recordingStartedAt: Value(startedAtMs),
        recordingIsSaving: const Value(false),
      ),
    );
  }

  /// Flip the saving flag on an existing recording. Used by the stop
  /// path to mark "we are pulling the video back from the device" so
  /// the UI can show a "保存中..." spinner while the bytes make their
  /// way off the phone.
  Future<void> setScreenRecordSaving(String serial, bool saving) async {
    await (update(savedDevices)..where((t) => t.serial.equals(serial))).write(
      SavedDevicesCompanion(
        recordingIsSaving: Value(saving),
      ),
    );
  }

  /// Drop the recording state for a device. Called on stop / failure /
  /// abandon so the cross-screen "is anyone recording?" lookup
  /// returns idle.
  Future<void> clearScreenRecord(String serial) async {
    await (update(savedDevices)..where((t) => t.serial.equals(serial))).write(
      SavedDevicesCompanion(
        recordingOwner: const Value(null),
        recordingStartedAt: const Value(null),
        recordingIsSaving: const Value(false),
      ),
    );
  }
}
