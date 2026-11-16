import 'dart:async';

import 'package:adb_tool/models/device.dart';
import 'package:adb_tool/providers/device_provider.dart';
import 'package:adb_tool/providers/logcat_state_provider.dart';
import 'package:adb_tool/services/api_client.dart';
import 'package:adb_tool/services/log_stream.dart';
import 'package:adb_tool/widgets/logcat/logcat_list.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  test('keeps the last 5000 lines and preserves IDs on refilter', () {
    final state = LogcatDeviceState(serial: 'device', historyLimit: 5000);
    final duplicate = LogEntry(raw: 'repeated');
    state.enqueue([
      ...List.generate(4999, (i) => LogEntry(raw: 'line $i')),
      duplicate,
      duplicate,
    ]);
    state.flushPending();
    final rows = state.displayed;
    expect(rows.length, 5000);
    expect(rows[0].entry.raw, 'line 1');
    expect(rows[4998].id, isNot(rows[4999].id));
    final newestId = rows[4999].id;

    state.filter.keyword = 'repeated';
    state.refreshDisplayed();
    expect(rows.length, 2);
    expect(rows.indexAfter(newestId), 2);
    expect(rows.indexAfter(newestId - 1), 1);
    state.enqueue(List.generate(5000, (i) => LogEntry(raw: 'other $i')));
    state.flushPending();
    expect(rows.length, 0);
    state.filter.keyword = '';
    state.refreshDisplayed();
    expect(rows.length, 5000);
    expect(rows[0].id, greaterThan(newestId));
    state.clearBuffers();
    expect(rows.length, 0);
    expect(state.hasLogs, isFalse);
  });

  test('counts pending and history evictions and resets them on clear', () {
    final state = LogcatDeviceState(serial: 'device', historyLimit: 5000);
    state.enqueue(List.generate(5300, (i) => LogEntry(raw: 'line $i')));
    state.flushPending();
    expect(state.displayed[0].entry.raw, 'line 300');
    expect(state.evictedRows, 300);
    state.enqueue([LogEntry(raw: 'additional line')]);
    state.flushPending();
    expect(state.evictedRows, 301);
    state.clearBuffers();
    expect(state.evictedRows, 0);
  });

  testWidgets('view filters restore any retained log without reconnecting',
      (tester) async {
    final fixture = _Fixture(tester);
    await fixture.show();
    final logs = [
      LogEntry.parse('11-16 12:00:00.000000 100 100 D Http: request'),
      LogEntry.parse('11-16 12:00:00.000001 200 200 I Http: result'),
      LogEntry.parse('11-16 12:00:00.000002 300 300 W UI: warning'),
    ];
    fixture.stream.logs.add(logs);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(fixture.state.displayed.length, 1);

    fixture.provider.updateField('device', priority: 'D', tag: 'Http');
    await tester.pump(const Duration(milliseconds: 200));
    expect(fixture.state.displayed.length, 2);
    expect(fixture.state.displayed[0].entry, same(logs[0]));

    fixture.provider.setPackagePid('device', '100 200', clearPackage: false);
    expect(fixture.state.displayed.length, 2);
    fixture.provider.updateField('device', keyword: 'result');
    await tester.pump(const Duration(milliseconds: 200));
    expect(fixture.state.displayed.length, 1);
    expect(fixture.state.displayed[0].entry, same(logs[1]));
    expect(fixture.stream.connects, 1);
  });

  testWidgets('pause freezes the view and resumes with retained arrivals',
      (tester) async {
    final fixture = _Fixture(tester);
    await fixture.show();
    await fixture.add(0, 100);
    fixture.provider.pauseStream('device');
    await fixture.add(100, 60);
    expect(fixture.state.displayed.length, 100);
    fixture.provider.resumeStream('device');
    await tester.pumpAndSettle();
    expect(fixture.state.displayed.length, 160);
    expect(fixture.atBottom('line 159'), isTrue);
    expect(fixture.stream.connects, 1);
  });

  for (final wrap in [false, true]) {
    testWidgets(
        'pins the visible row after the original anchor expired ($wrap)',
        (tester) async {
      final fixture = _Fixture(tester, wrap: wrap);
      await fixture.show();
      await fixture.add(0, 5000);
      await fixture.wheel(-50);
      await fixture.add(5000, 5000);
      await fixture.wheel(1800);
      expect(fixture.follow.value, isFalse);
      final line = find.text('line 5100');
      final before = tester.getTopLeft(line).dy;

      await fixture.add(10000, 25);
      expect(tester.getTopLeft(line).dy, before);
      expect(fixture.state.unseenRows.value, 5025);
      expect(fixture.state.evictedRows, 5025);
      await fixture.wheel(18);
      expect(tester.getTopLeft(find.text('line 5101')).dy, before);
      expect(fixture.follow.value, isFalse);
    });
  }

  testWidgets('compact rows have a fixed extent and long text can scroll',
      (tester) async {
    final fixture = _Fixture(tester, wrap: false);
    await fixture.show();
    await fixture.add(0, 3, multiline: true);
    expect(find.byType(SliverFixedExtentList, skipOffstage: false),
        findsOneWidget);
    expect(
      tester.getSize(find.text(_message(0, multiline: true))).height,
      tester.getSize(find.text(_message(1, multiline: true))).height,
    );
    final horizontal = tester
        .state<ScrollableState>(find.ancestor(
          of: fixture.viewport,
          matching: find.byType(Scrollable),
        ))
        .position;
    expect(horizontal.maxScrollExtent, greaterThan(800));
    horizontal.jumpTo(horizontal.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(horizontal.pixels, horizontal.maxScrollExtent);

    fixture.provider.setSoftWrap(true);
    await tester.pumpAndSettle();
    expect(find.byType(SliverFixedExtentList), findsNothing);
    expect(horizontal.maxScrollExtent, 0);
  });

  testWidgets('compact follow animates and resumes only at the true bottom',
      (tester) async {
    final fixture = _Fixture(tester, wrap: false);
    await fixture.show();
    await fixture.add(0, 100);
    final oldTail = find.text('line 99');
    final y = tester.getTopLeft(oldTail).dy;

    await fixture.add(100, 4, settle: false);
    expect(tester.getTopLeft(oldTail).dy, y);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getTopLeft(oldTail).dy, lessThan(y));
    expect(fixture.position.pixels, lessThan(fixture.position.maxScrollExtent));
    await tester.pumpAndSettle();
    expect(fixture.atBottom('line 103'), isTrue);

    await fixture.wheel(-5);
    expect(fixture.follow.value, isFalse);
    await fixture.add(104, 1);
    await fixture.wheel(22);
    expect(fixture.position.maxScrollExtent - fixture.position.pixels, 1);
    expect(fixture.follow.value, isFalse);
    await fixture.wheel(1);
    expect(fixture.follow.value, isTrue);
    expect(fixture.atBottom('line 104'), isTrue);
  });

  testWidgets('lays short logs out from the top without shifting old rows',
      (tester) async {
    final fixture = _Fixture(tester);
    await fixture.show();
    await fixture.add(0, 2);
    final top = tester.getTopLeft(fixture.viewport).dy;
    expect(tester.getTopLeft(find.text('line 0')).dy, top);

    await fixture.add(2, 2);
    expect(tester.getTopLeft(find.text('line 0')).dy, top);
    expect(tester.getTopLeft(find.text('line 3')).dy, greaterThan(top));
    expect(fixture.follow.value, isTrue);

    await fixture.add(4, 40, settle: false);
    expect(tester.getTopLeft(find.text('line 0')).dy, top);
    await tester.pumpAndSettle();
    expect(fixture.atBottom('line 43'), isTrue);
  });

  testWidgets('animates from the visible frame as new logs arrive',
      (tester) async {
    final fixture = _Fixture(tester);
    await fixture.show();
    await fixture.add(0, 100);
    final previousTail = find.text('line 99');
    final start = tester.getBottomLeft(previousTail).dy;

    await fixture.add(100, 4, settle: false);
    expect(tester.getBottomLeft(previousTail).dy, start);
    final firstTarget = fixture.position.minScrollExtent;
    expect(firstTarget, lessThan(fixture.position.pixels));

    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    final during = tester.getBottomLeft(previousTail).dy;
    expect(during, lessThan(start));
    expect(during, greaterThan(start + firstTarget));

    await fixture.add(104, 2, settle: false);
    expect(fixture.position.minScrollExtent, lessThan(firstTarget));
    expect(
        fixture.position.pixels, greaterThan(fixture.position.minScrollExtent));
    await tester.pumpAndSettle();
    expect(fixture.atBottom('line 105'), isTrue);
    expect(fixture.follow.value, isTrue);
  });

  testWidgets('a small upward wheel movement interrupts live animation',
      (tester) async {
    final fixture = _Fixture(tester);
    await fixture.show();
    await fixture.add(0, 100);
    await fixture.add(100, 6, settle: false);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    final before = fixture.position.pixels;

    await fixture.wheel(-9);
    expect(fixture.follow.value, isFalse);
    expect(fixture.position.pixels, closeTo(before + 9, 0.01));
    final reading = tester.getTopLeft(find.text('line 98')).dy;
    await fixture.add(106, 6);
    expect(tester.getTopLeft(find.text('line 98')).dy, reading);
  });

  testWidgets('compacts the live sliver without a jump during follow',
      (tester) async {
    final fixture = _Fixture(tester);
    await fixture.show();
    await fixture.add(0, 100);
    await fixture.add(100, 63);
    final previousTail = find.text('line 162');
    final start = tester.getBottomLeft(previousTail).dy;

    await fixture.add(163, 4, settle: false);
    expect(tester.getBottomLeft(previousTail).dy, start);
    await tester.pump(const Duration(milliseconds: 16));
    final after = tester.getBottomLeft(previousTail).dy;
    expect(after, lessThanOrEqualTo(start));
    expect(after, greaterThan(start - 24));

    await tester.pumpAndSettle();
    expect(fixture.atBottom('line 166'), isTrue);
    expect(fixture.position.pixels, 0);
  });

  testWidgets('a large burst animates the final part and retains its history',
      (tester) async {
    final fixture = _Fixture(tester);
    await fixture.show();
    await fixture.add(0, 5000);
    await fixture.add(5000, 1000, settle: false);

    final position = fixture.position;
    final distance = position.pixels - position.minScrollExtent;
    expect(distance, greaterThan(0));
    expect(distance, lessThan(position.viewportDimension));
    expect(fixture.state.displayed.length, 5000);
    expect(fixture.state.displayed[4000].entry.raw, 'line 5000');

    await tester.pumpAndSettle();
    expect(fixture.atBottom('line 5999'), isTrue);
    expect(fixture.follow.value, isTrue);
  });

  testWidgets('clicking a line pauses following and copies the log',
      (tester) async {
    final fixture = _Fixture(tester);
    String? clipboard;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await fixture.show();
    await fixture.add(0, 100);
    final line = find.text('line 97');
    final y = tester.getTopLeft(line).dy;
    await tester.tap(line);
    await tester.pumpAndSettle();
    expect(fixture.follow.value, isFalse);
    expect(clipboard, 'line 97');
    await fixture.add(100, 4);
    expect(tester.getTopLeft(line).dy, y);
  });

  testWidgets('keeps a read position until the user reaches the actual tail',
      (tester) async {
    final fixture = _Fixture(tester);
    await fixture.show();
    await fixture.add(0, 100);
    expect(fixture.position.pixels, 0);
    expect(fixture.atBottom('line 99'), isTrue);

    // One small movement must suspend follow, even within 24 pixels.
    await fixture.wheel(-9);
    expect(fixture.position.pixels, 9);
    expect(fixture.follow.value, isFalse);
    final readingY = tester.getTopLeft(find.text('line 97')).dy;

    await fixture.add(100, 12, multiline: true);
    expect(fixture.follow.value, isFalse);
    expect(tester.getTopLeft(find.text('line 97')).dy, readingY);
    expect(fixture.position.minScrollExtent, lessThan(0));

    // Return to within a pixel of the actual tail. It must remain detached.
    for (var i = 0; i < 80; i++) {
      final distance =
          fixture.position.pixels - fixture.position.minScrollExtent;
      if (distance <= 1) break;
      await fixture.wheel((distance - 1).clamp(0, 64).toDouble());
    }
    expect(fixture.position.pixels - fixture.position.minScrollExtent, 1);
    expect(fixture.follow.value, isFalse);

    await fixture.wheel(2);
    expect(fixture.follow.value, isTrue);
    expect(fixture.position.pixels, 0);
    expect(fixture.atBottom(_message(111, multiline: true)), isTrue);
    await fixture.add(112, 1);
    expect(fixture.atBottom('line 112'), isTrue);
  });

  testWidgets('reuses history rows while a full buffer rolls over',
      (tester) async {
    final fixture = _Fixture(tester);
    await fixture.show();
    await fixture.add(0, 5000);
    await fixture.wheel(-150);
    final line = find.text('line 4990');
    final oldElement = tester.element(line);
    final oldY = tester.getTopLeft(line).dy;

    await fixture.add(5000, 50);
    expect(fixture.follow.value, isFalse);
    expect(tester.element(line), same(oldElement));
    expect(tester.getTopLeft(line).dy, oldY);
    expect(fixture.state.displayed.length, 5000);

    // When the viewed history itself ages out, clamp to retained content.
    await fixture.add(5050, 5000);
    expect(fixture.follow.value, isFalse);
    expect(find.text('line 5050'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // The checkbox can still explicitly return to live logs.
    fixture.follow.value = true;
    await tester.pumpAndSettle();
    expect(fixture.atBottom('line 10049'), isTrue);
  });

  testWidgets('follows large batches, then lets a drag leave the tail',
      (tester) async {
    final fixture = _Fixture(tester);
    await fixture.show();
    await fixture.add(0, 5000);
    await fixture.add(5000, 100, multiline: true);
    expect(fixture.atBottom(_message(5099, multiline: true)), isTrue);
    expect(fixture.position.pixels, 0);

    await tester.drag(fixture.viewport, const Offset(0, 70));
    await tester.pumpAndSettle();
    expect(fixture.follow.value, isFalse);
    final offset = fixture.position.pixels;
    expect(offset, greaterThan(0));
    await fixture.add(5100, 100);
    expect(fixture.position.pixels, offset);
    expect(fixture.follow.value, isFalse);

    await tester.fling(fixture.viewport, const Offset(0, -400), 3000);
    await tester.pumpAndSettle();
    if (!fixture.follow.value) await fixture.wheel(3000);
    expect(fixture.atBottom('line 5199'), isTrue);
    expect(fixture.follow.value, isTrue);
  });

  testWidgets('keeps collecting when the cached list is hidden',
      (tester) async {
    final fixture = _Fixture(tester);
    await fixture.show();
    await fixture.add(0, 100);
    await fixture.show(active: false);
    await fixture.add(100, 10);
    expect(find.text('line 109'), findsNothing);
    expect(fixture.state.displayed.length, 110);
    await fixture.show();
    expect(fixture.atBottom('line 109'), isTrue);
  });
}

String _message(int i, {required bool multiline}) => multiline
    ? 'line $i ${List.filled(18, 'a long wrapped log message').join(' ')}'
    : 'line $i';

class _Fixture {
  _Fixture(this.tester, {bool wrap = true}) {
    final device = _Device();
    stream = _LogStream(device);
    provider =
        LogcatStateProvider(stream, ApiClient('http://localhost'), device)
          ..setHistoryLimit(5000)
          ..setSoftWrap(wrap)
          ..startStream('device');
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
      await stream.logs.close();
      device.dispose();
    });
  }

  final WidgetTester tester;
  ValueNotifier<bool> get follow => state.followLatest;
  late final LogcatStateProvider provider;
  late final _LogStream stream;
  LogcatDeviceState get state => provider.stateFor('device');
  Finder get viewport => find.byType(CustomScrollView);
  ScrollPosition get position => tester
      .state<ScrollableState>(find.descendant(
        of: viewport,
        matching: find.byType(Scrollable),
      ))
      .position;

  Future<void> show({bool active = true}) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: LogcatList(
              deviceSerial: 'device',
              active: active,
              highlightRules: const [],
              highlightVersion: 0,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> add(
    int start,
    int count, {
    bool multiline = false,
    bool settle = true,
  }) async {
    stream.logs.add(List.generate(count, (index) {
      final raw = _message(start + index, multiline: multiline);
      return LogEntry(raw: raw, message: raw);
    }));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> wheel(double dy) async {
    await tester.sendEventToBinding(PointerScrollEvent(
      position: tester.getCenter(viewport),
      scrollDelta: Offset(0, dy),
    ));
    await tester.pumpAndSettle();
  }

  bool atBottom(String text) {
    return (tester.getBottomLeft(viewport).dy -
                tester.getBottomLeft(find.text(text)).dy)
            .abs() <
        0.001;
  }
}

class _Device extends ChangeNotifier implements DeviceProvider {
  @override
  Stream<DeviceOfflineEvent> get onDeviceOffline => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LogStream extends LogStreamService {
  _LogStream(super.deviceProvider);

  final logs = StreamController<List<LogEntry>>.broadcast();

  int connects = 0;

  @override
  void connect(String serial) => connects++;

  @override
  Stream<List<LogEntry>> streamFor(String serial) => logs.stream;
}
