import 'package:adb_tool/db/database.dart';
import 'package:adb_tool/i18n.dart';
import 'package:adb_tool/providers/locale_provider.dart';
import 'package:adb_tool/providers/recording_settings_provider.dart';
import 'package:adb_tool/screens/settings_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/link.dart';

void main() {
  testWidgets('Settings credits pymobiledevice3 and links to the project',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final previousLanguage = currentLang;
    final locale = LocaleProvider();
    setLang('en');
    addTearDown(() async {
      locale.dispose();
      setLang(previousLanguage);
      await db.close();
    });

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: locale),
        ChangeNotifierProvider(
            create: (_) => RecordingSettingsProvider(db: db)),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ));

    expect(find.text('Third-party open source'), findsOneWidget);
    expect(find.text('pymobiledevice3'), findsOneWidget);
    expect(find.textContaining('GPL-3.0-or-later'), findsOneWidget);
    expect(tester.widget<Link>(find.byType(Link)).uri.toString(),
        'https://github.com/doronz88/pymobiledevice3');
  });
}
