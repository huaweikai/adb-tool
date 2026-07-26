import 'package:flutter/material.dart';

import '../design/app_palette.dart';
import '../design/design_tokens.dart';

/// ── New design system sidebar widgets ─────────────────────────
///
/// Mirrors the Ardot master component `34:52` (Sidebar, 240×923) from the
/// main design file `706601156104862`. These widgets are a **pure render**
/// layer — they do not bind to the legacy `NavItem` enum or `DeviceProvider`.
/// Callers feed in data + callbacks; the widgets draw the new dark UI.
///
/// Not yet wired into `home_screen.dart`. The legacy sidebar there uses a
/// *device-tree* interaction (multi-device rows, each expanding to its own
/// nav list), while this new design uses a *single-device switcher + flat
/// nav* model. Migrating the interaction is a separate task; these widgets
/// are extracted first so the visual layer is ready.
///
/// Colors come from the active theme's [AppPalette] (via `context.palette`)
/// so they switch automatically with `ThemeMode`. Do NOT read from
/// `Theme.of(context).colorScheme` (that's the legacy GitHub-dark seed) —
/// the design system's tokens live in [AppPalette].

/// Which nav group an item belongs to — drives the section label above it.
enum AppNavGroup { mainMenu, debug, advanced }

/// One navigation entry. The [id] is opaque to the widget; the caller
/// compares it against its own active-nav state and passes the match via
/// [AppSidebar.activeNavId].
class AppNavItemData {
  const AppNavItemData({
    required this.id,
    required this.icon,
    required this.label,
    required this.group,
  });

  final String id;
  final IconData icon;
  final String label;
  final AppNavGroup group;
}

/// ── AppNavGroupLabel ─────────────────────────────────────────
///
/// Small uppercase-style section header above a nav group.
///   主菜单 / 调试工具 / 高级
///
/// Spec: Noto Sans SC Regular 11, color `palette.textDisabled` (#5B6472 on dark).
class AppNavGroupLabel extends StatelessWidget {
  const AppNavGroupLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, // 16 — matches design x=14 + visual rhythm
        AppSpacing.md, // 12 — top breathing room before the group
        AppSpacing.lg,
        AppSpacing.xs, // 4 — tight to the first nav item below
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppFontSize.sm, // 10 — design uses 11; token sm=10 reads closer at this density
          color: context.palette.textDisabled,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// ── AppNavItem ───────────────────────────────────────────────
///
/// A single sidebar nav row. 212×40, horizontal, icon + label.
///
///   ┌────────────────────────────────────┐
///   │  ▢  仪表盘                          │  ← default: icon/label #9AA4B2, no bg
///   └────────────────────────────────────┘
///   ┌────────────────────────────────────┐
///   │  ▢  文件浏览          (active)      │  ← active: bg #162031, icon/label #3DDC84
///   └────────────────────────────────────┘
///
/// Spec: 212×40, cornerRadius 8, icon 18×18, label fontSize 14.
/// Default fill = transparent (sidebar panel shows through); active fill
/// = `palette.activeNav`. Hover gets `palette.raised`.
class AppNavItem extends StatefulWidget {
  const AppNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  /// When false, the item renders in the disabled style (greyed out) and
  /// ignores taps. Used for device-dependent items when no device is
  /// connected (mirrors the design's "未连接设备" sidebar state).
  final bool enabled;

  @override
  State<AppNavItem> createState() => _AppNavItemState();
}

class _AppNavItemState extends State<AppNavItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fg = !widget.enabled
        ? palette.textDisabled
        : widget.active
            ? palette.navActiveFg
            : palette.navDefaultFg;

    final bg = widget.active
        ? palette.activeNav
        : _hovering && widget.enabled
            ? palette.raised
            : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md), // 12 → 212 from 240
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md), // 8
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.enabled ? widget.onTap : null,
          mouseCursor:
              widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onHover: (h) => setState(() => _hovering = h),
          child: SizedBox(
            height: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Icon(widget.icon, size: 18, color: fg),
                  const SizedBox(width: AppSpacing.md), // 12 → label x=42
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: AppFontSize.title, // 14
                        color: fg,
                        fontWeight:
                            widget.active ? FontWeight.w600 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ── AppDeviceSwitcher ────────────────────────────────────────
///
/// The current-device card at the top of the sidebar. Tapping opens a
/// dropdown to switch devices.
///
///   ┌────────────────────────────────────┐
///   │  ▢  Pixel 8 Pro                ▼   │  ← connected
///   │  ⊙  USB · 已连接                    │
///  └────────────────────────────────────┘
///   ┌────────────────────────────────────┐
///   │  ▢  未连接设备                  ▼   │  ← disconnected
///  └────────────────────────────────────┘
///
/// Spec: 212×60, cornerRadius 10, fill `palette.raised` (#161B24 on dark),
/// stroke `palette.hairline` (#1E2430 on dark). Avatar 36×36 cornerRadius 8
/// with an 11×11 online dot at bottom-right. Two-line info: name
/// (Inter SemiBold 13) + status (Noto Sans SC Regular 11).
class AppDeviceSwitcher extends StatefulWidget {
  const AppDeviceSwitcher({
    super.key,
    required this.deviceName,
    required this.deviceStatus,
    required this.online,
    this.onTap,
  });

  final String deviceName;
  final String deviceStatus;
  final bool online;
  final VoidCallback? onTap;

  @override
  State<AppDeviceSwitcher> createState() => _AppDeviceSwitcherState();
}

class _AppDeviceSwitcherState extends State<AppDeviceSwitcher> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Material(
        color: palette.raised,
        borderRadius: BorderRadius.circular(AppRadius.lg), // 12 → design 10; token lg=12 close
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (h) => setState(() => _hovering = h),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: palette.hairline),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                // Avatar with online dot
                SizedBox(
                  width: 36,
                  height: 36,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: palette.panel,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: palette.hairline),
                        ),
                        child: Icon(
                          Icons.phone_android,
                          size: 18,
                          color: widget.online
                              ? palette.textSecondary
                              : palette.textDisabled,
                        ),
                      ),
                      if (widget.online)
                        Positioned(
                          right: -1,
                          bottom: -1,
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: palette.online,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: palette.raised,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Device info (name + status)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.deviceName,
                        style: TextStyle(
                          fontSize: AppFontSize.subtitle, // 13
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.deviceStatus,
                        style: TextStyle(
                          fontSize: AppFontSize.md, // 11
                          color: palette.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Chevron
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: _hovering
                      ? palette.textPrimary
                      : palette.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ── AppSidebar ───────────────────────────────────────────────
///
/// The full sidebar master, composing [AppDeviceSwitcher], nav group
/// labels, [AppNavItem]s, a spacer, and a footer status line.
///
/// Fixed width 240, full height. Receives the nav list + active id +
/// device info as props — no internal state. The caller owns active-nav
/// selection (this is what fixes the legacy "double-active" bug: there is
/// no default active item here; nothing is active unless the caller says so).
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.items,
    required this.activeNavId,
    required this.onNavTap,
    required this.deviceName,
    required this.deviceStatus,
    required this.deviceOnline,
    this.onDeviceSwitcherTap,
    this.backendOnline = true,
    this.backendStatusText,
  });

  /// All nav items, grouped by [AppNavGroup]. The widget renders group
  /// labels automatically between groups.
  final List<AppNavItemData> items;

  /// Opaque id compared against [AppNavItemData.id]. Null = nothing active.
  final String? activeNavId;

  /// Called with the tapped item's id.
  final void Function(String id)? onNavTap;

  // Device switcher props
  final String deviceName;
  final String deviceStatus;
  final bool deviceOnline;
  final VoidCallback? onDeviceSwitcherTap;

  // Footer props
  final bool backendOnline;
  /// Overrides the default "本地后端 · 在线" / "本地后端 · 离线" text.
  final String? backendStatusText;

  static const _groupLabels = {
    AppNavGroup.mainMenu: '主菜单',
    AppNavGroup.debug: '调试工具',
    AppNavGroup.advanced: '高级',
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Group items preserving their declared order within each group.
    final byGroup = <AppNavGroup, List<AppNavItemData>>{
      AppNavGroup.mainMenu: [],
      AppNavGroup.debug: [],
      AppNavGroup.advanced: [],
    };
    for (final item in items) {
      byGroup[item.group]?.add(item);
    }

    // Build the nav-group blocks separately so we can wrap them in a
    // scroll view. On short windows (< ~860px) the 15 nav items + labels +
    // logo + switcher + footer overflows a plain Column; scrolling the
    // middle section keeps the header + footer pinned.
    final navBlocks = <Widget>[
      for (final group in const [
        AppNavGroup.mainMenu,
        AppNavGroup.debug,
        AppNavGroup.advanced,
      ])
        if (byGroup[group]!.isNotEmpty) ...[
          AppNavGroupLabel(_groupLabels[group]!),
          for (final item in byGroup[group]!)
            AppNavItem(
              icon: item.icon,
              label: item.label,
              active: item.id == activeNavId,
              onTap: onNavTap == null ? null : () => onNavTap!(item.id),
            ),
        ],
    ];

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: palette.panel,
        border: Border(
          right: BorderSide(color: palette.hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg, // 16
              AppSpacing.md,
              AppSpacing.md + 2, // ~18 → design y=18
            ),
            child: Row(
              children: [
                Icon(Icons.adb, size: 26, color: palette.accent),
                const SizedBox(width: AppSpacing.md),
                Text(
                  'ADB Tool',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          // Device switcher
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppDeviceSwitcher(
              deviceName: deviceName,
              deviceStatus: deviceStatus,
              online: deviceOnline,
              onTap: onDeviceSwitcherTap,
            ),
          ),
          // Nav groups — scrollable middle section. Expanded gives it all
          // remaining vertical space; the footer stays pinned below.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: navBlocks,
              ),
            ),
          ),
          // Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: backendOnline
                        ? palette.online
                        : palette.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    backendStatusText ??
                        (backendOnline ? '本地后端 · 在线' : '本地后端 · 离线'),
                    style: TextStyle(
                      fontSize: AppFontSize.body, // 12
                      color: palette.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
