import 'dart:ui';

/// App-wide spacing tokens — the only source of truth for padding/margin.
/// All widgets must use these constants; hard-coded spacing values are
/// forbidden unless there is a very strong justification documented inline.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;
}

/// Border radius tokens.
class AppRadius {
  const AppRadius._();

  static const double xs = 4.0;
  static const double sm = 6.0;
  static const double md = 8.0;
  static const double lg = 12.0;
  static const double xl = 16.0;
  static const double full = 9999.0;
}

/// Font size tokens.
class AppFontSize {
  const AppFontSize._();

  static const double xs = 9.0;
  static const double sm = 10.0;
  static const double md = 11.0;
  static const double body = 12.0;
  static const double subtitle = 13.0;
  static const double title = 14.0;
  static const double headline = 16.0;
  static const double large = 20.0;
  static const double metric = 28.0;
}

/// Duration tokens for animations.
class AppDuration {
  const AppDuration._();

  static const Duration instant = Duration.zero;
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
}

/// Semantic elevation levels.
class AppElevation {
  const AppElevation._();

  static const double background = 0;
  static const double surface = 1;
  static const double card = 2;
  static const double elevated = 3;
  static const double dialog = 6;
  static const double popover = 12;
}

/// ── AppColors ───────────────────────────────────────────────
///
/// Color tokens for the **new design system** (Ardot 主文件 706601156104862,
/// 深色专用). These are intentionally a *separate* semantic layer from
/// `Theme.of(context).colorScheme` — the existing dark theme is GitHub-style
/// (`#0D1117` + blue seed), while this new system is a custom dark palette
/// anchored on Android green `#3DDC84`.
///
/// New widgets built from the new design (AppSidebar / AppTopbar / AppCard …)
/// MUST read colors from [AppColors], not from `colorScheme`, so they render
/// correctly regardless of the legacy theme. Migration of existing screens
/// to this palette is a separate, per-page effort — do not bulk-replace.
///
/// Values sourced from the design file node `fills` (no Ardot variables used).
/// Light-theme variants are TODO until a light design spec exists.
class AppColors {
  const AppColors._();

  // ── Surfaces (背景层级) ──
  /// App canvas / scaffold background. `#0A0C12`
  static const Color canvas = Color(0xFF0A0C12);

  /// Sidebar / card panel base. `#0E1118`  (sidebar 34:52 fill, card fill)
  static const Color panel = Color(0xFF0E1118);

  /// Raised surface (device switcher card, hover). `#161B24`
  static const Color raised = Color(0xFF161B24);

  /// Active navigation item background. `#162031`  (nav active 34:60 fill)
  static const Color activeNav = Color(0xFF162031);

  /// Hairline / border / stroke. `#1E2430`  (sidebar stroke, topbar stroke)
  static const Color hairline = Color(0xFF1E2430);

  // ── Accent ──
  /// Primary accent — Android green. `#3DDC84`
  /// Used for: active nav icon/label, online dot, brand logo, CTA buttons.
  static const Color accent = Color(0xFF3DDC84);

  // ── Text ──
  /// Primary text / titles. `#E7EAF0`
  static const Color textPrimary = Color(0xFFE7EAF0);

  /// Secondary text / labels / nav default. `#9AA4B2`
  static const Color textSecondary = Color(0xFF9AA4B2);

  /// Disabled / group labels / hints. `#5B6472`
  static const Color textDisabled = Color(0xFF5B6472);

  // ── Semantic ──
  /// Blue accent (info / screenshot quick action). `#4C8DFF`
  static const Color blue = Color(0xFF4C8DFF);

  /// Orange accent (warning). `#FF9F43`
  static const Color orange = Color(0xFFFF9F43);

  /// Red accent (error / record). `#FF6B6B`
  static const Color red = Color(0xFFFF6B6B);

  // ── Derived helpers ──
  /// Active nav foreground (icon + label) — same as [accent].
  static const Color navActiveFg = accent;

  /// Default nav foreground (icon + label) — same as [textSecondary].
  static const Color navDefaultFg = textSecondary;

  /// Online status dot — same as [accent].
  static const Color online = accent;
}
