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
  final String id;
  final String appName;
  final String packageName;
  final String appType;
  final String notes;
  final TestLogcatConfig logcat;
  final List<TestNamedValue> deepLinks;
  final List<TestFilePathConfig> filePaths;
  final List<TestNamedValue> testTexts;
  final List<TestFlowConfig> testFlows;

  const TestAppConfig({
    required this.id,
    required this.appName,
    required this.packageName,
    required this.appType,
    required this.notes,
    required this.logcat,
    required this.deepLinks,
    required this.filePaths,
    required this.testTexts,
    required this.testFlows,
  });

  factory TestAppConfig.fromJson(Map<String, dynamic> json, {int index = 0}) {
    final packageName = _stringValue(json['packageName']).trim();
    if (packageName.isEmpty) {
      throw TestConfigException('第 ${index + 1} 个 App 缺少包名 packageName');
    }
    final appName = _stringValue(json['appName'], fallback: packageName).trim();
    final appType = _stringValue(json['appType']).trim();
    return TestAppConfig(
      id: _stringValue(json['id'], fallback: packageName),
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

  Map<String, dynamic> toJson() => {
        'id': id,
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
