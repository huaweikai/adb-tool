import 'package:flutter/material.dart';
import '../i18n.dart' as i18n;

class LocaleProvider extends ChangeNotifier {
  String get currentLang => i18n.currentLang;

  void toggle() {
    i18n.setLang(i18n.currentLang == 'zh' ? 'en' : 'zh');
    notifyListeners();
  }

  void setLocale(String lang) {
    i18n.setLang(lang);
    notifyListeners();
  }
}
