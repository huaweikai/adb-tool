import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

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

class TestConfigProvider extends ChangeNotifier {
  final Directory? baseDirectory;
  List<TestAppConfig> _apps = const [];
  String? _currentAppId;
  bool _loaded = false;

  TestConfigProvider({this.baseDirectory});

  List<TestAppConfig> get apps => List.unmodifiable(_apps);
  bool get loaded => _loaded;

  TestAppConfig? get currentApp {
    if (_apps.isEmpty) return null;
    final id = _currentAppId;
    if (id == null || id.isEmpty) return null;
    for (final app in _apps) {
      if (app.id == id) return app;
    }
    return null;
  }

  bool get hasCurrentApp => currentApp != null;

  Future<void> load() async {
    final file = await _configFile();
    if (!await file.exists()) {
      _loaded = true;
      notifyListeners();
      return;
    }
    final json = jsonDecode(await file.readAsString());
    if (json is! Map<String, dynamic>) {
      throw const TestConfigException('本地测试配置不是有效 JSON 对象');
    }
    final appsJson = json['apps'];
    _apps = appsJson is List
        ? appsJson
            .whereType<Map<String, dynamic>>()
            .map(TestAppConfig.fromJson)
            .toList()
        : const [];
    _currentAppId = '';
    _loaded = true;
    notifyListeners();
  }

  Future<TestConfigImportResult> importFromJsonString(String source) async {
    final config = TestConfigFile.fromJsonString(source);
    _apps = config.apps;
    _loaded = true;
    await _persist();
    notifyListeners();
    return TestConfigImportResult(
      configName: config.configName,
      importedCount: config.apps.length,
      hasSensitiveValues: config.apps.any(
        (app) => app.testTexts.any((item) => item.sensitive),
      ),
    );
  }

  Future<void> selectApp(String appId) async {
    if (!_apps.any((app) => app.id == appId)) return;
    _currentAppId = appId;
    await _persist();
    notifyListeners();
  }

  Future<void> createOrUpdateApp(TestAppConfig app) async {
    final idx = _apps.indexWhere((a) => a.id == app.id);
    if (idx >= 0) {
      _apps = [..._apps]..[idx] = app;
    } else {
      _apps = [..._apps, app];
    }
    await _persist();
    notifyListeners();
  }

  Future<void> deleteApp(String appId) async {
    _apps = _apps.where((app) => app.id != appId).toList();
    if (_currentAppId == appId) {
      _currentAppId = '';
    }
    await _persist();
    notifyListeners();
  }

  Future<void> deselectApp() async {
    _currentAppId = '';
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    _apps = const [];
    _currentAppId = null;
    await _persist();
    notifyListeners();
  }

  Future<File> _configFile() async {
    final root = await _rootDirectory();
    await root.create(recursive: true);
    return File('${root.path}/test_configs.json');
  }

  Future<Directory> _rootDirectory() async {
    if (baseDirectory != null) return baseDirectory!;
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;
    return Directory('$home/ADBToolData');
  }

  Future<void> _persist() async {
    final file = await _configFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'currentAppId': _currentAppId,
        'apps': _apps.map((app) => app.toJson()).toList(),
      }),
    );
  }
}
