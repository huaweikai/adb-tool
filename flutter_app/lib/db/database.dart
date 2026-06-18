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
//   v3 — adds test_sessions.screen_record_owner to track who initiated
//        the current screen-recording on this session's device
//        (file_browser / test_session). Indexed for the cross-screen
//        "is anyone recording" lookup.
//   v4 — moves the screen-recording state OFF test_sessions and onto
//        saved_devices itself. Reason: file_browser often runs without
//        an active test_session, so test_sessions.screen_record_owner
//        was NULL in that case and the cross-screen "is anyone
//        recording on this device?" lookup missed it. The state is
//        really per-device, not per-session. New columns on
//        saved_devices: recording_owner, recording_started_at,
//        recording_is_saving. v3's screen_record_owner column is left
//        in place for the in-flight test_sessions family but no
//        longer read by the UI. (We're formatting the DB during the
//        refactor anyway, so v3→v4 migration isn't strictly needed
//        — the onCreate path will rebuild cleanly.)
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/test_session.dart';
import 'dao/app_states_dao.dart';
import 'dao/saved_devices_dao.dart';
import 'dao/test_sessions_dao.dart';
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
  daos: [SavedDevicesDao, AppStatesDao, TestSessionsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

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
          if (from < 3) {
            // v2 → v3: add the screen-record-owner column and a
            // supporting index for the "is anyone recording on this
            // device" query.
            await m.addColumn(testSessions, testSessions.screenRecordOwner);
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_sessions_recording_owner '
              'ON test_sessions (device_serial) WHERE screen_record_owner IS NOT NULL',
            );
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
  // Partial index: "which device currently has a screen recording open"
  await customStatement(
    'CREATE INDEX IF NOT EXISTS idx_sessions_recording_owner '
    'ON test_sessions (device_serial) WHERE screen_record_owner IS NOT NULL',
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
