// DAO for the test-sessions family. Wraps every read and write that the
// test-session UI / provider needs against the 7 test-session tables.
//
// Streams (`watch*`) are what the UI subscribes to for reactive updates.
// Mutations (`insert*` / `update*` / `delete*`) are fire-and-forget for
// most callers; the provider is responsible for batching them into a
// transaction when atomicity matters.
import 'package:drift/drift.dart';

import '../../models/test_session.dart';
import '../database.dart';
import '../tables/test_session_artifacts.dart';
import '../tables/test_session_events.dart';
import '../tables/test_session_issue_artifacts.dart';
import '../tables/test_session_issues.dart';
import '../tables/test_session_notes.dart';
import '../tables/test_session_plan_items.dart';
import '../tables/test_sessions.dart';

part 'test_sessions_dao.g.dart';

@DriftAccessor(tables: [
  TestSessions,
  TestSessionEvents,
  TestSessionArtifacts,
  TestSessionNotes,
  TestSessionIssues,
  TestSessionPlanItems,
  TestSessionIssueArtifacts,
])
class TestSessionsDao extends DatabaseAccessor<AppDatabase>
    with _$TestSessionsDaoMixin {
  TestSessionsDao(super.db);

  // ===== Streams: test_sessions ===========================================

  /// All sessions for one device, newest first. The Hub's history list
  /// subscribes to this.
  Stream<List<TestSessionRow>> watchSessionsForDevice(String serial) {
    return (select(testSessions)
          ..where((t) => t.deviceSerial.equals(serial))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .watch();
  }

  /// All RUNNING sessions across all devices. The floating action button
  /// subscribes to this to show "there's an active test on N device(s)".
  Stream<List<TestSessionRow>> watchAllActiveSessions() {
    return (select(testSessions)..where((t) => t.status.equals(0))).watch();
  }

  /// The (at most one) RUNNING session for a given device. Hub's "resume
  /// active session" panel subscribes to this. The partial unique index
  /// guarantees at most one row, so we use watchSingleOrNull.
  Stream<TestSessionRow?> watchActiveSessionForDevice(String serial) {
    return (select(testSessions)
          ..where(
              (t) => t.deviceSerial.equals(serial) & t.status.equals(0))
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Watch a single session by id (live-updates if the row changes).
  Stream<TestSessionRow?> watchSessionById(String id) {
    return (select(testSessions)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  // ===== Streams: children ================================================

  Stream<List<TestSessionEventRow>> watchEventsForSession(String sessionId) {
    return (select(testSessionEvents)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.time)]))
        .watch();
  }

  Stream<List<TestSessionArtifactRow>> watchArtifactsForSession(
      String sessionId) {
    return (select(testSessionArtifacts)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Stream<List<TestSessionIssueRow>> watchIssuesForSession(String sessionId) {
    return (select(testSessionIssues)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Stream<List<TestSessionNoteRow>> watchNotesForSession(String sessionId) {
    return (select(testSessionNotes)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Stream<List<TestSessionPlanItemRow>> watchPlanItemsForSession(
      String sessionId) {
    return (select(testSessionPlanItems)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  // ===== One-shot reads ===================================================

  Future<TestSessionRow?> findSessionById(String id) {
    return (select(testSessions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// All artifact rows linked to one issue (via the m:n table). Used by
  /// the "related artifacts" preview on the issue card.
  Future<List<TestSessionArtifactRow>> findArtifactsForIssue(String issueId) async {
    final query = select(testSessionIssueArtifacts).join([
      innerJoin(
        testSessionArtifacts,
        testSessionArtifacts.id.equalsExp(testSessionIssueArtifacts.artifactId),
      ),
    ])
      ..where(testSessionIssueArtifacts.issueId.equals(issueId));
    final rows = await query.get();
    return rows.map((r) => r.readTable(testSessionArtifacts)).toList();
  }

  // ===== Mutations: test_sessions =========================================

  /// Insert a new session. Throws if the partial unique index rejects it
  /// (another running session already exists for the same device) — the
  /// app-level check in TestSessionProvider.startSession should run first.
  Future<void> insertSession(TestSessionsCompanion entry) {
    return into(testSessions).insert(entry);
  }

  /// Patch a session's status (and endedAt when transitioning to
  /// finished / abandoned). Other fields are left untouched.
  Future<void> updateSessionStatus(
    String id,
    TestSessionStatus status, {
    DateTime? endedAt,
  }) async {
    await (update(testSessions)..where((t) => t.id.equals(id))).write(
      TestSessionsCompanion(
        status: Value(status),
        endedAt: endedAt != null ? Value(endedAt) : const Value.absent(),
      ),
    );
  }

  /// Delete a session and (via cascade) all its children rows. Callers are
  /// responsible for removing the on-disk artifact directory separately.
  Future<int> deleteSession(String id) {
    return (delete(testSessions)..where((t) => t.id.equals(id))).go();
  }

  /// Stamp the session as the "owner" of a screen recording that's
  /// currently in flight on the session's device. Only the file_browser
  /// and test_session values are meaningful; anything else is treated
  /// as a clear (pass null). The supporting partial index
  /// (`idx_sessions_recording_owner`) makes the cross-screen
  /// "is anyone recording on this device" lookup O(1).
  Future<void> updateSessionScreenRecordOwner(
    String id,
    String? owner,
  ) async {
    await (update(testSessions)..where((t) => t.id.equals(id))).write(
      TestSessionsCompanion(
        screenRecordOwner: owner == null
            ? const Value(null)
            : Value(owner),
      ),
    );
  }

  /// All sessions across all devices that currently have a screen
  /// recording attached. Returns at most one row per device (the
  /// partial index ensures it). Used by the file-browser to detect
  /// when a recording was started on the test-session side.
  Stream<List<TestSessionRow>> watchRecordingOwnersForDevice(String serial) {
    return (select(testSessions)
          ..where((t) =>
              t.deviceSerial.equals(serial) &
              t.screenRecordOwner.isNotNull())
          ..limit(1))
        .watch();
  }

  // ===== Mutations: children ==============================================

  Future<void> insertEvent(TestSessionEventsCompanion entry) {
    return into(testSessionEvents).insert(entry);
  }

  Future<void> insertArtifact(TestSessionArtifactsCompanion entry) {
    return into(testSessionArtifacts).insert(entry);
  }

  Future<void> insertNote(TestSessionNotesCompanion entry) {
    return into(testSessionNotes).insert(entry);
  }

  Future<void> insertIssue(TestSessionIssuesCompanion entry) {
    return into(testSessionIssues).insert(entry);
  }

  /// Bulk insert plan items (typically at session start when the test
  /// flow is snapshotted). Uses a single batch for one round-trip.
  Future<void> insertPlanItems(
      List<TestSessionPlanItemsCompanion> entries) {
    return batch((b) => b.insertAll(testSessionPlanItems, entries));
  }

  /// Patch a plan item. Pass only the fields you want to change.
  Future<void> updatePlanItem(
    String id, {
    TestSessionPlanStatus? status,
    String? message,
    DateTime? startedAt,
    DateTime? updatedAt,
  }) async {
    await (update(testSessionPlanItems)..where((t) => t.id.equals(id))).write(
      TestSessionPlanItemsCompanion(
        status: status != null ? Value(status) : const Value.absent(),
        message: message != null ? Value(message) : const Value.absent(),
        startedAt:
            startedAt != null ? Value(startedAt) : const Value.absent(),
        updatedAt:
            updatedAt != null ? Value(updatedAt) : const Value.absent(),
      ),
    );
  }

  /// Link an artifact to an issue. Idempotent (insertOrIgnore) so retries
  /// after a transient DB error don't blow up with a duplicate-key error.
  Future<void> linkIssueArtifact(String issueId, String artifactId) {
    return into(testSessionIssueArtifacts).insert(
      TestSessionIssueArtifactsCompanion.insert(
        issueId: issueId,
        artifactId: artifactId,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Delete a single artifact row. Used when the user removes an
  /// attachment from a running session.
  Future<int> deleteArtifact(String id) {
    return (delete(testSessionArtifacts)..where((t) => t.id.equals(id))).go();
  }

  /// Delete a single event row. When the event has an associated artifact
  /// (screenshot / video / log), callers should delete the artifact first.
  Future<int> deleteEvent(String id) {
    return (delete(testSessionEvents)..where((t) => t.id.equals(id))).go();
  }
}
