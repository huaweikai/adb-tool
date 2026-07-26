import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n.dart';
import '../design/app_palette.dart';
import '../design/design_tokens.dart';
import '../design/panel.dart';
import '../design/section_label.dart';
import '../design/topbar.dart';
import '../models/device_status.dart';
import '../db/database.dart';
import '../providers/device_provider.dart';
import '../services/api_client.dart';
import '../widgets/empty_state.dart';

/// Dashboard landing screen — Ardot design node 17:3 (已连接设备).
///
/// Structure: a 64px top bar + a content row split into
///   • main column (hero device card + quick actions + realtime performance)
///   • right panel (connected devices + recent activity)
///
/// The selected device is owned by [DeviceProvider.activeSerial]; this view
/// only reads it. Quick actions and device selection are forwarded to the
/// caller through callbacks so the shell keeps ownership of navigation.
class DashboardView extends StatefulWidget {
  const DashboardView({
    super.key,
    required this.serial,
    this.onQuickAction,
    this.onSelectDevice,
  });

  /// Active device serial (from [DeviceProvider.activeSerial]). Null when no
  /// device is selected yet — the view then shows a "pick a device" empty state.
  final String? serial;

  /// Emitted when a quick-action chip is tapped. [actionId] is one of
  /// `status` / `files` / `apps` / `logcat` / `command` / `mirror` / `wireless`.
  final void Function(String actionId)? onQuickAction;

  /// Emitted when a device row in the right panel is tapped.
  final void Function(String serial)? onSelectDevice;

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  DeviceStatus? _status;
  Timer? _timer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant DashboardView old) {
    super.didUpdateWidget(old);
    if (old.serial != widget.serial) {
      _status = null;
      _error = null;
      _load();
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    final serial = widget.serial;
    if (serial == null) return;
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _load(),
    );
  }

  Future<void> _load() async {
    final serial = widget.serial;
    if (serial == null) return;
    final api = context.read<ApiClient>();
    try {
      final s = await api.getDeviceStatus(serial);
      if (!mounted) return;
      setState(() {
        _status = s;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final deviceProvider = context.watch<DeviceProvider>();
    final serial = widget.serial;
    final device = serial == null
        ? null
        : deviceProvider.savedDevices
            .where((d) => d.serial == serial)
            .firstOrNull;

    final online = device?.isConnected ?? false;
    final deviceName = device?.displayName ?? tr('noDevice');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTopbar(
          title: tr('dashboard'),
          subtitle: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: online ? palette.online : palette.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                deviceName,
                style: TextStyle(
                  fontSize: AppFontSize.body,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
          actions: Text(
            tr('selectDevice'),
            style: TextStyle(
              fontSize: AppFontSize.md,
              color: palette.textDisabled,
            ),
          ),
        ),
        Expanded(
          child: serial == null
              ? _EmptyDevice(onPick: () => widget.onSelectDevice?.call(''))
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _MainColumn(
                        device: device,
                        status: _status,
                        error: _error,
                        onRetry: () => _load(),
                        onQuickAction: widget.onQuickAction,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: _RightPanel(
                          devices: deviceProvider.savedDevices,
                          activeSerial: serial,
                          onSelectDevice: widget.onSelectDevice,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _EmptyDevice extends StatelessWidget {
  const _EmptyDevice({this.onPick});

  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.device_unknown,
      title: tr('noDevice'),
      subtitle: tr('selectDevice'),
      action: onPick == null
          ? null
          : FilledButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.add, size: 16),
              label: Text(tr('selectDevice')),
            ),
    );
  }
}

class _MainColumn extends StatelessWidget {
  const _MainColumn({
    this.device,
    this.status,
    this.error,
    this.onRetry,
    this.onQuickAction,
  });

  final SavedDevice? device;
  final DeviceStatus? status;
  final String? error;
  final VoidCallback? onRetry;
  final void Function(String)? onQuickAction;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroCard(
            device: device,
            status: status,
            onQuickAction: onQuickAction,
          ),
          const SizedBox(height: AppSpacing.xl),
          _QuickActions(onQuickAction: onQuickAction),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.xl),
            _ErrorNote(error: error!, onRetry: onRetry),
          ],
        ],
      ),
    );
  }
}

/// Big hero card with the active device's identity, live metric stats,
/// and CTA column. Ardot node 17:401.
///
/// Layout: `[avatar 64] [device info flexible] [4 metric stats] [CTA column]`.
/// The stat cards read directly off [status] and default to `--` while data
/// is loading; they intentionally show no sparkline (compact) to leave room
/// for the CTAs and preserve the design's balanced hero rhythm.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    this.device,
    this.status,
    this.onQuickAction,
  });

  final SavedDevice? device;
  final DeviceStatus? status;

  /// Bubbled up so the CTA buttons ("开启投屏" / "实时截图") can route
  /// via the same channel the QuickActions row uses.
  final void Function(String)? onQuickAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final name = device?.displayName ?? tr('noDevice');
    final serial = device?.serial;
    final android = device?.sdk != null ? 'Android ${device!.sdk}' : null;
    final subtitle = [android, serial].whereType<String>().join('  ·  ');
    final online = device?.isConnected ?? false;

    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.xl), // 24 — design 卡片内边距
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1 — avatar + device identity + CTA column.
          //
          // The design (Ardot 17:401) is 1125px wide and horizontally packs
          // avatar + info + 4 stats + CTA into one row with `itemSpacing:
          // 52`. On real desktop windows (~1200-1400 usable content width
          // after sidebar + right rail + paddings) this overflows, so we
          // split into two rows: identity on top, stats below. Both rows
          // still share the same avatar / CTA column siblings, giving the
          // hero a stable 2-line height regardless of window width.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _HeroAvatar(online: online),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: AppFontSize.large, // 20
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: AppFontSize.body, // 12
                          fontFamily: 'Noto Sans Mono',
                          color: palette.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              _HeroCtaColumn(online: online, onQuickAction: onQuickAction),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Row 2 — 4 metric stats spread across the full hero width.
          Row(
            children: [
              _HeroStat(
                label: tr('monitorBattery'),
                value: status?.batteryLevel,
              ),
              const SizedBox(width: AppSpacing.md),
              _HeroStat(
                label: tr('monitorCpuUsage'),
                value: status?.cpuUsage,
              ),
              const SizedBox(width: AppSpacing.md),
              _HeroStat(
                label: tr('monitorMemory'),
                value: status?.memoryUsedPercent,
              ),
              const SizedBox(width: AppSpacing.md),
              _HeroStat(
                label: tr('monitorStorage'),
                value: status?.storageUsedPercent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 64×64 avatar with online halo + a small bottom-right online dot.
///
/// Design uses an accent-tinted fill (12% alpha) + accent stroke (40% alpha)
/// when online; when offline it falls back to the muted raised surface so
/// the halo doesn't imply a live device.
class _HeroAvatar extends StatelessWidget {
  const _HeroAvatar({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: online
                  ? palette.accent.withValues(alpha: 0.12)
                  : palette.raised,
              borderRadius: BorderRadius.circular(AppRadius.xl), // 16 — design
              border: Border.all(
                color: online
                    ? palette.accent.withValues(alpha: 0.4)
                    : palette.hairline,
              ),
            ),
            child: Icon(
              Icons.phone_android,
              size: 32,
              color:
                  online ? palette.accent : palette.textDisabled,
            ),
          ),
          if (online)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: palette.online,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.panel, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One 120-ish × ~58 metric card inside the hero (电量 / CPU / 内存 / 存储).
///
/// Style: raised surface with a rounded label + value pair. Height is
/// content-driven (not fixed) so the label (11pt) + gap + value (16pt)
/// always fit; a fixed 58 with a `spaceBetween` column overflows by
/// ~1-2px because 11pt + 16pt + line-height metrics > 38px content area.
/// Row context makes all 4 stats end up equal-height naturally because
/// they render the same 2-line structure.
class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final display = (value == null || value!.isEmpty) ? '--' : value!;
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minWidth: 0),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, // 12 — design x=12
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: palette.raised,
          borderRadius: BorderRadius.circular(AppRadius.lg - 2), // 10 — design
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: AppFontSize.md, // 11
                color: palette.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 4),
            Text(
              display,
              style: TextStyle(
                fontSize: AppFontSize.headline, // 16
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}

/// Right rail inside the hero: status pill + solid CTA + outlined CTA.
///
/// The two buttons forward to `onQuickAction('mirror' | 'screenshot')`
/// so the shell keeps a single navigation channel; the hero doesn't need
/// its own callbacks.
class _HeroCtaColumn extends StatelessWidget {
  const _HeroCtaColumn({required this.online, this.onQuickAction});

  final bool online;
  final void Function(String)? onQuickAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: 88,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status pill: accent-tinted when online, muted otherwise.
          Container(
            height: 27,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: online
                  ? palette.accent.withValues(alpha: 0.14)
                  : palette.raised,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: online ? palette.online : palette.textDisabled,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  online ? tr('online') : tr('offline'),
                  style: TextStyle(
                    fontSize: AppFontSize.body, // 12
                    fontWeight: FontWeight.w500,
                    color: online
                        ? palette.accent
                        : palette.textDisabled,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Primary CTA: 开启投屏
          _HeroCtaButton(
            label: tr('startMirror'),
            filled: true,
            enabled: online && onQuickAction != null,
            onTap: () => onQuickAction?.call('mirror'),
          ),
          const SizedBox(height: 10),
          // Secondary CTA: 实时截图 — routes via hierarchy screen for now
          // (dashboard doesn't own a screenshot capture pipeline).
          _HeroCtaButton(
            label: tr('liveScreenshot'),
            filled: false,
            enabled: online && onQuickAction != null,
            onTap: () => onQuickAction?.call('hierarchy'),
          ),
        ],
      ),
    );
  }
}

/// Filled = solid accent bg + near-black text (design's high-contrast
/// primary CTA). Outlined = panel bg + hairline border + textPrimary.
class _HeroCtaButton extends StatelessWidget {
  const _HeroCtaButton({
    required this.label,
    required this.filled,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bg = filled
        ? (enabled ? palette.accent : palette.raised)
        : palette.raised;
    final fg = filled
        ? (enabled ? palette.canvas : palette.textDisabled)
        : (enabled ? palette.textPrimary : palette.textDisabled);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.md), // 8
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: filled
              ? null
              : BoxDecoration(
                  border: Border.all(color: palette.hairline),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppFontSize.subtitle, // 13
              fontWeight: filled ? FontWeight.w600 : FontWeight.w500,
              color: fg,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// Quick-action chips. Each forwards an [actionId] to the shell.
class _QuickActions extends StatelessWidget {
  const _QuickActions({this.onQuickAction});

  final void Function(String)? onQuickAction;

  @override
  Widget build(BuildContext context) {
    const items = <(String, IconData, String)>[
      ('status', Icons.phone_android, 'status'),
      ('files', Icons.folder_open, 'files'),
      ('apps', Icons.android, 'apps'),
      ('logcat', Icons.list_alt, 'logcat'),
      ('command', Icons.terminal, 'command'),
      ('mirror', Icons.cast, 'screenMirror'),
      ('wireless', Icons.wifi_tethering, 'wirelessAdb'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AppSectionLabel(tr('quickActions')),
        ),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.lg,
          children: items
              .map(
                (a) => _QuickChip(
                  id: a.$1,
                  icon: a.$2,
                  label: tr(a.$3),
                  onTap: onQuickAction == null
                      ? null
                      : () => onQuickAction!(a.$1),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.id,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final String id;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onTap != null;
    return Material(
      color: palette.raised,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        mouseCursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: enabled
                    ? palette.navActiveFg
                    : palette.textDisabled,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppFontSize.body,
                  color: enabled
                      ? palette.textPrimary
                      : palette.textDisabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.error, this.onRetry});

  final String error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderColor: palette.red.withValues(alpha: 0.4),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: palette.red),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                fontSize: AppFontSize.md,
                color: palette.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(tr('refresh')),
            ),
        ],
      ),
    );
  }
}

/// Right panel: connected-devices list + recent-activity placeholder.
class _RightPanel extends StatelessWidget {
  const _RightPanel({
    required this.devices,
    required this.activeSerial,
    this.onSelectDevice,
  });

  final List<SavedDevice> devices;
  final String activeSerial;
  final void Function(String serial)? onSelectDevice;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionLabel(tr('connectedDevices')),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            flex: 2,
            child: _DeviceList(
              devices: devices,
              activeSerial: activeSerial,
              onSelectDevice: onSelectDevice,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppSectionLabel(tr('recentActivity')),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            flex: 3,
            child: _RecentActivity(),
          ),
        ],
      ),
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({
    required this.devices,
    required this.activeSerial,
    this.onSelectDevice,
  });

  final List<SavedDevice> devices;
  final String activeSerial;
  final void Function(String serial)? onSelectDevice;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (devices.isEmpty) {
      return Center(
        child: Text(
          tr('noDevices'),
          style: TextStyle(
            fontSize: AppFontSize.md,
            color: palette.textDisabled,
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: devices.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final d = devices[i];
        final active = d.serial == activeSerial;
        return Material(
          color: active ? palette.activeNav : palette.panel,
          borderRadius: BorderRadius.circular(AppRadius.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onSelectDevice == null
                ? null
                : () => onSelectDevice!(d.serial),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: palette.raised,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: palette.hairline),
                    ),
                    child: Icon(
                      Icons.phone_android,
                      size: 16,
                      color: d.isConnected
                          ? palette.textSecondary
                          : palette.textDisabled,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          d.displayName,
                          style: TextStyle(
                            fontSize: AppFontSize.body,
                            fontWeight:
                                active ? FontWeight.w600 : FontWeight.w400,
                            color: palette.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          d.isConnected
                              ? tr('backendOnline')
                              : tr('backendOffline'),
                          style: TextStyle(
                            fontSize: AppFontSize.md,
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: d.isConnected
                          ? palette.online
                          : palette.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Recent-activity feed. The backend does not yet emit an activity stream,
/// so this renders a calm empty placeholder rather than fabricated rows.
class _RecentActivity extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: Text(
          tr('noRecentActivity'),
          style: TextStyle(
            fontSize: AppFontSize.md,
            color: palette.textDisabled,
          ),
        ),
      ),
    );
  }
}
