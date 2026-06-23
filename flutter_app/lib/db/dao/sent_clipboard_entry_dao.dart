// DAO for SentClipboardEntry (global, per-device-shared).
//
// Trim policy: `watchRecent(limit)` emits favorites first, then the N
// most recent non-favorites. `insert` dedups by `content` — if the same
// text is sent again, the existing row is moved to the top and
// `sendCount` is incremented. `trimTo` enforces the cap so the table
// doesn't grow unbounded.
import 'dart:async';

import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/sent_clipboard_entry.dart';

part 'sent_clipboard_entry_dao.g.dart';

@DriftAccessor(tables: [SentClipboardEntry])
class SentClipboardEntryDao extends DatabaseAccessor<AppDatabase>
    with _$SentClipboardEntryDaoMixin {
  SentClipboardEntryDao(super.db);

  /// Watch recent history. Favorites first (pinned at top), then the
  /// N most recent non-favorites. Stream re-emits on any change.
  Stream<List<SentClipboardEntryData>> watchRecent({int limit = 20}) {
    // Two queries unioned in Dart to keep the SQL portable — drift's
    // UNION support is a bit clunky, and the favorites set is tiny
    // (users favorite at most a handful of snippets).
    final favs = (select(sentClipboardEntry)
          ..where((t) => t.favorite.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.sentAt)]))
        .watch();
    final recents = (select(sentClipboardEntry)
          ..where((t) => t.favorite.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.sentAt)])
          ..limit(limit))
        .watch();
    return _combineLatest2(favs, recents, (f, r) => [...f, ...r]);
  }

  /// Insert a new entry. If a row with the same `content` already
  /// exists, it is moved to the top (sent_at updated) and `sendCount`
  /// is incremented — the clipboard tab treats repeats as "this is a
  /// useful snippet, surface it higher".
  ///
  /// After the insert, `trimTo(_historyLimit)` is called to enforce the
  /// cap. The cap is fixed here rather than in the UI to keep the
  /// policy in one place.
  Future<void> insertOrBump(String text, {int historyLimit = 20}) async {
    if (text.isEmpty) return;
    await transaction(() async {
      final existing = await (select(sentClipboardEntry)
            ..where((t) => t.content.equals(text))
            ..limit(1))
          .getSingleOrNull();
      if (existing != null) {
        await (update(sentClipboardEntry)
              ..where((t) => t.id.equals(existing.id)))
            .write(SentClipboardEntryCompanion(
          sentAt: Value(DateTime.now()),
          sendCount: Value(existing.sendCount + 1),
        ));
      } else {
        await into(sentClipboardEntry).insert(
          SentClipboardEntryCompanion.insert(
            content: text,
            sentAt: DateTime.now(),
            favorite: false,
            sendCount: 1,
          ),
        );
      }
      await trimTo(historyLimit);
    });
  }

  /// Flip the favorite flag on a single row.
  Future<void> toggleFavorite(int id) async {
    final row =
        await (select(sentClipboardEntry)..where((t) => t.id.equals(id)))
            .getSingleOrNull();
    if (row == null) return;
    await (update(sentClipboardEntry)..where((t) => t.id.equals(id)))
        .write(SentClipboardEntryCompanion(
      favorite: Value(!row.favorite),
    ));
  }

  /// Keep all favorites and the N most recent non-favorites; delete
  /// everything older than that. Safe to call repeatedly.
  Future<void> trimTo(int maxNonFavorites) async {
    // 1. Find the cutoff: the sentAt of the Nth most recent
    //    non-favorite row.
    final cutoff = await (select(sentClipboardEntry)
          ..where((t) => t.favorite.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.sentAt)])
          ..limit(maxNonFavorites, offset: maxNonFavorites))
        .getSingleOrNull();
    // 2. Delete all non-favorite rows older than the cutoff.
    if (cutoff != null) {
      await (delete(sentClipboardEntry)
            ..where((t) =>
                t.favorite.equals(false) &
                t.sentAt.isSmallerThanValue(cutoff.sentAt)))
          .go();
    }
  }

  /// Wipe everything (favorites included). Not currently exposed to
  /// the UI but kept here for future "clear all" affordance.
  Future<int> clearAll() {
    return delete(sentClipboardEntry).go();
  }
}

// Tiny helper to merge two streams into one, emitting whenever either
// input changes. Kept here (rather than reaching for rxdart) because
// the rest of the codebase is stream-builder-free.
Stream<R> _combineLatest2<A, B, R>(
  Stream<A> a,
  Stream<B> b,
  R Function(A, B) combine,
) {
  late StreamController<R> controller;
  A? lastA;
  B? lastB;
  bool hasA = false;
  bool hasB = false;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;

  void emit() {
    if (hasA && hasB) {
      controller.add(combine(lastA as A, lastB as B));
    }
  }

  controller = StreamController<R>(
    onListen: () {
      subA = a.listen((v) {
        lastA = v;
        hasA = true;
        emit();
      }, onError: controller.addError);
      subB = b.listen((v) {
        lastB = v;
        hasB = true;
        emit();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
    },
  );
  return controller.stream;
}
