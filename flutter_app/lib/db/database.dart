// Root entry for the local database.
//
// All Drift code generation lives in `database.g.dart` (next to this file)
// and is rebuilt with `dart run build_runner build`.
//
// Public usage:
//   final db = AppDatabase();                      // shared singleton via Provider
//   db.savedDevicesDao.watchAllSavedDevices();    // → Stream<List<SavedDevice>>
//   db.appStatesDao.updateAppState(...);           // patch the singleton UI-state row
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'dao/app_states_dao.dart';
import 'dao/saved_devices_dao.dart';
import 'tables/app_states.dart';
import 'tables/saved_devices.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [SavedDevices, AppStates],
  daos: [SavedDevicesDao, AppStatesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        // Defensive: if a future bump adds a new table, this is where we'd
        // backfill data. For now there are no migrations to run.
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationSupportDirectory();
    final file = File(p.join(dbFolder.path, 'adb_tool.db'));
    debugPrint('[DB] Opening database at ${file.path}');
    return NativeDatabase.createInBackground(file);
  });
}

// ── Cross-table extensions ───────────────────────────────────────────────

/// UI-facing display name for the device. Prefers `model` (e.g. "Pixel 6"),
/// falls back to `brand`, then to `serial` for unknown devices.
extension SavedDeviceExtension on SavedDevice {
  String get displayName {
    if (model.isNotEmpty) return model;
    if (brand.isNotEmpty) return brand;
    return serial;
  }
}
