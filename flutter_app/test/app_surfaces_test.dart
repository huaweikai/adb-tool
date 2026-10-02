import 'package:adb_tool/design/topbar.dart';
import 'package:adb_tool/widgets/app_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests for the design-system surface widgets as they exist in
/// `lib/design/` and `lib/widgets/`.
///
/// Run: `flutter test test/app_surfaces_test.dart`
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('AppBackground', () {
    testWidgets('renders child on top of the glow', (tester) async {
      await tester.pumpWidget(wrap(AppBackground(child: const Text('on glow'))));
      expect(find.text('on glow'), findsOneWidget);
    });

    testWidgets('uses a radial gradient decoration', (tester) async {
      await tester.pumpWidget(wrap(AppBackground(child: const SizedBox())));
      final decorated = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(AppBackground),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(decorated.decoration, isA<BoxDecoration>());
      expect((decorated.decoration as BoxDecoration).gradient,
          isA<RadialGradient>(),
          reason: 'background must use a radial gradient for the green glow');
    });
  });

  group('AppTopbar', () {
    testWidgets('renders title, subtitle and actions', (tester) async {
      await tester.pumpWidget(wrap(const AppTopbar(
        title: '仪表盘',
        subtitle: Text('Pixel 8 Pro'),
        actions: Text('选择设备'),
      )));
      expect(find.text('仪表盘'), findsOneWidget);
      expect(find.text('Pixel 8 Pro'), findsOneWidget);
      expect(find.text('选择设备'), findsOneWidget);
    });

    testWidgets('holds the 64px design height', (tester) async {
      await tester.pumpWidget(wrap(const AppTopbar(title: 'T')));
      expect(tester.getSize(find.byType(AppTopbar)).height, 64);
    });

    testWidgets('paints the panel fill with a bottom hairline',
        (tester) async {
      await tester.pumpWidget(wrap(const AppTopbar(title: 'T')));
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(AppTopbar),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border!.bottom.width, 1);
    });
  });
}
