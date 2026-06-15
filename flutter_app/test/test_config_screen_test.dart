import 'dart:io';

import 'package:adb_tool/providers/locale_provider.dart';
import 'package:adb_tool/providers/test_config_provider.dart';
import 'package:adb_tool/screens/test_config_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('adb_tool_config_screen_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('TestConfigScreen shows imported app configs and current app',
      (tester) async {
    final provider = TestConfigProvider(baseDirectory: tempDir);
    await provider.importFromJsonString(_musicConfigJson);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TestConfigProvider>.value(value: provider),
          ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
        ],
        child: const MaterialApp(home: Scaffold(body: TestConfigScreen())),
      ),
    );
    await tester.pump();

    expect(find.text('测试配置中心'), findsOneWidget);
    expect(find.text('抽象音乐 - 测试包'), findsOneWidget);
    expect(find.text('抽象音乐 - 正式包'), findsOneWidget);
    expect(find.text('当前测试 App'), findsOneWidget);
    expect(find.text('com.hua.music.debug'), findsOneWidget);
  });
}

const _musicConfigJson = '''
{
  "schemaVersion": 1,
  "configName": "抽象音乐 App 测试配置",
  "apps": [
    {
      "appName": "抽象音乐",
      "packageName": "com.hua.music.debug",
      "appType": "测试包",
      "logcat": {
        "keywords": ["网络请求", "music/Http"],
        "tags": ["music/Http"],
        "defaultLevel": "warn"
      }
    },
    {
      "appName": "抽象音乐",
      "packageName": "com.hua.music",
      "appType": "正式包",
      "logcat": {
        "keywords": ["网络请求", "music/Http"],
        "tags": ["music/Http"],
        "defaultLevel": "warn"
      }
    }
  ]
}
''';
