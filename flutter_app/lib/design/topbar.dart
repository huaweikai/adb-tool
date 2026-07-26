import 'package:flutter/material.dart';
import 'app_palette.dart';
import 'design_tokens.dart';

/// ── AppTopbar ───────────────────────────────────────────────
///
/// Unified top bar shell — Ardot design node 2:10 (Topbar).
///
/// Spec: height 64, horizontal padding 24 ([AppSpacing.xl], aligned with the
/// content inset), fill `palette.panel`, 1px `palette.hairline` bottom
/// border. This is the single shell every content screen should compose its
/// header into — previously each screen hand-rolled its own `_Topbar`.
///
/// Layout: `[title] [subtitle?] [Spacer] [actions?]` in a 64px row.
/// Screen-specific status dots / device names go in [subtitle]; CTA buttons
/// or hint text go in [actions]. The shell owns only the box + spacing, so
/// colors/typography stay consistent across pages and a token change here
/// propagates everywhere.
class AppTopbar extends StatelessWidget {
  const AppTopbar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  });

  /// Primary title text (e.g. page name). Rendered at headline size, bold.
  final String title;

  /// Optional widget placed right after the title — typically a status dot +
  /// device name for the dashboard, or omitted on plain pages.
  final Widget? subtitle;

  /// Optional trailing widget pushed to the far right (hint text, buttons…).
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: BoxDecoration(
        color: palette.panel,
        border: Border(bottom: BorderSide(color: palette.hairline)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: AppFontSize.headline,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: AppSpacing.md),
            subtitle!,
          ],
          const Spacer(),
          if (actions != null) actions!,
        ],
      ),
    );
  }
}
