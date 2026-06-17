// Markdown report generator. Reads the session + all child rows from the
// DB, formats into report.md, writes to disk under the session's
// artifact directory.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../db/database.dart';
import '../../models/test_session.dart';
import 'formatter.dart';
import 'session_translate.dart';

class SessionExporter {
  final SessionTranslate t;
  SessionExporter(this.t);

  /// Render the test session as a Markdown report and write it to
  /// `<base>/.session_artifacts/<sessionId>/report.md`. Returns the
  /// absolute path of the written file.
  Future<String> writeReport(TestSessionRow session,
      {required AppDatabase db}) async {
    final events = await db.testSessionsDao.watchEventsForSession(session.id).first;
    final artifacts =
        await db.testSessionsDao.watchArtifactsForSession(session.id).first;
    final issues =
        await db.testSessionsDao.watchIssuesForSession(session.id).first;
    final notes =
        await db.testSessionsDao.watchNotesForSession(session.id).first;
    final planItems = await db
        .testSessionsDao
        .watchPlanItemsForSession(session.id)
        .first;

    final appSupport = await getApplicationSupportDirectory();
    final reportDir = Directory(p.join(
      appSupport.path,
      '.session_artifacts',
      session.id,
    ));
    if (!await reportDir.exists()) await reportDir.create(recursive: true);
    final report = File(p.join(reportDir.path, 'report.md'));

    final buffer = StringBuffer()
      ..writeln('# ${session.name}')
      ..writeln()
      ..writeln('## ${t('reportIssueSummary')}')
      ..writeln();
    if (issues.isEmpty) {
      buffer.writeln('-');
    } else {
      for (var i = 0; i < issues.length; i++) {
        final issue = issues[i];
        final linkedArtifacts = await db.testSessionsDao
            .findArtifactsForIssue(issue.id);
        final linkedNames =
            linkedArtifacts.map((a) => a.name).join(', ');
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
              '- ${t('reportRelatedAttachments')}: ${linkedNames.isEmpty ? '-' : linkedNames}')
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
    if (planItems.isEmpty) {
      buffer.writeln('-');
    } else {
      for (final item in planItems) {
        final status = switch (item.status) {
          TestSessionPlanStatus.pending => t('notFilled'),
          TestSessionPlanStatus.passed => t('testPlanPassed'),
          TestSessionPlanStatus.failed => t('testPlanFailed'),
        };
        final durStr = (item.startedAt != null && item.updatedAt != null)
            ? ' (${item.updatedAt!.difference(item.startedAt!).inMinutes}m '
                '${item.updatedAt!.difference(item.startedAt!).inSeconds.remainder(60)}s)'
            : '';
        buffer.writeln(
            '- [$status] ${item.flowName} / ${item.step}$durStr');
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
    if (notes.isEmpty) {
      buffer.writeln('-');
    } else {
      for (final note in notes) {
        buffer.writeln(
            '- ${SessionFormatters.displayDate(note.createdAt)} ${note.content}');
      }
    }
    buffer
      ..writeln()
      ..writeln('## ${t('reportTimeline')}')
      ..writeln();
    for (final event in events) {
      buffer.writeln(
          '- ${SessionFormatters.displayDate(event.time)} ${event.title}${event.detail.isEmpty ? '' : '：${event.detail}'}');
    }
    buffer
      ..writeln()
      ..writeln('## ${t('reportAttachments')}')
      ..writeln();
    if (artifacts.isEmpty) {
      buffer.writeln('-');
    } else {
      for (final artifact in artifacts) {
        buffer.writeln('- ${artifact.kind.name}：${artifact.name}');
      }
    }
    await report.writeAsString(buffer.toString());
    return report.path;
  }

  /// Builds the human-readable "copy bug info" text from an issue.
  /// Looks up artifacts via the m:n table; everything else reads from
  /// the row itself.
  String buildIssueClipboardText({
    required TestSessionRow session,
    required TestSessionIssueRow issue,
    required List<TestSessionArtifactRow> linkedArtifacts,
  }) {
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
      ..writeln('${t('reportDevice')}：${session.deviceModel.isEmpty ? session.deviceSerial : session.deviceModel}')
      ..writeln('${t('reportBrand')}：${session.deviceBrand.isEmpty ? '-' : session.deviceBrand}')
      ..writeln('${t('reportSdk')}：${session.deviceSdk.isEmpty ? '-' : session.deviceSdk}')
      ..writeln('${t('reportPackageName')}：${session.packageName.isEmpty ? '-' : session.packageName}')
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
    buffer.write(linkedArtifacts.isEmpty
        ? '-'
        : linkedArtifacts
            .map((artifact) => '${artifact.kind.name}：${artifact.path}')
            .join('\n'));
    return buffer.toString();
  }
}
