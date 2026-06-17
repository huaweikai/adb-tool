import 'package:flutter/material.dart';
import '../models/test_session.dart';
import '../utils/time_formatters.dart';

/// Status icon for a single test plan item.
class PlanStatusIcon extends StatelessWidget {
  final TestSessionPlanStatus status;

  const PlanStatusIcon(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = switch (status) {
      TestSessionPlanStatus.passed => (Icons.check_circle, Colors.green),
      TestSessionPlanStatus.failed => (Icons.cancel, theme.colorScheme.error),
      TestSessionPlanStatus.pending => (
          Icons.radio_button_unchecked,
          theme.colorScheme.onSurfaceVariant,
        ),
    };
    return Icon(icon, size: 18, color: color);
  }
}

/// A single event row in the session timeline.
class SessionTimelineItem extends StatelessWidget {
  final ThemeData theme;
  final TestSessionEvent event;

  /// (type) => translated event title
  final String Function(TestSessionEventType) eventTitle;

  /// (type, theme) => dot color
  final Color Function(TestSessionEventType, ThemeData) eventColor;

  const SessionTimelineItem({
    super.key,
    required this.theme,
    required this.event,
    required this.eventTitle,
    required this.eventColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            fmtTime(event.time),
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 2),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: eventColor(event.type, theme),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eventTitle(event.type),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (event.detail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.detail,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (event.filePath != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.filePath!,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

}

/// Translated event title for each [TestSessionEventType].
String sessionEventTitle(
    TestSessionEventType type, String Function(String) tr) {
  return switch (type) {
    TestSessionEventType.sessionCreated => tr('eventSessionCreated'),
    TestSessionEventType.noteAdded => tr('eventNoteAdded'),
    TestSessionEventType.logcatStarted => tr('eventLogcatStarted'),
    TestSessionEventType.logcatSaved => tr('eventLogcatSaved'),
    TestSessionEventType.screenshotTaken => tr('eventScreenshotSaved'),
    TestSessionEventType.screenRecordStarted => tr('eventScreenRecordStarted'),
    TestSessionEventType.screenRecordStopped => tr('eventScreenRecordSaved'),
    TestSessionEventType.testPlanUpdated => tr('eventTestPlanUpdated'),
    TestSessionEventType.issueMarked => tr('eventIssueMarked'),
    TestSessionEventType.sessionFinished => tr('eventSessionFinished'),
  };
}

/// Dot color for each [TestSessionEventType].
Color sessionEventColor(TestSessionEventType type, ThemeData theme) {
  return switch (type) {
    TestSessionEventType.sessionCreated => theme.colorScheme.primary,
    TestSessionEventType.noteAdded => Colors.amber,
    TestSessionEventType.logcatStarted => Colors.green,
    TestSessionEventType.logcatSaved => Colors.green,
    TestSessionEventType.screenshotTaken => Colors.blue,
    TestSessionEventType.screenRecordStarted => Colors.purple,
    TestSessionEventType.screenRecordStopped => Colors.purpleAccent,
    TestSessionEventType.testPlanUpdated => Colors.teal,
    TestSessionEventType.issueMarked => Colors.deepOrange,
    TestSessionEventType.sessionFinished => theme.colorScheme.error,
  };
}
