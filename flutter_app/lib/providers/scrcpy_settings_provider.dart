// Per-device scrcpy settings. Each device serial gets its own row in
// the `scrcpy_options_` DB table so the user can have, e.g.,
// "Pixel 7: H.265+60fps, 4K mirror" and "Galaxy Tab: H.264+30fps,
// low bitrate" without the settings fighting each other.
//
// Read on device-select (so the panel is ready by the time it renders)
// and write on every change. We don't debounce — settings change
// rarely, and a stale persisted value is much worse than a tiny amount
// of write amplification.
//
// v5: switched persistence from SharedPreferences to the DB. The DAO
// already wipes the corresponding `scrcpy_opts_<serial>` SP keys on
// first cold start (see database.dart _wipeLegacyPrefs), so there
// is no data left behind in SP after this migration.
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../db/database.dart';
import '../models/scrcpy_options.dart';

class ScrcpySettingsProvider extends ChangeNotifier {
  final AppDatabase _db;

  final Map<String, ScrcpyOptions> _cache = {};
  String? _activeSerial;

  ScrcpySettingsProvider({required AppDatabase db}) : _db = db;

  ScrcpyOptions? get current =>
      _activeSerial == null ? null : _cache[_activeSerial!];

  /// Switch which device's settings are surfaced through [current].
  /// Loads from the DB on first switch — sync if already cached, async
  /// otherwise.
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
  /// object is replaced (immutable model), and persisted to the DB.
  Future<void> update(ScrcpyOptions Function(ScrcpyOptions current) mutate) async {
    final serial = _activeSerial;
    if (serial == null) return;
    final current = _cache[serial] ?? ScrcpyOptions.defaults();
    final next = mutate(current);
    _cache[serial] = next;
    notifyListeners();
    await _db.scrcpyOptionsDao.upsert(serial, next);
  }

  Future<void> resetActiveToDefaults() async {
    final serial = _activeSerial;
    if (serial == null) return;
    final defaults = ScrcpyOptions.defaults();
    _cache[serial] = defaults;
    notifyListeners();
    await _db.scrcpyOptionsDao.upsert(serial, defaults);
  }

  void _loadFor(String serial) {
    // Async — fire and forget. notifyListeners happens after the read.
    _db.scrcpyOptionsDao.getBySerial(serial).then((opts) {
      _cache[serial] = opts ?? ScrcpyOptions.defaults();
      // Only notify if this is still the active device; otherwise the
      // user moved on and the notify would be confusing.
      if (_activeSerial == serial) {
        notifyListeners();
      }
    });
  }
}
