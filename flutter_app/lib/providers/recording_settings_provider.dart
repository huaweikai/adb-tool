// Recording settings — global UI preference for which screen-recording
// method to use (legacy `adb screenrecord` vs the new scrcpy-based
// windowless recording path). Persisted on the AppStates singleton
// row so the choice survives across launches and is visible to every
// surface that wants to start a recording.
//
// Read path: any consumer (capture mixin, recording settings page)
// calls `method` to get the current choice. The provider also
// surfaces the user's chosen scrcpy output directory so the capture
// mixin can hand it to the backend start call without a separate
// read.
//
// Write path: every mutation goes through [setMethod] / [setOutputDir]
// so the DB write and the in-memory state stay in sync. We don't
// debounce — settings change rarely and a stale persisted value is
// much worse than a tiny amount of write amplification.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../db/database.dart';

/// The two recording methods. Stored in the DB as a plain text
/// column; this enum is the typed view for the rest of the app.
enum ScreenRecordMethod {
  /// Legacy `adb screenrecord` path. Always available, but on some
  /// devices produces a corrupt / unusable MP4 (the original
  /// motivation for adding the scrcpy path).
  adb,

  /// Windowless scrcpy recording (`scrcpy --no-window --record=…`).
  /// Works around the `adb screenrecord` bugs on those devices, at
  /// the cost of needing a user-picked output directory and a
  /// bundled scrcpy binary (macOS / Windows only).
  scrcpy;

  String get dbValue {
    switch (this) {
      case ScreenRecordMethod.adb:
        return 'adb';
      case ScreenRecordMethod.scrcpy:
        return 'scrcpy';
    }
  }

  static ScreenRecordMethod fromDb(String s) {
    switch (s) {
      case 'scrcpy':
        return ScreenRecordMethod.scrcpy;
      case 'adb':
      default:
        return ScreenRecordMethod.adb;
    }
  }
}

class RecordingSettingsProvider extends ChangeNotifier {
  final AppDatabase _db;

  ScreenRecordMethod _method = ScreenRecordMethod.adb;
  String? _outputDir;
  bool _loaded = false;

  RecordingSettingsProvider({required AppDatabase db}) : _db = db;

  ScreenRecordMethod get method => _method;
  String? get outputDir => _outputDir;
  bool get loaded => _loaded;

  /// True iff the user has picked scrcpy mode AND chosen an output
  /// directory. The capture mixin uses this to decide whether to
  /// show a "先在录屏设置中选择目录" snackbar vs. actually starting
  /// the recording.
  bool get scrcpyConfigured =>
      _method == ScreenRecordMethod.scrcpy &&
      _outputDir != null &&
      _outputDir!.isNotEmpty;

  /// One-shot read on app start so the in-memory state matches the
  /// DB before any consumer reads it. Safe to call multiple times —
  /// only the first call hits the DB; later calls return immediately.
  Future<void> load() async {
    if (_loaded) return;
    final state = await _db.appStatesDao.getAppState();
    _method = ScreenRecordMethod.fromDb(state.screenRecordMethod);
    _outputDir = state.scrcpyRecordOutputDir;
    _loaded = true;
    notifyListeners();
  }

  /// Switch the recording method. Persisted to the DB on success.
  Future<void> setMethod(ScreenRecordMethod method) async {
    if (_method == method && _loaded) return;
    _method = method;
    notifyListeners();
    await _db.appStatesDao.updateAppState(screenRecordMethod: method.dbValue);
  }

  /// Update the scrcpy output directory. Pass null to clear it
  /// (the user can "unset" the directory to be forced to re-pick).
  Future<void> setOutputDir(String? dir) async {
    if (_outputDir == dir && _loaded) return;
    _outputDir = dir;
    notifyListeners();
    if (dir == null) {
      await _db.appStatesDao.updateAppState(clearScrcpyRecordOutputDir: true);
    } else {
      await _db.appStatesDao.updateAppState(scrcpyRecordOutputDir: dir);
    }
  }
}
