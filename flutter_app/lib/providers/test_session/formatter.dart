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

  /// Unique-enough session ID: microseconds + safe name. Microseconds are
  /// guaranteed unique within a process even for same-second sessions.
  static String sessionId(DateTime time, String name) {
    return '${id(time)}_${safeName(name)}';
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

  /// Plan item ID scoped to a session. Appended to the session's microsecond ID
  /// so the same step name in different sessions never collides.
  static String planItemId(String sessionId, int index) =>
      '${sessionId}_STEP-${issueNumber(index)}';

  static String safeName(String name) {
    final value = name.trim().isEmpty ? 'session' : name.trim();
    // No `+` quantifier — each non-allowed char becomes its own `_`
    // (e.g. `"Test / Debug"` → `"Test__Debug"`, not `"Test_Debug"`).
    // This matches what test/session_formatter_test.dart expects and
    // also gives stable width for downstream IDs / log file names.
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9\u4e00-\u9fa5_-]'), '_');
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

  /// Strips empty steps and resets each step's status to `pending`
  /// (so re-imported plans start fresh). Does NOT assign IDs — the caller
  /// (startSession) must call planItemId() with the session ID.
  static List<TestSessionPlanItem> normalizeTestPlan(
      List<TestSessionPlanItem> items) {
    final result = <TestSessionPlanItem>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final step = item.step.trim();
      if (step.isEmpty) continue;
      result.add(
        item.copyWith(
          id: item.id.trim(),
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
