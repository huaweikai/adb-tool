import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/test_session.dart';

typedef SessionTranslate = String Function(String key,
    [Map<String, String>? args]);

class TestSessionProvider extends ChangeNotifier {
  final Directory? baseDirectory;
  SessionTranslate _translate;
  String? _translationLanguage;
  TestSession? _currentSession;
  TestSessionProvider({this.baseDirectory, SessionTranslate? translate})
      : _translate = translate ?? _fallbackTranslate;

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
  }) async {
    final now = DateTime.now();
    final id = '${_compactDate(now)}_${_safeName(name)}';
    final root = await _rootDirectory();
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
      events: [
        _event(
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
    await _persist();
    notifyListeners();
    return session;
  }

  Future<void> addNote(String content) async {
    final session = _requireRunningSession();
    final text = content.trim();
    if (text.isEmpty) return;
    final now = DateTime.now();
    final note = TestSessionNote(
      id: _id(now),
      createdAt: now,
      content: text,
    );
    _currentSession = session.copyWith(
      notes: [...session.notes, note],
      events: [
        ...session.events,
        _event(TestSessionEventType.noteAdded, _t('eventNoteAdded'), text,
            now: now),
      ],
    );
    await _persist();
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
    final issueId = _issueId(session.issues.length + 1);
    final relatedArtifactIds = _recentArtifactIds(session);
    if (recentLogContent.trim().isNotEmpty) {
      final artifact = await _writeIssueRecentLogArtifact(
        session: session,
        issueId: issueId,
        content: recentLogContent,
        now: now,
      );
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
        _event(
          TestSessionEventType.issueMarked,
          _t('eventIssueMarked'),
          '${_severityLabel(severity)} / ${_issueTypeLabel(type)} / ${issue.title}',
          now: now,
        ),
      ],
    );
    await _persist();
    notifyListeners();
    return issue;
  }

  String buildIssueClipboardText(TestSessionIssue issue) {
    final session = _currentSession;
    final artifacts = session == null
        ? <TestSessionArtifact>[]
        : _issueArtifacts(session, issue);
    final buffer = StringBuffer()
      ..writeln(_bracket('clipboardIssueTitle'))
      ..writeln(issue.title)
      ..writeln()
      ..writeln(_bracket('clipboardIssueType'))
      ..writeln(_issueTypeLabel(issue.type))
      ..writeln()
      ..writeln(_bracket('clipboardIssueSeverity'))
      ..writeln(_severityLabel(issue.severity))
      ..writeln()
      ..writeln('【发生时间】')
      ..writeln(_dateTimeStr(issue.createdAt))
      ..writeln()
      ..writeln(_bracket('clipboardTestEnvironment'))
      ..writeln(
          '${_t('reportDevice')}：${session == null ? '-' : _deviceLabel(session)}')
      ..writeln(
          '${_t('reportBrand')}：${_emptyIfNone(session?.deviceBrand)}')
      ..writeln(
          '${_t('reportSdk')}：${_emptyIfNone(session?.deviceSdk)}')
      ..writeln(
          '${_t('reportPackageName')}：${_emptyIfNone(session?.packageName)}')
      ..writeln()
      ..writeln(_bracket('clipboardIssueSteps'))
      ..writeln(issue.steps.isEmpty ? '-' : issue.steps)
      ..writeln()
      ..writeln(_bracket('clipboardIssueExpected'))
      ..writeln(issue.expected.isEmpty ? '-' : issue.expected)
      ..writeln()
      ..writeln(_bracket('clipboardIssueActual'))
      ..writeln(issue.actual.isEmpty ? '-' : issue.actual)
      ..writeln()
      ..writeln(_bracket('clipboardIssueNote'))
      ..writeln(issue.note.isEmpty ? '-' : issue.note)
      ..writeln()
      ..writeln(_bracket('clipboardAttachments'));
    buffer.write(artifacts.isEmpty
        ? '-'
        : artifacts
            .map((artifact) => '${artifact.kind.name}：${artifact.path}')
            .join('\n'));
    return buffer.toString();
  }

  String _emptyIfNone(String? value) {
    if (value == null || value.isEmpty) return '-';
    return value;
  }

  String _dateTimeStr(DateTime time) {
    return '${time.year}-${_pad2(time.month)}-${_pad2(time.day)} '
        '${_pad2(time.hour)}:${_pad2(time.minute)}:${_pad2(time.second)}';
  }

  String _pad2(int value) => value.toString().padLeft(2, '0');

  String _issueTypeLabel(TestSessionIssueType type) => switch (type) {
        TestSessionIssueType.crash => _t('issueTypeCrash'),
        TestSessionIssueType.anr => _t('issueTypeAnr'),
        TestSessionIssueType.performance => _t('issueTypePerformance'),
        TestSessionIssueType.ui => _t('issueTypeUi'),
        TestSessionIssueType.api => _t('issueTypeApi'),
        TestSessionIssueType.functional => _t('issueTypeFunctional'),
        TestSessionIssueType.compatibility => _t('issueTypeCompatibility'),
        TestSessionIssueType.other => _t('issueTypeOther'),
      };

  String _severityLabel(TestSessionIssueSeverity s) => switch (s) {
        TestSessionIssueSeverity.blocker => _t('issueSeverityBlocker'),
        TestSessionIssueSeverity.major => _t('issueSeverityMajor'),
        TestSessionIssueSeverity.normal => _t('issueSeverityNormal'),
        TestSessionIssueSeverity.minor => _t('issueSeverityMinor'),
      };

  Future<String> saveLogcat(String content) async {
    final session = _requireRunningSession();
    final now = DateTime.now();
    final name = '${_fileDate(now)}.log';
    final file = File('${session.directoryPath}/logs/$name');
    await file.writeAsString(content);
    final artifact = await _artifact(
      kind: TestSessionArtifactKind.log,
      name: name,
      path: file.path,
      now: now,
    );
    _currentSession = session.copyWith(
      artifacts: [...session.artifacts, artifact],
      events: [
        ...session.events,
        _event(
          TestSessionEventType.logcatSaved,
          _t('eventLogcatSaved'),
          name,
          filePath: file.path,
          now: now,
        ),
      ],
    );
    await _persist();
    notifyListeners();
    return file.path;
  }

  Future<String> saveScreenshotBytes(List<int> bytes) async {
    final session = _requireRunningSession();
    final now = DateTime.now();
    final name = '${_fileDate(now)}.png';
    final file = File('${session.directoryPath}/screenshots/$name');
    await file.writeAsBytes(bytes);
    final artifact = await _artifact(
      kind: TestSessionArtifactKind.screenshot,
      name: name,
      path: file.path,
      now: now,
    );
    _currentSession = session.copyWith(
      artifacts: [...session.artifacts, artifact],
      events: [
        ...session.events,
        _event(
          TestSessionEventType.screenshotTaken,
          _t('eventScreenshotSaved'),
          name,
          filePath: file.path,
          now: now,
        ),
      ],
    );
    await _persist();
    notifyListeners();
    return file.path;
  }

  Future<void> markScreenRecordStarted() async {
    final session = _requireRunningSession();
    final now = DateTime.now();
    _currentSession = session.copyWith(
      events: [
        ...session.events,
        _event(
          TestSessionEventType.screenRecordStarted,
          _t('eventScreenRecordStarted'),
          _t('eventScreenRecordStartedDetail'),
          now: now,
        ),
      ],
    );
    await _persist();
    notifyListeners();
  }

  Future<void> markLogcatStarted() async {
    final session = _requireRunningSession();
    final now = DateTime.now();
    _currentSession = session.copyWith(
      events: [
        ...session.events,
        _event(TestSessionEventType.logcatStarted, _t('eventLogcatStarted'),
            _t('eventLogcatStartedDetail'),
            now: now),
      ],
    );
    await _persist();
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
      id: _id(now),
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
        _event(
          TestSessionEventType.logcatSaved,
          _t('eventLogcatStopped'),
          name,
          filePath: path,
          now: now,
        ),
      ],
    );
    await _persist();
    notifyListeners();
    return path;
  }

  Future<String> saveVideoBytes(List<int> bytes) async {
    final session = _requireRunningSession();
    final now = DateTime.now();
    final name = '${_fileDate(now)}.mp4';
    final file = File('${session.directoryPath}/videos/$name');
    await file.writeAsBytes(bytes);
    final artifact = await _artifact(
      kind: TestSessionArtifactKind.video,
      name: name,
      path: file.path,
      now: now,
    );
    _currentSession = session.copyWith(
      artifacts: [...session.artifacts, artifact],
      events: [
        ...session.events,
        _event(
          TestSessionEventType.screenRecordStopped,
          _t('eventScreenRecordSaved'),
          name,
          filePath: file.path,
          now: now,
        ),
      ],
    );
    await _persist();
    notifyListeners();
    return file.path;
  }

  Future<TestSession> finishSession() async {
    final session = _requireRunningSession();
    final now = DateTime.now();
    final finished = session.copyWith(
      status: TestSessionStatus.finished,
      endedAt: now,
      events: [
        ...session.events,
        _event(TestSessionEventType.sessionFinished, _t('eventSessionFinished'),
            '',
            now: now),
      ],
    );
    _currentSession = finished;
    await _writeReport();
    await _persist();
    notifyListeners();
    return _currentSession!;
  }

  Future<String> writeReport() async {
    final session = _currentSession;
    if (session == null) throw StateError(_t('errorNoSession'));
    await _writeReport();
    return '${session.directoryPath}/report.md';
  }

  Future<String> exportSession({String? targetPath}) async {
    final session = _currentSession;
    if (session == null) throw StateError(_t('errorNoSession'));
    await _writeReport();
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

  // ── History & lifecycle ──────────────────────────────────────

  /// Scans [ADBToolData/sessions/] and returns parsed [TestSession] instances
  /// sorted by start time (newest first).
  Future<List<TestSession>> scanHistory() async {
    final root = await _rootDirectory();
    final sessionsDir = Directory('${root.path}/sessions');
    if (!await sessionsDir.exists()) return [];
    final results = <TestSession>[];
    await for (final entity in sessionsDir.list()) {
      if (entity is! Directory) continue;
      final jsonFile = File('${entity.path}/session.json');
      if (!await jsonFile.exists()) continue;
      try {
        final json = jsonDecode(await jsonFile.readAsString())
            as Map<String, dynamic>;
        results.add(TestSession.fromJson(json));
      } catch (_) {
        // Skip corrupted / unreadable session directories.
      }
    }
    results.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return results;
  }

  /// Loads a historical session from disk and makes it the current session.
  /// The loaded session is treated as read-only (its status is not changed).
  Future<TestSession> loadHistoricalSession(String sessionId) async {
    final root = await _rootDirectory();
    final sessionDir = Directory('${root.path}/sessions/$sessionId');
    if (!await sessionDir.exists()) {
      throw Exception(
          _t('errorLogFileNotFound', {'path': sessionDir.path}));
    }
    final jsonFile = File('${sessionDir.path}/session.json');
    if (!await jsonFile.exists()) {
      throw Exception(
          _t('errorLogFileNotFound', {'path': jsonFile.path}));
    }
    final json =
        jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;
    _currentSession = TestSession.fromJson(json);
    notifyListeners();
    return _currentSession!;
  }

  /// Deletes an entire session directory (including all artifacts).
  Future<void> deleteSession(String sessionId) async {
    final root = await _rootDirectory();
    final sessionDir = Directory('${root.path}/sessions/$sessionId');
    if (await sessionDir.exists()) {
      await sessionDir.delete(recursive: true);
    }
    // If the deleted session is the one currently loaded, clear it.
    if (_currentSession?.id == sessionId) {
      _currentSession = null;
      notifyListeners();
    }
  }

  /// Deletes a single artifact from the current session.
  /// Removes the file from disk, drops the entry from the artifact list,
  /// and persists the change.
  Future<void> deleteArtifact(String artifactId) async {
    final session = _requireRunningSession();
    final idx = session.artifacts.indexWhere((a) => a.id == artifactId);
    if (idx == -1) return;
    final artifact = session.artifacts[idx];
    // Remove the file from disk (best effort).
    try {
      final file = File(artifact.path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
    _currentSession = session.copyWith(
      artifacts: [
        for (var i = 0; i < session.artifacts.length; i++)
          if (i != idx) session.artifacts[i],
      ],
    );
    await _persist();
    notifyListeners();
  }

  TestSession _requireRunningSession() {
    final session = _currentSession;
    if (session == null || session.status != TestSessionStatus.running) {
      throw StateError(_t('errorNoRunningSession'));
    }
    return session;
  }

  Future<Directory> _rootDirectory() async {
    if (baseDirectory != null) return baseDirectory!;
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    final dir = Directory('$home/ADBToolData');
    await dir.create(recursive: true);
    return dir;
  }

  Future<void> _persist() async {
    final session = _currentSession;
    if (session == null) return;
    final file = File('${session.directoryPath}/session.json');
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(session.toJson()));
  }

  Future<void> _writeReport() async {
    final session = _currentSession;
    if (session == null) return;
    final report = File('${session.directoryPath}/report.md');
    final buffer = StringBuffer()
      ..writeln('# ${session.name}')
      ..writeln()
      ..writeln('## ${_t('reportIssueSummary')}')
      ..writeln();
    if (session.issues.isEmpty) {
      buffer.writeln('-');
    } else {
      for (var i = 0; i < session.issues.length; i++) {
        final issue = session.issues[i];
        final attachments = _issueArtifacts(session, issue);
        buffer
          ..writeln('### ISSUE-${_issueNumber(i + 1)} ${issue.title}')
          ..writeln()
          ..writeln('- ${_t('reportType')}: ${_issueTypeLabel(issue.type)}')
          ..writeln(
              '- ${_t('reportSeverity')}: ${_severityLabel(issue.severity)}')
          ..writeln(
              '- ${_t('reportOccurredAt')}: ${_displayDate(issue.createdAt)}')
          ..writeln(
              '- ${_t('reportRelatedAttachments')}: ${attachments.isEmpty ? '-' : attachments.map((artifact) => artifact.name).join(', ')}')
          ..writeln()
          ..writeln('${_t('reportSteps')}:')
          ..writeln(issue.steps.isEmpty ? '-' : issue.steps)
          ..writeln()
          ..writeln('${_t('reportExpected')}:')
          ..writeln(issue.expected.isEmpty ? '-' : issue.expected)
          ..writeln()
          ..writeln('${_t('reportActual')}:')
          ..writeln(issue.actual.isEmpty ? '-' : issue.actual)
          ..writeln();
      }
    }
    buffer
      ..writeln()
      ..writeln('## ${_t('reportBasicInfo')}')
      ..writeln()
      ..writeln('- ${_t('reportTestType')}: ${session.type}')
      ..writeln(
          '- ${_t('reportStatus')}: ${session.status == TestSessionStatus.running ? _t('sessionRunning') : _t('sessionFinished')}')
      ..writeln(
          '- ${_t('reportStartedAt')}: ${_displayDate(session.startedAt)}')
      ..writeln(
          '- ${_t('reportEndedAt')}: ${session.endedAt == null ? '-' : _displayDate(session.endedAt!)}')
      ..writeln(
          '- ${_t('reportDevice')}: ${session.deviceModel.isEmpty ? session.deviceSerial : session.deviceModel}')
      ..writeln(
          '- ${_t('reportBrand')}: ${session.deviceBrand.isEmpty ? '-' : session.deviceBrand}')
      ..writeln(
          '- ${_t('reportSdk')}: ${session.deviceSdk.isEmpty ? '-' : session.deviceSdk}')
      ..writeln(
          '- ${_t('reportPackageName')}: ${session.packageName.isEmpty ? '-' : session.packageName}')
      ..writeln()
      ..writeln('## ${_t('reportInitialNote')}')
      ..writeln()
      ..writeln(session.note.isEmpty ? '-' : session.note)
      ..writeln()
      ..writeln('## ${_t('reportNotes')}')
      ..writeln();
    if (session.notes.isEmpty) {
      buffer.writeln('-');
    } else {
      for (final note in session.notes) {
        buffer.writeln('- ${_displayDate(note.createdAt)} ${note.content}');
      }
    }
    buffer
      ..writeln()
      ..writeln('## ${_t('reportTimeline')}')
      ..writeln();
    for (final event in session.events) {
      buffer.writeln(
          '- ${_displayDate(event.time)} ${event.title}${event.detail.isEmpty ? '' : '：${event.detail}'}');
    }
    buffer
      ..writeln()
      ..writeln('## ${_t('reportAttachments')}')
      ..writeln();
    if (session.artifacts.isEmpty) {
      buffer.writeln('-');
    } else {
      for (final artifact in session.artifacts) {
        buffer.writeln('- ${artifact.kind.name}：${artifact.name}');
      }
    }
    await report.writeAsString(buffer.toString());
  }

  String _t(String key, [Map<String, String>? args]) => _translate(key, args);

  String _bracket(String key) {
    final label = _t(key);
    return label.startsWith('[') || label.startsWith('【') ? label : '【$label】';
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
    'eventSessionCreated': '创建测试会话',
    'eventSessionCreatedDetail': '设备：{device}，包名：{package}',
    'eventNoteAdded': '添加备注',
    'eventIssueMarked': '标记问题',
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

  TestSessionEvent _event(
    TestSessionEventType type,
    String title,
    String detail, {
    String? filePath,
    DateTime? now,
  }) {
    final time = now ?? DateTime.now();
    return TestSessionEvent(
      id: _id(time),
      type: type,
      time: time,
      title: title,
      detail: detail,
      filePath: filePath,
    );
  }

  Future<TestSessionArtifact> _artifact({
    required TestSessionArtifactKind kind,
    required String name,
    required String path,
    required DateTime now,
  }) async {
    final file = File(path);
    return TestSessionArtifact(
      id: _id(now),
      kind: kind,
      name: name,
      path: path,
      createdAt: now,
      size: await file.exists() ? await file.length() : 0,
    );
  }

  Future<TestSessionArtifact> _writeIssueRecentLogArtifact({
    required TestSession session,
    required String issueId,
    required String content,
    required DateTime now,
  }) async {
    final dir = Directory('${session.directoryPath}/issue_logs');
    await dir.create(recursive: true);
    final name = '${issueId}_last_1000_${_fileDate(now)}.log';
    final file = File('${dir.path}/$name');
    await file.writeAsString(content.trimRight());
    return _artifact(
      kind: TestSessionArtifactKind.log,
      name: name,
      path: file.path,
      now: now,
    );
  }

  List<String> _recentArtifactIds(TestSession session) {
    final selected = <TestSessionArtifact>[];
    for (final kind in [
      TestSessionArtifactKind.screenshot,
      TestSessionArtifactKind.video,
      TestSessionArtifactKind.log,
    ]) {
      final matches =
          session.artifacts.where((artifact) => artifact.kind == kind).toList();
      if (matches.isNotEmpty) selected.add(matches.last);
    }
    return selected.map((artifact) => artifact.id).toList();
  }

  List<TestSessionArtifact> _issueArtifacts(
    TestSession session,
    TestSessionIssue issue,
  ) {
    final ids = issue.relatedArtifactIds.toSet();
    return session.artifacts
        .where((artifact) => ids.contains(artifact.id))
        .toList();
  }

  String _deviceLabel(TestSession session) {
    return session.deviceModel.isEmpty
        ? session.deviceSerial
        : session.deviceModel;
  }

  String _issueId(int index) => 'ISSUE-${_issueNumber(index)}';

  String _issueNumber(int index) => index.toString().padLeft(3, '0');

  String _id(DateTime time) => '${time.microsecondsSinceEpoch}';

  String _compactDate(DateTime time) {
    return '${time.year}${_two(time.month)}${_two(time.day)}_${_two(time.hour)}${_two(time.minute)}${_two(time.second)}';
  }

  String _fileDate(DateTime time) {
    return '${time.year}${_two(time.month)}${_two(time.day)}_${_two(time.hour)}${_two(time.minute)}${_two(time.second)}';
  }

  String _displayDate(DateTime time) {
    return '${time.year}-${_two(time.month)}-${_two(time.day)} ${_two(time.hour)}:${_two(time.minute)}:${_two(time.second)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _safeName(String name) {
    final value = name.trim().isEmpty ? 'session' : name.trim();
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9\u4e00-\u9fa5_-]+'), '_');
  }
}
