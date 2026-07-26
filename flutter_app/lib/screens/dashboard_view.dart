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
import '../widgets/sparkline.dart';

/// Dashboard landing screen — Ardot design nodes 17:3 (已连接设备) and
/// 17:202 (未连接设备).
///
/// Structure: a 64px top bar + a content row split into
///   • main column (hero device card + quick actions grid + realtime perf)
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
  /// device is selected yet — the view keeps the full skeleton but swaps the
  /// hero card for a "未连接设备" prompt and dims interactive tiles.
  final String? serial;

  /// Emitted when a quick-action tile is tapped. [actionId] is one of
  /// `screenRecord` / `mirror` / `screenshot` / `installApk` / `wireless` /
  /// `clipboard`. The shell maps these to real navigation targets.
  final void Function(String actionId)? onQuickAction;

  /// Emitted when a device row in the right panel is tapped (empty string
  /// means "open device switcher").
  final void Function(String serial)? onSelectDevice;

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  DeviceStatus? _status;
  Timer? _timer;
  String? _error;

  /// Ring buffers for the realtime perf sparkline. Keep last 40 samples
  /// (~2min at 3s cadence) so the chart shows enough context without
  /// growing unbounded.
  static const _perfWindow = 40;
  final List<double> _cpuSeries = <double>[];
  final List<double> _memSeries = <double>[];

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
      _cpuSeries.clear();
      _memSeries.clear();
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
        _appendSample(s);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    }
  }

  /// Push CPU / memory readings into the sparkline ring buffers. Values
  /// come in as `"23%"` / `"52%"` strings from `DeviceStatus`; we tolerate
  /// missing or malformed entries by falling back to the previous sample
  /// (or 0 if the series is still empty) — that keeps the curve visually
  /// stable when a single poll misses.
  void _appendSample(DeviceStatus s) {
    final cpu = _parsePercent(s.cpuUsage) ?? _cpuSeries.lastOrNull ?? 0;
    final mem =
        _parsePercent(s.memoryUsedPercent) ?? _memSeries.lastOrNull ?? 0;
    _cpuSeries.add(cpu);
    _memSeries.add(mem);
    if (_cpuSeries.length > _perfWindow) {
      _cpuSeries.removeAt(0);
    }
    if (_memSeries.length > _perfWindow) {
      _memSeries.removeAt(0);
    }
  }

  static double? _parsePercent(String raw) {
    if (raw.isEmpty) return null;
    final cleaned = raw.replaceAll('%', '').trim();
    return double.tryParse(cleaned);
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: _MainColumn(
                  device: device,
                  status: _status,
                  error: _error,
                  cpuSeries: _cpuSeries,
                  memSeries: _memSeries,
                  onRetry: () => _load(),
                  onQuickAction: widget.onQuickAction,
                  onOpenPicker: () => widget.onSelectDevice?.call(''),
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
                    onQuickAction: widget.onQuickAction,
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

class _MainColumn extends StatelessWidget {
  const _MainColumn({
    this.device,
    this.status,
    this.error,
    required this.cpuSeries,
    required this.memSeries,
    this.onRetry,
    this.onQuickAction,
    this.onOpenPicker,
  });

  final SavedDevice? device;
  final DeviceStatus? status;
  final String? error;
  final List<double> cpuSeries;
  final List<double> memSeries;
  final VoidCallback? onRetry;
  final void Function(String)? onQuickAction;
  final VoidCallback? onOpenPicker;

  @override
  Widget build(BuildContext context) {
    final hasDevice = device != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasDevice)
            _HeroCard(
              device: device,
              status: status,
              onQuickAction: onQuickAction,
            )
          else
            _DisconnectedHeroCard(onOpenPicker: onOpenPicker),
          const SizedBox(height: AppSpacing.xl),
          _QuickActions(
            onQuickAction: onQuickAction,
            enabled: hasDevice,
          ),
          const SizedBox(height: AppSpacing.xl),
          _RealtimePerformance(
            device: device,
            status: status,
            cpuSeries: cpuSeries,
            memSeries: memSeries,
          ),
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
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    this.device,
    this.status,
    this.onQuickAction,
  });

  final SavedDevice? device;
  final DeviceStatus? status;
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
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
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
                        fontSize: AppFontSize.large,
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
                          fontSize: AppFontSize.body,
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

/// Empty-device hero — matches Ardot node 17:202. Preserves the skeleton so
/// the surrounding quick-actions grid and perf card stay in place.
class _DisconnectedHeroCard extends StatelessWidget {
  const _DisconnectedHeroCard({this.onOpenPicker});

  final VoidCallback? onOpenPicker;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: palette.raised,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: palette.hairline),
            ),
            child: Icon(
              Icons.phone_android,
              size: 36,
              color: palette.textDisabled,
            ),
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('deviceOffline'),
                  style: TextStyle(
                    fontSize: AppFontSize.large,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  tr('noDevicesHint'),
                  style: TextStyle(
                    fontSize: AppFontSize.body,
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    _HeroCtaButton(
                      label: tr('selectDevice'),
                      filled: true,
                      enabled: onOpenPicker != null,
                      onTap: onOpenPicker ?? () {},
                      width: 132,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 64×64 avatar with online halo + a small bottom-right online dot.
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
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: online
                    ? palette.accent.withValues(alpha: 0.4)
                    : palette.hairline,
              ),
            ),
            child: Icon(
              Icons.phone_android,
              size: 32,
              color: online ? palette.accent : palette.textDisabled,
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

/// One metric card inside the hero (电量 / CPU / 内存 / 存储).
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
          horizontal: AppSpacing.md,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: palette.raised,
          borderRadius: BorderRadius.circular(AppRadius.lg - 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: AppFontSize.md,
                color: palette.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 4),
            Text(
              display,
              style: TextStyle(
                fontSize: AppFontSize.headline,
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
                    fontSize: AppFontSize.body,
                    fontWeight: FontWeight.w500,
                    color:
                        online ? palette.accent : palette.textDisabled,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _HeroCtaButton(
            label: tr('startMirror'),
            filled: true,
            enabled: online && onQuickAction != null,
            onTap: () => onQuickAction?.call('mirror'),
          ),
          const SizedBox(height: 10),
          _HeroCtaButton(
            label: tr('liveScreenshot'),
            filled: false,
            enabled: online && onQuickAction != null,
            onTap: () => onQuickAction?.call('screenshot'),
          ),
        ],
      ),
    );
  }
}

class _HeroCtaButton extends StatelessWidget {
  const _HeroCtaButton({
    required this.label,
    required this.filled,
    required this.enabled,
    required this.onTap,
    this.width,
  });

  final String label;
  final bool filled;
  final bool enabled;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bg = filled
        ? (enabled ? palette.accent : palette.raised)
        : palette.raised;
    final fg = filled
        ? (enabled ? palette.canvas : palette.textDisabled)
        : (enabled ? palette.textPrimary : palette.textDisabled);
    final content = Container(
      height: 40,
      width: width,
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
          fontSize: AppFontSize.subtitle,
          fontWeight: filled ? FontWeight.w600 : FontWeight.w500,
          color: fg,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: content,
      ),
    );
  }
}

/// Quick actions — Ardot 17:3 中部 2×3 网格。每格是「大图标 + 主标题 +
/// 副标题」的动作型入口。tile id 与 [DashboardView.onQuickAction] 契约一致，
/// 由外层 shell 决定映射到哪个页面。
class _QuickActions extends StatelessWidget {
  const _QuickActions({
    this.onQuickAction,
    this.enabled = true,
  });

  final void Function(String)? onQuickAction;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const items = <_QuickActionSpec>[
      _QuickActionSpec(
        id: 'screenRecord',
        icon: Icons.videocam_outlined,
        titleKey: 'screenRecord',
        subtitleKey: 'screenRecordHint',
      ),
      _QuickActionSpec(
        id: 'mirror',
        icon: Icons.cast,
        titleKey: 'screenMirror',
        subtitleKey: 'mirrorTileHint',
      ),
      _QuickActionSpec(
        id: 'screenshot',
        icon: Icons.photo_camera_outlined,
        titleKey: 'screenshot',
        subtitleKey: 'screenshotHint',
      ),
      _QuickActionSpec(
        id: 'installApk',
        icon: Icons.download_outlined,
        titleKey: 'installApk',
        subtitleKey: 'installApkHint',
      ),
      _QuickActionSpec(
        id: 'wireless',
        icon: Icons.wifi_tethering,
        titleKey: 'wirelessAdb',
        subtitleKey: 'wirelessAdbTileHint',
      ),
      _QuickActionSpec(
        id: 'clipboard',
        icon: Icons.content_paste_outlined,
        titleKey: 'clipboard',
        subtitleKey: 'clipboardTileHint',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppSectionLabel(tr('quickActions')),
                  const SizedBox(height: 2),
                  Text(
                    tr('quickActionsHint'),
                    style: TextStyle(
                      fontSize: AppFontSize.md,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              enabled ? '${tr('viewAll')} →' : tr('deviceOffline'),
              style: TextStyle(
                fontSize: AppFontSize.md,
                color: palette.textDisabled,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            const columns = 3;
            const gap = AppSpacing.lg;
            final tileWidth =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: items.map((spec) {
                final effectiveTap = enabled && onQuickAction != null
                    ? () => onQuickAction!(spec.id)
                    : null;
                return SizedBox(
                  width: tileWidth,
                  child: _QuickActionTile(
                    icon: spec.icon,
                    title: tr(spec.titleKey),
                    subtitle: tr(spec.subtitleKey),
                    onTap: effectiveTap,
                    dimmed: !enabled,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _QuickActionSpec {
  const _QuickActionSpec({
    required this.id,
    required this.icon,
    required this.titleKey,
    required this.subtitleKey,
  });

  final String id;
  final IconData icon;
  final String titleKey;
  final String subtitleKey;
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.dimmed = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      color: dimmed ? palette.panel : palette.raised,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: dimmed
                  ? palette.raised
                  : palette.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: dimmed ? palette.textDisabled : palette.accent,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: TextStyle(
              fontSize: AppFontSize.subtitle,
              fontWeight: FontWeight.w600,
              color:
                  dimmed ? palette.textDisabled : palette.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: AppFontSize.md,
              color: palette.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Realtime performance chart — Ardot 17:3 底部一整块。
///
/// 已连接：section header 显示"实时"药丸 + 前台应用副文案，body 是双曲线
/// (CPU 绿 / 内存蓝) 的 sparkline，下方是图例。
/// 未连接：body 显示"等待设备连接"占位提示，保留骨架不塌陷。
class _RealtimePerformance extends StatelessWidget {
  const _RealtimePerformance({
    this.device,
    this.status,
    required this.cpuSeries,
    required this.memSeries,
  });

  final SavedDevice? device;
  final DeviceStatus? status;
  final List<double> cpuSeries;
  final List<double> memSeries;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final connected = device?.isConnected ?? false;
    final hasData = connected && cpuSeries.length >= 2;

    // Header — 左侧标题 + 副文案，右侧 "实时" 药丸 / "等待设备连接" 文案。
    Widget header = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSectionLabel(tr('realtimePerformance')),
              const SizedBox(height: 2),
              Text(
                connected
                    ? _subtitleFor(device, status)
                    : tr('waitingForDeviceHint'),
                style: TextStyle(
                  fontSize: AppFontSize.md,
                  color: palette.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (connected)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              tr('live'),
              style: TextStyle(
                fontSize: AppFontSize.md,
                fontWeight: FontWeight.w500,
                color: palette.accent,
              ),
            ),
          )
        else
          Text(
            tr('waitingForDevice'),
            style: TextStyle(
              fontSize: AppFontSize.md,
              color: palette.textDisabled,
            ),
          ),
      ],
    );

    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 140,
            child: hasData
                ? Stack(
                    children: [
                      Sparkline(
                        data: memSeries,
                        color: palette.blue,
                        height: 140,
                        lineWidth: 1.5,
                      ),
                      Sparkline(
                        data: cpuSeries,
                        color: palette.accent,
                        height: 140,
                        lineWidth: 1.8,
                      ),
                    ],
                  )
                : Center(
                    child: Text(
                      tr('waitingForDeviceHint'),
                      style: TextStyle(
                        fontSize: AppFontSize.body,
                        color: palette.textDisabled,
                      ),
                    ),
                  ),
          ),
          if (hasData) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _PerfLegend(
                  color: palette.accent,
                  label: tr('perfLegendCpu', {
                    'value': _formatPercent(status?.cpuUsage),
                  }),
                ),
                const SizedBox(width: AppSpacing.lg),
                _PerfLegend(
                  color: palette.blue,
                  label: tr('perfLegendMemory', {
                    'value': _formatPercent(status?.memoryUsedPercent),
                  }),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _subtitleFor(SavedDevice? device, DeviceStatus? status) {
    final parts = <String>[];
    if (device?.displayName.isNotEmpty ?? false) parts.add(device!.displayName);
    parts.add('CPU / ${tr('monitorMemory')}');
    final top = status?.topProcesses.firstOrNull;
    if (top != null && top.name.isNotEmpty) {
      parts.add(top.name);
    }
    return parts.join(' · ');
  }

  static String _formatPercent(String? raw) {
    if (raw == null || raw.isEmpty) return '--';
    return raw.endsWith('%') ? raw : '$raw%';
  }
}

class _PerfLegend extends StatelessWidget {
  const _PerfLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: TextStyle(
            fontSize: AppFontSize.md,
            color: palette.textSecondary,
          ),
        ),
      ],
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
    this.onQuickAction,
  });

  final List<SavedDevice> devices;
  final String? activeSerial;
  final void Function(String serial)? onSelectDevice;
  final void Function(String)? onQuickAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: AppSectionLabel(tr('connectedDevices'))),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: palette.raised,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '${devices.length}',
                  style: TextStyle(
                    fontSize: AppFontSize.md,
                    fontWeight: FontWeight.w600,
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            flex: 2,
            child: _DeviceList(
              devices: devices,
              activeSerial: activeSerial ?? '',
              onSelectDevice: onSelectDevice,
              onScan: onQuickAction == null
                  ? null
                  : () => onQuickAction!('wireless'),
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
    this.onScan,
  });

  final List<SavedDevice> devices;
  final String activeSerial;
  final void Function(String serial)? onSelectDevice;
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (devices.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.phone_android, size: 32, color: palette.textDisabled),
          const SizedBox(height: AppSpacing.sm),
          Text(
            tr('noDevices'),
            style: TextStyle(
              fontSize: AppFontSize.body,
              color: palette.textDisabled,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            tr('noDevicesHint'),
            style: TextStyle(
              fontSize: AppFontSize.md,
              color: palette.textDisabled,
            ),
            textAlign: TextAlign.center,
          ),
          if (onScan != null) ...[
            const SizedBox(height: AppSpacing.md),
            _HeroCtaButton(
              label: tr('wirelessScan'),
              filled: true,
              enabled: true,
              onTap: onScan!,
              width: 140,
            ),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.separated(
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
                                  fontWeight: active
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: palette.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                d.serial,
                                style: TextStyle(
                                  fontSize: AppFontSize.md,
                                  fontFamily: 'Noto Sans Mono',
                                  color: palette.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: d.isConnected
                                ? palette.accent.withValues(alpha: 0.14)
                                : palette.raised,
                            borderRadius:
                                BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            d.isConnected ? tr('online') : tr('offline'),
                            style: TextStyle(
                              fontSize: AppFontSize.xs,
                              fontWeight: FontWeight.w500,
                              color: d.isConnected
                                  ? palette.accent
                                  : palette.textDisabled,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (onScan != null) ...[
          const SizedBox(height: AppSpacing.md),
          _HeroCtaButton(
            label: tr('wirelessScan'),
            filled: false,
            enabled: true,
            onTap: onScan!,
          ),
        ],
      ],
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.access_time,
              size: 24,
              color: palette.textDisabled,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              tr('noRecentActivity'),
              style: TextStyle(
                fontSize: AppFontSize.md,
                color: palette.textDisabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
