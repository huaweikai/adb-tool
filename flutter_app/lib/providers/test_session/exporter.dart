// Generates the Markdown report file for the current session.
import 'dart:io';

import 'package:adb_tool/models/test_session.dart';
import 'package:adb_tool/providers/test_session/formatter.dart';
import 'package:adb_tool/providers/test_session/session_translate.dart';

class SessionExporter {
  final SessionTranslate t;
  SessionExporter(this.t);

  /// Renders the test session as a Markdown report at
  /// `<sessionDir>/report.md` and returns the path.
  Future<String> writeReport(TestSession session) async {
    final report = File('${session.directoryPath}/report.md');
    final buffer = StringBuffer()
      ..writeln('# ${session.name}')
      ..writeln()
      ..writeln('## ${t('reportIssueSummary')}')
      ..writeln();
    if (session.issues.isEmpty) {
      buffer.writeln('-');
    } else {
      for (var i = 0; i < session.issues.length; i++) {
        final issue = session.issues[i];
        final attachments = SessionFormatters.issueArtifacts(session, issue);
        buffer
          ..writeln(
              '### ISSUE-${SessionFormatters.issueNumber(i + 1)} ${issue.title}')
          ..writeln()
          ..writeln(
              '- ${t('reportType')}: ${SessionFormatters.issueTypeLabel(t, issue.type)}')
          ..writeln(
              '- ${t('reportSeverity')}: ${SessionFormatters.severityLabel(t, issue.severity)}')
          ..writeln(
              '- ${t('reportOccurredAt')}: ${SessionFormatters.displayDate(issue.createdAt)}')
          ..writeln(
              '- ${t('reportRelatedAttachments')}: ${attachments.isEmpty ? '-' : attachments.map((artifact) => artifact.name).join(', ')}')
          ..writeln()
          ..writeln('${t('reportSteps')}:')
          ..writeln(issue.steps.isEmpty ? '-' : issue.steps)
          ..writeln()
          ..writeln('${t('reportExpected')}:')
          ..writeln(issue.expected.isEmpty ? '-' : issue.expected)
          ..writeln()
          ..writeln('${t('reportActual')}:')
          ..writeln(issue.actual.isEmpty ? '-' : issue.actual)
          ..writeln();
      }
    }
    buffer
      ..writeln()
      ..writeln('## ${t('reportBasicInfo')}')
      ..writeln()
      ..writeln('- ${t('reportTestType')}: ${session.type}')
      ..writeln(
          '- ${t('reportStatus')}: ${session.status == TestSessionStatus.running ? t('sessionRunning') : t('sessionFinished')}')
      ..writeln(
          '- ${t('reportStartedAt')}: ${SessionFormatters.displayDate(session.startedAt)}')
      ..writeln(
          '- ${t('reportEndedAt')}: ${session.endedAt == null ? '-' : SessionFormatters.displayDate(session.endedAt!)}')
      ..writeln(
          '- ${t('reportDevice')}: ${session.deviceModel.isEmpty ? session.deviceSerial : session.deviceModel}')
      ..writeln(
          '- ${t('reportBrand')}: ${session.deviceBrand.isEmpty ? '-' : session.deviceBrand}')
      ..writeln(
          '- ${t('reportSdk')}: ${session.deviceSdk.isEmpty ? '-' : session.deviceSdk}')
      ..writeln(
          '- ${t('reportPackageName')}: ${session.packageName.isEmpty ? '-' : session.packageName}')
      ..writeln()
      ..writeln('## ${t('sessionTestPlan')}')
      ..writeln();
    if (session.testPlan.isEmpty) {
      buffer.writeln('-');
    } else {
      for (final item in session.testPlan) {
        final status = switch (item.status) {
          TestSessionPlanStatus.pending => t('notFilled'),
          TestSessionPlanStatus.passed => t('testPlanPassed'),
          TestSessionPlanStatus.failed => t('testPlanFailed'),
        };
        buffer.writeln('- [$status] ${item.flowName} / ${item.step}');
        if (item.message.isNotEmpty) {
          buffer.writeln('  - ${item.message}');
        }
      }
    }
    buffer
      ..writeln()
      ..writeln('## ${t('reportInitialNote')}')
      ..writeln()
      ..writeln(session.note.isEmpty ? '-' : session.note)
      ..writeln()
      ..writeln('## ${t('reportNotes')}')
      ..writeln();
    if (session.notes.isEmpty) {
      buffer.writeln('-');
    } else {
      for (final note in session.notes) {
        buffer.writeln(
            '- ${SessionFormatters.displayDate(note.createdAt)} ${note.content}');
      }
    }
    buffer
      ..writeln()
      ..writeln('## ${t('reportTimeline')}')
      ..writeln();
    for (final event in session.events) {
      buffer.writeln(
          '- ${SessionFormatters.displayDate(event.time)} ${event.title}${event.detail.isEmpty ? '' : '：${event.detail}'}');
    }
    buffer
      ..writeln()
      ..writeln('## ${t('reportAttachments')}')
      ..writeln();
    if (session.artifacts.isEmpty) {
      buffer.writeln('-');
    } else {
      for (final artifact in session.artifacts) {
        buffer.writeln('- ${artifact.kind.name}：${artifact.name}');
      }
    }
    await report.writeAsString(buffer.toString());
    return report.path;
  }

  /// Builds the human-readable "copy bug info" text from an issue.
  String buildIssueClipboardText(
      TestSession? session, TestSessionIssue issue) {
    final artifacts = session == null
        ? <TestSessionArtifact>[]
        : SessionFormatters.issueArtifacts(session, issue);
    final buffer = StringBuffer()
      ..writeln(SessionFormatters.bracket(t, 'clipboardIssueTitle'))
      ..writeln(issue.title)
      ..writeln()
      ..writeln(SessionFormatters.bracket(t, 'clipboardIssueType'))
      ..writeln(SessionFormatters.issueTypeLabel(t, issue.type))
      ..writeln()
      ..writeln(SessionFormatters.bracket(t, 'clipboardIssueSeverity'))
      ..writeln(SessionFormatters.severityLabel(t, issue.severity))
      ..writeln()
      ..writeln('【发生时间】')
      ..writeln(SessionFormatters.dateTime(issue.createdAt))
      ..writeln()
      ..writeln(SessionFormatters.bracket(t, 'clipboardTestEnvironment'))
      ..writeln(
          '${t('reportDevice')}：${session == null ? '-' : SessionFormatters.deviceLabel(session)}')
      ..writeln(
          '${t('reportBrand')}：${SessionFormatters.emptyIfNone(session?.deviceBrand)}')
      ..writeln(
          '${t('reportSdk')}：${SessionFormatters.emptyIfNone(session?.deviceSdk)}')
      ..writeln(
          '${t('reportPackageName')}：${SessionFormatters.emptyIfNone(session?.packageName)}')
      ..writeln()
      ..writeln(SessionFormatters.bracket(t, 'clipboardIssueSteps'))
      ..writeln(issue.steps.isEmpty ? '-' : issue.steps)
      ..writeln()
      ..writeln(SessionFormatters.bracket(t, 'clipboardIssueExpected'))
      ..writeln(issue.expected.isEmpty ? '-' : issue.expected)
      ..writeln()
      ..writeln(SessionFormatters.bracket(t, 'clipboardIssueActual'))
      ..writeln(issue.actual.isEmpty ? '-' : issue.actual)
      ..writeln()
      ..writeln(SessionFormatters.bracket(t, 'clipboardIssueNote'))
      ..writeln(issue.note.isEmpty ? '-' : issue.note)
      ..writeln()
      ..writeln(SessionFormatters.bracket(t, 'clipboardAttachments'));
    buffer.write(artifacts.isEmpty
        ? '-'
        : artifacts
            .map((artifact) => '${artifact.kind.name}：${artifact.path}')
            .join('\n'));
    return buffer.toString();
  }
}
