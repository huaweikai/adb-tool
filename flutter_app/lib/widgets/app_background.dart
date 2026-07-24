import 'package:flutter/material.dart';

import '../design/design_tokens.dart';

/// ── AppBackground ────────────────────────────────────────────
///
/// The radial green glow that sits behind every screen's main content
/// area in the new design. Mirrors the design's `背景光晕` node:
/// `GRADIENT_RADIAL` from accent `#3DDC84` @ alpha 0.14 → fully
/// transparent, painted over the canvas `#0A0C12`.
///
///   ┌─────────────────────────────────┐
///   │  · ·  glow fades out  · ·       │
///   │   ·   toward edges    ·         │
///   │       [content on top]          │
///   └─────────────────────────────────┘
///
/// Wrap the main content area (everything to the right of the sidebar)
/// in this. The sidebar itself is NOT wrapped — it has its own panel fill.
class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.child,
    this.accentStrength = 0.14,
    this.center = const Alignment(-0.25, -0.7),
    this.radius = 1.3,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        // Gradient goes accent(alpha) → canvas(opaque). The opaque end
        // stop replaces the need for a separate background color.
        gradient: RadialGradient(
          center: center,
          radius: radius,
          colors: [
            AppColors.accent.withOpacity(accentStrength),
            AppColors.canvas,
          ],
          stops: const [0.0, 1.0],
        ),
      ),
      child: child,
    );
  }
}
