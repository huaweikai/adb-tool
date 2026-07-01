import 'package:adb_tool/db/database.dart';
import 'package:adb_tool/i18n.dart';
import 'package:adb_tool/providers/clipboard_history_provider.dart';
import 'package:adb_tool/providers/device_provider.dart';
import 'package:adb_tool/providers/emulator_engine_provider.dart';
import 'package:adb_tool/providers/emulator_image_provider.dart';
import 'package:adb_tool/providers/emulator_instance_provider.dart';
import 'package:adb_tool/providers/emulator_java_provider.dart';
import 'package:adb_tool/providers/locale_provider.dart';
import 'package:adb_tool/providers/scrcpy_settings_provider.dart';
import 'package:adb_tool/providers/test_config_provider.dart';
import 'package:adb_tool/providers/test_session_provider.dart';
import 'package:adb_tool/providers/theme_provider.dart';
import 'package:adb_tool/screens/home_screen.dart';
import 'package:adb_tool/services/api_client.dart';
import 'package:adb_tool/services/log_stream.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
      'keeps previously opened workspace pages mounted when switching tabs',
      (tester) async {
    setLang('en');
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final api = ApiClient('http://localhost:9876', dio: _FakeDio());
    final deviceProvider = DeviceProvider(db: db);
    final testConfigProvider = TestConfigProvider(db.testAppConfigsDao);
    final scrcpySettingsProvider = ScrcpySettingsProvider(db: db);
    final clipboardHistoryProvider = ClipboardHistoryProvider(db: db);
    final testSessionProvider = TestSessionProvider(db: db);
    final emulatorEngineProvider = EmulatorEngineProvider(api: api, db: db);
    final emulatorJavaProvider = EmulatorJavaProvider(api: api, db: db);
    final emulatorImageProvider = EmulatorImageProvider(api: api);
    final emulatorInstanceProvider = EmulatorInstanceProvider(api: api);

    addTearDown(() async {
      deviceProvider.dispose();
      testConfigProvider.dispose();
      scrcpySettingsProvider.dispose();
      clipboardHistoryProvider.dispose();
      testSessionProvider.dispose();
      emulatorEngineProvider.dispose();
      emulatorJavaProvider.dispose();
      emulatorImageProvider.dispose();
      emulatorInstanceProvider.dispose();
      await db.close();
    });

    await db.into(db.savedDevices).insert(SavedDevicesCompanion.insert(
          serial: 'device-a',
          model: 'Device A',
          brand: 'brand',
          sdk: '35',
          isConnected: true,
          firstSeenAt: DateTime(2026),
        ));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: db),
          Provider<ApiClient>.value(value: api),
          Provider<LogStreamService>.value(value: LogStreamService(deviceProvider)),
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<LocaleProvider>(
              create: (_) => LocaleProvider()),
          ChangeNotifierProvider<DeviceProvider>.value(value: deviceProvider),
          ChangeNotifierProvider<TestConfigProvider>.value(
              value: testConfigProvider),
          ChangeNotifierProvider<ScrcpySettingsProvider>.value(
              value: scrcpySettingsProvider),
          ChangeNotifierProvider<ClipboardHistoryProvider>.value(
              value: clipboardHistoryProvider),
          ChangeNotifierProvider<TestSessionProvider>.value(
              value: testSessionProvider),
          ChangeNotifierProvider<EmulatorEngineProvider>.value(
              value: emulatorEngineProvider),
          ChangeNotifierProvider<EmulatorJavaProvider>.value(
              value: emulatorJavaProvider),
          ChangeNotifierProvider<EmulatorImageProvider>.value(
              value: emulatorImageProvider),
          ChangeNotifierProvider<EmulatorInstanceProvider>.value(
              value: emulatorInstanceProvider),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Device A'));
    await tester.pump();
    await tester.tap(find.text('Status'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(IndexedStack), findsOneWidget);
    expect(find.text('88%'), findsOneWidget);

    await tester.tap(find.text('Files'));
    await tester.pump();
    expect(find.text('/system'), findsOneWidget);
    expect(find.text('88%'), findsOneWidget);
  });
}

class _FakeDio extends DioForNative {
  _FakeDio() : super(BaseOptions(baseUrl: 'http://localhost:9876'));

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    if (path == '/api/adb-path') {
      return _json<T>(path, {'ok': true, 'data': {}});
    }
    if (path == '/api/devices') {
      return _json<T>(path, {
        'ok': true,
        'data': [
          {
            'serial': 'device-a',
            'state': 'device',
            'model': 'Device A',
            'brand': 'brand',
            'sdk': '35',
          }
        ],
      });
    }
    if (path == '/api/device-status') {
      return _json<T>(path, {
        'ok': true,
        'data': {
          'status': {
            'batteryLevel': '88',
            'batteryStatus': 'charging',
            'topProcesses': [],
          }
        },
      });
    }
    if (path == '/api/files') {
      return _json<T>(path, {
        'ok': true,
        'data': {
          'files': [
            {
              'name': 'system',
              'path': '/system',
              'size': 0,
              'isDir': true,
              'permissions': 'drwxr-xr-x',
              'modified': '2026-01-01',
            }
          ],
        },
      });
    }
    return _json<T>(path, {'ok': true, 'data': {}});
  }

  Response<T> _json<T>(String path, Object body) {
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: body as T,
    );
  }
}
