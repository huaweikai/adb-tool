import 'dart:convert';
import 'dart:io';

import 'package:adb_tool/i18n.dart' as i18n;
import 'package:adb_tool/models/test_session.dart';
import 'package:adb_tool/providers/test_session_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late TestSessionProvider provider;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('adb_tool_session_test_');
    provider = TestSessionProvider(baseDirectory: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('startSession creates a running session with directory and timeline',
      () async {
    final session = await provider.startSession(
      name: '登录流程测试',
      type: '缺陷复现',
      serial: 'device-123',
      model: 'Pixel 7',
      brand: 'Google',
      sdk: '34',
      deviceDisplayName: 'Pixel 7',
      packageName: 'com.example.app',
      note: '复现登录问题',
    );

    expect(session.status, TestSessionStatus.running);
    expect(session.deviceSerial, 'device-123');
    expect(session.deviceModel, 'Pixel 7');
    expect(session.packageName, 'com.example.app');
    expect(session.events, hasLength(1));
    expect(session.events.single.type, TestSessionEventType.sessionCreated);
    expect(await Directory(session.directoryPath).exists(), isTrue);
    expect(
        await File('${session.directoryPath}/session.json').exists(), isTrue);
  });

  test('saveLogcat adds a log artifact and persists session json', () async {
    final session = await provider.startSession(
      name: '日志测试',
      type: '冒烟测试',
      serial: 'serial',
      deviceDisplayName: 'serial',
      packageName: 'com.example.app',
    );

    final path = await provider.saveLogcat('line1\nline2');
    final saved = provider.currentSession!;

    expect(path, endsWith('.log'));
    expect(await File(path).readAsString(), 'line1\nline2');
    expect(saved.artifacts.where((a) => a.kind == TestSessionArtifactKind.log),
        hasLength(1));
    expect(saved.events.last.type, TestSessionEventType.logcatSaved);

    final jsonFile = File('${session.directoryPath}/session.json');
    final json =
        jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;
    expect(json['artifacts'], hasLength(1));
  });

  test('finishSession writes report with notes and marks session finished',
      () async {
    await provider.startSession(
      name: '导出测试',
      type: '回归测试',
      serial: 'serial',
      model: 'Xiaomi 13',
      deviceDisplayName: 'Xiaomi 13',
      packageName: 'com.example.app',
    );
    await provider.addNote('点击头像后闪退');

    final finished = await provider.finishSession();

    expect(finished.status, TestSessionStatus.finished);
    expect(finished.endedAt, isNotNull);
    final report = File('${finished.directoryPath}/report.md');
    expect(await report.exists(), isTrue);
    final content = await report.readAsString();
    expect(content, contains('导出测试'));
    expect(content, contains('点击头像后闪退'));
  });

  test('markIssue stores structured issue and associates recent artifacts',
      () async {
    final session = await provider.startSession(
      name: '问题测试',
      type: '缺陷复现',
      serial: 'serial',
      model: 'Xiaomi 13',
      deviceDisplayName: 'Xiaomi 13',
      packageName: 'com.example.app',
    );
    await provider.saveScreenshotBytes([1, 2, 3]);
    await provider.saveLogcat('FATAL EXCEPTION\nNullPointerException');

    final issue = await provider.markIssue(
      title: '登录后点击头像闪退',
      type: TestSessionIssueType.crash,
      severity: TestSessionIssueSeverity.major,
      steps: '1. 登录\n2. 点击头像',
      expected: '进入头像编辑页面',
      actual: 'App 闪退',
      note: '小米 13 必现',
    );
    final saved = provider.currentSession!;

    expect(saved.issues, hasLength(1));
    expect(issue.title, '登录后点击头像闪退');
    expect(issue.relatedArtifactIds, hasLength(2));
    expect(saved.events.last.type, TestSessionEventType.issueMarked);

    final jsonFile = File('${session.directoryPath}/session.json');
    final json =
        jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;
    expect(json['issues'], hasLength(1));
    expect(json['issues'][0]['severity'], 'major');
  });

  test('markIssue writes recent log snapshot as independent issue artifact',
      () async {
    final session = await provider.startSession(
      name: '最近日志测试',
      type: '缺陷复现',
      serial: 'serial',
      model: 'Pixel 7',
      deviceDisplayName: 'Pixel 7',
      packageName: 'com.example.app',
    );

    final issue = await provider.markIssue(
      title: '点击保存后崩溃',
      type: TestSessionIssueType.crash,
      severity: TestSessionIssueSeverity.major,
      recentLogContent: List.generate(3, (i) => 'recent log $i').join('\n'),
    );
    final saved = provider.currentSession!;
    final logArtifacts = saved.artifacts
        .where((artifact) => artifact.kind == TestSessionArtifactKind.log)
        .toList();

    expect(logArtifacts, hasLength(1));
    expect(logArtifacts.single.name, contains('ISSUE-001_last_1000'));
    expect(issue.relatedArtifactIds, contains(logArtifacts.single.id));
    expect(await File(logArtifacts.single.path).readAsString(),
        'recent log 0\nrecent log 1\nrecent log 2');
    expect(logArtifacts.single.path,
        startsWith('${session.directoryPath}/issue_logs/'));
  });

  test('setTranslator notifies listeners so language switch can refresh UI',
      () async {
    var notified = false;
    provider.addListener(() => notified = true);

    provider.setTranslator((key, [args]) => key);

    expect(notified, isTrue);
  });

  test('provider uses injected translator for clipboard and report text',
      () async {
    i18n.setLang('en');
    provider = TestSessionProvider(baseDirectory: tempDir, translate: i18n.tr);
    await provider.startSession(
      name: 'English report',
      type: 'Bug Reproduction',
      serial: 'serial',
      model: 'Pixel 7',
      deviceDisplayName: 'Pixel 7',
      packageName: 'com.example.app',
    );
    final issue = await provider.markIssue(
      title: 'Payment page blank',
      type: TestSessionIssueType.functional,
      severity: TestSessionIssueSeverity.blocker,
      steps: '1. Open payment page',
      expected: 'Payment methods are shown',
      actual: 'Blank page',
    );

    final text = provider.buildIssueClipboardText(issue);
    final finished = await provider.finishSession();
    final report =
        await File('${finished.directoryPath}/report.md').readAsString();

    expect(text, contains('[Issue Title]'));
    expect(text, contains('[Reproduction Steps]'));
    expect(text, contains('Blocker'));
    expect(report, contains('## Issue Summary'));
    expect(report, contains('- Severity: Blocker'));
    expect(report, isNot(contains('## 问题摘要')));
    i18n.setLang('zh');
  });

  test('report and clipboard text prioritize issue details for developers',
      () async {
    await provider.startSession(
      name: '报告测试',
      type: '缺陷复现',
      serial: 'serial',
      model: 'Pixel 7',
      deviceDisplayName: 'Pixel 7',
      packageName: 'com.example.app',
    );
    final issue = await provider.markIssue(
      title: '支付页白屏',
      type: TestSessionIssueType.functional,
      severity: TestSessionIssueSeverity.blocker,
      steps: '1. 进入支付页',
      expected: '展示支付方式',
      actual: '页面白屏',
      note: '回归版本出现',
    );

    final text = provider.buildIssueClipboardText(issue);
    final finished = await provider.finishSession();
    final report =
        await File('${finished.directoryPath}/report.md').readAsString();

    expect(text, contains('【问题标题】'));
    expect(text, contains('支付页白屏'));
    expect(text, contains('【复现步骤】'));
    expect(report, contains('## 问题摘要'));
    expect(report, contains('ISSUE-001 支付页白屏'));
    expect(report, contains('阻塞'));
  });
}
