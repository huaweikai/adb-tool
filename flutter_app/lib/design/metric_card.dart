import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'design_tokens.dart';
import 'panel.dart';
import '../widgets/sparkline.dart';

/// How far a [AppMetricCard]'s reading sits from its healthy range.
///
/// Derived from the reading plus the caller's thresholds; drives one colour
/// (icon, progress track, sparkline) so a card never mixes signals.
enum AppMetricSeverity { ok, warning, critical }

/// A single live reading (CPU / memory / storage / battery …).
///
/// Extracted from `device_status_screen`'s private `_metricCard`, which was
/// the only real implementation of a threshold-tinted reading card. Spec:
/// compact [AppPanel] (padding 16), big [AppFontSize.metric] value, optional
/// progress track + sparkline tinted by [AppMetricSeverity], and desktop
/// hover lift from [AppPanel.hoverable].
class AppMetricCard extends StatelessWidget {
  const AppMetricCard({
    super.key,
    required this.title,
    required this.icon,
    required this.value,
    this.subtitle,
    this.progress,
    this.warningThreshold,
    this.criticalThreshold,
    this.invertedThresholds = false,
    this.sparkline,
  });

  /// Reading name (e.g. "CPU").
  final String title;

  final IconData icon;

  /// Formatted reading (e.g. "23%").
  final String value;

  /// Secondary line under the value; omitted when null/empty.
  final String? subtitle;

  /// 0..1 fill for the progress track; null hides the track.
  final double? progress;

  /// [progress] at or above this tints the card [AppMetricSeverity.warning].
  final double? warningThreshold;

  /// [progress] at or above this tints the card [AppMetricSeverity.critical].
  final double? criticalThreshold;

  /// Flip the comparison for readings where *low* is bad (battery): warn at
  /// or below [warningThreshold], critical at or below [criticalThreshold].
  /// The legacy `_metricCard` compared `>=` for every reading, which tinted a
  /// full battery red; this flag restores the intended battery semantics.
  final bool invertedThresholds;

  /// Recent samples (0..1) drawn as a sparkline; needs >= 2 points.
  final List<double>? sparkline;

  AppMetricSeverity? get severity {
    final p = progress;
    if (p == null) return null;
    final critical = criticalThreshold;
    final warning = warningThreshold;
    if (invertedThresholds) {
      if (critical != null && p <= critical) return AppMetricSeverity.critical;
      if (warning != null && p <= warning) return AppMetricSeverity.warning;
      return AppMetricSeverity.ok;
    }
    if (critical != null && p >= critical) return AppMetricSeverity.critical;
    if (warning != null && p >= warning) return AppMetricSeverity.warning;
    return AppMetricSeverity.ok;
  }

  Color _severityColor(AppPalette palette) {
    switch (severity) {
      case AppMetricSeverity.critical:
        return palette.red;
      case AppMetricSeverity.warning:
        return palette.orange;
      case AppMetricSeverity.ok:
      case null:
        return palette.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tint = _severityColor(palette);
    final hasProgress = progress != null;
    final samples = sparkline;
    final sub = subtitle;
    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      hoverable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: tint),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: AppFontSize.body,
                    color: palette.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: TextStyle(
              fontSize: AppFontSize.metric,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (hasProgress) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: palette.raised,
                valueColor: AlwaysStoppedAnimation<Color>(tint),
              ),
            ),
          ],
          if (samples != null && samples.length >= 2) ...[
            const SizedBox(height: AppSpacing.sm),
            Sparkline(data: samples, height: 24, color: tint),
          ],
          if (sub != null && sub.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              sub,
              style: TextStyle(
                fontSize: AppFontSize.md,
                color: palette.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
