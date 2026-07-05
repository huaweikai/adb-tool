import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CrashNotificationPref extends ChangeNotifier {
  static const _key = 'crash_toast_enabled';
  bool _enabled = true;

  CrashNotificationPref() {
    _load();
  }

  bool get enabled => _enabled;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_key) ?? true;
    notifyListeners();
  }

  Future<void> toggle() async {
    _enabled = !_enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _enabled);
    notifyListeners();
  }
}
