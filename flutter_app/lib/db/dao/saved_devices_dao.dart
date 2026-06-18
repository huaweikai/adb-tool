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
  Future<void> upsertSavedDevice({
    required String serial,
    required String model,
    required String brand,
    required String sdk,
    required bool isConnected,
  }) async {
    await into(savedDevices).insertOnConflictUpdate(
      SavedDevicesCompanion.insert(
        serial: serial,
        model: model,
        brand: brand,
        sdk: sdk,
        isConnected: isConnected,
        firstSeenAt: DateTime.now(),
        lastSeenAt: Value(DateTime.now()),
      ),
    );
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
  /// serials. Flips `isConnected` and `lastSeenAt` for any device whose
  /// status differs.
  Future<void> updateAllDevicesConnection(Set<String> onlineSerials) async {
    final allDevices = await getAllSavedDevices();
    for (final device in allDevices) {
      final isOnline = onlineSerials.contains(device.serial);
      if (device.isConnected != isOnline) {
        await updateDeviceConnection(device.serial, isOnline);
      }
    }
  }

  /// Delete a saved device.
  Future<void> deleteSavedDevice(String serial) {
    return (delete(savedDevices)..where((t) => t.serial.equals(serial))).go();
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
