// One-shot cleanup of pre-database test session data.
//
// The old test-session implementation stored everything on disk at
// `~/ADBToolData/sessions/<id>/`. We've moved to a proper DB-backed model
// and don't need the old files anymore. This helper finds any leftover
// ADBToolData directories from before the migration and deletes them.
//
// Safe to call on every startup — a marker file in the app-support
// directory records completion so we only scan once per machine.
//
// Threading: scanning happens on the main isolate (cheap — just `stat()`
// calls). The actual recursive delete runs inside `Isolate.run` so even a
// huge legacy directory can't stall the main isolate's event loop, which
// is the one driving the Flutter UI.
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Removes legacy test-session on-disk storage (the pre-DB layout under
/// `~/ADBToolData/sessions/`). Runs idempotently on every app start.
class LegacySessionCleanup {
  /// Marker filename placed in the app-support directory after a successful
  /// sweep. Bump the suffix (`_v2`, `_v3`, ...) if you ever need to re-run
  /// the cleanup (e.g. a new legacy path is discovered).
  static const _markerFileName = '.legacy_sessions_cleaned_v2';

  /// Run the cleanup. Returns when finished; safe to call from `main()` as a
  /// fire-and-forget (use `unawaited(...)`).
  static Future<void> run() async {
    try {
      final appSupport = await getApplicationSupportDirectory();
      final marker = File('${appSupport.path}${Platform.pathSeparator}$_markerFileName');
      if (await marker.exists()) {
        debugPrint('[LegacyCleanup] Marker present, skipping scan.');
        return;
      }

      final paths = await _findLegacyRootPaths();
      if (paths.isEmpty) {
        debugPrint('[LegacyCleanup] No legacy ADBToolData found.');
      } else {
        for (final path in paths) {
          try {
            // Hand the actual delete off to a background isolate. Even if
            // this dir contains tens of thousands of files, the main
            // isolate (which is running Flutter's UI) stays unaffected.
            await Isolate.run(() => _deleteRecursiveSync(path));
            debugPrint('[LegacyCleanup] Deleted $path');
          } catch (e) {
            // Per-dir failure is non-fatal: the marker still gets written,
            // we just lose one location's worth of cleanup. User can manually
            // remove it.
            debugPrint('[LegacyCleanup] Failed to delete $path: $e');
          }
        }
      }

      // Write the marker so subsequent startups skip the scan entirely.
      await marker.writeAsString(
        'cleaned at ${DateTime.now().toIso8601String()}\n'
        'candidates checked: ${paths.length}\n',
      );
      debugPrint('[LegacyCleanup] Done. Marker written.');
    } catch (e, st) {
      // Cleanup must never block app startup or crash the app. Log and move on.
      debugPrint('[LegacyCleanup] Sweep failed (non-fatal): $e');
      debugPrint('[LegacyCleanup] Stack: $st');
    }
  }

  /// Synchronous delete — must only be called from a non-UI isolate
  /// (typically via [Isolate.run]). `Directory.deleteSync` walks the tree
  /// in-process; for a large legacy dir this can take real wall time, so we
  /// want it off the main isolate.
  static void _deleteRecursiveSync(String path) {
    final dir = Directory(path);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }

  /// Returns the absolute paths of legacy `ADBToolData` directories we want
  /// to remove. Probes (cheap stat calls) happen on the main isolate; the
  /// actual deletion is deferred to [Isolate.run].
  ///
  /// Checked locations:
  /// 1. `$HOME/ADBToolData` (macOS / Linux: `HOME`; Windows: `USERPROFILE`)
  /// 2. Current working directory + `/ADBToolData` (dev runs from project root)
  ///
  /// Returns the union, deduplicated by resolved absolute path.
  static Future<List<String>> _findLegacyRootPaths() async {
    final seen = <String>{};
    final result = <String>[];

    Future<bool> addIfExists(String path) async {
      try {
        final dir = Directory(path);
        if (await dir.exists()) {
          final absolute = await dir.absolute.path;
          if (seen.add(absolute)) {
            result.add(absolute);
            return true;
          }
        }
      } catch (_) {
        // Probe failures (permission, missing parent) — skip silently.
      }
      return false;
    }

    // 1. Home directory (cross-platform).
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'];
    if (home != null && home.isNotEmpty) {
      await addIfExists('$home${Platform.pathSeparator}ADBToolData');
    }

    // 2. Current working directory (only useful for `flutter run` from the
    //    project root — production launches use the install dir, not cwd).
    try {
      final cwd = Directory.current.path;
      await addIfExists('$cwd${Platform.pathSeparator}ADBToolData');
    } catch (_) {}

    return result;
  }
}
