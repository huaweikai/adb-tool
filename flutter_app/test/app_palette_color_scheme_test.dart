import 'package:adb_tool/design/app_palette.dart';
import 'package:adb_tool/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the palette → ColorScheme bridge. Screens and widgets read
/// `Theme.of(context).colorScheme` at ~350 sites versus ~22 `context.palette`
/// sites, so this bridge is what actually makes the design system reach the
/// app; if a mapping drops out, the theme silently goes back to two tracks.
void main() {
  double contrastRatio(Color fg, Color bg) {
    final a = fg.computeLuminance();
    final b = bg.computeLuminance();
    final hi = a > b ? a : b;
    final lo = a > b ? b : a;
    return (hi + 0.05) / (lo + 0.05);
  }

  group('AppPalette.toColorScheme', () {
    test('maps the fields the app reads most', () {
      const p = AppPalette.dark;
      final scheme = p.toColorScheme();
      expect(scheme.primary, p.accent);
      expect(scheme.surface, p.panel);
      expect(scheme.onSurface, p.textPrimary);
      expect(scheme.onSurfaceVariant, p.textSecondary);
      expect(scheme.surfaceContainerHighest, p.raised);
      expect(scheme.surfaceContainerLowest, p.canvas);
      expect(scheme.outlineVariant, p.hairline);
      expect(scheme.error, p.red);
    });

    test('works off the same tokens for the light preset', () {
      const p = AppPalette.light;
      final scheme = p.toColorScheme();
      expect(scheme.primary, p.accent);
      expect(scheme.surface, p.panel);
      expect(scheme.onSurfaceVariant, p.textSecondary);
      expect(scheme.outlineVariant, p.hairline);
    });

    test('infers brightness from the canvas token', () {
      expect(AppPalette.dark.toColorScheme().brightness, Brightness.dark);
      expect(AppPalette.light.toColorScheme().brightness, Brightness.light);
    });

    test('keeps text readable on the accent fill', () {
      for (final palette in [AppPalette.dark, AppPalette.light]) {
        final scheme = palette.toColorScheme();
        expect(contrastRatio(scheme.onPrimary, scheme.primary),
            greaterThan(4.5),
            reason: 'accent ${palette.accent} needs a legible onPrimary');
        expect(contrastRatio(scheme.onSurface, scheme.surface),
            greaterThan(4.5));
      }
    });

    test('keeps the container depth stack monotonic', () {
      const p = AppPalette.dark;
      final scheme = p.toColorScheme();
      final lumas = [
        scheme.surfaceContainerLowest.computeLuminance(),
        scheme.surface.computeLuminance(),
        scheme.surfaceContainerLow.computeLuminance(),
        scheme.surfaceContainer.computeLuminance(),
        scheme.surfaceContainerHigh.computeLuminance(),
        scheme.surfaceContainerHighest.computeLuminance(),
      ];
      for (var i = 1; i < lumas.length; i++) {
        expect(lumas[i], greaterThan(lumas[i - 1]),
            reason: 'depth level $i must sit above level ${i - 1}');
      }
    });
  });

  group('ThemeProvider', () {
    test('builds both themes from the palette, not from a colour seed', () {
      final provider = ThemeProvider();
      expect(provider.darkTheme.colorScheme.primary, AppPalette.dark.accent);
      expect(
          provider.darkTheme.scaffoldBackgroundColor, AppPalette.dark.canvas);
      expect(provider.darkTheme.dividerColor, AppPalette.dark.hairline);
      expect(provider.lightTheme.colorScheme.primary, AppPalette.light.accent);
      expect(
          provider.lightTheme.scaffoldBackgroundColor, AppPalette.light.canvas);
      expect(provider.darkTheme.extension<AppPalette>(), AppPalette.dark);
      expect(provider.lightTheme.extension<AppPalette>(), AppPalette.light);
    });
  });
}
