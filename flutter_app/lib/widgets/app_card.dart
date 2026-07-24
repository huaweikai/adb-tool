import 'package:flutter/material.dart';

import '../design/design_tokens.dart';

/// ── AppCard ──────────────────────────────────────────────────
///
/// The new design system's base surface card. Mirrors the unified Card
/// spec from the Ardot design: cornerRadius 12, fill #0E1118
/// ([AppColors.panel]), optional 1px hairline border ([AppColors.hairline]).
///
///   ┌─── AppCard ───────────────────────────────┐
///   │  Title              trailing               │  ← optional header
///   │  subtitle                                   │
///   ├─────────────────────────────────────────────┤
///   │  child                                      │
///   └─────────────────────────────────────────────┘
///
/// Use this as the base for every elevated content block in the new UI
/// (device summary, quick actions, log card, metric cards, …). The legacy
/// `lib/design/cards.dart` (MetricCard/SettingCard/ActionCard) stays for
/// old screens; new screens use [AppCard] + compose their own header/body.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.headerPadding,
    this.cornerRadius = AppRadius.lg, // 12 — design spec
    this.fill = AppColors.panel,
    this.showBorder = true,
    this.onTap,
  });

  /// Card body. If [title] is set, this sits below the header.
  final Widget child;

  /// Optional header title. When non-null, renders a header row above [child].
  final String? title;

  /// Optional header subtitle, shown under [title] in secondary color.
  final String? subtitle;

  /// Optional widget at the header's right edge (action button, badge, …).
  final Widget? trailing;

  /// Padding around [child]. Default 16 all sides.
  final EdgeInsetsGeometry padding;

  /// Override header padding (defaults to [padding] with bottom = 12).
  final EdgeInsetsGeometry? headerPadding;

  /// Corner radius. Default 12 (design spec).
  final double cornerRadius;

  /// Card fill. Default [AppColors.panel].
  final Color fill;

  /// Whether to draw the 1px hairline border. Default true.
  final bool showBorder;

  /// Makes the whole card tappable (InkWell). Null = non-interactive.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasHeader = title != null || trailing != null;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(cornerRadius),
    );

    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasHeader)
          Padding(
            padding: headerPadding ??
                EdgeInsets.fromLTRB(
                  padding.resolve(TextDirection.ltr).left,
                  padding.resolve(TextDirection.ltr).top,
                  padding.resolve(TextDirection.ltr).right,
                  AppSpacing.md, // 12 — tighter below header
                ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title != null)
                        Text(
                          title!,
                          style: const TextStyle(
                            fontSize: AppFontSize.headline, // 16
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: AppFontSize.body, // 12
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  trailing!,
                ],
              ],
            ),
          ),
        Expanded(child: Padding(padding: padding, child: child)),
      ],
    );

    // No header → just pad the child directly, no Column needed.
    final content = hasHeader
        ? inner
        : Padding(padding: padding, child: child);

    final card = Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(cornerRadius),
        border: showBorder
            ? Border.all(color: AppColors.hairline)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: card),
    );
  }
}
