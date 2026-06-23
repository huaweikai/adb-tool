import 'dart:convert';

class TestConfigException implements Exception {
  final String message;

  const TestConfigException(this.message);

  @override
  String toString() => message;
}

class TestConfigFile {
  final int schemaVersion;
  final String configName;
  final String description;
  final List<TestAppConfig> apps;

  const TestConfigFile({
    required this.schemaVersion,
    required this.configName,
    required this.description,
    required this.apps,
  });

  factory TestConfigFile.fromJsonString(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) {
        throw const TestConfigException('配置文件必须是 JSON 对象');
      }
      return TestConfigFile.fromJson(decoded);
    } on FormatException catch (e) {
      throw TestConfigException('JSON 格式错误：${e.message}');
    }
  }

  factory TestConfigFile.fromJson(Map<String, dynamic> json) {
    final appsJson = json['apps'];
    if (appsJson is! List || appsJson.isEmpty) {
      throw const TestConfigException('配置里至少需要一个 App');
    }
    final apps = <TestAppConfig>[];
    for (var i = 0; i < appsJson.length; i++) {
      final item = appsJson[i];
      if (item is! Map<String, dynamic>) {
        throw TestConfigException('第 ${i + 1} 个 App 配置不是有效对象');
      }
      apps.add(TestAppConfig.fromJson(item, index: i));
    }
    return TestConfigFile(
      schemaVersion: _intValue(json['schemaVersion'], fallback: 1),
      configName: _stringValue(json['configName'], fallback: '未命名测试配置'),
      description: _stringValue(json['description']),
      apps: apps,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'configName': configName,
        'description': description,
        'apps': apps.map((app) => app.toJson()).toList(),
      };
}

class TestAppConfig {
  // DB-assigned primary key. null = the row hasn't been inserted yet
  // (e.g. brand-new in-memory config waiting for createOrUpdateApp).
  // The id is INTERNAL — it never round-trips through JSON exports
  // or imports. Every import inserts as a new row and lets drift
  // mint a fresh id, so a JSON file is portable across machines
  // and re-imports never collide on a stale primary key.
  final int? id;
  final String appName;
  final String packageName;
  final String appType;
  final String notes;
  final TestLogcatConfig logcat;
  final List<TestNamedValue> deepLinks;
  final List<TestFilePathConfig> filePaths;
  final List<TestNamedValue> testTexts;
  final List<TestFlowConfig> testFlows;
  // True for at most one row at a time; the "current" config the
  // rest of the app reads from. Stays a column (not a singleton
  // table) so copy / delete / import don't have to special-case a
  // separate settings row.
  final bool isChecked;

  const TestAppConfig({
    this.id,
    required this.appName,
    required this.packageName,
    this.appType = '',
    this.notes = '',
    this.logcat = const TestLogcatConfig(),
    this.deepLinks = const [],
    this.filePaths = const [],
    this.testTexts = const [],
    this.testFlows = const [],
    this.isChecked = false,
  });

  factory TestAppConfig.fromJson(Map<String, dynamic> json, {int index = 0}) {
    final packageName = _stringValue(json['packageName']).trim();
    if (packageName.isEmpty) {
      throw TestConfigException('第 ${index + 1} 个 App 缺少包名 packageName');
    }
    final appName = _stringValue(json['appName'], fallback: packageName).trim();
    final appType = _stringValue(json['appType']).trim();
    return TestAppConfig(
      // id is intentionally null on parse. The old string-based id
      // ("com.example.app" / "com_example_app_<millis>") is dead
      // now that the DB owns the primary key — see the doc comment
      // on the field. If a stale export still carries one, ignore it.
      appName: appName.isEmpty ? packageName : appName,
      packageName: packageName,
      appType: appType,
      notes: _stringValue(json['notes']),
      logcat: json['logcat'] is Map<String, dynamic>
          ? TestLogcatConfig.fromJson(json['logcat'] as Map<String, dynamic>)
          : const TestLogcatConfig(),
      deepLinks: _namedValues(json['deepLinks']),
      filePaths: _filePaths(json['filePaths']),
      testTexts: _namedValues(json['testTexts']),
      testFlows: _testFlows(json['testFlows']),
    );
  }

  String get displayName => appType.isEmpty ? appName : '$appName - $appType';

  // Returns a copy of this config with selected fields overridden.
  // Used by the dialog save flow (id is null for new, set for update)
  // and by copyApp (id is null so DB mints a fresh one).
  TestAppConfig copyWith({
    int? id,
    String? appName,
    String? packageName,
    String? appType,
    String? notes,
    TestLogcatConfig? logcat,
    List<TestNamedValue>? deepLinks,
    List<TestFilePathConfig>? filePaths,
    List<TestNamedValue>? testTexts,
    List<TestFlowConfig>? testFlows,
    bool? isChecked,
  }) {
    return TestAppConfig(
      id: id ?? this.id,
      appName: appName ?? this.appName,
      packageName: packageName ?? this.packageName,
      appType: appType ?? this.appType,
      notes: notes ?? this.notes,
      logcat: logcat ?? this.logcat,
      deepLinks: deepLinks ?? this.deepLinks,
      filePaths: filePaths ?? this.filePaths,
      testTexts: testTexts ?? this.testTexts,
      testFlows: testFlows ?? this.testFlows,
      isChecked: isChecked ?? this.isChecked,
    );
  }

  Map<String, dynamic> toJson() => {
        // We intentionally don't round-trip the DB id into the export
        // — it's an internal primary key, not a stable cross-machine
        // identifier. Re-importing the same export would otherwise
        // collide on PK or, worse, overwrite the wrong row.
        'appName': appName,
        'packageName': packageName,
        'appType': appType,
        'notes': notes,
        'logcat': logcat.toJson(),
        'deepLinks': deepLinks.map((item) => item.toJson()).toList(),
        'filePaths': filePaths.map((item) => item.toJson()).toList(),
        'testTexts': testTexts.map((item) => item.toJson()).toList(),
        'testFlows': testFlows.map((item) => item.toJson()).toList(),
      };
}

class TestLogcatConfig {
  final List<String> keywords;
  final List<String> tags;
  final String defaultLevel;

  const TestLogcatConfig({
    this.keywords = const [],
    this.tags = const [],
    this.defaultLevel = '',
  });

  factory TestLogcatConfig.fromJson(Map<String, dynamic> json) {
    return TestLogcatConfig(
      keywords: _stringList(json['keywords']),
      tags: _stringList(json['tags']),
      defaultLevel: _stringValue(json['defaultLevel']),
    );
  }

  Map<String, dynamic> toJson() => {
        'keywords': keywords,
        'tags': tags,
        'defaultLevel': defaultLevel,
      };
}

class TestNamedValue {
  final String name;
  final String value;
  final bool sensitive;

  const TestNamedValue({
    required this.name,
    required this.value,
    this.sensitive = false,
  });

  factory TestNamedValue.fromJson(Map<String, dynamic> json) {
    return TestNamedValue(
      name: _stringValue(json['name']),
      value: _stringValue(json['value'] ?? json['url']),
      sensitive: json['sensitive'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        if (sensitive) 'sensitive': true,
      };
}

class TestFilePathConfig {
  final String name;
  final String path;

  const TestFilePathConfig({required this.name, required this.path});

  factory TestFilePathConfig.fromJson(Map<String, dynamic> json) {
    return TestFilePathConfig(
      name: _stringValue(json['name']),
      path: _stringValue(json['path']),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
      };
}

class TestFlowConfig {
  final String name;
  final List<String> steps;

  const TestFlowConfig({required this.name, required this.steps});

  factory TestFlowConfig.fromJson(Map<String, dynamic> json) {
    return TestFlowConfig(
      name: _stringValue(json['name']),
      steps: _stringList(json['steps']),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'steps': steps,
      };
}

String _stringValue(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  return value.toString();
}

int _intValue(Object? value, {required int fallback}) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

List<TestNamedValue> _namedValues(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map<String, dynamic>>().map(TestNamedValue.fromJson).toList();
}

List<TestFilePathConfig> _filePaths(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map<String, dynamic>>()
      .map(TestFilePathConfig.fromJson)
      .where((item) => item.path.trim().isNotEmpty)
      .toList();
}

List<TestFlowConfig> _testFlows(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map<String, dynamic>>().map(TestFlowConfig.fromJson).toList();
}
