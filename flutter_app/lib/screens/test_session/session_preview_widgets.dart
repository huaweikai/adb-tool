// Shared session-preview widgets used by both the hub's history preview
// and the active session's right panel. Kept in their own file so both
// screens can render the same look without duplication.
import 'package:flutter/material.dart';

import '../../i18n.dart';
import '../../models/test_session.dart';
import '../../utils/time_formatters.dart';

Widget previewSectionTitle(ThemeData theme, String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    ),
  );
}

Widget previewInfoCard(ThemeData theme, List<Widget> children) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: theme.dividerColor),
    ),
    child: Column(children: children),
  );
}

Widget previewKv(BuildContext ctx, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 12)),
        ),
      ],
    ),
  );
}

Widget previewPlanItem(
  ThemeData theme,
  TestSessionPlanItem item, {
  VoidCallback? onStatusChange,
}) {
  return Card(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 6),
    color: theme.colorScheme.surfaceContainerLow,
    child: InkWell(
      onTap: onStatusChange,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            planStatusIcon(item.status),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.flowName.isNotEmpty)
                    Text(
                      item.flowName,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  Text(
                    item.step,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  if (item.message.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        item.message,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (onStatusChange != null)
              Icon(
                Icons.chevron_right,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    ),
  );
}

Widget planStatusIcon(TestSessionPlanStatus status) {
  return Icon(
    switch (status) {
      TestSessionPlanStatus.pending => Icons.radio_button_unchecked,
      TestSessionPlanStatus.passed => Icons.check_circle,
      TestSessionPlanStatus.failed => Icons.cancel,
    },
    size: 16,
    color: switch (status) {
      TestSessionPlanStatus.pending => Colors.grey,
      TestSessionPlanStatus.passed => Colors.green,
      TestSessionPlanStatus.failed => Colors.red,
    },
  );
}

Widget previewIssueItem(ThemeData theme, TestSessionIssue issue) {
  return Card(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 6),
    color: theme.colorScheme.surfaceContainerLow,
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: severityColor(issue.severity).withAlpha(35),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  severityLabel(issue.severity),
                  style: TextStyle(
                    fontSize: 11,
                    color: severityColor(issue.severity),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  issue.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          if (issue.actual.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(issue.actual, style: const TextStyle(fontSize: 12)),
          ],
          const SizedBox(height: 4),
          Text(
            fmtDateTime(issue.createdAt),
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget previewNoteItem(ThemeData theme, TestSessionNote note) {
  return Card(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 6),
    color: theme.colorScheme.surfaceContainerLow,
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fmtDateTime(note.createdAt),
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(note.content),
        ],
      ),
    ),
  );
}

Widget previewArtifactItem(ThemeData theme, TestSessionArtifact a) {
  return Card(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 6),
    color: theme.colorScheme.surfaceContainerLow,
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Icon(
            artifactIcon(a.kind),
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(a.name, style: const TextStyle(fontSize: 12)),
          ),
          if (a.size > 0)
            Text(
              fmtBytes(a.size),
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    ),
  );
}

IconData artifactIcon(TestSessionArtifactKind k) => switch (k) {
      TestSessionArtifactKind.screenshot => Icons.image,
      TestSessionArtifactKind.video => Icons.videocam,
      TestSessionArtifactKind.log => Icons.list_alt,
      TestSessionArtifactKind.report => Icons.description,
    };

Color severityColor(TestSessionIssueSeverity s) => switch (s) {
      TestSessionIssueSeverity.blocker => Colors.red,
      TestSessionIssueSeverity.major => Colors.deepOrange,
      TestSessionIssueSeverity.normal => Colors.orange,
      TestSessionIssueSeverity.minor => Colors.blueGrey,
    };

String severityLabel(TestSessionIssueSeverity s) => switch (s) {
      TestSessionIssueSeverity.blocker => tr('issueSeverityBlocker'),
      TestSessionIssueSeverity.major => tr('issueSeverityMajor'),
      TestSessionIssueSeverity.normal => tr('issueSeverityNormal'),
      TestSessionIssueSeverity.minor => tr('issueSeverityMinor'),
    };

String formatElapsedDuration(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  if (h > 0) return '${h}h ${m}m ${s}s';
  return '${m}m ${s}s';
}
