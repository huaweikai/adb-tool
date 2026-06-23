import 'dart:io';

import 'package:adb_tool/models/test_config.dart';
import 'package:adb_tool/providers/test_config_provider.dart';
import 'package:adb_tool/utils/test_flow_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('adb_tool_config_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
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

  test('provider imports config, selects first app and persists locally',
      () async {
    final provider = TestConfigProvider(baseDirectory: tempDir);

    final result = await provider.importFromJsonString(_musicConfigJson);

    expect(result.importedCount, 2);
    expect(provider.apps, hasLength(2));
    expect(provider.currentApp?.packageName, 'com.hua.music.debug');

    final reloaded = TestConfigProvider(baseDirectory: tempDir);
    await reloaded.load();

    expect(reloaded.apps, hasLength(2));
    expect(reloaded.currentApp?.displayName, '抽象音乐 - 测试包');
  });

  test('import appends apps by packageName, replaces duplicates', () async {
    final provider = TestConfigProvider(baseDirectory: tempDir);
    await provider.importFromJsonString(_musicConfigJson);
    expect(provider.apps, hasLength(2));

    final result = await provider.importFromJsonString(_anotherConfigJson);
    expect(result.importedCount, 1);
    expect(provider.apps, hasLength(3));
    final packages = provider.apps.map((a) => a.packageName).toSet();
    expect(packages, containsAll([
      'com.hua.music.debug',
      'com.hua.music',
      'com.example.app',
    ]));
    expect(result.configName, '另一个测试配置');
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
