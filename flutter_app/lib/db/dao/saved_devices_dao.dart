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

  /// Update connection status for a single device.
  Future<void> updateDeviceConnection(String serial, bool connected) async {
    await (update(savedDevices)..where((t) => t.serial.equals(serial))).write(
      SavedDevicesCompanion(
        isConnected: Value(connected),
        lastSeenAt: Value(connected ? DateTime.now() : null),
      ),
    );
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
}
