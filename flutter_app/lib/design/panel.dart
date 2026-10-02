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
///
/// Desktop hover: a panel is interactive when it has [onTap] or is marked
/// [hoverable]; on hover it lifts with a shadow derived from
/// [AppElevation.card] (spec §7 — hover feedback comes from elevation, never
/// from a colour swap) and settles back over [AppDuration.fast].
class AppPanel extends StatefulWidget {
  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.color,
    this.borderColor,
    this.borderRadius,
    this.onTap,
    this.hoverable = false,
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

  /// Lift on hover even without [onTap] (e.g. read-only metric cards that
  /// still want desktop hover feedback).
  final bool hoverable;

  @override
  State<AppPanel> createState() => _AppPanelState();
}

class _AppPanelState extends State<AppPanel> {
  bool _hovered = false;

  bool get _interactive => widget.onTap != null || widget.hoverable;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = widget.borderRadius ?? AppRadius.lg;
    final decoration = BoxDecoration(
      color: widget.color ?? palette.panel,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: widget.borderColor ?? palette.hairline),
      boxShadow: _interactive && _hovered
          ? [
              BoxShadow(
                color: Colors.black.withAlpha(56),
                blurRadius: AppElevation.card * 4,
                offset: Offset(0, AppElevation.card),
              ),
            ]
          : null,
    );
    Widget content = AnimatedContainer(
      duration: AppDuration.fast,
      decoration: decoration,
      padding: widget.padding,
      child: widget.child,
    );
    if (_interactive) {
      content = MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: content,
      );
    }
    if (widget.onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: widget.onTap, child: content),
    );
  }
}
