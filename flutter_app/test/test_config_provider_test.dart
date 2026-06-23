import 'dart:convert';

import 'package:adb_tool/db/database.dart';
import 'package:adb_tool/models/test_config.dart';
import 'package:adb_tool/providers/test_config_provider.dart';
import 'package:adb_tool/utils/test_flow_text.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late TestConfigProvider provider;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    provider = TestConfigProvider(db.testAppConfigsDao);
  });

  tearDown(() async {
    provider.dispose();
    await db.close();
  });

  test(
      'parseConfig imports multiple apps with logcat keywords and sensitive text',
      () {
    final config = TestConfigFile.fromJsonString(_musicConfigJson);

    expect(config.configName, '抽象音乐 App 测试配置');
    expect(config.apps, hasLength(2));
    expect(config.apps.first.displayName, '抽象音乐 - 测试包');
    expect(config.apps.first.packageName, 'com.hua.music.debug');
    expect(config.apps.first.logcat.keywords,
        containsAll(['网络请求', 'music/Http', 'FATAL EXCEPTION']));
    expect(config.apps.first.testTexts.last.sensitive, isTrue);
  });

  test('test flow text parser keeps flow names and ordered steps', () {
    final flows = parseTestFlowText('''
登录流程：
1. 打开 App
2. 输入账号密码
3. 点击登录

支付流程:
- 进入收银台
- 确认支付
''');

    expect(flows, hasLength(2));
    expect(flows.first.name, '登录流程');
    expect(flows.first.steps, ['打开 App', '输入账号密码', '点击登录']);
    expect(flows.last.name, '支付流程');
    expect(flows.last.steps, ['进入收银台', '确认支付']);
    expect(formatTestFlowText(flows), contains('登录流程：'));
    expect(formatTestFlowText(flows), contains('- 输入账号密码'));
  });

  test('parseConfig rejects app without packageName', () {
    expect(
      () => TestConfigFile.fromJsonString('''
        {
          "schemaVersion": 1,
          "configName": "错误配置",
          "apps": [
            { "appName": "没有包名" }
          ]
        }
      '''),
      throwsA(isA<TestConfigException>()),
    );
  });

  test('import inserts apps but does not auto-select any', () async {
    final result = await provider.importFromJsonString(_musicConfigJson);

    expect(result.importedCount, 2);
    // Streams are async — wait one tick for the provider to mirror
    // the DAO's first emission into its own _apps list.
    await Future<void>.delayed(Duration.zero);
    expect(provider.apps, hasLength(2));
    // The new behaviour: an import never auto-selects a row. Even
    // when the table was empty before, the current stays empty.
    expect(provider.currentApp, isNull);
  });

  test('selectApp sets one row as current; deselectApp clears it',
      () async {
    await provider.importFromJsonString(_musicConfigJson);
    await Future<void>.delayed(Duration.zero);

    final first = provider.apps.first;
    final firstId = first.id;
    expect(firstId, isNotNull, reason: 'inserted row should have an int id');
    await provider.selectApp(firstId!);
    await Future<void>.delayed(Duration.zero);

    expect(provider.currentApp, isNotNull);
    expect(provider.currentApp!.packageName, first.packageName);

    await provider.deselectApp();
    await Future<void>.delayed(Duration.zero);
    expect(provider.currentApp, isNull);
  });

  test('selecting a different app moves the current pointer', () async {
    await provider.importFromJsonString(_musicConfigJson);
    await Future<void>.delayed(Duration.zero);

    final apps = provider.apps;
    final firstId = apps[0].id!;
    final secondId = apps[1].id!;

    await provider.selectApp(firstId);
    await Future<void>.delayed(Duration.zero);
    expect(provider.currentApp!.packageName, apps[0].packageName);

    await provider.selectApp(secondId);
    await Future<void>.delayed(Duration.zero);
    expect(provider.currentApp!.packageName, apps[1].packageName);
  });

  test('import after a selection does not change the current', () async {
    await provider.importFromJsonString(_musicConfigJson);
    await Future<void>.delayed(Duration.zero);

    final first = provider.apps.first;
    await provider.selectApp(first.id!);
    await Future<void>.delayed(Duration.zero);

    // A second import that re-supplies the same packageName should
    // overwrite the existing row but leave the current selection
    // untouched.
    await provider.importFromJsonString(_musicConfigJson);
    await Future<void>.delayed(Duration.zero);

    expect(provider.apps, hasLength(2));
    expect(provider.currentApp, isNotNull);
    expect(provider.currentApp!.packageName, first.packageName);
  });

  test('import appends apps by packageName, replaces duplicates', () async {
    await provider.importFromJsonString(_musicConfigJson);
    await Future<void>.delayed(Duration.zero);
    expect(provider.apps, hasLength(2));

    final result = await provider.importFromJsonString(_anotherConfigJson);
    expect(result.importedCount, 1);
    // The DAO streams are async; let them fire before reading
    // provider.apps, otherwise we see the pre-insert snapshot.
    await Future<void>.delayed(Duration.zero);
    expect(provider.apps, hasLength(3));
    final packages = provider.apps.map((a) => a.packageName).toSet();
    expect(packages, containsAll([
      'com.hua.music.debug',
      'com.hua.music',
      'com.example.app',
    ]));
    expect(result.configName, '另一个测试配置');
  });

  test('copyApp inserts a new row with a fresh id, never checked',
      () async {
    await provider.importFromJsonString(_musicConfigJson);
    await Future<void>.delayed(Duration.zero);
    final source = provider.apps.first;
    final sourceId = source.id!;

    // Mark the source as current; copying should NOT transfer the
    // current flag to the copy.
    await provider.selectApp(sourceId);
    await Future<void>.delayed(Duration.zero);

    final copy = await provider.copyApp(sourceId);
    await Future<void>.delayed(Duration.zero);

    expect(copy.id, isNotNull);
    expect(copy.id, isNot(equals(sourceId)));
    expect(copy.appName, '${source.appName}（副本）');
    expect(copy.packageName, source.packageName);
    // The copy was inserted unchecked, so the current row is still
    // the source.
    expect(provider.currentApp!.id, sourceId);
    expect(provider.apps, hasLength(3));
  });

  test('deleteApp removes the row and clears current if it was the one',
      () async {
    await provider.importFromJsonString(_musicConfigJson);
    await Future<void>.delayed(Duration.zero);
    final first = provider.apps.first;
    await provider.selectApp(first.id!);
    await Future<void>.delayed(Duration.zero);

    await provider.deleteApp(first.id!);
    await Future<void>.delayed(Duration.zero);

    expect(provider.apps, hasLength(1));
    expect(provider.currentApp, isNull);
  });

  test('clear empties the table and clears the current', () async {
    await provider.importFromJsonString(_musicConfigJson);
    await Future<void>.delayed(Duration.zero);
    await provider.selectApp(provider.apps.first.id!);
    await Future<void>.delayed(Duration.zero);

    await provider.clear();
    await Future<void>.delayed(Duration.zero);

    expect(provider.apps, isEmpty);
    expect(provider.currentApp, isNull);
  });

  test('exportAsConfigFile produces JSON that can be re-imported', () async {
    await provider.importFromJsonString(_musicConfigJson);
    await Future<void>.delayed(Duration.zero);

    final exported = provider.exportAsConfigFile();
    expect(exported.apps, hasLength(2));
    expect(exported.apps.first.packageName, 'com.hua.music.debug');
    expect(exported.schemaVersion, 1);

    // Build a JSON string the same way _exportAllConfigs() does on
    // the UI side, and feed it back into the provider. The point of
    // this test is that the export and import shapes match.
    final encoded = const JsonEncoder.withIndent('  ').convert(exported.toJson());
    final reimported = await provider.importFromJsonString(encoded);
    expect(reimported.importedCount, 2);
  });
}

const _musicConfigJson = '''
{
  "schemaVersion": 1,
  "configName": "抽象音乐 App 测试配置",
  "description": "用于抽象音乐测试包和正式包的日常测试配置",
  "apps": [
    {
      "appName": "抽象音乐",
      "packageName": "com.hua.music.debug",
      "appType": "测试包",
      "notes": "抽象音乐测试包",
      "logcat": {
        "keywords": [
          "网络请求",
          "music/Http",
          "Exception",
          "Error",
          "Crash",
          "ANR",
          "FATAL EXCEPTION"
        ],
        "tags": ["music/Http"],
        "defaultLevel": "warn"
      },
      "deepLinks": [],
      "filePaths": [
        {
          "name": "下载目录",
          "path": "/storage/emulated/0/Download"
        },
        {
          "name": "App 外部数据目录",
          "path": "/storage/emulated/0/Android/data/com.hua.music.debug"
        }
      ],
      "testTexts": [
        {
          "name": "测试账号",
          "value": "amy"
        },
        {
          "name": "测试密码",
          "value": "请在软件内手动填写",
          "sensitive": true
        }
      ]
    },
    {
      "appName": "抽象音乐",
      "packageName": "com.hua.music",
      "appType": "正式包",
      "notes": "抽象音乐正式包",
      "logcat": {
        "keywords": ["网络请求", "music/Http", "Exception", "Error", "Crash", "ANR"],
        "tags": ["music/Http"],
        "defaultLevel": "warn"
      },
      "deepLinks": [],
      "filePaths": [
        {
          "name": "App 外部数据目录",
          "path": "/storage/emulated/0/Android/data/com.hua.music"
        }
      ],
      "testTexts": [
        {
          "name": "测试账号",
          "value": "qwer"
        },
        {
          "name": "测试密码",
          "value": "请在软件内手动填写",
          "sensitive": true
        }
      ]
    }
  ]
}
''';

const _anotherConfigJson = '''
{
  "schemaVersion": 1,
  "configName": "另一个测试配置",
  "description": "追加导入测试",
  "apps": [
    {
      "appName": "示例应用",
      "packageName": "com.example.app",
      "appType": "",
      "notes": "",
      "logcat": {
        "keywords": ["crash", "error"],
        "tags": [],
        "defaultLevel": "warn"
      },
      "deepLinks": [],
      "filePaths": [],
      "testTexts": []
    }
  ]
}
''';
