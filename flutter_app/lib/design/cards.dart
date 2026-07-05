import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// ── MetricCard ──────────────────────────────────────────────
///
/// Dashboard-style card with a prominent value, optional progress
/// bar, and a left-side threshold color indicator.
///
///   ┌─── MetricCard ──────────────────────────┐
///   │ │  🔋 Battery    (colored left border)  │
///   │ │  85%   (large value)                  │
///   │ │  ████████████░░░░░░  (progress bar)   │
///   │ │  Charging · 32°C                      │
///   └─────────────────────────────────────────┘
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
    this.progress,
    this.progressColor,
    this.warningThreshold,
    this.criticalThreshold,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;
  final double? progress;
  final Color? progressColor;
  final double? warningThreshold;
  final double? criticalThreshold;
  final VoidCallback? onTap;

  Color _thresholdColor(ThemeData theme) {
    if (progress == null) return Colors.transparent;
    if (criticalThreshold != null && progress! >= criticalThreshold!) {
      return theme.colorScheme.error;
    }
    if (warningThreshold != null && progress! >= warningThreshold!) {
      return Colors.orange;
    }
    return Colors.green;
  }

  Color _barColor(ThemeData theme) {
    if (progressColor != null) return progressColor!;
    if (progress == null) return theme.colorScheme.primary;
    if (criticalThreshold != null && progress! >= criticalThreshold!) {
      return theme.colorScheme.error;
    }
    if (warningThreshold != null && progress! >= warningThreshold!) {
      return Colors.orange;
    }
    return theme.colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _thresholdColor(theme);
    final hasProgress = progress != null;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: color == Colors.transparent
              ? null
              : BoxDecoration(
                  border: Border(left: BorderSide(width: 3, color: color)),
                ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: AppFontSize.body,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                value,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
              if (hasProgress) ...[
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: LinearProgressIndicator(
                    value: progress!.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHighest,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(_barColor(theme)),
                  ),
                ),
              ],
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: AppFontSize.body,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// ── SettingCard ─────────────────────────────────────────────
///
/// Settings / configuration card with an action button.
///
///   ┌─── SettingCard ──────────────────────────┐
///   │  🧹  Clean Cache                [Clean]  │
///   │  Delete all temporary files              │
///   └──────────────────────────────────────────┘
class SettingCard extends StatelessWidget {
  const SettingCard({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.actionDisabled = false,
    this.trailing,
    this.isLoading = false,
  });

  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool actionDisabled;
  final Widget? trailing;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (description != null && description!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: AppSpacing.sm),
              isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : FilledButton.tonalIcon(
                      onPressed: actionDisabled ? null : onAction,
                      icon: const Icon(Icons.chevron_right, size: 16),
                      label: Text(actionLabel!),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        textStyle: const TextStyle(fontSize: AppFontSize.body),
                      ),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ── ActionCard ──────────────────────────────────────────────
///
/// Compact single-action card, similar to a list tile but with
/// Card elevation.
///
///   ┌─── ActionCard ──────────────────────────┐
///   │  📡  Wireless ADB                    →  │
///   └─────────────────────────────────────────┘
class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.isActive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: isActive
              ? theme.colorScheme.primaryContainer.withAlpha(80)
              : null,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: AppFontSize.title,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w500,
                        color: isActive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: AppFontSize.body,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
