import 'package:flutter/material.dart';
import 'app_palette.dart';
import 'design_tokens.dart';

/// ── AppPanel ────────────────────────────────────────────────
///
/// Content card / panel shell — Ardot design node 34:1 (Panel).
///
/// The base surface container used everywhere a content card is needed:
/// hero cards, metric cards, error notes, empty placeholders. Before this
/// existed, `dashboard_view` hand-rolled the same
/// `Container(decoration: BoxDecoration(color: panel, borderRadius: lg,
/// border: hairline))` in four different widgets (_HeroCard, _MetricCard,
/// _ErrorNote, _RecentActivity) — a textbook case of the component-layer gap.
///
/// Spec: fill `palette.panel`, 1px `palette.hairline` border, corner
/// radius [AppRadius.lg] (12). Default padding [AppSpacing.xl] (24) per the
/// design token "卡片内边距 = 24px"; pass an explicit [padding] to override
/// (e.g. compact metric cards use 16).
class AppPanel extends StatelessWidget {
  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.color,
    this.borderColor,
    this.borderRadius,
    this.onTap,
  });

  final Widget child;

  /// Inner padding. Defaults to [EdgeInsets.all]([AppSpacing.xl]) = 24, the
  /// design token for card inset. Pass a smaller value for compact cards,
  /// or [EdgeInsets.zero] for full-bleed content (e.g. a Sparkline that
  /// paints edge-to-edge).
  final EdgeInsets padding;

  /// Defaults to `palette.panel`.
  final Color? color;

  /// Defaults to `palette.hairline`. Pass a tinted color (e.g. error red)
  /// for semantic variants like the error note panel.
  final Color? borderColor;

  /// Defaults to [AppRadius.lg] = 12.
  final double? borderRadius;

  /// When set, the panel becomes tappable (InkWell ripple clipped to the
  /// border radius).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = borderRadius ?? AppRadius.lg;
    final decoration = BoxDecoration(
      color: color ?? palette.panel,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? palette.hairline),
    );
    final Widget content = Container(
      decoration: decoration,
      padding: padding,
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
