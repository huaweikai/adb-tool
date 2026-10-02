import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'design_tokens.dart';

/// ── AppStatusBadge ──────────────────────────────────────────
///
/// Status dot plus label — the unit every surface needed and hand-rolled:
/// `BoxShape.circle` appears 19 times across `lib/screens/` and `lib/widgets/`,
/// mostly paired with a label and a gap.
///
/// Spec: [dotSize] circle in [color], [AppSpacing.sm] gap, then the label at
/// [AppFontSize.body] in `palette.textSecondary`. Defaults are chosen so the
/// common "device online" case needs no arguments beyond the label.
class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.label,
    this.color,
    this.labelColor,
    this.dotSize = 8,
  });

  final String label;

  /// Dot fill. Defaults to `palette.online` (the accent green).
  final Color? color;

  /// Label colour. Defaults to `palette.textSecondary`.
  final Color? labelColor;

  final double dotSize;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: color ?? palette.online,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppFontSize.body,
              color: labelColor ?? palette.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
