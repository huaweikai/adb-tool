import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

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

  void toggle() {
    _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    savePrefs({'dark': isDark});
    notifyListeners();
  }
}
