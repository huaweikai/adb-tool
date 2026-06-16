// Pure string formatters, model constructors, and small helpers used across
// the other test_session/* files. No file I/O lives here.
import 'package:adb_tool/models/test_session.dart';
import 'package:adb_tool/providers/test_session/session_translate.dart';

class SessionFormatters {
  // ===== Date formatting =====

  static String pad2(int value) => value.toString().padLeft(2, '0');
  static String two(int value) => value.toString().padLeft(2, '0');

  static String dateTime(DateTime time) {
    return '${time.year}-${pad2(time.month)}-${pad2(time.day)} '
        '${pad2(time.hour)}:${pad2(time.minute)}:${pad2(time.second)}';
  }

  static String compactDate(DateTime time) {
    return '${time.year}${two(time.month)}${two(time.day)}_'
        '${two(time.hour)}${two(time.minute)}${two(time.second)}';
  }

  static String fileDate(DateTime time) => compactDate(time);

  static String displayDate(DateTime time) {
    return '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }

  // ===== Identifiers =====

  static String id(DateTime time) => '${time.microsecondsSinceEpoch}';

  static String issueId(int index) => 'ISSUE-${issueNumber(index)}';

  static String issueNumber(int index) => index.toString().padLeft(3, '0');

  static String safeName(String name) {
    final value = name.trim().isEmpty ? 'session' : name.trim();
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9\u4e00-\u9fa5_-]+'), '_');
  }

  // ===== Labels (translated) =====

  static String issueTypeLabel(
      SessionTranslate t, TestSessionIssueType type) {
    return switch (type) {
      TestSessionIssueType.crash => t('issueTypeCrash'),
      TestSessionIssueType.anr => t('issueTypeAnr'),
      TestSessionIssueType.performance => t('issueTypePerformance'),
      TestSessionIssueType.ui => t('issueTypeUi'),
      TestSessionIssueType.api => t('issueTypeApi'),
      TestSessionIssueType.functional => t('issueTypeFunctional'),
      TestSessionIssueType.compatibility => t('issueTypeCompatibility'),
      TestSessionIssueType.other => t('issueTypeOther'),
    };
  }

  static String severityLabel(
      SessionTranslate t, TestSessionIssueSeverity s) {
    return switch (s) {
      TestSessionIssueSeverity.blocker => t('issueSeverityBlocker'),
      TestSessionIssueSeverity.major => t('issueSeverityMajor'),
      TestSessionIssueSeverity.normal => t('issueSeverityNormal'),
      TestSessionIssueSeverity.minor => t('issueSeverityMinor'),
    };
  }

  static String deviceLabel(TestSession session) {
    return session.deviceModel.isEmpty
        ? session.deviceSerial
        : session.deviceModel;
  }

  static String emptyIfNone(String? value) {
    if (value == null || value.isEmpty) return '-';
    return value;
  }

  /// Wraps a translation in 【】 if it isn't already bracketed.
  static String bracket(SessionTranslate t, String key) {
    final label = t(key);
    return label.startsWith('[') || label.startsWith('【')
        ? label
        : '【$label】';
  }

  // ===== Test plan normalization =====

  /// Strips empty steps, fills in missing step IDs, and resets each step's
  /// status to `pending` (so re-imported plans start fresh).
  static List<TestSessionPlanItem> normalizeTestPlan(
      List<TestSessionPlanItem> items) {
    final result = <TestSessionPlanItem>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final step = item.step.trim();
      if (step.isEmpty) continue;
      result.add(
        item.copyWith(
          id: item.id.trim().isEmpty
              ? 'STEP-${issueNumber(result.length + 1)}'
              : item.id,
          status: TestSessionPlanStatus.pending,
          message: '',
        ),
      );
    }
    return result;
  }

  // ===== Artifact helpers =====

  /// Returns the most-recent artifact ID for each interesting kind, in a
  /// fixed order (screenshot, video, log). Used to auto-link to a marked
  /// issue the artifacts the tester most likely cared about.
  static List<String> recentArtifactIds(TestSession session) {
    final selected = <TestSessionArtifact>[];
    for (final kind in [
      TestSessionArtifactKind.screenshot,
      TestSessionArtifactKind.video,
      TestSessionArtifactKind.log,
    ]) {
      final matches = session.artifacts
          .where((artifact) => artifact.kind == kind)
          .toList();
      if (matches.isNotEmpty) selected.add(matches.last);
    }
    return selected.map((artifact) => artifact.id).toList();
  }

  static List<TestSessionArtifact> issueArtifacts(
      TestSession session, TestSessionIssue issue) {
    final ids = issue.relatedArtifactIds.toSet();
    return session.artifacts
        .where((artifact) => ids.contains(artifact.id))
        .toList();
  }

  // ===== Event / artifact construction =====

  /// Builds a [TestSessionEvent]. The id is microsecond-precise so consecutive
  /// events never collide even when added in a tight loop.
  static TestSessionEvent buildEvent(
    TestSessionEventType type,
    String title,
    String detail, {
    String? filePath,
    DateTime? now,
  }) {
    final time = now ?? DateTime.now();
    return TestSessionEvent(
      id: id(time),
      type: type,
      time: time,
      title: title,
      detail: detail,
      filePath: filePath,
    );
  }
}
