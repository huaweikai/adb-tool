import 'package:adb_tool/db/database.dart';
import 'package:adb_tool/providers/locale_provider.dart';
import 'package:adb_tool/providers/test_config_provider.dart';
import 'package:adb_tool/screens/test_config_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late TestConfigProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'sample_config_loaded': true});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    provider = TestConfigProvider(db.testAppConfigsDao);
  });

  tearDown(() async {
    provider.dispose();
    await db.close();
  });

  testWidgets(
      'TestConfigScreen lists imported apps and renders the current card after manual select',
      (tester) async {
    await provider.importFromJsonString(_musicConfigJson);
    // The DAO streams are async — give them a couple of microtasks
    // to land before we pump the widget.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    // Pre-select the first app so the "current" card is visible —
    // imports no longer auto-select in this codebase.
    final firstId = provider.apps.first.id;
    expect(firstId, isNotNull);
    await provider.selectApp(firstId!);
    await Future<void>.delayed(Duration.zero);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TestConfigProvider>.value(value: provider),
          ChangeNotifierProvider<LocaleProvider>(
              create: (_) => LocaleProvider()),
        ],
        child: const MaterialApp(home: Scaffold(body: TestConfigScreen())),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('测试配置中心'), findsOneWidget);
    expect(find.text('抽象音乐 - 测试包'), findsOneWidget);
    expect(find.text('抽象音乐 - 正式包'), findsOneWidget);
    expect(find.text('当前测试 App'), findsOneWidget);
    expect(find.text('com.hua.music.debug'), findsOneWidget);
  });

  testWidgets(
      'new app config dialog closes safely with Esc while input has focus',
      (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TestConfigProvider>.value(value: provider),
          ChangeNotifierProvider<LocaleProvider>(
              create: (_) => LocaleProvider()),
        ],
        child: const MaterialApp(home: Scaffold(body: TestConfigScreen())),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('新建 App 配置'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextField, 'App 名称'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    // Dialog dismissed, the screen is back behind it.
    expect(find.text('新建 App 配置'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'App 名称'), findsNothing);
    expect(tester.takeException(), isNull);
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
