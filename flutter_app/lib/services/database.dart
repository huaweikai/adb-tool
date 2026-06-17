import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

part 'database.g.dart';

/// Extension to add displayName to SavedDevice
extension SavedDeviceExtension on SavedDevice {
  String get displayName {
    if (model.isNotEmpty) return model;
    if (brand.isNotEmpty) return brand;
    return serial;
  }
}

/// Saved devices table - persists device info across app restarts
class SavedDevices extends Table {
  TextColumn get serial => text()();
  TextColumn get model => text()();
  TextColumn get brand => text()();
  TextColumn get sdk => text()();
  BoolColumn get isConnected => boolean()();
  DateTimeColumn get firstSeenAt => dateTime()();
  DateTimeColumn get lastSeenAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {serial};
}

/// App state table - stores UI state
class AppStates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get activeSerial => text().nullable()();
  TextColumn get activeKey => text().nullable()();
  TextColumn get expandedSerials => text()(); // JSON array
  DateTimeColumn get lastSuccessfulRefresh => dateTime().nullable()();
  TextColumn get currentSessionId => text().nullable()();
  TextColumn get recentSessionIds => text()(); // JSON array
}

@DriftDatabase(tables: [SavedDevices, AppStates])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // ── SavedDevices DAO ──────────────────────────────────────

  /// Watch all saved devices - auto-updates when data changes
  Stream<List<SavedDevice>> watchAllSavedDevices() {
    return select(savedDevices).watch();
  }

  /// Get all saved devices
  Future<List<SavedDevice>> getAllSavedDevices() {
    return select(savedDevices).get();
  }

  /// Get a single device by serial
  Future<SavedDevice?> getSavedDeviceBySerial(String serial) {
    return (select(savedDevices)..where((t) => t.serial.equals(serial)))
        .getSingleOrNull();
  }

  /// Insert or update a saved device
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

  /// Update connection status for a device
  Future<void> updateDeviceConnection(String serial, bool connected) async {
    await (update(savedDevices)..where((t) => t.serial.equals(serial))).write(
      SavedDevicesCompanion(
        isConnected: Value(connected),
        lastSeenAt: Value(connected ? DateTime.now() : null),
      ),
    );
  }

  /// Update all devices connection status
  Future<void> updateAllDevicesConnection(Set<String> onlineSerials) async {
    final allDevices = await getAllSavedDevices();
    for (final device in allDevices) {
      final isOnline = onlineSerials.contains(device.serial);
      if (device.isConnected != isOnline) {
        await updateDeviceConnection(device.serial, isOnline);
      }
    }
  }

  /// Delete a saved device
  Future<void> deleteSavedDevice(String serial) {
    return (delete(savedDevices)..where((t) => t.serial.equals(serial))).go();
  }

  // ── AppState DAO ─────────────────────────────────────────

  /// Get or create app state (singleton)
  Future<AppState> getAppState() async {
    final states = await select(appStates).get();
    if (states.isEmpty) {
      final id = await into(appStates).insert(
        AppStatesCompanion.insert(
          expandedSerials: '[]',
          recentSessionIds: '[]',
        ),
      );
      return (select(appStates)..where((t) => t.id.equals(id))).getSingle();
    }
    return states.first;
  }

  /// Watch app state changes
  Stream<AppState?> watchAppState() {
    return (select(appStates)..limit(1)).watchSingleOrNull();
  }

  /// Update app state
  Future<void> updateAppState({
    String? activeSerial,
    String? activeKey,
    List<String>? expandedSerials,
    DateTime? lastSuccessfulRefresh,
    String? currentSessionId,
    List<String>? recentSessionIds,
  }) async {
    final state = await getAppState();
    await (update(appStates)..where((t) => t.id.equals(state.id))).write(
      AppStatesCompanion(
        activeSerial: activeSerial != null ? Value(activeSerial) : const Value.absent(),
        activeKey: activeKey != null ? Value(activeKey) : const Value.absent(),
        expandedSerials: expandedSerials != null
            ? Value(_listToJson(expandedSerials))
            : const Value.absent(),
        lastSuccessfulRefresh: lastSuccessfulRefresh != null
            ? Value(lastSuccessfulRefresh)
            : const Value.absent(),
        currentSessionId: currentSessionId != null
            ? Value(currentSessionId)
            : const Value.absent(),
        recentSessionIds: recentSessionIds != null
            ? Value(_listToJson(recentSessionIds))
            : const Value.absent(),
      ),
    );
  }

  String _listToJson(List<String> list) {
    return '[${list.map((s) => '"$s"').join(',')}]';
  }

  List<String> _jsonToList(String json) {
    if (json.isEmpty || json == '[]') return [];
    final content = json.substring(1, json.length - 1);
    if (content.isEmpty) return [];
    return content.split(',').map((s) => s.trim().replaceAll('"', '')).toList();
  }

  /// Get expanded serials
  Future<List<String>> getExpandedSerials() async {
    final state = await getAppState();
    return _jsonToList(state.expandedSerials);
  }

  /// Get active key
  Future<String?> getActiveKey() async {
    final state = await getAppState();
    return state.activeKey;
  }

  /// Get active serial
  Future<String?> getActiveSerial() async {
    final state = await getAppState();
    return state.activeSerial;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationSupportDirectory();
    final file = File(p.join(dbFolder.path, 'adb_tool.db'));
    debugPrint('[DB] Opening database at ${file.path}');
    return NativeDatabase.createInBackground(file);
  });
}
