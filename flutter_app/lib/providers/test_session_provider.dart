// Test session — DB-backed implementation.
//
// All state lives in `adb_tool.db`. This provider exposes:
//
//   1. **Stream accessors** (preferred for new UI) —
//        watchSessionsForDevice, watchAllActiveSessions,
//        watchActiveSessionForDevice, watchSessionById,
//        watchEventsForSession, watchArtifactsForSession,
//        watchIssuesForSession, watchNotesForSession,
//        watchPlanItemsForSession.
//
//   2. **Legacy accessors** (kept working for the in-flight test_session_screen
//      rewrite; removed in step 7) — `currentSession` and
//      `hasRunningSession`, which return a hydrated TestSession model.
//
//   3. **Mutations** — `startSession`, `finishSession`, `addNote`,
//      `markIssue`, `updateTestPlanItem`, `saveScreenshotBytes`,
//      `saveVideoBytes`, `saveLogcat`, `saveLogcatFile`,
//      `markLogcatStarted`, `markScreenRecordStarted`, `deleteArtifact`,
//      `deleteSession`, `loadHistoricalSession`, `exportSession`,
//      `writeReport`, `buildIssueClipboardText`. Every multi-row write
//      runs inside `db.transaction(...)` so partial state never escapes.
//
// File I/O for screenshots / videos / logs is delegated to
// `SessionAttachmentStore`; this provider wraps the file write and the
// DB row insert into the same transaction.
import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart' show Value;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../db/database.dart';
import '../db/dao/test_sessions_dao.dart';
import '../models/test_session.dart';
import '../services/screen_record_owner.dart'
    show ScreenRecordOwner, ScreenRecordOwnerX;
import 'device_provider.dart';
import 'test_session/attachment_store.dart';
import 'test_session/exporter.dart';
import 'test_session/formatter.dart';
import 'test_session/session_translate.dart';

export 'test_session/session_translate.dart' show SessionTranslate;

class TestSessionProvider extends ChangeNotifier {
  final AppDatabase _db;
  late final TestSessionsDao _dao;
  final SessionAttachmentStore _attachments;
  final SessionExporter _exporter;

  SessionTranslate _translate;
  String? _translationLanguage;

  // ── Device-offline → recording cleanup bridge ─────────────────────
  StreamSubscription<DeviceOfflineEvent>? _deviceOfflineSub;

  /// Emits the serial whose active test-session screen recording was
  /// torn down because the device went offline mid-recording. UI
  /// subscribes to this to show "录制中断，附件缺失" instead of the
  /// normal "录制已结束" snackbar — the file was on the now-unreachable
  /// device storage, so no attachment was pulled. Distinct from the
  /// logcat provider's same-named stream so listeners can route
  /// messages correctly.
  final _recordingInterrupted = StreamController<String>.broadcast();
  Stream<String> get onRecordingInterrupted => _recordingInterrupted.stream;

  /// The session the provider currently considers "active" — the one that
  /// was started most recently and not yet finished. Mutations without
  /// an explicit sessionId operate against this. Cleared on finish.
  String? _activeSessionId;
  TestSession? _currentHydrated;

  TestSessionProvider({
    required AppDatabase db,
    SessionTranslate? translate,
    DeviceProvider? deviceProvider,
  })  : _db = db,
        _attachments = SessionAttachmentStore(),
        _exporter = SessionExporter(translate ?? _fallbackTranslate),
        _translate = translate ?? _fallbackTranslate {
    _dao = _db.testSessionsDao;
    // Best-effort: rehydrate the most recent running session so the UI
    // can show "resume" after a restart. Failure is non-fatal.
    unawaited(_tryResume());

    // Bridge device-offline events → session dialog.
    // The actual dialog is shown by the UI layer (HomeScreen) which
    // listens to onDeviceOfflineDialog; this provider owns the logic.
    if (deviceProvider != null) {
      _deviceOfflineSub =
          deviceProvider.onDeviceOffline.listen(_onDeviceOffline);
    }
  }

  void _onDeviceOffline(DeviceOfflineEvent event) {
    debugPrint('[TestSessionProvider] device offline: ${event.serial}');
    // The DB lookup needs the stable identity (saved_devices.serial =
    // ro.serialno post-v8→v9), not the transient adb-serial in
    // event.serial. Fall back to event.serial if hardwareSerial is
    // empty (e.g. unauthorized device — its DB row is keyed by
    // adb-serial under that case).
    final lookup = event.hardwareSerial ?? event.serial;
    // Was a recording owned by anyone running on this device? The DB
    // row tracks recording_owner (testSession / fileBrowser / null).
    // We don't await — the snackbar UX fires from the stream callback
    // regardless of when the DB write actually lands.
    unawaited(_stopRecordingIfNeeded(lookup));
  }

  Future<void> _stopRecordingIfNeeded(String serial) async {
    try {
      // Peek the row first so we can decide whether to fire the
      // "interrupted" signal. Reading then writing is two trips to
      // SQLite but they're indexed by primary key, both fast.
      final row = await _db.savedDevicesDao.getSavedDeviceBySerial(serial);
      final wasRecording = row?.recordingOwner != null;
      await _db.savedDevicesDao.clearScreenRecord(serial);
      if (wasRecording && !_recordingInterrupted.isClosed) {
        _recordingInterrupted.add(serial);
      }
    } catch (e) {
      debugPrint(
          '[TestSessionProvider] failed to clear recording on offline: $e');
    }
  }

  Future<void> _tryResume() async {
    try {
      final running = await _dao.watchAllActiveSessions().first;
      if (running.isNotEmpty) {
        _activeSessionId = running.first.id;
        await _refreshCurrentHydrated();
      }
    } catch (_) {}
  }

  // ===== Translator ========================================================

  void setTranslator(SessionTranslate t, {String? language}) {
    if (language != null && language == _translationLanguage) {
      _translate = t;
      return;
    }
    _translate = t;
    _translationLanguage = language;
    notifyListeners();
  }

  String _t(String key, [Map<String, String>? args]) => _translate(key, args);

  // ===== Stream accessors (preferred) ======================================

  Stream<List<TestSessionRow>> watchSessionsForDevice(String serial) =>
      _dao.watchSessionsForDevice(serial);

  Stream<List<TestSessionRow>> watchAllActiveSessions() =>
      _dao.watchAllActiveSessions();

  Stream<TestSessionRow?> watchActiveSessionForDevice(String serial) =>
      _dao.watchActiveSessionForDevice(serial);

  Stream<TestSessionRow?> watchSessionById(String id) =>
      _dao.watchSessionById(id);

  Stream<List<TestSessionEventRow>> watchEventsForSession(String sessionId) =>
      _dao.watchEventsForSession(sessionId);

  Stream<List<TestSessionArtifactRow>> watchArtifactsForSession(
          String sessionId) =>
      _dao.watchArtifactsForSession(sessionId);

  Stream<List<TestSessionIssueRow>> watchIssuesForSession(String sessionId) =>
      _dao.watchIssuesForSession(sessionId);

  Stream<List<TestSessionNoteRow>> watchNotesForSession(String sessionId) =>
      _dao.watchNotesForSession(sessionId);

  Stream<List<TestSessionPlanItemRow>> watchPlanItemsForSession(
          String sessionId) =>
      _dao.watchPlanItemsForSession(sessionId);

  // ===== Legacy accessors (kept until step 7) =============================

  /// Hydrated full TestSession for the active session, or null. Use
  /// `watch*ForSession` streams in new code instead.
  TestSession? get currentSession => _currentHydrated;
  bool get hasRunningSession =>
      _currentHydrated?.status == TestSessionStatus.running;

  void clearCurrentSessionIfDifferentDevice(String serial) {
    final current = _currentHydrated;
    if (current == null && _activeSessionId == null) return;
    if (current == null || current.deviceSerial != serial) {
      _activeSessionId = null;
      _currentHydrated = null;
      notifyListeners();
    }
  }

  /// Absolute on-disk path of the active session's logcat directory. The
  /// backend's session-logcat endpoint needs a real path; the legacy
  /// `TestSession.directoryPath` field is left empty, so the UI must use
  /// this getter instead. Returns null when no active session.
  Future<String?> currentSessionLogcatDir() async {
    final id = _activeSessionId;
    if (id == null) return null;
    final dir = await _attachments.artifactsDir(id);
    return dir.path;
  }

  Future<void> _refreshCurrentHydrated() async {
    final id = _activeSessionId;
    if (id == null) {
      _currentHydrated = null;
      notifyListeners();
      return;
    }
    _currentHydrated = await _hydrate(id);
    notifyListeners();
  }

  Future<TestSession?> _hydrate(String sessionId) async {
    final s = await _dao.findSessionById(sessionId);
    if (s == null) return null;
    // Start all five child-table queries before awaiting any of them.
    // The previous sequential `await … .first` per table made each
    // hydrate (called after every note / issue / screenshot mutation)
    // pay 5 isolate round-trips back-to-back. Drift's background
    // isolate still runs them in order, but dispatching them together
    // collapses the await/hop overhead from 5 round-trips to one batch.
    final eventsF = _dao.watchEventsForSession(sessionId).first;
    final artifactsF = _dao.watchArtifactsForSession(sessionId).first;
    final notesF = _dao.watchNotesForSession(sessionId).first;
    final issuesF = _dao.watchIssuesForSession(sessionId).first;
    final planItemsF = _dao.watchPlanItemsForSession(sessionId).first;
    final events = await eventsF;
    final artifacts = await artifactsF;
    final notes = await notesF;
    final issues = await issuesF;
    final planItems = await planItemsF;
    return _rowToModel(s, events, artifacts, notes, issues, planItems);
  }

  TestSession _rowToModel(
    TestSessionRow s,
    List<TestSessionEventRow> events,
    List<TestSessionArtifactRow> artifacts,
    List<TestSessionNoteRow> notes,
    List<TestSessionIssueRow> issues,
    List<TestSessionPlanItemRow> planItems,
  ) {
    return TestSession(
      id: s.id,
      name: s.name,
      type: s.type,
      status: s.status,
      startedAt: s.startedAt,
      endedAt: s.endedAt,
      directoryPath: '', // legacy field — base dir is derived per-call now
      deviceSerial: s.deviceSerial,
      deviceModel: s.deviceModel,
      deviceBrand: s.deviceBrand,
      deviceSdk: s.deviceSdk,
      packageName: s.packageName,
      note: s.note,
      events: events
          .map((e) => TestSessionEvent(
                id: e.id,
                type: e.type,
                time: e.time,
                title: e.title,
                detail: e.detail,
                filePath: e.filePath,
              ))
          .toList(),
      artifacts: artifacts
          .map((a) => TestSessionArtifact(
                id: a.id,
                kind: a.kind,
                name: a.name,
                path: a.path,
                createdAt: a.createdAt,
                size: a.size,
              ))
          .toList(),
      notes: notes
          .map((n) => TestSessionNote(
                id: n.id,
                createdAt: n.createdAt,
                content: n.content,
              ))
          .toList(),
      issues: issues
          .map((i) => TestSessionIssue(
                id: i.id,
                createdAt: i.createdAt,
                title: i.title,
                type: i.type,
                severity: i.severity,
                steps: i.steps,
                expected: i.expected,
                actual: i.actual,
                note: i.note,
                relatedArtifactIds: const [], // populated by hydration
              ))
          .toList(),
      testPlan: planItems
          .map((p) => TestSessionPlanItem(
                id: p.id,
                flowName: p.flowName,
                step: p.step,
                status: p.status,
                message: p.message,
                startedAt: p.startedAt,
                updatedAt: p.updatedAt,
              ))
          .toList(),
    );
  }

  // ===== Session lifecycle =================================================

  Future<TestSession> startSession({
    required String name,
    required String type,
    required String serial,
    String model = '',
    String brand = '',
    String sdk = '',
    String deviceDisplayName = '',
    String packageName = '',
    String note = '',
    List<TestSessionPlanItem> testPlanItems = const [],
  }) async {
    // 1. App-level guard: at most one running session per device.
    final existing = await _dao.watchActiveSessionForDevice(serial).first;
    if (existing != null) {
      throw StateError(_t('errorDeviceAlreadyHasRunningSession'));
    }

    final now = DateTime.now();
    final id = SessionFormatters.sessionId(now, name);

    // 2. Ensure base + subdirs on disk.
    final base = await _attachments.artifactsDir(id);
    for (final sub in ['screenshots', 'videos', 'logs', 'issue_logs']) {
      await Directory('${base.path}/$sub').create(recursive: true);
    }

    // 3. Transactional write of session + initial event + plan items.
    await _db.transaction(() async {
      await _dao.insertSession(TestSessionsCompanion.insert(
        id: id,
        name: name.trim().isEmpty ? _t('sessionUntitled') : name.trim(),
        type: type.trim().isEmpty ? _t('issueTypeOther') : type.trim(),
        status: TestSessionStatus.running,
        startedAt: now,
        deviceSerial: serial,
        deviceModel: Value(model),
        deviceBrand: Value(brand),
        deviceSdk: Value(sdk),
        packageName: Value(packageName.trim()),
        note: Value(note.trim()),
      ));

      await _dao.insertEvent(TestSessionEventsCompanion.insert(
        id: SessionFormatters.id(now),
        sessionId: id,
        type: TestSessionEventType.sessionCreated,
        time: now,
        title: _t('eventSessionCreated'),
        detail: Value(_t('eventSessionCreatedDetail', {
          'device': deviceDisplayName,
          'package':
              packageName.trim().isEmpty ? _t('notFilled') : packageName.trim(),
        })),
      ));

      if (testPlanItems.isNotEmpty) {
        final normalized = SessionFormatters.normalizeTestPlan(testPlanItems);
        await _dao.insertPlanItems([
          for (var i = 0; i < normalized.length; i++)
            TestSessionPlanItemsCompanion.insert(
              id: normalized[i].id.isEmpty
                  ? SessionFormatters.planItemId(id, i + 1)
                  : normalized[i].id,
              sessionId: id,
              flowName: normalized[i].flowName,
              step: normalized[i].step,
              status: TestSessionPlanStatus.pending,
              message: Value(normalized[i].message),
              sortOrder: Value(i),
            ),
        ]);
      }
    });

    _activeSessionId = id;
    await _refreshCurrentHydrated();
    final result = _currentHydrated;
    if (result == null) {
      throw StateError('Session not found after create: $id');
    }
    return result;
  }

  Future<TestSession> finishSession() async {
    final id = _requireActiveId();
    final now = DateTime.now();
    await _db.transaction(() async {
      await _dao.updateSessionStatus(id, TestSessionStatus.finished,
          endedAt: now);
      // Clear any screen-record owner flag — once the session is
      // finished, no recording can still be attached to it.
      await _dao.updateSessionScreenRecordOwner(id, null);
      await _dao.insertEvent(TestSessionEventsCompanion.insert(
        id: SessionFormatters.id(now),
        sessionId: id,
        type: TestSessionEventType.sessionFinished,
        time: now,
        title: _t('eventSessionFinished'),
      ));
    });
    final row = await _dao.findSessionById(id);
    if (row != null) {
      await _exporter.writeReport(row, db: _db);
    }
    // Don't rely on _currentHydrated — it may be null if initial hydration
    // failed while _activeSessionId was already set. Re-hydrate directly.
    _activeSessionId = null;
    await _refreshCurrentHydrated();
    final result = await _hydrate(id);
    if (result == null) {
      throw StateError('Session not found after finish: $id');
    }
    return result;
  }

  /// Mark the active session as abandoned (device dropped / user force-end).
  /// The report is still written; no further mutations will be accepted.
  Future<void> abandonActiveSession() async {
    final id = _requireActiveId();
    final now = DateTime.now();
    await _db.transaction(() async {
      await _dao.updateSessionStatus(id, TestSessionStatus.abandoned,
          endedAt: now);
      // Same as finishSession — drop the screen-record owner marker
      // so the cross-screen lookup doesn't return a stale row.
      await _dao.updateSessionScreenRecordOwner(id, null);
      await _dao.insertEvent(TestSessionEventsCompanion.insert(
        id: SessionFormatters.id(now),
        sessionId: id,
        type: TestSessionEventType.sessionFinished,
        time: now,
        title: _t('eventSessionAbandoned'),
        detail: Value(_t('eventSessionAbandonedDetail')),
      ));
    });
    final session = await _dao.findSessionById(id);
    if (session != null) {
      await _exporter.writeReport(session, db: _db);
    }
    _activeSessionId = null;
    await _refreshCurrentHydrated();
  }

  // ===== Mutations: test plan =============================================

  Future<void> updateTestPlanItem(
    String itemId,
    TestSessionPlanStatus status, {
    String message = '',
  }) async {
    final id = _requireActiveId();
    final now = DateTime.now();
    final items = await _dao.watchPlanItemsForSession(id).first;
    final current = items.firstWhere(
      (p) => p.id == itemId,
      orElse: () => throw StateError('plan item not found: $itemId'),
    );
    final startedAt = current.startedAt ??
        (status != TestSessionPlanStatus.pending ? now : null);

    await _db.transaction(() async {
      await _dao.updatePlanItem(
        itemId,
        status: status,
        message: message,
        startedAt: startedAt,
        updatedAt: now,
      );
      await _dao.insertEvent(TestSessionEventsCompanion.insert(
        id: SessionFormatters.id(now),
        sessionId: id,
        type: TestSessionEventType.testPlanUpdated,
        time: now,
        title: _t('eventTestPlanUpdated'),
        detail: Value('${current.flowName} / ${current.step}'),
      ));
    });
    await _refreshCurrentHydrated();
  }

  // ===== Mutations: notes & issues ========================================

  Future<void> addNote(String content) async {
    final id = _requireActiveId();
    final text = content.trim();
    if (text.isEmpty) return;
    final now = DateTime.now();
    await _db.transaction(() async {
      await _dao.insertNote(TestSessionNotesCompanion.insert(
        id: SessionFormatters.id(now),
        sessionId: id,
        createdAt: now,
        content: text,
      ));
      await _dao.insertEvent(TestSessionEventsCompanion.insert(
        id: SessionFormatters.id(now),
        sessionId: id,
        type: TestSessionEventType.noteAdded,
        time: now,
        title: _t('eventNoteAdded'),
        detail: Value(text),
      ));
    });
    await _refreshCurrentHydrated();
  }

  Future<TestSessionIssue> markIssue({
    required String title,
    TestSessionIssueType type = TestSessionIssueType.other,
    TestSessionIssueSeverity severity = TestSessionIssueSeverity.major,
    String steps = '',
    String expected = '',
    String actual = '',
    String note = '',
    String recentLogContent = '',
  }) async {
    final id = _requireActiveId();
    final now = DateTime.now();
    late final String issueId;

    await _db.transaction(() async {
      final issueNumber = await _dao.countIssuesForSession(id) + 1;
      issueId = SessionFormatters.issueId(id, issueNumber);

      // Snapshot the most-recent logcat to disk; best-effort.
      String? snapshotRelPath;
      String? snapshotName;
      if (recentLogContent.trim().isNotEmpty) {
        final snap = await _attachments.writeIssueRecentLog(
          sessionId: id,
          issueId: issueId,
          content: recentLogContent,
          now: now,
        );
        snapshotRelPath = snap.relativePath;
        snapshotName = snap.name;
      }

      // 1. Optional log snapshot artifact.
      if (snapshotRelPath != null) {
        await _dao.insertArtifact(TestSessionArtifactsCompanion.insert(
          id: SessionFormatters.id(now),
          sessionId: id,
          kind: TestSessionArtifactKind.log,
          name: snapshotName!,
          path: snapshotRelPath,
          createdAt: now,
          size: Value(0),
        ));
      }

      // 2. The issue itself.
      await _dao.insertIssue(TestSessionIssuesCompanion.insert(
        id: issueId,
        sessionId: id,
        createdAt: now,
        title: title.trim().isEmpty ? _t('issueUntitled') : title.trim(),
        type: type,
        severity: severity,
        steps: Value(steps.trim()),
        expected: Value(expected.trim()),
        actual: Value(actual.trim()),
        note: Value(note.trim()),
      ));

      // 3. Auto-link the most recent screenshot / video / log artifacts.
      final all = await _dao.watchArtifactsForSession(id).first;
      for (final kind in [
        TestSessionArtifactKind.screenshot,
        TestSessionArtifactKind.video,
        TestSessionArtifactKind.log,
      ]) {
        final matches = all.where((a) => a.kind == kind).toList();
        if (matches.isNotEmpty) {
          await _dao.linkIssueArtifact(issueId, matches.last.id);
        }
      }

      // 4. Issue-marked event.
      await _dao.insertEvent(TestSessionEventsCompanion.insert(
        id: SessionFormatters.id(now),
        sessionId: id,
        type: TestSessionEventType.issueMarked,
        time: now,
        title: _t('eventIssueMarked'),
        detail: Value(
            '${SessionFormatters.severityLabel(_t, severity)} / ${SessionFormatters.issueTypeLabel(_t, type)} / ${title.trim().isEmpty ? _t('issueUntitled') : title.trim()}'),
      ));
    });
    await _refreshCurrentHydrated();
    final s = _currentHydrated;
    if (s == null) {
      throw StateError('Session not found: $_activeSessionId');
    }
    return s.issues.firstWhere((i) => i.id == issueId);
  }

  String buildIssueClipboardText(TestSessionIssue issue) {
    final s = _currentHydrated;
    if (s == null) return '';
    final issueRow =
        s.issues.firstWhere((i) => i.id == issue.id, orElse: () => issue);
    final linkedArtifacts = <TestSessionArtifact>[];
    for (final a in s.artifacts) {
      if (issue.relatedArtifactIds.contains(a.id)) linkedArtifacts.add(a);
    }
    return _exporter.buildIssueClipboardText(
      session: _sessionToRow(s),
      issue: _issueToRow(issueRow),
      linkedArtifacts: linkedArtifacts.map(_artifactToRow).toList(),
    );
  }

  TestSessionRow _sessionToRow(TestSession s) {
    return TestSessionRow(
      id: s.id,
      name: s.name,
      type: s.type,
      status: s.status,
      startedAt: s.startedAt,
      endedAt: s.endedAt,
      deviceSerial: s.deviceSerial,
      deviceModel: s.deviceModel,
      deviceBrand: s.deviceBrand,
      deviceSdk: s.deviceSdk,
      packageName: s.packageName,
      note: s.note,
    );
  }

  TestSessionIssueRow _issueToRow(TestSessionIssue i) {
    return TestSessionIssueRow(
      id: i.id,
      sessionId: _requireActiveId(),
      createdAt: i.createdAt,
      title: i.title,
      type: i.type,
      severity: i.severity,
      steps: i.steps,
      expected: i.expected,
      actual: i.actual,
      note: i.note,
    );
  }

  TestSessionArtifactRow _artifactToRow(TestSessionArtifact a) {
    return TestSessionArtifactRow(
      id: a.id,
      sessionId: _requireActiveId(),
      kind: a.kind,
      name: a.name,
      path: a.path,
      createdAt: a.createdAt,
      size: a.size,
    );
  }

  // ===== Mutations: artifacts =============================================

  Future<String> saveScreenshotBytes(List<int> bytes) async {
    final id = _requireActiveId();
    final now = DateTime.now();
    final desc = await _attachments.writeScreenshot(
      sessionId: id,
      bytes: bytes,
      now: now,
    );
    final artifactId = SessionFormatters.id(now);
    await _db.transaction(() async {
      await _dao.insertArtifact(TestSessionArtifactsCompanion.insert(
        id: artifactId,
        sessionId: id,
        kind: TestSessionArtifactKind.screenshot,
        name: desc.name,
        path: desc.relativePath,
        createdAt: now,
        size: Value(desc.size),
      ));
      await _dao.insertEvent(TestSessionEventsCompanion.insert(
        id: SessionFormatters.id(now),
        sessionId: id,
        type: TestSessionEventType.screenshotTaken,
        time: now,
        title: _t('eventScreenshotSaved'),
        detail: Value(desc.name),
        filePath: Value(desc.relativePath),
      ));
    });
    await _refreshCurrentHydrated();
    return desc.relativePath;
  }

  Future<String> saveVideoBytes(List<int> bytes) async {
    final id = _requireActiveId();
    final now = DateTime.now();
    final desc =
        await _attachments.writeVideo(sessionId: id, bytes: bytes, now: now);
    final artifactId = SessionFormatters.id(now);
    await _db.transaction(() async {
      await _dao.insertArtifact(TestSessionArtifactsCompanion.insert(
        id: artifactId,
        sessionId: id,
        kind: TestSessionArtifactKind.video,
        name: desc.name,
        path: desc.relativePath,
        createdAt: now,
        size: Value(desc.size),
      ));
      await _dao.insertEvent(TestSessionEventsCompanion.insert(
        id: SessionFormatters.id(now),
        sessionId: id,
        type: TestSessionEventType.screenRecordStopped,
        time: now,
        title: _t('eventScreenRecordSaved'),
        detail: Value(desc.name),
        filePath: Value(desc.relativePath),
      ));
    });
    await _refreshCurrentHydrated();
    return desc.relativePath;
  }

  Future<String> saveLogcat(String content) async {
    final id = _requireActiveId();
    final now = DateTime.now();
    final desc = await _attachments.writeLogcat(
        sessionId: id, content: content, now: now);
    final artifactId = SessionFormatters.id(now);
    await _db.transaction(() async {
      await _dao.insertArtifact(TestSessionArtifactsCompanion.insert(
        id: artifactId,
        sessionId: id,
        kind: TestSessionArtifactKind.log,
        name: desc.name,
        path: desc.relativePath,
        createdAt: now,
        size: Value(desc.size),
      ));
      await _dao.insertEvent(TestSessionEventsCompanion.insert(
        id: SessionFormatters.id(now),
        sessionId: id,
        type: TestSessionEventType.logcatSaved,
        time: now,
        title: _t('eventLogcatSaved'),
        detail: Value(desc.name),
        filePath: Value(desc.relativePath),
      ));
    });
    await _refreshCurrentHydrated();
    return desc.relativePath;
  }

  /// Adopt a file that the backend (session-logcat) already wrote for us.
  /// Records the artifact in the DB and emits a "logcat stopped" event.
  Future<String> saveLogcatFile(String path) async {
    final id = _requireActiveId();
    final file = File(path);
    if (!await file.exists()) {
      throw Exception(_t('errorLogFileNotFound', {'path': path}));
    }
    final size = await file.length();
    final name = file.uri.pathSegments.last;
    final now = DateTime.now();
    final artifactId = SessionFormatters.id(now);
    // The backend writes logcat files into `<sessionDir>/logcat.log` (or
    // similar). We treat that absolute path as the artifact and record
    // it as-is — the legacy UI uses it directly via `file.readAsBytes()`.
    await _db.transaction(() async {
      await _dao.insertArtifact(TestSessionArtifactsCompanion.insert(
        id: artifactId,
        sessionId: id,
        kind: TestSessionArtifactKind.log,
        name: name,
        path: path,
        createdAt: now,
        size: Value(size),
      ));
      await _dao.insertEvent(TestSessionEventsCompanion.insert(
        id: SessionFormatters.id(now),
        sessionId: id,
        type: TestSessionEventType.logcatSaved,
        time: now,
        title: _t('eventLogcatStopped'),
        detail: Value(name),
        filePath: Value(path),
      ));
    });
    await _refreshCurrentHydrated();
    return path;
  }

  Future<void> markLogcatStarted() async {
    final id = _requireActiveId();
    final now = DateTime.now();
    await _db.transaction(() async {
      await _dao.insertEvent(TestSessionEventsCompanion.insert(
        id: SessionFormatters.id(now),
        sessionId: id,
        type: TestSessionEventType.logcatStarted,
        time: now,
        title: _t('eventLogcatStarted'),
        detail: Value(_t('eventLogcatStartedDetail')),
      ));
    });
    await _refreshCurrentHydrated();
  }

  /// Insert a "logcat stopped" event. Idempotent: if the most recent logcat
  /// event is already a stop (or there's no running logcat at all), this
  /// is a no-op. Called from `_stopLogcat` so the timeline always has a
  /// matching end for every start.
  Future<void> markLogcatStopped() async {
    final id = _requireActiveId();
    final events = await _dao.watchEventsForSession(id).first;
    // Find the most recent logcatStarted/logcatStopped event. If it's
    // already a stop, don't add another one.
    final lastLogcat = events.lastWhere(
      (e) =>
          e.type == TestSessionEventType.logcatStarted ||
          e.type == TestSessionEventType.logcatStopped ||
          e.type == TestSessionEventType.logcatSaved,
      orElse: () =>
          events.isEmpty ? throw StateError('no events') : events.first,
    );
    if (lastLogcat.type == TestSessionEventType.logcatStopped) return;
    final now = DateTime.now();
    await _db.transaction(() async {
      await _dao.insertEvent(TestSessionEventsCompanion.insert(
        id: SessionFormatters.id(now),
        sessionId: id,
        type: TestSessionEventType.logcatStopped,
        time: now,
        title: _t('eventLogcatStopped'),
      ));
    });
    await _refreshCurrentHydrated();
  }

  Future<void> markScreenRecordStarted() async {
    final id = _requireActiveId();
    final now = DateTime.now();
    await _db.transaction(() async {
      await _dao.insertEvent(TestSessionEventsCompanion.insert(
        id: SessionFormatters.id(now),
        sessionId: id,
        type: TestSessionEventType.screenRecordStarted,
        time: now,
        title: _t('eventScreenRecordStarted'),
        detail: Value(_t('eventScreenRecordStartedDetail')),
      ));
    });
    await _refreshCurrentHydrated();
  }

  /// Mark the active session as the owner of the in-flight screen
  /// recording. Persists `test_sessions.screen_record_owner` so the
  /// file-browser screen can see "someone is recording on this device"
  /// even when the user jumps between pages. Idempotent: re-setting
  /// the same owner is a no-op.
  ///
  /// Pass [ScreenRecordOwner.testSession] for the session screen,
  /// [ScreenRecordOwner.fileBrowser] only if the file-browser has a
  /// reason to also flag the session (currently it doesn't — it
  /// runs in its own local flow).
  Future<void> setScreenRecordOwner(ScreenRecordOwner owner) async {
    if (_activeSessionId == null) return;
    final id = _activeSessionId!;
    await _dao.updateSessionScreenRecordOwner(id, owner.dbValue);
    await _refreshCurrentHydrated();
  }

  /// Drop the screen-record owner marker. Called on stop / abandon /
  /// any failure path so the cross-screen lookup returns idle.
  Future<void> clearScreenRecordOwner() async {
    if (_activeSessionId == null) return;
    final id = _activeSessionId!;
    await _dao.updateSessionScreenRecordOwner(id, null);
    await _refreshCurrentHydrated();
  }

  Future<void> deleteArtifact(String artifactId) async {
    final id = _requireActiveId();
    final artifacts = await _dao.watchArtifactsForSession(id).first;
    final target = artifacts.firstWhere(
      (a) => a.id == artifactId,
      orElse: () => throw StateError('artifact not found: $artifactId'),
    );
    await _attachments.deleteFile(target.path);
    await _dao.deleteArtifact(artifactId);
    await _refreshCurrentHydrated();
  }

  /// Delete an event (and its linked artifact if applicable, e.g. screenshot/
  /// video/log events).
  ///
  /// The session-level boundary events (`sessionCreated`, `sessionFinished`)
  /// cannot be deleted and throw.
  ///
  /// For paired events (e.g. `logcatStarted` → `logcatStopped` →
  /// `logcatSaved`), deleting the **start** also removes the matching stop
  /// and any saved-event in the same pair. Deleting the stop or saved
  /// events removes just that single event.
  Future<void> deleteEvent(String eventId) async {
    final id = _requireActiveId();
    final events = await _dao.watchEventsForSession(id).first;
    final idx = events.indexWhere((e) => e.id == eventId);
    if (idx < 0) throw StateError('event not found: $eventId');
    final event = events[idx];
    if (event.type == TestSessionEventType.sessionCreated ||
        event.type == TestSessionEventType.sessionFinished) {
      throw StateError(_t('errorCannotDeleteSystemEvent'));
    }

    // Compute the set of event ids to remove.
    final toDelete = <String>{eventId};
    if (event.type == TestSessionEventType.logcatStarted ||
        event.type == TestSessionEventType.screenRecordStarted) {
      // Walk forward through events of the same capture pair and add
      // every related event (stop, saved) until we hit a different pair
      // or a non-related event.
      final pairKinds = _pairKindsFor(event.type);
      for (var j = idx + 1; j < events.length; j++) {
        final next = events[j];
        if (!pairKinds.contains(next.type)) break;
        toDelete.add(next.id);
      }
    }

    // Collect the file paths of any artifacts that the deleted events
    // referenced, so we can wipe the on-disk files too.
    final pathsToDelete = <String>{};
    for (final eid in toDelete) {
      final e = events.firstWhere((e) => e.id == eid);
      if (e.filePath != null && e.filePath!.isNotEmpty) {
        pathsToDelete.add(e.filePath!);
      }
    }

    await _db.transaction(() async {
      // 1. Delete on-disk artifacts whose path is referenced.
      if (pathsToDelete.isNotEmpty) {
        final artifacts = await _dao.watchArtifactsForSession(id).first;
        for (final a in artifacts) {
          if (pathsToDelete.contains(a.path)) {
            await _attachments.deleteFile(a.path);
            await _dao.deleteArtifact(a.id);
          }
        }
      }
      // 2. Delete the events themselves.
      for (final eid in toDelete) {
        await _dao.deleteEvent(eid);
      }
    });
    await _refreshCurrentHydrated();
  }

  /// Returns the set of event types that belong to the same capture pair
  /// as the given start type. Used by deleteEvent to find sibling events
  /// to drop together.
  static Set<TestSessionEventType> _pairKindsFor(
      TestSessionEventType startType) {
    return switch (startType) {
      TestSessionEventType.logcatStarted => {
          TestSessionEventType.logcatStarted,
          TestSessionEventType.logcatStopped,
          TestSessionEventType.logcatSaved,
        },
      TestSessionEventType.screenRecordStarted => {
          TestSessionEventType.screenRecordStarted,
          TestSessionEventType.screenRecordStopped,
        },
      _ => {startType},
    };
  }

  // ===== History & lifecycle ==============================================

  /// All sessions for the given device, newest first. One-shot read used
  /// by the legacy history dialog.
  Future<List<TestSession>> scanHistoryForDevice(String serial) async {
    final rows = await _dao.watchSessionsForDevice(serial).first;
    final out = <TestSession>[];
    for (final r in rows) {
      final hydrated = await _hydrate(r.id);
      if (hydrated != null) out.add(hydrated);
    }
    return out;
  }

  /// Backwards-compat: scan across all devices (used by the old "all
  /// history" dialog). Iterates each saved device.
  Future<List<TestSession>> scanHistory() async {
    final devices = await _db.savedDevicesDao.getAllSavedDevices();
    final all = <TestSession>[];
    for (final d in devices) {
      all.addAll(await scanHistoryForDevice(d.serial));
    }
    all.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return all;
  }

  /// Make the given session the "active" one (legacy UI compatibility).
  /// Hydrates and notifies so the existing screen re-renders.
  /// Throws [StateError] if the session is not found in the database.
  Future<TestSession> loadHistoricalSession(String sessionId) async {
    _activeSessionId = sessionId;
    await _refreshCurrentHydrated();
    if (_currentHydrated == null) {
      throw StateError('Session not found: $sessionId');
    }
    return _currentHydrated!;
  }

  Future<void> deleteSession(String sessionId) async {
    await _dao.deleteSession(sessionId);
    await _attachments.deleteSessionDir(sessionId);
    if (_activeSessionId == sessionId) {
      _activeSessionId = null;
      await _refreshCurrentHydrated();
    }
  }

  // ===== Report / export ===================================================

  Future<String> writeReport() async {
    final id = _requireActiveId();
    final session = await _dao.findSessionById(id);
    if (session == null) throw StateError(_t('errorNoSession'));
    return _exporter.writeReport(session, db: _db);
  }

  /// Export a ZIP of the session directory + report.md.
  Future<String> exportSession({String? targetPath, String? sessionId}) async {
    final id = sessionId ?? _requireActiveId();
    final session = await _dao.findSessionById(id);
    if (session == null) throw StateError(_t('errorNoSession'));
    await _exporter.writeReport(session, db: _db);
    final base = await _attachments.artifactsDir(id);
    final destination = targetPath ?? '${base.path}.zip';
    await _zipArtifacts(base, destination);
    return destination;
  }

  /// Export session to the Downloads folder.
  Future<String> exportSessionToDownloads({String? sessionId}) async {
    final id = sessionId ?? _requireActiveId();
    final session = await _dao.findSessionById(id);
    if (session == null) throw StateError(_t('errorNoSession'));

    final downloadsDir = await _getDownloadsDirectory();
    if (downloadsDir == null) {
      throw Exception(_t('errorNoDownloadsDir'));
    }

    final sessionName = _sanitizeFileName(session.name);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final targetPath = '${downloadsDir.path}/${sessionName}_$timestamp.zip';

    return exportSession(targetPath: targetPath, sessionId: id);
  }

  /// Export session with user picking the save location via file picker.
  Future<String?> exportSessionWithPicker({String? sessionId}) async {
    final id = sessionId ?? _requireActiveId();
    final session = await _dao.findSessionById(id);
    if (session == null) throw StateError(_t('errorNoSession'));

    final sessionName = _sanitizeFileName(session.name);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final suggestedName = '${sessionName}_$timestamp.zip';

    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'ZIP Archive',
          extensions: ['zip'],
        ),
      ],
    );

    if (location == null) return null;

    final targetPath = location.path;
    await _exporter.writeReport(session, db: _db);
    final base = await _attachments.artifactsDir(id);
    await _zipArtifacts(base, targetPath);
    return targetPath;
  }

  Future<Directory?> _getDownloadsDirectory() async {
    try {
      final dir = await getDownloadsDirectory();
      if (dir != null && dir.existsSync()) return dir;

      if (Platform.isMacOS) {
        return Directory('${Platform.environment['HOME']}/Downloads');
      } else if (Platform.isLinux) {
        return Directory('${Platform.environment['HOME']}/Downloads');
      } else if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'] ?? '';
        return Directory('$userProfile\\Downloads');
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }

  /// Bundle the session's artifact directory into a ZIP at [destination].
  ///
  /// Uses the `archive` package so we don't depend on the system `zip` CLI
  /// (which isn't shipped with Windows by default). UTF-8 filenames are
  /// preserved, including CJK characters that the system `zip` corrupts
  /// on Windows because it defaults to CP437 entry names.
  Future<void> _zipArtifacts(Directory base, String destination) async {
    try {
      final encoder = ZipFileEncoder();
      encoder.create(destination);
      encoder.addDirectory(base, includeDirName: false);
      encoder.close();
    } catch (e) {
      throw Exception(_t('exportFailed'));
    }
  }

  // ===== Internals ========================================================

  String _requireActiveId() {
    final id = _activeSessionId;
    if (id == null) {
      throw StateError(_t('errorNoRunningSession'));
    }
    return id;
  }

  static String _fallbackTranslate(String key, [Map<String, String>? args]) {
    var value = _fallbackTranslations[key] ?? key;
    if (args != null) {
      for (final entry in args.entries) {
        value = value.replaceAll('{${entry.key}}', entry.value);
      }
    }
    return value;
  }

  static const Map<String, String> _fallbackTranslations = {
    'sessionUntitled': '未命名测试',
    'issueUntitled': '未命名问题',
    'issueTypeOther': '其他',
    'notFilled': '未填写',
    'sessionTestPlan': '当前测试内容',
    'testPlanPassed': '通过',
    'testPlanFailed': '失败',
    'eventSessionCreated': '创建测试会话',
    'eventSessionCreatedDetail': '设备：{device}，包名：{package}',
    'eventNoteAdded': '添加备注',
    'eventIssueMarked': '标记问题',
    'eventTestPlanUpdated': '更新测试步骤',
    'eventLogcatSaved': '保存日志',
    'eventScreenshotSaved': '保存截屏',
    'eventScreenRecordStarted': '开始录屏',
    'eventScreenRecordStartedDetail': '最长建议 3 分钟',
    'eventLogcatStarted': '开始采集日志',
    'eventLogcatStartedDetail': '持续记录中',
    'eventLogcatStopped': '停止采集日志',
    'eventScreenRecordSaved': '保存录屏',
    'eventSessionFinished': '结束测试会话',
    'eventSessionAbandoned': '会话被强制结束',
    'eventSessionAbandonedDetail': '设备已离线',
    'errorNoSession': '没有测试会话',
    'errorNoRunningSession': '没有进行中的测试会话',
    'errorDeviceAlreadyHasRunningSession': '该设备已有进行中的测试会话',
    'errorCannotDeleteSystemEvent': '系统事件无法删除',
    'errorLogFileNotFound': '日志文件不存在: {path}',
    'issueTypeCrash': '崩溃',
    'issueTypeAnr': 'ANR',
    'issueTypePerformance': '性能问题',
    'issueTypeUi': 'UI异常',
    'issueTypeApi': '接口异常',
    'issueTypeFunctional': '功能异常',
    'issueTypeCompatibility': '兼容性',
    'issueSeverityBlocker': '阻塞',
    'issueSeverityMajor': '严重',
    'issueSeverityNormal': '一般',
    'issueSeverityMinor': '轻微',
    'clipboardIssueTitle': '【问题标题】',
    'clipboardIssueType': '【问题类型】',
    'clipboardIssueSeverity': '【严重程度】',
    'clipboardTestEnvironment': '【测试环境】',
    'clipboardIssueSteps': '【复现步骤】',
    'clipboardIssueExpected': '【预期结果】',
    'clipboardIssueActual': '【实际结果】',
    'clipboardIssueNote': '【备注】',
    'clipboardAttachments': '【附件】',
    'reportIssueSummary': '问题摘要',
    'reportType': '类型',
    'reportSeverity': '严重程度',
    'reportOccurredAt': '发生时间',
    'reportRelatedAttachments': '关联附件',
    'reportSteps': '复现步骤',
    'reportExpected': '预期结果',
    'reportActual': '实际结果',
    'reportBasicInfo': '基础信息',
    'reportTestType': '测试类型',
    'reportStatus': '状态',
    'reportStartedAt': '开始时间',
    'reportEndedAt': '结束时间',
    'reportDevice': '设备',
    'reportBrand': '品牌',
    'reportSdk': 'SDK',
    'reportPackageName': '包名',
    'reportInitialNote': '初始备注',
    'reportNotes': '问题备注',
    'reportTimeline': '时间线',
    'reportAttachments': '附件',
    'sessionRunning': '进行中',
    'sessionFinished': '已结束',
    'exportFailed': '导出失败',
  };

  @override
  void dispose() {
    _deviceOfflineSub?.cancel();
    _recordingInterrupted.close();
    super.dispose();
  }
}
