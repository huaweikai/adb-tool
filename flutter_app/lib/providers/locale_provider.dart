import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../i18n.dart' as i18n;
import 'theme_provider.dart';

class LocaleProvider extends ChangeNotifier {
  LocaleProvider() {
    final prefs = _loadPrefsMap();
    if (prefs.containsKey('lang')) {
      i18n.setLang(prefs['lang'] as String);
    }
  }

  String get currentLang => i18n.currentLang;

  void toggle() {
    final newLang = i18n.currentLang == 'zh' ? 'en' : 'zh';
    i18n.setLang(newLang);
    savePrefs({'lang': newLang});
    notifyListeners();
  }

  void setLocale(String lang) {
    i18n.setLang(lang);
    savePrefs({'lang': lang});
    notifyListeners();
  }
}

Map<String, dynamic> _loadPrefsMap() {
  try {
    final file = File(prefsPath);
    if (file.existsSync()) {
      return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
    }
  } catch (_) {}
  return {};
}
