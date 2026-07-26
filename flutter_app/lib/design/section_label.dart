import 'package:flutter/material.dart';
import 'app_palette.dart';
import 'design_tokens.dart';

/// ── AppSectionLabel ─────────────────────────────────────────
///
/// Content-area section label — Ardot design node 34:21 (SectionLabel).
///
/// A small bold heading used to title a group of content inside a screen
/// (e.g. "Connected devices", "Recent activity", "Quick actions"). Before
/// this existed, `dashboard_view` hand-rolled the same style in two places
/// (`_SectionLabel` + the `_QuickActions` heading) — a textbook example of
/// why the component layer was needed.
///
/// Spec: Noto Sans SC 14 ([AppFontSize.title]), weight 600, color
/// `palette.textPrimary`. This is distinct from `AppNavGroupLabel` in
/// `app_sidebar.dart`, which is the smaller, muted label used to head nav
/// *groups* in the sidebar (11px, textDisabled, letter-spaced) — do not
/// reuse one for the other.
class AppSectionLabel extends StatelessWidget {
  const AppSectionLabel(
    this.label, {
    super.key,
    this.color,
  });

  final String label;

  /// Override the default `palette.textPrimary` color (e.g. a muted variant
  /// for secondary sections).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: AppFontSize.title,
        fontWeight: FontWeight.w600,
        color: color ?? context.palette.textPrimary,
      ),
    );
  }
}
