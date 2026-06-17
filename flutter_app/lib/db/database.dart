// Root entry for the local database.
//
// All Drift code generation lives in `database.g.dart` (next to this file)
// and is rebuilt with `dart run build_runner build`.
//
// Public usage:
//   final db = AppDatabase();                      // shared singleton via Provider
//   db.savedDevicesDao.watchAllSavedDevices();    // → Stream<List<SavedDevice>>
//   db.appStatesDao.updateAppState(...);           // patch the singleton UI-state row
//
// Schema history:
//   v1 — initial: SavedDevices, AppStates
//   v2 — adds test_sessions + children (events, artifacts, notes, issues,
//        plan_items, issue_artifacts) plus the
//        idx_one_running_per_device partial unique index.
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/test_session.dart';
import 'dao/app_states_dao.dart';
import 'dao/saved_devices_dao.dart';
import 'tables/app_states.dart';
import 'tables/saved_devices.dart';
import 'tables/test_session_artifacts.dart';
import 'tables/test_session_events.dart';
import 'tables/test_session_issue_artifacts.dart';
import 'tables/test_session_issues.dart';
import 'tables/test_session_notes.dart';
import 'tables/test_session_plan_items.dart';
import 'tables/test_sessions.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    SavedDevices,
    AppStates,
    TestSessions,
    TestSessionEvents,
    TestSessionArtifacts,
    TestSessionNotes,
    TestSessionIssues,
    TestSessionPlanItems,
    TestSessionIssueArtifacts,
  ],
  daos: [SavedDevicesDao, AppStatesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createTestSessionIndices();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v1 → v2: add the test-sessions family.
            // Order matters for FKs: parent first, then children, then m:n.
            await m.createTable(testSessions);
            await m.createTable(testSessionEvents);
            await m.createTable(testSessionArtifacts);
            await m.createTable(testSessionNotes);
            await m.createTable(testSessionIssues);
            await m.createTable(testSessionPlanItems);
            await m.createTable(testSessionIssueArtifacts);
            await _createTestSessionIndices();
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Two SQL indices that drift's table-builder can't express declaratively:
  ///   - partial unique index enforcing "at most one running session per
  ///     device" at the DB level (defence-in-depth alongside the app-level
  ///     check in TestSessionProvider.startSession)
  ///   - composite index for the Hub's "sessions for this device, newest
  ///     first" query
  Future<void> _createTestSessionIndices() async {
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_one_running_per_device '
      'ON test_sessions (device_serial) WHERE status = 0',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sessions_device_started '
      'ON test_sessions (device_serial, started_at DESC)',
    );
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
