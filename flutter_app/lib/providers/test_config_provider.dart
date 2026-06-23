import 'dart:async';

import 'package:flutter/foundation.dart';

import '../db/dao/test_app_configs_dao.dart';
import '../models/test_config.dart';

class TestConfigImportResult {
  final String configName;
  final int importedCount;
  final bool hasSensitiveValues;

  const TestConfigImportResult({
    required this.configName,
    required this.importedCount,
    required this.hasSensitiveValues,
  });
}

/// In-memory view of the test-app-config table, mirrored from the DAO
/// via two streams:
///   * `watchAll()` → `_apps`     (insertion-order list)
///   * `watchChecked()` → `_currentApp` (single row, or null)
///
/// Same public surface the screens already use (`apps`, `currentApp`,
/// `selectApp`, etc.) so the refactor doesn't ripple to the UI.
class TestConfigProvider extends ChangeNotifier {
  final TestAppConfigsDao _dao;
  List<TestAppConfig> _apps = const [];
  TestAppConfig? _currentApp;
  StreamSubscription<List<TestAppConfigRow>>? _allSub;
  StreamSubscription<TestAppConfigRow?>? _checkedSub;
  bool _loaded = false;

  TestConfigProvider(this._dao) {
    _allSub = _dao.watchAll().listen((rows) {
      _apps = rows.map(_dao.rowToModel).toList();
      _loaded = true;
      notifyListeners();
    });
    _checkedSub = _dao.watchChecked().listen((row) {
      _currentApp = row == null ? null : _dao.rowToModel(row);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _allSub?.cancel();
    _checkedSub?.cancel();
    super.dispose();
  }

  List<TestAppConfig> get apps => List.unmodifiable(_apps);
  bool get loaded => _loaded;
  TestAppConfig? get currentApp => _currentApp;
  bool get hasCurrentApp => _currentApp != null;

  /// No-op kept for source compatibility with the old JSON-backed
  /// provider. The streams above deliver the data the moment the DAO
  /// emits it, so screens that still call `load()` don't need to be
  /// updated.
  Future<void> load() async {}

  Future<TestConfigImportResult> importFromJsonString(String source) async {
    final config = TestConfigFile.fromJsonString(source);
    final imported = config.apps;
    for (final incoming in imported) {
      // Insert path: brand-new packageName, or existing row was
      // somehow missing its id. Drift assigns a fresh id.
      await _dao.insertRow(incoming.copyWith(id: null, isChecked: false));
    }
    return TestConfigImportResult(
      configName: config.configName,
      importedCount: imported.length,
      hasSensitiveValues: imported.any(
        (app) => app.testTexts.any((item) => item.sensitive),
      ),
    );
  }

  /// Build a JSON export containing either the given app ids (if
  /// provided) or every config in the table. Used by the
  /// batch-export UI button.
  TestConfigFile exportAsConfigFile({List<int>? ids}) {
    final selected = (ids == null)
        ? _apps
        : _apps.where((app) => app.id != null && ids.contains(app.id));
    return TestConfigFile(
      schemaVersion: 1,
      configName: 'ADBTool 导出配置',
      description: '',
      apps: selected.toList(),
    );
  }

  Future<void> selectApp(int appId) async {
    if (!_apps.any((app) => app.id == appId)) return;
    await _dao.setChecked(appId);
  }

  Future<void> createOrUpdateApp(TestAppConfig app) async {
    if (app.id == null) {
      // New row — strip any id the caller passed and let drift assign.
      await _dao.insertRow(app.copyWith(id: null, isChecked: false));
    } else {
      // Update path. is_checked is preserved as-is on the existing
      // row (we don't accidentally demote the current when the
      // user edits a different field of it).
      await _dao.updateRow(app.id!, app);
    }
  }

  /// Deep-clone `appId` and insert the copy as a brand-new row with
  /// a fresh auto-increment id. The copy's name gets a "（副本）"
  /// suffix and a millisecond-suffix-free body so repeated copies
  /// of the same source stay visually distinguishable in the list.
  Future<TestAppConfig> copyApp(int appId) async {
    final source = _apps.firstWhere(
      (app) => app.id == appId,
      orElse: () => throw StateError('appId not found: $appId'),
    );
    const suffix = '（副本）';
    const maxBase = 60;
    final base = source.appName.length > maxBase
        ? source.appName.substring(0, maxBase)
        : source.appName;
    final copy = TestAppConfig(
      // id null → drift mints a fresh int on insert
      appName: '$base$suffix',
      packageName: source.packageName,
      appType: source.appType,
      notes: source.notes,
      logcat: TestLogcatConfig(
        keywords: List<String>.from(source.logcat.keywords),
        tags: List<String>.from(source.logcat.tags),
        defaultLevel: source.logcat.defaultLevel,
      ),
      deepLinks: source.deepLinks
          .map((d) => TestNamedValue(
              name: d.name, value: d.value, sensitive: d.sensitive))
          .toList(),
      filePaths: source.filePaths
          .map((p) => TestFilePathConfig(name: p.name, path: p.path))
          .toList(),
      testTexts: source.testTexts
          .map((t) => TestNamedValue(
              name: t.name, value: t.value, sensitive: t.sensitive))
          .toList(),
      testFlows: source.testFlows
          .map((f) =>
              TestFlowConfig(name: f.name, steps: List<String>.from(f.steps)))
          .toList(),
      // The copy is unchecked even if the source was checked —
      // copying a config shouldn't hijack the current selection.
      isChecked: false,
    );
    final newId = await _dao.insertRow(copy);
    final row = await _dao.getById(newId);
    if (row == null) {
      throw StateError('inserted copy row not found: $newId');
    }
    return _dao.rowToModel(row);
  }

  Future<void> deleteApp(int appId) async {
    await _dao.deleteById(appId);
  }

  Future<void> deselectApp() async {
    await _dao.clearChecked();
  }

  Future<void> clear() async {
    await _dao.deleteAll();
  }
}
