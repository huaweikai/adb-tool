// One-shot "clean all adb-tool caches" entry point.
//
// Mirrors POST /api/cache/cleanup on the backend. The dialog UI in
// lib/widgets/cleanup_cache_dialog.dart reads the response to tell
// the user what was wiped.
import 'package:adb_tool/services/api_client.dart';

mixin CleanupApi on ApiBase {
  /// Wipe all whitelisted adb-tool caches. Requires the caller to
  /// pass [confirmed] = true — the dialog enforces a two-stage
  /// confirmation but the API itself guards against accidental
  /// scripted calls by demanding the flag.
  ///
  /// [keepSDK] (default true) is sent for documentation only; the
  /// backend never adds the Android SDK to its wipe list, so this
  /// field is purely advisory.
  Future<CacheCleanupResult> cleanupCache({
    bool keepSDK = true,
    bool confirmed = false,
  }) async {
    if (!confirmed) {
      throw Exception(
        'cleanupCache requires confirmed=true; the UI dialog must '
        'ask the user before calling this',
      );
    }
    final response = await dio.post(
      '/api/cache/cleanup?confirm=true',
      data: {'keepSDK': keepSDK},
    );
    final data = responseMap(response);
    return CacheCleanupResult.fromJson(data);
  }
}

class CacheCleanupEntry {
  final String path;
  final String description;
  final bool existed;
  final int sizeBytes;
  final String? error;

  const CacheCleanupEntry({
    required this.path,
    this.description = '',
    this.existed = false,
    this.sizeBytes = 0,
    this.error,
  });

  factory CacheCleanupEntry.fromJson(Map<String, dynamic> json) {
    return CacheCleanupEntry(
      path: json['path'] as String? ?? '',
      description: json['description'] as String? ?? '',
      existed: json['existed'] as bool? ?? false,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      error: json['error'] as String?,
    );
  }

  /// Human-readable size string ("12.3 MB", "678 B").
  String get sizeFormatted {
    final n = sizeBytes;
    if (n < 1024) return '$n B';
    if (n < 1024 * 1024) {
      return '${(n / 1024).toStringAsFixed(1)} KB';
    }
    if (n < 1024 * 1024 * 1024) {
      return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(n / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class CacheCleanupResult {
  final bool success;
  final bool keptSDK;
  final int totalBytes;
  final List<CacheCleanupEntry> cleaned;
  final List<CacheCleanupEntry> skipped;

  const CacheCleanupResult({
    this.success = false,
    this.keptSDK = true,
    this.totalBytes = 0,
    this.cleaned = const [],
    this.skipped = const [],
  });

  factory CacheCleanupResult.fromJson(Map<String, dynamic> json) {
    return CacheCleanupResult(
      success: json['success'] as bool? ?? false,
      keptSDK: json['keptSDK'] as bool? ?? true,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      cleaned: (json['cleaned'] as List<dynamic>?)
              ?.map((e) => CacheCleanupEntry.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList() ??
          [],
      skipped: (json['skipped'] as List<dynamic>?)
              ?.map((e) => CacheCleanupEntry.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList() ??
          [],
    );
  }

  int get cleanedCount => cleaned.length;
  int get skippedCount => skipped.length;

  /// "12.3 MB" / "678 B"
  String get totalFormatted {
    final n = totalBytes;
    if (n < 1024) return '$n B';
    if (n < 1024 * 1024) {
      return '${(n / 1024).toStringAsFixed(1)} KB';
    }
    if (n < 1024 * 1024 * 1024) {
      return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(n / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
