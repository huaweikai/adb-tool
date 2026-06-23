// Global clipboard-send history. Shared across all devices (any
// device the user sends text to shows up in the same list) — the
// clipboard tab acts as a "recently used snippets" library rather
// than a per-device log.
//
// Backed by `sent_clipboard_entry` in the DB. The provider keeps an
// in-memory mirror of the DAO's `watchRecent` stream so the UI can
// use a regular `ChangeNotifier` and avoid stream-builder noise.
//
// v5: switched persistence from SharedPreferences to the DB. The DAO
// already wipes the corresponding `clipboard_sent_history` SP key on
// first cold start (see database.dart _wipeLegacyPrefs), so there
// is no data left behind in SP after this migration.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../db/database.dart';

class ClipboardHistoryProvider extends ChangeNotifier {
  final AppDatabase _db;
  final int _historyLimit;

  StreamSubscription<List<SentClipboardEntryData>>? _sub;
  List<SentClipboardEntryData> _entries = const [];

  ClipboardHistoryProvider({
    required AppDatabase db,
    int historyLimit = 20,
  })  : _db = db,
        _historyLimit = historyLimit;

  List<SentClipboardEntryData> get entries => _entries;

  int get historyLimit => _historyLimit;

  /// Subscribe to the DAO's watchRecent stream. Safe to call once from
  /// the provider's create callback. Cancels the previous sub if
  /// called again (e.g. on hot-restart).
  void load() {
    _sub?.cancel();
    _sub = _db.sentClipboardEntryDao
        .watchRecent(limit: _historyLimit)
        .listen((rows) {
      _entries = rows;
      notifyListeners();
    });
  }

  /// Record that the user sent [text] to a device. Dedups by content
  /// and bumps `sendCount` if the text was sent before.
  Future<void> recordSent(String text) =>
      _db.sentClipboardEntryDao.insertOrBump(text, historyLimit: _historyLimit);

  Future<void> toggleFavorite(int id) =>
      _db.sentClipboardEntryDao.toggleFavorite(id);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
