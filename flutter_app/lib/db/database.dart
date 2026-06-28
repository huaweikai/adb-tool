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
//   v5 — moves two previously-SharedPreferences-backed features into
//        the DB:
//          * scrcpy_options (per device)
//          * clipboard_history (global, shared across all devices)
//        on first open we wipe the corresponding SharedPreferences keys
//        (scrcpy_opts_*, clipboard_sent_history) so the two stores
//        don't drift. No data migration — fresh start by user request.
//   v7 — reserved for emulator support
//        ~/ADBToolData/test_configs.json) into the DB. One
//        test_app_configs row per app, with nested collections
//        (logcat, deep links, file paths, test texts, test flows)
//        stored as JSON-encoded TEXT columns. The "current" config
//        is the row with is_checked = 1, kept on the row itself
//        (not in a singleton settings table) so copy / delete /
//        import don't need a second table to keep in sync. On first
//        open the legacy JSON file is read once, inserted with
//        is_checked = 0, and the original `currentAppId` is
//        resolved by packageName to set is_checked = 1 on the
//        matching new row. The JSON file is then deleted so a
//        rollback to an older binary won't re-trigger the import.
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/test_session.dart';
import 'dao/app_states_dao.dart';
import 'dao/sent_clipboard_entry_dao.dart';
import 'dao/saved_devices_dao.dart';
import 'dao/scrcpy_options_dao.dart';
import 'dao/test_app_configs_dao.dart';
import 'dao/test_sessions_dao.dart';
import 'tables/app_states.dart';
import 'tables/sent_clipboard_entry.dart';
import 'tables/saved_devices.dart';
import 'tables/scrcpy_options.dart';
import 'tables/test_app_configs.dart';
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
    ScrcpyOptions_,
    SentClipboardEntry,
    TestSessions,
    TestSessionEvents,
    TestSessionArtifacts,
    TestSessionNotes,
    TestSessionIssues,
    TestSessionPlanItems,
    TestSessionIssueArtifacts,
    TestAppConfigs,
  ],
  daos: [
    SavedDevicesDao,
    AppStatesDao,
    ScrcpyOptionsDao,
    SentClipboardEntryDao,
    TestSessionsDao,
    TestAppConfigsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 8;

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
          if (from < 5) {
            await m.createTable(scrcpyOptions);
            await m.createTable(sentClipboardEntry);
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_clipboard_history_favorites '
              'ON sent_clipboard_entry (sent_at DESC) WHERE favorite = 1',
            );
          }
          if (from < 6) {
            // v5 → v6: test configs move from a JSON file into the DB.
            // The table itself is created above via createAll / addTable;
            // the actual JSON→DB transfer runs in beforeOpen (see below)
            // because it needs the AppDatabase instance to read the file
            // and is safer to retry on a fresh launch.
            await m.createTable(testAppConfigs);
          }
          if (from < 7) {
            // v6 → v7: add emulator toolchain selections (SDK and Java paths)
            await m.addColumn(appStates, appStates.selectedSDKPath);
            await m.addColumn(appStates, appStates.selectedJavaPath);
          }
          if (from < 8) {
            // v7 → v8: add sidebar UI preferences (width and collapsed state)
            await m.addColumn(appStates, appStates.sidebarWidth);
            await m.addColumn(appStates, appStates.sidebarCollapsed);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          // Any recording state left behind from an unclean exit (crash /
          // force-quit / battery pull) is now invalid — the adb-side
          // process is dead and the app has no way to recover it.
          // Clear it so the UI boots into a clean idle state.
          await customStatement(
            'UPDATE saved_devices '
            'SET recording_owner = NULL, '
            '    recording_started_at = NULL, '
            '    recording_is_saving = 0 '
            'WHERE recording_owner IS NOT NULL',
          );
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
