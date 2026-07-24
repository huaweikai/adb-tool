import 'package:adb_tool/design/design_tokens.dart';
import 'package:adb_tool/widgets/app_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget test for the new-design AppSidebar suite.
///
/// These tests do three things:
/// 1. Verify the sidebar renders without errors (compile + layout check).
/// 2. Verify the "double-active" bug is structurally impossible — only the
///    item whose id matches `activeNavId` is highlighted.
/// 3. Verify tap routing fires `onNavTap` with the right id.
///
/// Run: `flutter test test/app_sidebar_test.dart`
void main() {
  /// The 13 nav items from the design (主菜单 5 / 调试工具 5 / 高级 3).
  /// Icons are Material approximations of the design's custom SVGs.
  final navItems = <AppNavItemData>[
    const AppNavItemData(
        id: 'dashboard', icon: Icons.dashboard_outlined, label: '仪表盘', group: AppNavGroup.mainMenu),
    const AppNavItemData(
        id: 'info', icon: Icons.phone_android, label: '设备信息', group: AppNavGroup.mainMenu),
    const AppNavItemData(
        id: 'performance', icon: Icons.show_chart, label: '实时性能', group: AppNavGroup.mainMenu),
    const AppNavItemData(
        id: 'files', icon: Icons.folder_open, label: '文件浏览', group: AppNavGroup.mainMenu),
    const AppNavItemData(
        id: 'apps', icon: Icons.apps, label: '应用管理', group: AppNavGroup.mainMenu),
    const AppNavItemData(
        id: 'logcat', icon: Icons.terminal, label: 'Logcat', group: AppNavGroup.debug),
    const AppNavItemData(
        id: 'mirror', icon: Icons.cast, label: '投屏控制', group: AppNavGroup.debug),
    const AppNavItemData(
        id: 'clipboard', icon: Icons.content_paste, label: '剪贴板', group: AppNavGroup.debug),
    const AppNavItemData(
        id: 'wireless', icon: Icons.wifi, label: '无线调试', group: AppNavGroup.debug),
    const AppNavItemData(
        id: 'command', icon: Icons.terminal, label: 'ADB 指令', group: AppNavGroup.debug),
    const AppNavItemData(
        id: 'session', icon: Icons.assignment_outlined, label: '测试会话', group: AppNavGroup.advanced),
    const AppNavItemData(
        id: 'settings', icon: Icons.settings, label: '设置', group: AppNavGroup.advanced),
    const AppNavItemData(
        id: 'backend', icon: Icons.list_alt, label: '后端日志', group: AppNavGroup.advanced),
  ];

  Widget buildSidebar({
    String? activeNavId = 'dashboard',
    String? tappedId,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            AppSidebar(
              items: navItems,
              activeNavId: activeNavId,
              onNavTap: (id) => tappedId = id,
              deviceName: 'Pixel 8 Pro',
              deviceStatus: 'USB · 已连接',
              deviceOnline: true,
              backendOnline: true,
            ),
            const Expanded(child: ColoredBox(color: Colors.black, child: SizedBox.expand())),
          ],
        ),
      ),
    );
  }

  testWidgets('renders logo, device, group labels, and footer', (tester) async {
    await tester.pumpWidget(buildSidebar());

    expect(find.text('ADB Tool'), findsOneWidget, reason: 'brand logo');
    expect(find.text('Pixel 8 Pro'), findsOneWidget, reason: 'device name');
    expect(find.text('USB · 已连接'), findsOneWidget, reason: 'device status');
    expect(find.text('主菜单'), findsOneWidget, reason: 'group label 主菜单');
    expect(find.text('调试工具'), findsOneWidget, reason: 'group label 调试工具');
    expect(find.text('高级'), findsOneWidget, reason: 'group label 高级');
    expect(find.text('本地后端 · 在线'), findsOneWidget, reason: 'footer status');
  });

  testWidgets('all 13 nav labels are present', (tester) async {
    await tester.pumpWidget(buildSidebar());

    for (final item in navItems) {
      expect(find.text(item.label), findsOneWidget, reason: 'nav label: ${item.label}');
    }
  });

  testWidgets('only the active item is highlighted — no double-active bug',
      (tester) async {
    await tester.pumpWidget(buildSidebar(activeNavId: 'files'));

    // The active item's text should use the accent color.
    final filesLabel = tester.widget<Text>(find.text('文件浏览'));
    expect(filesLabel.style?.color, AppColors.accent,
        reason: 'active nav label must be accent green');

    // A non-active item must NOT be accent.
    final dashboardLabel = tester.widget<Text>(find.text('仪表盘'));
    expect(dashboardLabel.style?.color, isNot(AppColors.accent),
        reason: 'non-active nav must not be accent — guards against the '
            'legacy double-active bug where master defaulted one item active');
  });

  testWidgets('null activeNavId highlights nothing', (tester) async {
    await tester.pumpWidget(buildSidebar(activeNavId: null));

    // No nav label should carry the accent color.
    final labels = tester.widgetList<Text>(
      find.byWidgetPredicate((w) => w is Text && navItems.any((i) => i.label == (w).data)),
    );
    for (final label in labels) {
      expect(label.style?.color, isNot(AppColors.accent),
          reason: 'with null activeNavId, no item should be accent');
    }
  });

  testWidgets('tapping a nav item fires onNavTap with its id', (tester) async {
    String? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSidebar(
            items: navItems,
            activeNavId: 'dashboard',
            onNavTap: (id) => tapped = id,
            deviceName: 'Pixel 8 Pro',
            deviceStatus: 'USB · 已连接',
            deviceOnline: true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Logcat'));
    await tester.pump();
    expect(tapped, 'logcat');
  });
}
