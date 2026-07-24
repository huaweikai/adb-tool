import 'package:adb_tool/widgets/app_background.dart';
import 'package:adb_tool/widgets/app_card.dart';
import 'package:adb_tool/widgets/app_topbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests for the P1 new-design surface widgets:
/// [AppCard], [AppBackground], [AppTopbar] (+ [AppTopbarIconButton],
/// [AppStatusBadge]).
///
/// Run: `flutter test test/app_surfaces_test.dart`
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('AppCard', () {
    testWidgets('renders child content', (tester) async {
      await tester.pumpWidget(wrap(const AppCard(child: Text('body'))));
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('renders header title, subtitle and trailing', (tester) async {
      await tester.pumpWidget(wrap(AppCard(
        title: '实时性能',
        subtitle: 'CPU / 内存',
        trailing: const Icon(Icons.show_chart),
        child: const SizedBox(),
      )));
      expect(find.text('实时性能'), findsOneWidget);
      expect(find.text('CPU / 内存'), findsOneWidget);
      expect(find.byIcon(Icons.show_chart), findsOneWidget);
    });

    testWidgets('onTap makes the card tappable', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(AppCard(
        child: const Text('tap me'),
        onTap: () => tapped = true,
      )));
      await tester.tap(find.text('tap me'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('without header skips the Column branch', (tester) async {
      await tester.pumpWidget(wrap(const AppCard(child: Text('only body'))));
      expect(find.text('only body'), findsOneWidget);
      // No header → content is a plain Padding, not a Column.
      expect(
        find.descendant(
          of: find.byType(AppCard),
          matching: find.byType(Column),
        ),
        findsNothing,
      );
    });
  });

  group('AppBackground', () {
    testWidgets('renders child on top of the glow', (tester) async {
      await tester.pumpWidget(wrap(AppBackground(child: const Text('on glow'))));
      expect(find.text('on glow'), findsOneWidget);
    });

    testWidgets('uses a radial gradient decoration', (tester) async {
      await tester.pumpWidget(wrap(AppBackground(child: const SizedBox())));
      final decorated = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
      final decoration = decorated.decoration as BoxDecoration;
      expect(decoration.gradient, isA<RadialGradient>(),
          reason: 'background must use a radial gradient for the green glow');
    });
  });

  group('AppTopbar', () {
    testWidgets('renders title and action widgets', (tester) async {
      await tester.pumpWidget(wrap(const AppTopbar(
        title: '仪表盘',
        actions: [AppStatusBadge(label: '在线')],
      )));
      expect(find.text('仪表盘'), findsOneWidget);
      expect(find.text('在线'), findsOneWidget);
    });

    testWidgets('respects height and border', (tester) async {
      await tester.pumpWidget(wrap(const AppTopbar(title: 'T')));
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.constraints?.maxHeight, 64);
    });

    testWidgets('AppTopbarIconButton fires onPressed', (tester) async {
      var pressed = false;
      await tester.pumpWidget(wrap(AppTopbar(
        title: 'T',
        actions: [
          AppTopbarIconButton(
            icon: Icons.brightness_6,
            tooltip: 'theme',
            onPressed: () => pressed = true,
          ),
        ],
      )));
      await tester.tap(find.byIcon(Icons.brightness_6));
      await tester.pump();
      expect(pressed, isTrue);
    });

    testWidgets('AppStatusBadge renders label text', (tester) async {
      await tester.pumpWidget(wrap(const AppStatusBadge(label: '离线', color: Color(0xFFFF6B6B))));
      expect(find.text('离线'), findsOneWidget);
    });
  });
}
