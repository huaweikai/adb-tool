import 'package:flutter/material.dart';

import '../design/app_palette.dart';

/// ── AppBackground ────────────────────────────────────────────
///
/// The radial green glow that sits behind every screen's main content
/// area in the new design. Mirrors the design's `背景光晕` node:
/// `GRADIENT_RADIAL` from accent @ alpha 0.14 → fully transparent, painted
/// over the theme's canvas color (`palette.canvas`).
///
///   ┌─────────────────────────────────┐
///   │  · ·  glow fades out  · ·       │
///   │   ·   toward edges    ·         │
///   │       [content on top]          │
///   └─────────────────────────────────┘
///
/// Wrap the root window in this (see [AdbToolApp]'s [MaterialApp.builder]).
/// The custom title bar is transparent so the glow shows through it, and
/// each page paints its own opaque, theme-colored scaffold on top — so the
/// glow reads as a soft accent behind the title bar rather than a full
/// content wash. Sidebars / panels keep their own opaque panel fill.
class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.child,
    this.accentStrength = 0.14,
    this.center = const Alignment(-0.25, -0.7),
    // radius 从 1.3 调小到 0.8
    this.radius = 0.8,
  });

  /// The content painted on top of the glow.
  final Widget child;

  /// Peak alpha of the accent green at the gradient center. Design uses 0.14.
  final double accentStrength;

  /// Where the glow is brightest. Defaults to upper-left-ish, matching the
  /// design where the glow sits behind the top-left of the content area.
  final Alignment center;

  /// Gradient radius as a fraction of the box's longest side.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Canvas follows the active theme (dark → near-black, light → near-white)
    // so the glow reads correctly whether the window is in light or dark mode.
    return Container(
      color: palette.canvas,
      child: Stack(
        children: [
          // 2. 在底色上叠加光晕层
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: center,
                  radius: radius, // 使用调小后的 radius (例如 0.8)
                  colors: [
                    // 中心：峰值亮度的绿色
                    palette.accent.withValues(alpha: accentStrength),
                    // 1.0 边缘：完全透明，透出底部的画布色
                    palette.accent.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 1.0], // 线性过渡
                ),
              ),
            ),
          ),
          // 3. 将实际内容 Widget 放在光晕上方
          child,
        ],
      ),
    );
  }
}
