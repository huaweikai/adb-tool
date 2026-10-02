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
