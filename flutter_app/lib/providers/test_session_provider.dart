// Test session — public entry point. The class only owns state + notifyListeners.
//
// Heavy lifting is delegated to helper classes under lib/providers/test_session/:
//
//   - repository.dart        session.json I/O + history scan + delete
//   - attachment_store.dart  logs / screenshots / videos / issue_logs files
//   - exporter.dart          report.md generation + clipboard text
//   - formatter.dart         pure string formatters (dates, ids, labels)
//
// All public methods keep their original signatures so call sites are unchanged.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/test_session.dart';
import '../services/database.dart';
import 'device_provider.dart';
import 'test_session/attachment_store.dart';
import 'test_session/exporter.dart';
import 'test_session/formatter.dart';
import 'test_session/repository.dart';
import 'test_session/session_translate.dart';

export 'test_session/session_translate.dart' show SessionTranslate;

/// Owns the active [TestSession] in memory. Persists every state change to disk
/// (via [SessionRepository]) so a crash mid-test loses at most one tick.
class TestSessionProvider extends ChangeNotifier {
  final Directory? baseDirectory;
  final SessionRepository _repo;
  final SessionAttachmentStore _attachments;
  final SessionExporter _exporter;
  final AppDatabase _db;

  SessionTranslate _translate;
  String? _translationLanguage;
  TestSession? _currentSession;

  TestSessionProvider({
    this.baseDirectory,
    SessionTranslate? translate,
    AppDatabase? db,
  })  : _translate = translate ?? _fallbackTranslate,
        _repo = SessionRepository(baseDirectory),
        _attachments = SessionAttachmentStore(),
        _exporter = SessionExporter(translate ?? _fallbackTranslate),
        _db = db ?? AppDatabase() {
    _tryResume();
  }

  /// Try to resume a running session from disk on startup.
  Future<void> _tryResume() async {
    if (_currentSession != null) return;
    try {
      final running = await scanHistory();
      final ongoing = running.where((s) => s.status == TestSessionStatus.running).toList();
      if (ongoing.isEmpty) return;
      if (ongoing.length == 1) {
        _currentSession = ongoing.first;
        await _persistCurrentSessionId();
        notifyListeners();
      }
      // Multiple running sessions: let the user pick via history screen.
    } catch (_) {}
  }

  // ===== Translator wiring =====

  void setTranslator(SessionTranslate translate, {String? language}) {
    if (language != null && language == _translationLanguage) {
      _translate = translate;
      return;
    }
    _translate = translate;
    _translationLanguage = language;
    notifyListeners();
  }

  TestSession? get currentSession => _currentSession;
  bool get hasRunningSession =>
      _currentSession?.status == TestSessionStatus.running;

  String _t(String key, [Map<String, String>? args]) => _translate(key, args);

  // ===== Session lifecycle =====

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
    final now = DateTime.now();
    final id =
        '${SessionFormatters.compactDate(now)}_${SessionFormatters.safeName(name)}';
    final root = await _repo.rootDirectory();
    final sessionDir = Directory('${root.path}/sessions/$id');
    await Directory('${sessionDir.path}/logs').create(recursive: true);
    await Directory('${sessionDir.path}/screenshots').create(recursive: true);
    await Directory('${sessionDir.path}/videos').create(recursive: true);

    final session = TestSession(
      id: id,
      name: name.trim().isEmpty ? _t('sessionUntitled') : name.trim(),
      type: type.trim().isEmpty ? _t('issueTypeOther') : type.trim(),
      status: TestSessionStatus.running,
      startedAt: now,
      directoryPath: sessionDir.path,
      deviceSerial: serial,
      deviceModel: model,
      deviceBrand: brand,
      deviceSdk: sdk,
      packageName: packageName.trim(),
      note: note.trim(),
      testPlan: SessionFormatters.normalizeTestPlan(testPlanItems),
      events: [
        SessionFormatters.buildEvent(
          TestSessionEventType.sessionCreated,
          _t('eventSessionCreated'),
          _t('eventSessionCreatedDetail', {
            'device': deviceDisplayName,
            'package': packageName.trim().isEmpty
                ? _t('notFilled')
                : packageName.trim(),
          }),
          now: now,
        ),
      ],
    );
    _currentSession = session;
    await _repo.persist(session);
    await _persistCurrentSessionId();
    notifyListeners();
    return session;
  }

  Future<void> updateTestPlanItem(
    String itemId,
    TestSessionPlanStatus status, {
    String message = '',
  }) async {
    final session = _requireRunningSession();
    final index = session.testPlan.indexWhere((item) => item.id == itemId);
    if (index == -1) return;
    final now = DateTime.now();
    final currentItem = session.testPlan[index];
    // Set startedAt on first mark (when step moves out of pending)
    final startedAt = currentItem.startedAt ??
        (status != TestSessionPlanStatus.pending ? now : null);

    final updated = [
      for ( var i = 0; i < session.testPlan.length; i++)
        if (i == index)
          session.testPlan[i].copyWith(
            status: status,
            message: message.trim(),
            startedAt: startedAt,
            updatedAt: now,
          )
        else
          session.testPlan[i],
    ];
    final item = updated[index];
    _currentSession = session.copyWith(
      testPlan: updated,
      events: [
        ...session.events,
        SessionFormatters.buildEvent(
          TestSessionEventType.testPlanUpdated,
          _t('eventTestPlanUpdated'),
          '${item.flowName} / ${item.step}',
          now: now,
        ),
      ],
    );
    await _repo.persist(_currentSession!);
    notifyListeners();
  }

  Future<void> addNote(String content) async {
    final session = _requireRunningSession();
    final text = content.trim();
    if (text.isEmpty) return;
    final now = DateTime.now();
    final note = TestSessionNote(
      id: SessionFormatters.id(now),
      createdAt: now,
      content: text,
    );
    _currentSession = session.copyWith(
      notes: [...session.notes, note],
      events: [
        ...session.events,
        SessionFormatters.buildEvent(
            TestSessionEventType.noteAdded, _t('eventNoteAdded'), text,
            now: now),
      ],
    );
    await _repo.persist(_currentSession!);
    notifyListeners();
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
    var session = _requireRunningSession();
    final now = DateTime.now();
    final cleanTitle =
        title.trim().isEmpty ? _t('issueUntitled') : title.trim();
    final issueId =
        SessionFormatters.issueId(session.issues.length + 1);
    final relatedArtifactIds = SessionFormatters.recentArtifactIds(session);
    if (recentLogContent.trim().isNotEmpty) {
      final artifact = await _attachments.writeIssueRecentLog(
          session, issueId, recentLogContent, now);
      session = session.copyWith(artifacts: [...session.artifacts, artifact]);
      relatedArtifactIds.add(artifact.id);
    }
    final issue = TestSessionIssue(
      id: issueId,
      createdAt: now,
      title: cleanTitle,
      type: type,
      severity: severity,
      steps: steps.trim(),
      expected: expected.trim(),
      actual: actual.trim(),
      note: note.trim(),
      relatedArtifactIds: relatedArtifactIds,
    );
    _currentSession = session.copyWith(
      issues: [...session.issues, issue],
      events: [
        ...session.events,
        SessionFormatters.buildEvent(
          TestSessionEventType.issueMarked,
          _t('eventIssueMarked'),
          '${SessionFormatters.severityLabel(_t, severity)} / ${SessionFormatters.issueTypeLabel(_t, type)} / ${issue.title}',
          now: now,
        ),
      ],
    );
    await _repo.persist(_currentSession!);
    notifyListeners();
    return issue;
  }

  String buildIssueClipboardText(TestSessionIssue issue) {
    return _exporter.buildIssueClipboardText(_currentSession, issue);
  }

  // ===== Attachments =====

  Future<String> saveLogcat(String content) async {
    final session = _requireRunningSession();
    final now = DateTime.now();
    final artifact = await _attachments.writeLogcat(session, content, now);
    _currentSession = session.copyWith(
      artifacts: [...session.artifacts, artifact],
      events: [
        ...session.events,
        SessionFormatters.buildEvent(
          TestSessionEventType.logcatSaved,
          _t('eventLogcatSaved'),
          artifact.name,
          filePath: artifact.path,
          now: now,
        ),
      ],
    );
    await _repo.persist(_currentSession!);
    notifyListeners();
    return artifact.path;
  }

  Future<String> saveScreenshotBytes(List<int> bytes) async {
    final session = _requireRunningSession();
    final now = DateTime.now();
    final artifact =
        await _attachments.writeScreenshot(session, bytes, now);
    _currentSession = session.copyWith(
      artifacts: [...session.artifacts, artifact],
      events: [
        ...session.events,
        SessionFormatters.buildEvent(
          TestSessionEventType.screenshotTaken,
          _t('eventScreenshotSaved'),
          artifact.name,
          filePath: artifact.path,
          now: now,
        ),
      ],
    );
    await _repo.persist(_currentSession!);
    notifyListeners();
    return artifact.path;
  }

  Future<void> markScreenRecordStarted() async {
    final session = _requireRunningSession();
    final now = DateTime.now();
    _currentSession = session.copyWith(
      events: [
        ...session.events,
        SessionFormatters.buildEvent(
          TestSessionEventType.screenRecordStarted,
          _t('eventScreenRecordStarted'),
          _t('eventScreenRecordStartedDetail'),
          now: now,
        ),
      ],
    );
    await _repo.persist(_currentSession!);
    notifyListeners();
  }

  Future<void> markLogcatStarted() async {
    final session = _requireRunningSession();
    final now = DateTime.now();
    _currentSession = session.copyWith(
      events: [
        ...session.events,
        SessionFormatters.buildEvent(
          TestSessionEventType.logcatStarted,
          _t('eventLogcatStarted'),
          _t('eventLogcatStartedDetail'),
          now: now,
        ),
      ],
    );
    await _repo.persist(_currentSession!);
    notifyListeners();
  }

  Future<String> saveLogcatFile(String path) async {
    final session = _requireRunningSession();
    final now = DateTime.now();
    final file = File(path);
    if (!await file.exists()) {
      throw Exception(_t('errorLogFileNotFound', {'path': path}));
    }
    final size = await file.length();
    final name = file.uri.pathSegments.last;
    final artifact = TestSessionArtifact(
      id: SessionFormatters.id(now),
      kind: TestSessionArtifactKind.log,
      name: name,
      path: path,
      createdAt: now,
      size: size,
    );
    _currentSession = session.copyWith(
      artifacts: [...session.artifacts, artifact],
      events: [
        ...session.events,
        SessionFormatters.buildEvent(
          TestSessionEventType.logcatSaved,
          _t('eventLogcatStopped'),
          name,
          filePath: path,
          now: now,
        ),
      ],
    );
    await _repo.persist(_currentSession!);
    notifyListeners();
    return path;
  }

  Future<String> saveVideoBytes(List<int> bytes) async {
    final session = _requireRunningSession();
    final now = DateTime.now();
    final artifact = await _attachments.writeVideo(session, bytes, now);
    _currentSession = session.copyWith(
      artifacts: [...session.artifacts, artifact],
      events: [
        ...session.events,
        SessionFormatters.buildEvent(
          TestSessionEventType.screenRecordStopped,
          _t('eventScreenRecordSaved'),
          artifact.name,
          filePath: artifact.path,
          now: now,
        ),
      ],
    );
    await _repo.persist(_currentSession!);
    notifyListeners();
    return artifact.path;
  }

  // ===== Finish / report / export =====

  Future<TestSession> finishSession() async {
    final session = _requireRunningSession();
    final now = DateTime.now();
    final finished = session.copyWith(
      status: TestSessionStatus.finished,
      endedAt: now,
      events: [
        ...session.events,
        SessionFormatters.buildEvent(
          TestSessionEventType.sessionFinished,
          _t('eventSessionFinished'),
          '',
          now: now,
        ),
      ],
    );
    _currentSession = finished;
    await _exporter.writeReport(finished);
    await _repo.persist(finished);
    await _persistCurrentSessionId();
    notifyListeners();
    return _currentSession!;
  }

  Future<String> writeReport() async {
    final session = _currentSession;
    if (session == null) throw StateError(_t('errorNoSession'));
    return _exporter.writeReport(session);
  }

  Future<String> exportSession({String? targetPath}) async {
    final session = _currentSession;
    if (session == null) throw StateError(_t('errorNoSession'));
    await _exporter.writeReport(session);
    final destination = targetPath ?? '${session.directoryPath}.zip';
    final result = await Process.run(
      'zip',
      ['-r', destination, '.'],
      workingDirectory: session.directoryPath,
    );
    if (result.exitCode != 0) {
      throw Exception(result.stderr.toString().isEmpty
          ? _t('exportFailed')
          : result.stderr.toString());
    }
    return destination;
  }

  // ===== History & lifecycle =====

  Future<List<TestSession>> scanHistory() => _repo.scanHistory();

  Future<TestSession> loadHistoricalSession(String sessionId) async {
    final loaded = await _repo.loadHistorical(sessionId);
    _currentSession = loaded;
    notifyListeners();
    return loaded;
  }

  Future<void> deleteSession(String sessionId) async {
    await _repo.deleteSessionDir(sessionId);
    if (_currentSession?.id == sessionId) {
      _currentSession = null;
      await _persistCurrentSessionId();
      notifyListeners();
    }
  }

  /// Persist the current session ID to database so we can resume it after restart.
  Future<void> _persistCurrentSessionId() async {
    try {
      // Keep recent session list trimmed.
      final recent = _currentSession != null
          ? [_currentSession!.id]
          : <String>[];
      
      await _db.updateAppState(
        currentSessionId: _currentSession?.id,
        recentSessionIds: recent,
      );
    } catch (_) {}
  }

  Future<void> deleteArtifact(String artifactId) async {
    final session = _requireRunningSession();
    final idx = session.artifacts.indexWhere((a) => a.id == artifactId);
    if (idx == -1) return;
    final artifact = session.artifacts[idx];
    await _attachments.deleteFile(artifact.path);
    _currentSession = session.copyWith(
      artifacts: [
        for (var i = 0; i < session.artifacts.length; i++)
          if (i != idx) session.artifacts[i],
      ],
    );
    await _repo.persist(_currentSession!);
    notifyListeners();
  }

  // ===== Internals =====

  TestSession _requireRunningSession() {
    final session = _currentSession;
    if (session == null || session.status != TestSessionStatus.running) {
      throw StateError(_t('errorNoRunningSession'));
    }
    return session;
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
    'eventLogcatSaved': '保存 Logcat',
    'eventScreenshotSaved': '保存截屏',
    'eventScreenRecordStarted': '开始录屏',
    'eventScreenRecordStartedDetail': '最长建议 3 分钟',
    'eventLogcatStarted': '开始采集日志',
    'eventLogcatStartedDetail': '持续记录中',
    'eventLogcatStopped': '停止采集日志',
    'eventScreenRecordSaved': '保存录屏',
    'eventSessionFinished': '结束测试会话',
    'errorNoSession': '没有测试会话',
    'errorNoRunningSession': '没有进行中的测试会话',
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
}
