import 'package:adb_tool/models/device.dart';
import 'package:adb_tool/widgets/logcat/highlight_rule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LogEntry _entry({
  String raw = '',
  String message = '',
  String priority = 'I',
}) {
  return LogEntry(raw: raw, message: message, priority: priority);
}

void main() {
  group('HighlightRule.matches', () {
    test('case-insensitive substring on raw', () {
      final rule = HighlightRule(
        label: 'crash',
        pattern: 'FATAL',
        color: const Color(0xFF000000),
        builtin: true,
        enabled: true,
      );
      expect(rule.matches(_entry(raw: 'FATAL EXCEPTION here')), isTrue);
      expect(rule.matches(_entry(raw: 'fatal exception here')), isTrue);
      expect(rule.matches(_entry(raw: 'all good')), isFalse);
    });

    test('falls back to message when raw is empty', () {
      final rule = HighlightRule(
        label: 'foo',
        pattern: 'oops',
        color: const Color(0xFF000000),
        builtin: false,
        enabled: true,
      );
      expect(
        rule.matches(_entry(raw: '', message: 'something oops happened')),
        isTrue,
      );
    });
  });

  group('HighlightRules.isCrashEntry', () {
    test('flags FATAL EXCEPTION in raw', () {
      expect(
        HighlightRules.isCrashEntry(_entry(raw: 'FATAL EXCEPTION in main')),
        isTrue,
      );
    });

    test('flags stack-trace continuation lines', () {
      expect(
        HighlightRules.isCrashEntry(_entry(message: 'caused by: NPE')),
        isTrue,
      );
      expect(
        HighlightRules.isCrashEntry(_entry(message: 'at com.example.Foo.bar')),
        isTrue,
      );
    });

    test('flags priority E and F regardless of content', () {
      expect(
        HighlightRules.isCrashEntry(_entry(raw: 'boring', priority: 'E')),
        isTrue,
      );
      expect(
        HighlightRules.isCrashEntry(_entry(raw: 'boring', priority: 'F')),
        isTrue,
      );
    });

    test('does not flag normal info entries', () {
      expect(
        HighlightRules.isCrashEntry(
            _entry(raw: 'User opened settings screen', priority: 'I')),
        isFalse,
      );
    });
  });

  group('HighlightRules.isNetworkEntry', () {
    test('flags http / https / okhttp / socket keywords', () {
      expect(HighlightRules.isNetworkEntry(_entry(raw: 'GET https://api/')), isTrue);
      expect(HighlightRules.isNetworkEntry(_entry(raw: '---> okhttp call')), isTrue);
      expect(HighlightRules.isNetworkEntry(_entry(raw: 'socket closed')), isTrue);
    });

    test('does not flag non-network entries', () {
      expect(
        HighlightRules.isNetworkEntry(_entry(raw: 'clicked button')),
        isFalse,
      );
    });
  });

  group('HighlightRules.match', () {
    test('returns the first enabled user rule that matches', () {
      final rules = [
        HighlightRule(
          label: 'a',
          pattern: 'foo',
          color: const Color(0xFF000000),
          builtin: false,
          enabled: true,
        ),
        HighlightRule(
          label: 'b',
          pattern: 'foo',
          color: const Color(0xFF000000),
          builtin: false,
          enabled: true,
        ),
      ];
      final hit = HighlightRules.match(rules, _entry(raw: 'foo bar'), _idTr);
      expect(hit?.label, 'a');
    });

    test('skips disabled rules', () {
      final rules = [
        HighlightRule(
          label: 'a',
          pattern: 'foo',
          color: const Color(0xFF000000),
          builtin: false,
          enabled: false,
        ),
      ];
      final hit = HighlightRules.match(rules, _entry(raw: 'foo'), _idTr);
      // Disabled user rule misses; synthetic crash rule also misses (no
      // crash keywords); so the result is null.
      expect(hit, isNull);
    });

    test('falls back to synthetic crash rule', () {
      final hit = HighlightRules.match(
        const [],
        _entry(raw: 'FATAL EXCEPTION happened'),
        _idTr,
      );
      expect(hit, isNotNull);
      expect(hit?.builtin, isTrue);
    });
  });
}

String _idTr(String key, [Map<String, String>? _]) => key;

const _dummy = Color(0xFF000000);
