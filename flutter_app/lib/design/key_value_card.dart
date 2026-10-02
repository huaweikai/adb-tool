import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'design_tokens.dart';
import 'panel.dart';

/// One label/value row inside an [AppKeyValueCard].
///
/// [onTap] makes the value a desktop affordance (click cursor + hover
/// underline) — `device_status_screen` used this to open a copyable detail
/// sheet for long readings such as IP addresses or frame stats.
class AppKeyValueItem {
  const AppKeyValueItem({
    required this.label,
    required this.value,
    this.icon,
    this.onTap,
  });

  final String label;

  /// Formatted value; the card renders it verbatim (callers map empty to
  /// their "unknown" copy).
  final String value;

  final IconData? icon;

  final VoidCallback? onTap;
}

/// A grouped list of static readings (resolution / density / signal / …).
///
/// Extracted from `device_status_screen`'s private `_pairedCard`, the only
/// real implementation of a label/value property card. Spec: compact
/// [AppPanel] (padding 16), muted header row, then monospace values aligned
/// in a fixed-width label column so rows line up across the masonry grid.
class AppKeyValueCard extends StatelessWidget {
  const AppKeyValueCard({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
  });

  /// Group name (e.g. "Network / Signal").
  final String title;

  final IconData icon;

  final List<AppKeyValueItem> items;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      hoverable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: palette.accent),
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
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < items.length; i++) ...[
            _KeyValueRow(item: items[i]),
            if (i != items.length - 1) const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatefulWidget {
  const _KeyValueRow({required this.item});

  final AppKeyValueItem item;

  @override
  State<_KeyValueRow> createState() => _KeyValueRowState();
}

class _KeyValueRowState extends State<_KeyValueRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final item = widget.item;
    final tappable = item.onTap != null;
    final value = Text(
      item.value,
      style: TextStyle(
        fontSize: AppFontSize.body,
        fontWeight: FontWeight.w600,
        fontFamily: 'Noto Sans Mono',
        color: palette.textPrimary,
        decoration:
            tappable && _hovered ? TextDecoration.underline : null,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    return Row(
      children: [
        if (item.icon != null) ...[
          Icon(item.icon, size: 14, color: palette.textDisabled),
          const SizedBox(width: AppSpacing.xs),
        ],
        SizedBox(
          width: 96,
          child: Text(
            item.label,
            style: TextStyle(
              fontSize: AppFontSize.md,
              color: palette.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: tappable
              ? MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _hovered = true),
                  onExit: (_) => setState(() => _hovered = false),
                  child: GestureDetector(onTap: item.onTap, child: value),
                )
              : value,
        ),
      ],
    );
  }
}
