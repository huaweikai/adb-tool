import 'package:adb_tool/main.dart';
import 'package:adb_tool/screens/test_session_screen.dart';
import 'package:adb_tool/providers/device_provider.dart';
import 'package:adb_tool/providers/locale_provider.dart';
import 'package:adb_tool/providers/test_session_provider.dart';
import 'package:adb_tool/providers/theme_provider.dart';
import 'package:adb_tool/services/api_client.dart';
import 'package:adb_tool/services/log_stream.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>(
              create: (_) => ApiClient('http://localhost:9876')),
          Provider<LogStreamService>(create: (_) => LogStreamService()),
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<DeviceProvider>(
              create: (_) => DeviceProvider()),
          ChangeNotifierProvider<LocaleProvider>(
              create: (_) => LocaleProvider()),
          ChangeNotifierProvider<TestSessionProvider>(
              create: (_) => TestSessionProvider()),
        ],
        child: const AdbToolApp(),
      ),
    );
    await tester.pump();

    expect(find.text('ADB Tool'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Test Session toolbar does not overflow on narrow width',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>(
              create: (_) => ApiClient('http://localhost:9876')),
          Provider<LogStreamService>(create: (_) => LogStreamService()),
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<DeviceProvider>(
              create: (_) => DeviceProvider()),
          ChangeNotifierProvider<LocaleProvider>(
              create: (_) => LocaleProvider()),
          ChangeNotifierProvider<TestSessionProvider>(
              create: (_) => TestSessionProvider()),
        ],
        child: const MaterialApp(home: Scaffold(body: TestSessionScreen())),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
