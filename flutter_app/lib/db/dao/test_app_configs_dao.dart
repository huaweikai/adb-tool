// DAO for the test_app_configs table.
//
// One row per TestAppConfig. Nested collections (logcat / deep links /
// file paths / test texts / test flows) are JSON-encoded in TEXT columns
// — the data is small, accessed as a unit, and never queried piecemeal,
// so the cost of normalized child tables would outweigh the benefit.
//
// The "current" config is the single row with is_checked = 1. Mutating
// the selection (setChecked / clearChecked) wraps the two updates in a
// transaction so the invariant "at most one row checked" holds even
// under concurrent calls.
//
// The `id` column is the DB's own auto-increment primary key. It is
// not part of the JSON import/export format — every imported app
// is a brand-new row, drift mints the id, and a re-imported export
// never collides on a stale key.
import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../models/test_config.dart';
import '../database.dart';
import '../tables/test_app_configs.dart';

// Re-export the generated row type so callers (the provider) can
// reference TestAppConfigRow without having to also import
// database.g.dart. The row class itself is generated there.
export '../database.dart' show TestAppConfigRow;

part 'test_app_configs_dao.g.dart';

@DriftAccessor(tables: [TestAppConfigs])
class TestAppConfigsDao extends DatabaseAccessor<AppDatabase>
    with _$TestAppConfigsDaoMixin {
  TestAppConfigsDao(super.db);

  // ── Reads ─────────────────────────────────────────────────────────────

  /// All rows, in insertion order (the auto-increment id is the order
  /// the rows were created, which matches the user's mental model —
  /// "first thing I configured, then second, ...").
  Stream<List<TestAppConfigRow>> watchAll() {
    return (select(testAppConfigs)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .watch();
  }

  Future<List<TestAppConfigRow>> getAll() {
    return (select(testAppConfigs)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
  }

  Stream<TestAppConfigRow?> watchById(int id) {
    return (select(testAppConfigs)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<TestAppConfigRow?> getById(int id) {
    return (select(testAppConfigs)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// The row with is_checked = 1, or null if no row is currently
  /// selected. Emits a new value every time the selection flips.
  Stream<TestAppConfigRow?> watchChecked() {
    return (select(testAppConfigs)..where((t) => t.isChecked.equals(true)))
        .watchSingleOrNull();
  }

  Future<TestAppConfigRow?> getChecked() {
    return (select(testAppConfigs)..where((t) => t.isChecked.equals(true)))
        .getSingleOrNull();
  }

  // ── Writes ────────────────────────────────────────────────────────────

  /// Insert a new row. The id field on `app` is ignored — drift
  /// assigns a fresh auto-increment id. Returns the new id so the
  /// caller (e.g. copyApp) can fetch the inserted row back if needed.
  Future<int> insertRow(TestAppConfig app) {
    return into(testAppConfigs).insert(_toCompanion(app));
  }

  /// Update an existing row by id. Pass the row's id explicitly; the
  /// rest of the fields on `app` overwrite the stored values. Returns
  /// true if a row was actually updated.
  ///
  /// Intentionally does NOT touch `is_checked` — selection is a
  /// separate concern owned by `setChecked` / `clearChecked`, and
  /// silently demoting a current row would surprise the user. If
  /// the caller wants to flip the selection, they go through
  /// `setChecked` instead.
  Future<bool> updateRow(int id, TestAppConfig app) async {
    final affected = await (update(testAppConfigs)
          ..where((t) => t.id.equals(id)))
        .write(_toCompanion(app).copyWith(
      // Force updatedAt to "now" on every update.
      updatedAt: Value(DateTime.now()),
    ));
    return affected > 0;
  }

  /// Delete a single row. If it was the checked row, the next caller
  /// of watchChecked() will see null — we don't auto-promote another
  /// row, by design (deleting the current means "I don't have a
  /// current anymore").
  Future<int> deleteById(int id) {
    return (delete(testAppConfigs)..where((t) => t.id.equals(id))).go();
  }

  /// Wipe all rows. Used by the "clear" UI action.
  Future<int> deleteAll() {
    return delete(testAppConfigs).go();
  }

  // ── Selection ────────────────────────────────────────────────────────

  /// Mark exactly one row as the current. Wrapped in a transaction
  /// so we never end up with two rows checked at once, even if two
  /// callers race.
  Future<void> setChecked(int id) async {
    await transaction(() async {
      await (update(testAppConfigs)..where((t) => t.isChecked.equals(true)))
          .write(const TestAppConfigsCompanion(isChecked: Value(false)));
      await (update(testAppConfigs)..where((t) => t.id.equals(id)))
          .write(const TestAppConfigsCompanion(isChecked: Value(true)));
    });
  }

  /// Clear any current selection. No-op if no row is currently
  /// checked, but the call is still atomic (a single UPDATE).
  Future<void> clearChecked() async {
    await (update(testAppConfigs)..where((t) => t.isChecked.equals(true)))
        .write(const TestAppConfigsCompanion(isChecked: Value(false)));
  }

  // ── Model conversion ─────────────────────────────────────────────────

  TestAppConfig rowToModel(TestAppConfigRow row) {
    return TestAppConfig(
      id: row.id,
      appName: row.appName,
      packageName: row.packageName,
      appType: row.appType,
      notes: row.notes,
      logcat: _decodeLogcat(row.logcatJson),
      deepLinks: _decodeNamedValues(row.deepLinksJson),
      filePaths: _decodeFilePaths(row.filePathsJson),
      testTexts: _decodeNamedValues(row.testTextsJson),
      testFlows: _decodeTestFlows(row.testFlowsJson),
      isChecked: row.isChecked,
    );
  }

  // ── Internals ────────────────────────────────────────────────────────

  TestAppConfigsCompanion _toCompanion(TestAppConfig app) {
    return TestAppConfigsCompanion.insert(
      appName: app.appName,
      packageName: app.packageName,
      appType: Value(app.appType),
      notes: Value(app.notes),
      logcatJson: _encodeLogcat(app.logcat),
      deepLinksJson: _encodeNamedValues(app.deepLinks),
      filePathsJson: _encodeFilePaths(app.filePaths),
      testTextsJson: _encodeNamedValues(app.testTexts),
      testFlowsJson: _encodeTestFlows(app.testFlows),
      // isChecked is intentionally Value.absent() — selection is
      // managed by setChecked/clearChecked, not by inserting or
      // updating an app row. See updateRow's doc comment.
      isChecked: const Value.absent(),
    );
  }

  // JSON helpers — small, so a malformed column shouldn't crash the
  // whole app. Fall back to empty values on parse error.

  String _encodeLogcat(TestLogcatConfig c) =>
      jsonEncode(c.toJson());

  TestLogcatConfig _decodeLogcat(String raw) {
    try {
      final m = jsonDecode(raw);
      if (m is Map<String, dynamic>) return TestLogcatConfig.fromJson(m);
    } catch (_) {}
    return const TestLogcatConfig();
  }

  String _encodeNamedValues(List<TestNamedValue> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  List<TestNamedValue> _decodeNamedValues(String raw) {
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map(TestNamedValue.fromJson)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  String _encodeFilePaths(List<TestFilePathConfig> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  List<TestFilePathConfig> _decodeFilePaths(String raw) {
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map(TestFilePathConfig.fromJson)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  String _encodeTestFlows(List<TestFlowConfig> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  List<TestFlowConfig> _decodeTestFlows(String raw) {
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map(TestFlowConfig.fromJson)
            .toList();
      }
    } catch (_) {}
    return const [];
  }
}
