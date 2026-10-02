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

/// ── AppTopbarIconButton ─────────────────────────────────────
///
/// Header action button. Screens assembled `Tooltip` + `IconButton` by hand in
/// ~20 places with three different hit areas, so header controls never lined up
/// with each other or with the 64px [AppTopbar].
///
/// Spec: 36×36 hit area, `palette.raised` on hover/press, icon 18 in
/// `palette.textSecondary`, switching to [AppPalette.accent] when [isActive].
class AppTopbarIconButton extends StatelessWidget {
  const AppTopbarIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.isActive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Marks a toggle-style action (recording on, filters shown, ...) without
  /// changing the hit area.
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 18,
          color: isActive ? palette.accent : palette.textSecondary,
        ),
        style: IconButton.styleFrom(
          minimumSize: const Size(36, 36),
          padding: EdgeInsets.zero,
          hoverColor: palette.raised,
          highlightColor: palette.raised,
          // Without this the platform's padded tap target silently raises the
          // button to 48px, so the declared 36px hit area would be a lie.
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
