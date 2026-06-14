import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

String get _prefsPath {
  final home = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '.';
  return '$home/.adb_tool_prefs.json';
}

ThemeMode _loadTheme() {
  try {
    final f = File(_prefsPath);
    if (f.existsSync()) {
      final data = json.decode(f.readAsStringSync());
      return data['dark'] == false ? ThemeMode.light : ThemeMode.dark;
    }
  } catch (_) {}
  return ThemeMode.dark;
}

void _saveTheme(bool dark) {
  try {
    File(_prefsPath).writeAsStringSync(json.encode({'dark': dark}));
  } catch (_) {}
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = _loadTheme();

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  void toggle() {
    _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    _saveTheme(isDark);
    notifyListeners();
  }
}
