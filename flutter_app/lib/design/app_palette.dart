import 'package:flutter/material.dart';

/// ── AppPalette ──────────────────────────────────────────────
///
/// The new design system's color tokens, exposed as a [ThemeExtension] so
/// values switch automatically with `ThemeMode` and interpolate across
/// theme transitions.
///
/// Access from a widget via `context.palette.<token>`:
///
/// ```dart
/// Container(color: context.palette.panel, ...)
/// ```
///
/// [AppPalette] is the single source of truth for colour: [toColorScheme]
/// feeds these same values into `Theme.of(context).colorScheme`, so legacy
/// screens and new design-system widgets resolve from one set of tokens.
///
/// Field semantics mirror the design nodes in Ardot main file
/// `706601156104862`. See each field's doc for the mapped design node.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.canvas,
    required this.panel,
    required this.raised,
    required this.activeNav,
    required this.hairline,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.blue,
    required this.orange,
    required this.red,
  });

  // ── Surfaces ──
  /// App canvas / scaffold background.
  final Color canvas;

  /// Sidebar / card panel base.
  final Color panel;

  /// Raised surface (device switcher card, hover, tile bg).
  final Color raised;

  /// Active navigation item background (accent-tinted panel).
  final Color activeNav;

  /// Hairline / border / stroke.
  final Color hairline;

  // ── Accent ──
  /// Primary accent — Android green (dark) or a slightly darker variant
  /// on light to preserve contrast.
  final Color accent;

  // ── Text ──
  /// Primary text / titles.
  final Color textPrimary;

  /// Secondary text / labels / nav default.
  final Color textSecondary;

  /// Disabled / group labels / hints.
  final Color textDisabled;

  // ── Semantic ──
  final Color blue;
  final Color orange;
  final Color red;

  // ── Derived helpers (getters, not stored) ──
  /// Active nav foreground (icon + label). Alias of [accent].
  Color get navActiveFg => accent;

  /// Default nav foreground (icon + label). Alias of [textSecondary].
  Color get navDefaultFg => textSecondary;

  /// Online status dot. Alias of [accent].
  Color get online => accent;

  /// Foreground for text or icons sitting on an [accent]-filled surface.
  /// Picked by contrast rather than by theme: the dark preset's bright green
  /// needs near-black, and the light preset's darker green reaches only
  /// ~2.6:1 with white versus ~7.4:1 with near-black.
  Color get onAccent {
    const nearBlack = Color(0xFF0A0C12);
    final l = accent.computeLuminance();
    final againstNearBlack = (l + 0.05) / (nearBlack.computeLuminance() + 0.05);
    final againstWhite = 1.05 / (l + 0.05);
    return againstNearBlack >= againstWhite ? nearBlack : Colors.white;
  }

  // ── Presets ──────────────────────────────────────────────
  //
  // Dark values are frozen — they mirror the Ardot design file 1:1 and
  // must not drift. Light values are the new spec we agreed on; adjust
  // here only.

  static const AppPalette dark = AppPalette(
    canvas: Color(0xFF0A0C12),
    panel: Color(0xFF0E1118),
    raised: Color(0xFF161B24),
    activeNav: Color(0xFF162031),
    hairline: Color(0xFF1E2430),
    accent: Color(0xFF3DDC84),
    textPrimary: Color(0xFFE7EAF0),
    textSecondary: Color(0xFF9AA4B2),
    textDisabled: Color(0xFF5B6472),
    blue: Color(0xFF4C8DFF),
    orange: Color(0xFFFF9F43),
    red: Color(0xFFFF6B6B),
  );

  static const AppPalette light = AppPalette(
    // Canvas: slightly cool light gray. The AppBackground glow layer sits
    // on top of this, and translucent panels above let the glow bleed
    // through — mirrors the dark design's soft-accent feel without going
    // pure white.
    canvas: Color(0xFFF5F7FB),
    // Panel: 90% white so the accent glow behind the whole screen shows
    // through as a subtle green tint on the panel surface, instead of the
    // panel reading as a hard white wall. Text still passes contrast on
    // the effective ~E6-EE background.
    panel: Color(0xE6FBFCFE),
    // Raised: slightly darker + still translucent for hover / tile / inner
    // surfaces. Depth stacking = canvas < raised < panel.
    raised: Color(0xE6EEF1F6),
    // Active nav: accent-tinted, translucent so it doesn't over-punch on
    // the panel it sits inside.
    activeNav: Color(0xCCD4F1E1),
    // Hairline: 8% black — a single value that stays readable on both
    // translucent panels and the darker canvas, no per-surface tuning.
    hairline: Color(0x14000000),
    // Darker accent variant to preserve contrast on light surfaces.
    accent: Color(0xFF22B573),
    textPrimary: Color(0xFF18191C),
    textSecondary: Color(0xFF5B6472),
    textDisabled: Color(0xFF9AA4B2),
    blue: Color(0xFF3A73E6),
    orange: Color(0xFFE88B2A),
    red: Color(0xFFE5484D),
  );

  /// Material bridge: express these tokens as a [ColorScheme].
  ///
  /// Screens and widgets read `Theme.of(context).colorScheme` at ~350 sites
  /// versus ~22 `context.palette` sites, so without this bridge a theme switch
  /// only repaints the few design-system widgets and every legacy screen keeps
  /// its own seed-derived colours. The two systems stop competing here: the
  /// palette is the single source of truth and ColorScheme is derived from it.
  ///
  /// Only the fields the app actually reads are mapped; the remaining ones keep
  /// the M3 baseline values from [ColorScheme.light] / [ColorScheme.dark].
  ColorScheme toColorScheme() {
    final isLight = canvas.computeLuminance() > 0.5;
    final onAccent = this.onAccent;
    final midContainer = Color.lerp(panel, raised, 0.6)!;
    final base = isLight
        ? const ColorScheme.light()
        : const ColorScheme.dark();
    return base.copyWith(
      primary: accent,
      onPrimary: onAccent,
      primaryContainer: activeNav,
      onPrimaryContainer: textPrimary,
      secondary: accent,
      onSecondary: onAccent,
      secondaryContainer: activeNav,
      onSecondaryContainer: textPrimary,
      tertiary: blue,
      error: red,
      onError: Colors.white,
      errorContainer: Color.lerp(panel, red, isLight ? 0.12 : 0.18)!,
      onErrorContainer: textPrimary,
      surface: panel,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      surfaceTint: accent,
      surfaceContainerLowest: canvas,
      surfaceContainerLow: Color.lerp(panel, raised, 0.35)!,
      surfaceContainer: midContainer,
      surfaceContainerHigh: Color.lerp(panel, raised, 0.8)!,
      surfaceContainerHighest: raised,
      outline: hairline,
      outlineVariant: hairline,
    );
  }

  @override
  AppPalette copyWith({
    Color? canvas,
    Color? panel,
    Color? raised,
    Color? activeNav,
    Color? hairline,
    Color? accent,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? blue,
    Color? orange,
    Color? red,
  }) {
    return AppPalette(
      canvas: canvas ?? this.canvas,
      panel: panel ?? this.panel,
      raised: raised ?? this.raised,
      activeNav: activeNav ?? this.activeNav,
      hairline: hairline ?? this.hairline,
      accent: accent ?? this.accent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      blue: blue ?? this.blue,
      orange: orange ?? this.orange,
      red: red ?? this.red,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      activeNav: Color.lerp(activeNav, other.activeNav, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      blue: Color.lerp(blue, other.blue, t)!,
      orange: Color.lerp(orange, other.orange, t)!,
      red: Color.lerp(red, other.red, t)!,
    );
  }
}

/// Convenience getter: `context.palette.panel` instead of the long
/// `Theme.of(context).extension<AppPalette>()!` dance.
///
/// Falls back to [AppPalette.dark] if the extension is somehow missing
/// (e.g. a widget rendered outside a themed subtree in tests) — this
/// keeps rendering, but such a fallback should never happen in prod.
extension AppPaletteX on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}
