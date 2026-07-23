import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../design/design_tokens.dart';

String get prefsPath {
  final home = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '.';
  return '$home/.adb-tool/prefs.json';
}

Map<String, dynamic> _loadPrefs() {
  try {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    final legacyFile = File('$home/.adb_tool_prefs.json');
    final newFile = File(prefsPath);
    if (!newFile.existsSync() && legacyFile.existsSync()) {
      newFile.parent.createSync(recursive: true);
      legacyFile.renameSync(newFile.path);
    }
    if (newFile.existsSync()) {
      return json.decode(newFile.readAsStringSync()) as Map<String, dynamic>;
    }
  } catch (_) {}
  return {};
}

void savePrefs(Map<String, dynamic> data) {
  try {
    final file = File(prefsPath);
    file.parent.createSync(recursive: true);
    final existing = _loadPrefs();
    file.writeAsStringSync(json.encode({...existing, ...data}));
  } catch (_) {}
}

const Color _darkScaffoldBg = Color(0xFF0D1117);
const Color _darkDivider = Color(0xFF30363D);
const Color _lightDivider = Color(0xFFD0D7DE);

ThemeData _buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorSchemeSeed: Colors.blue,
    scaffoldBackgroundColor: _darkScaffoldBg,
    dividerColor: _darkDivider,
    fontFamily: Platform.isWindows ? 'Microsoft YaHei' : null,
    visualDensity: VisualDensity.compact,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
    cardTheme: const CardThemeData(
      elevation: AppElevation.card,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      isDense: false,
    ),
    dividerTheme: const DividerThemeData(
      thickness: 1,
      indent: 0,
      endIndent: 0,
      space: AppSpacing.sm,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      minLeadingWidth: 24,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
    ),
  );
}

ThemeData _buildLightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: Colors.blue,
    scaffoldBackgroundColor: Colors.white,
    dividerColor: _lightDivider,
    fontFamily: Platform.isWindows ? 'Microsoft YaHei' : null,
    visualDensity: VisualDensity.compact,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
    cardTheme: const CardThemeData(
      elevation: AppElevation.card,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      isDense: false,
    ),
    dividerTheme: const DividerThemeData(
      thickness: 1,
      indent: 0,
      endIndent: 0,
      space: AppSpacing.sm,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      minLeadingWidth: 24,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
    ),
  );
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeProvider() {
    final prefs = _loadPrefs();
    if (prefs.containsKey('dark')) {
      _themeMode = prefs['dark'] == false ? ThemeMode.light : ThemeMode.dark;
    }
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;
  ThemeData get darkTheme => _buildDarkTheme();
  ThemeData get lightTheme => _buildLightTheme();

  void toggle() {
    _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    savePrefs({'dark': isDark});
    notifyListeners();
  }

  /// Set a specific theme mode (used by the settings page's theme
  /// segmented control). No-op when the value is unchanged.
  void setDark(bool dark) {
    if (isDark == dark) return;
    _themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    savePrefs({'dark': dark});
    notifyListeners();
  }
}
