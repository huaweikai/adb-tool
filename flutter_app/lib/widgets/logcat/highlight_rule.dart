// Highlight-rule model + built-in defaults used by the logcat screen.
//
// Extracted from logcat_screen.dart so the rule definition can be unit-tested
// in isolation and so future screens (e.g. session detail viewer) can share
// the same highlight vocabulary.

import 'package:flutter/material.dart';

import '../../models/device.dart';

/// A single logcat highlight rule — when [enabled] and [pattern] is a
/// case-insensitive substring of a log entry, the entry is colored
/// with [color] in the logcat list.
class HighlightRule {
  final String label;
  final String pattern;
  final Color color;
  final bool builtin;
  bool enabled;

  HighlightRule({
    required this.label,
    required this.pattern,
    required this.color,
    required this.builtin,
    required this.enabled,
  });

  bool matches(LogEntry entry) {
    final target = entry.raw.isEmpty ? entry.message : entry.raw;
    return target.toLowerCase().contains(pattern.toLowerCase());
  }
}

/// Factory + lookup helpers for highlight rules. Kept separate from the model
/// so the model stays a plain data class and the default rule set can grow
/// without touching the screen widget.
class HighlightRules {
  /// Built-in rule list seeded into the logcat screen on first run.
  static List<HighlightRule> defaults() => [
        HighlightRule(
          label: 'Crash',
          pattern: 'FATAL EXCEPTION',
          color: Colors.red,
          builtin: true,
          enabled: true,
        ),
        HighlightRule(
          label: 'AndroidRuntime',
          pattern: 'AndroidRuntime',
          color: Colors.redAccent,
          builtin: true,
          enabled: true,
        ),
        HighlightRule(
          label: 'Network',
          pattern: 'http',
          color: Colors.cyan,
          builtin: true,
          enabled: true,
        ),
        HighlightRule(
          label: 'OkHttp',
          pattern: 'okhttp',
          color: Colors.lightBlue,
          builtin: true,
          enabled: true,
        ),
      ];

  /// Color palette offered to users when they add a custom rule.
  static const List<Color> customPalette = [
    Colors.amber,
    Colors.pinkAccent,
    Colors.deepPurpleAccent,
    Colors.tealAccent,
    Colors.limeAccent,
    Colors.orangeAccent,
  ];

  /// Keywords that flag a log entry as a crash-like event when no user
  /// rule matches.
  static const List<String> crashKeywords = [
    'fatal exception',
    'androidruntime',
    'exception',
    'error',
  ];

  /// Continuation-line prefixes produced by the platform for stack traces.
  static const List<String> crashStackPrefixes = ['caused by:', 'at '];

  /// Substrings that flag a log entry as network-related when no user
  /// rule matches.
  static const List<String> networkKeywords = [
    'http://',
    'https://',
    ' okhttp',
    'okhttp',
    'retrofit',
    'volley',
    'grpc',
    'socket',
    'dns',
    'response',
    'request',
  ];

  /// Logcat priority codes that always indicate a crash.
  static const List<String> crashPriorities = ['E', 'F'];

  static bool isCrashEntry(LogEntry entry) {
    final raw = entry.raw.isEmpty ? entry.message : entry.raw;
    final lower = raw.toLowerCase();
    if (crashKeywords.any(lower.contains)) return true;
    final message = entry.message.toLowerCase();
    if (crashStackPrefixes.any(message.startsWith)) return true;
    return crashPriorities.contains(entry.priority);
  }

  static bool isNetworkEntry(LogEntry entry) {
    final raw = entry.raw.isEmpty ? entry.message : entry.raw;
    final lower = raw.toLowerCase();
    return networkKeywords.any(lower.contains);
  }

  /// Find the first matching user-defined rule for [entry], or fall back to
  /// a synthetic rule describing the built-in crash / network heuristics.
  /// Returns null if nothing matches.
  static HighlightRule? match(
    List<HighlightRule> rules,
    LogEntry entry,
    String Function(String key) tr,
  ) {
    for (final rule in rules) {
      if (rule.enabled &&
          rule.pattern.trim().isNotEmpty &&
          rule.matches(entry)) {
        return rule;
      }
    }
    if (isCrashEntry(entry)) {
      return HighlightRule(
        label: tr('logRuleCrash'),
        pattern: 'crash',
        color: Colors.red,
        builtin: true,
        enabled: true,
      );
    }
    if (isNetworkEntry(entry)) {
      return HighlightRule(
        label: tr('logRuleNetwork'),
        pattern: 'network',
        color: Colors.cyan,
        builtin: true,
        enabled: true,
      );
    }
    return null;
  }
}
