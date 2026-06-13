import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adb_tool/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AdbToolApp());
    await tester.pump();

    expect(find.text('ADB Tool'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
