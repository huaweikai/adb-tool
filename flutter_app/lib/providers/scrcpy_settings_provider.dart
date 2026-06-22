// Per-device scrcpy settings. Each device serial gets its own row in
// SharedPreferences so the user can have, e.g., "Pixel 7: H.265+60fps,
// 4K mirror" and "Galaxy Tab: H.264+30fps, low bitrate" without the
// settings fighting each other.
//
// Storage: a single JSON blob per serial under
//   scrcpy_opts_<serial> = <json>
// Read on device-select (so the panel is ready by the time it renders)
// and write on every change. We don't debounce — settings change
// rarely, and a stale persisted value is much worse than a tiny amount
// of write amplification.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scrcpy_options.dart';

class ScrcpySettingsProvider extends ChangeNotifier {
  static const _keyPrefix = 'scrcpy_opts_';

  final Map<String, ScrcpyOptions> _cache = {};
  String? _activeSerial;
  SharedPreferences? _prefs;

  ScrcpyOptions? get current => _activeSerial == null ? null : _cache[_activeSerial!];

  /// Switch which device's settings are surfaced through [current].
  /// Loads from SharedPreferences on first switch — sync if already
  /// cached, async otherwise.
  void setActiveSerial(String? serial) {
    if (_activeSerial == serial) return;
    _activeSerial = serial;
    if (serial != null && !_cache.containsKey(serial)) {
      _loadFor(serial);
    } else {
      // Already cached or switching to null — notify now.
      notifyListeners();
    }
  }

  /// Update a field on the active device's settings. The whole options
  /// object is replaced (immutable model), and persisted to disk.
  Future<void> update(ScrcpyOptions Function(ScrcpyOptions current) mutate) async {
    final serial = _activeSerial;
    if (serial == null) return;
    final current = _cache[serial] ?? ScrcpyOptions.defaults();
    final next = mutate(current);
    _cache[serial] = next;
    notifyListeners();
    await _saveFor(serial, next);
  }

  Future<void> resetActiveToDefaults() async {
    final serial = _activeSerial;
    if (serial == null) return;
    _cache[serial] = ScrcpyOptions.defaults();
    notifyListeners();
    await _saveFor(serial, ScrcpyOptions.defaults());
  }

  String _key(String serial) => '$_keyPrefix$serial';

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  void _loadFor(String serial) {
    // Async — fire and forget. notifyListeners happens after the read.
    _ensurePrefs().then((prefs) {
      final raw = prefs.getString(_key(serial));
      if (raw != null && raw.isNotEmpty) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          _cache[serial] = ScrcpyOptions.fromJson(map);
        } catch (_) {
          // Corrupted blob — fall back to defaults and overwrite next save.
          _cache[serial] = ScrcpyOptions.defaults();
        }
      } else {
        _cache[serial] = ScrcpyOptions.defaults();
      }
      // Only notify if this is still the active device; otherwise the
      // user moved on and the notify would be confusing.
      if (_activeSerial == serial) {
        notifyListeners();
      }
    });
  }

  Future<void> _saveFor(String serial, ScrcpyOptions opts) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(_key(serial), jsonEncode(opts.toJson()));
  }
}
