import 'package:flutter_test/flutter_test.dart';
import 'package:adb_tool/providers/test_session/formatter.dart';

void main() {
  group('SessionFormatters', () {
    test('planItemId is unique per session', () {
      final s1 = '20250618_143022_session1';
      final s2 = '20250618_143022_session2';

      // Same step index, different sessions → different IDs
      final p1 = SessionFormatters.planItemId(s1, 1);
      final p2 = SessionFormatters.planItemId(s2, 1);

      expect(p1, isNot(equals(p2)));
      expect(p1, equals('${s1}_STEP-001'));
      expect(p2, equals('${s2}_STEP-001'));
    });

    test('planItemId includes session prefix and step number', () {
      final sid = '20250618_143022_缺陷复现测试';
      expect(SessionFormatters.planItemId(sid, 1), equals('${sid}_STEP-001'));
      expect(SessionFormatters.planItemId(sid, 10), equals('${sid}_STEP-010'));
      expect(SessionFormatters.planItemId(sid, 100), equals('${sid}_STEP-100'));
    });

    test('sessionId uses microseconds and safe name', () {
      final t1 = DateTime.fromMillisecondsSinceEpoch(1781759485100);
      final t2 = DateTime.fromMillisecondsSinceEpoch(1781759485200);

      final id1 = SessionFormatters.sessionId(t1, '缺陷复现测试');
      final id2 = SessionFormatters.sessionId(t2, '缺陷复现测试');

      // Different timestamps → different IDs
      expect(id1, isNot(equals(id2)));
      expect(id1, startsWith('${t1.microsecondsSinceEpoch}_'));
      expect(id2, startsWith('${t2.microsecondsSinceEpoch}_'));
    });

    test('sessionId handles same timestamp with different names', () {
      final t = DateTime.fromMillisecondsSinceEpoch(1781759485100);
      final id1 = SessionFormatters.sessionId(t, '会话A');
      final id2 = SessionFormatters.sessionId(t, '会话B');
      expect(id1, isNot(equals(id2)));
    });

    test('issueNumber pads correctly', () {
      expect(SessionFormatters.issueNumber(1), equals('001'));
      expect(SessionFormatters.issueNumber(10), equals('010'));
      expect(SessionFormatters.issueNumber(100), equals('100'));
    });

    test('safeName strips special chars', () {
      expect(SessionFormatters.safeName('缺陷复现测试'), equals('缺陷复现测试'));
      expect(SessionFormatters.safeName('Test / Debug'), equals('Test__Debug'));
      expect(SessionFormatters.safeName(''), equals('session'));
    });
  });
}
