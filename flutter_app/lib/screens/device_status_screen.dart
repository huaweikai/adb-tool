import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import '../i18n.dart';
import '../models/device_status.dart';
import '../providers/device_provider.dart';
import '../providers/locale_provider.dart';
import '../services/api_client.dart';
import '../db/database.dart';
import '../design/app_palette.dart';
import '../design/design_tokens.dart';
import '../design/key_value_card.dart';
import '../design/metric_card.dart';
import '../design/panel.dart';
import '../design/section_label.dart';
import '../design/status_badge.dart';
import '../design/topbar.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';

/// Device status monitor — the design-system exemplar page.
///
/// Composed entirely from `lib/design/` shells (AppTopbar / AppPanel /
/// AppSectionLabel / AppStatusBadge) and the data cards extracted from this
/// page's former private `_metricCard` / `_pairedCard` (AppMetricCard /
/// AppKeyValueCard). Every reading, control and failure state the legacy
/// page offered is preserved: auto-refresh + manual refresh, last-updated
/// stamp, threshold tinting, sparkline history, tappable value detail sheet
/// and the top-process list.
class DeviceStatusScreen extends StatefulWidget {
  const DeviceStatusScreen({super.key});

  @override
  State<DeviceStatusScreen> createState() => _DeviceStatusScreenState();
}

class _DeviceStatusScreenState extends State<DeviceStatusScreen> {
  /// Stable device identity (ro.serialno). Survives reconnects —
  /// handed to `ApiClient` directly; the API boundary resolves
  /// it to the current adb address on demand.
  String? get _selectedSerial => context.read<DeviceSerialScope>().serial;
  bool _isActive({bool listen = false}) {
    try {
      return Provider.of<DeviceScreenActiveScope>(context, listen: listen)
          .active;
    } on ProviderNotFoundException {
      return true;
    }
  }

  DeviceStatus? _status;
  Timer? _timer;
  bool _loading = false;
  bool _disposed = false;
  bool _wasActive = false;
  bool _autoRefresh = true;
  String? _error;
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 3;
  static const int _maxHistory = 30;

  final List<double> _cpuHistory = [];
  final List<double> _memHistory = [];
  final List<double> _batteryHistory = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isActive()) return;
      _loadStatus();
      _startTimer();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = _isActive(listen: true);
    if (active) {
      _startTimer();
      if (!_wasActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isActive() && !_loading) {
            _loadStatus(silent: _status != null);
          }
        });
      }
    } else {
      _stopTimer();
    }
    _wasActive = active;
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTimer();
    super.dispose();
  }

  void _startTimer() {
    if (_timer != null || _disposed) return;
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_autoRefresh && !_loading && _isActive()) {
        _loadStatus(silent: true);
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _loadStatus({bool silent = false}) async {
    if (_loading || (silent && !_isActive())) return;
    final stable = _selectedSerial;
    if (stable == null) {
      setState(() => _error = tr('selectDevice'));
      return;
    }
    final api = context.read<ApiClient>();
    setState(() {
      _loading = true;
      if (!silent) {
        _error = null;
      }
    });
    try {
      final status = await api.getDeviceStatus(stable);
      if (!mounted) return;
      _consecutiveErrors = 0;
      _pushHistory(status);
      setState(() {
        _status = status;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      _consecutiveErrors++;
      final autoRefreshDisabled = _consecutiveErrors >= _maxConsecutiveErrors;
      setState(() {
        _error = e.toString();
        _loading = false;
        if (autoRefreshDisabled) {
          _autoRefresh = false;
        }
      });
    }
  }

  void _pushHistory(DeviceStatus status) {
    final cpu = _parsePercent(status.cpuUsage) / 100;
    if (cpu > 0) {
      _cpuHistory.add(cpu.clamp(0.0, 1.0));
      if (_cpuHistory.length > _maxHistory) _cpuHistory.removeAt(0);
    }
    final mem = _parsePercent(status.memoryUsedPercent) / 100;
    if (mem > 0) {
      _memHistory.add(mem.clamp(0.0, 1.0));
      if (_memHistory.length > _maxHistory) _memHistory.removeAt(0);
    }
    final batt = _parsePercent(status.batteryLevel) / 100;
    if (batt > 0) {
      _batteryHistory.add(batt.clamp(0.0, 1.0));
      if (_batteryHistory.length > _maxHistory) _batteryHistory.removeAt(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<DeviceSerialScope>();
    context.watch<LocaleProvider>();
    if (_selectedSerial == null) {
      return EmptyState(
        icon: Icons.monitor_heart_outlined,
        title: tr('monitorTitle'),
        subtitle: tr('selectDeviceSidebar'),
      );
    }

    final status = _status;
    final error = _error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTopbar(context, status: status, error: error),
        if (_loading && status == null)
          const Expanded(child: LoadingView())
        else if (error != null && status == null)
          Expanded(
            child: ErrorView(
              message: error,
              onRetry: _loadStatus,
              retryLabel: tr('retry'),
            ),
          )
        else
          Expanded(child: _buildDashboard(context)),
      ],
    );
  }

  Widget _buildTopbar(
    BuildContext context, {
    required DeviceStatus? status,
    required String? error,
  }) {
    final palette = context.palette;
    final serial = _selectedSerial;
    final device = serial != null
        ? context
            .read<DeviceProvider>()
            .savedDevices
            .where((d) => d.serial == serial)
            .firstOrNull
        : null;
    final online = device?.isConnected ?? false;

    return AppTopbar(
      title: tr('monitorTitle'),
      subtitle: AppStatusBadge(
        label: device?.displayName ?? serial ?? '--',
        color: online ? palette.online : palette.red,
      ),
      actions: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error != null && status != null) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Text(
                error,
                style: TextStyle(fontSize: AppFontSize.md, color: palette.red),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          if (status?.collectedAt.isNotEmpty == true) ...[
            Text(
              '${tr('monitorLastUpdated')}: ${status?.collectedAt ?? ''}',
              style: TextStyle(
                fontSize: AppFontSize.md,
                color: palette.textDisabled,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: _autoRefresh,
                onChanged: (v) => setState(() => _autoRefresh = v),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Text(
                tr('monitorAutoRefresh'),
                style: TextStyle(
                  fontSize: AppFontSize.md,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          if (_loading)
            const SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            AppTopbarIconButton(
              icon: Icons.refresh,
              tooltip: tr('refresh'),
              onPressed: _loadStatus,
            ),
        ],
      ),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    final status = _status;
    if (status == null) {
      return Center(child: Text(tr('monitorNoData')));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _gridColumns(constraints.maxWidth, maxColumns: 4);
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.sm),
                child: _buildSummaryHeader(context, status),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.sm),
              sliver: SliverToBoxAdapter(child: AppSectionLabel(tr('monitorLiveMetrics'))),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.md),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: columns,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childCount: 4,
                itemBuilder: (context, index) =>
                    _metricCards(context, status)[index],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.sm),
              sliver: SliverToBoxAdapter(child: AppSectionLabel(tr('monitorDeviceDetails'))),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.md),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: columns,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childCount: 6,
                itemBuilder: (context, index) =>
                    _keyValueCards(context, status)[index],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xl),
              sliver: SliverToBoxAdapter(
                child: _buildProcesses(context, status.topProcesses),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryHeader(BuildContext context, DeviceStatus status) {
    final palette = context.palette;
    final deviceProvider = context.read<DeviceProvider>();
    final serial = _selectedSerial;
    final device = serial != null
        ? deviceProvider.savedDevices
            .where((d) => d.serial == serial)
            .firstOrNull
        : null;
    final healthOk = status.thermalStatus.toLowerCase().contains('cool') ||
        status.thermalStatus.toLowerCase().contains('normal');

    final chips = <Widget>[
      _summaryChip(palette, Icons.phone_android,
          device?.displayName ?? serial ?? '--'),
      if (status.resolution.isNotEmpty)
        _summaryChip(palette, Icons.aspect_ratio, status.resolution),
      if (status.uptime.isNotEmpty)
        _summaryChip(palette, Icons.timer_outlined, status.uptime),
      if (status.batteryStatus.isNotEmpty)
        _summaryChip(palette, Icons.battery_charging_full, status.batteryStatus),
    ];

    return AppPanel(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(Icons.monitor_heart_outlined, size: 16, color: palette.accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: chips
                    .map((c) => Padding(
                          padding:
                              const EdgeInsets.only(right: AppSpacing.md),
                          child: c,
                        ))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Tooltip(
            message: status.thermalStatus.isNotEmpty
                ? '${tr('monitorThermalStatus')}: ${status.thermalStatus}'
                : '',
            child: AppStatusBadge(
              label: status.thermalStatus.isNotEmpty
                  ? status.thermalStatus
                  : tr('monitorSystemHealth'),
              color: healthOk ? palette.online : palette.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(AppPalette palette, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: palette.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: TextStyle(
            fontSize: AppFontSize.body,
            color: palette.textSecondary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  List<Widget> _metricCards(BuildContext context, DeviceStatus status) {
    final cpuPct = _parsePercent(status.cpuUsage) / 100;
    final memPct = _parsePercent(status.memoryUsedPercent) / 100;
    final battPct = _parsePercent(status.batteryLevel) / 100;
    return [
      AppMetricCard(
        title: tr('monitorBattery'),
        icon: Icons.battery_full,
        value: _value(status.batteryLevel, suffix: '%'),
        subtitle: _join([status.batteryStatus, status.batteryTemperature]),
        progress: battPct,
        warningThreshold: 0.3,
        criticalThreshold: 0.15,
        invertedThresholds: true,
        sparkline: _batteryHistory,
      ),
      AppMetricCard(
        title: tr('monitorCpuUsage'),
        icon: Icons.memory,
        value: _value(status.cpuUsage),
        subtitle: '${tr('monitorCpuLoad')}: ${_value(status.cpuLoad)}',
        progress: cpuPct,
        warningThreshold: 0.5,
        criticalThreshold: 0.8,
        sparkline: _cpuHistory,
      ),
      AppMetricCard(
        title: tr('monitorMemory'),
        icon: Icons.storage,
        value: _value(status.memoryUsedPercent),
        subtitle:
            '${tr('monitorAvailable')}: ${_value(status.memoryAvailable)} / ${_value(status.memoryTotal)}',
        progress: memPct,
        warningThreshold: 0.5,
        criticalThreshold: 0.8,
        sparkline: _memHistory,
      ),
      AppMetricCard(
        title: tr('monitorStorage'),
        icon: Icons.folder_outlined,
        value: _value(status.storageUsedPercent),
        subtitle:
            '${_value(status.storageUsed)} / ${_value(status.storageTotal)}',
        progress: _parsePercent(status.storageUsedPercent) / 100,
      ),
    ];
  }

  List<Widget> _keyValueCards(BuildContext context, DeviceStatus status) {
    AppKeyValueItem item(String label, String raw, IconData icon) {
      final display = _value(raw);
      return AppKeyValueItem(
        label: label,
        value: display,
        icon: icon,
        onTap: raw.trim().isNotEmpty
            ? () => _showValueDetail(context, display)
            : null,
      );
    }

    return [
      AppKeyValueCard(
        title: tr('monitorScreenAndFrames'),
        icon: Icons.screenshot_monitor_outlined,
        items: [
          item(tr('monitorResolution'), status.resolution, Icons.aspect_ratio),
          item(tr('monitorDensity'), status.density, Icons.density_medium),
        ],
      ),
      AppKeyValueCard(
        title: tr('monitorDisplay'),
        icon: Icons.refresh,
        items: [
          item(tr('monitorRefreshRate'), status.refreshRate, Icons.refresh),
          item(tr('monitorFrameStats'), status.frameStats, Icons.speed),
        ],
      ),
      AppKeyValueCard(
        title: tr('monitorNetworkSignal'),
        icon: Icons.network_wifi,
        items: [
          item(tr('monitorNetworkType'), status.networkType, Icons.wifi),
          item(tr('monitorWifiSsid'), status.wifiSsid, Icons.wifi_find),
        ],
      ),
      AppKeyValueCard(
        title: tr('monitorSignal'),
        icon: Icons.signal_cellular_alt,
        items: [
          item(tr('monitorWifiRssi'), status.wifiRssi,
              Icons.signal_wifi_statusbar_4_bar),
          item(tr('monitorMobileSignal'), status.mobileSignal,
              Icons.signal_cellular_alt),
        ],
      ),
      AppKeyValueCard(
        title: tr('monitorNetworkAndUptime'),
        icon: Icons.language,
        items: [
          item(tr('monitorIpAddress'), status.ipAddress, Icons.language),
          item(tr('monitorUptime'), status.uptime, Icons.timer_outlined),
        ],
      ),
      AppKeyValueCard(
        title: tr('monitorSystemHealth'),
        icon: Icons.health_and_safety_outlined,
        items: [
          item(tr('monitorThermalStatus'), status.thermalStatus,
              Icons.thermostat),
          item(tr('monitorCpuLoad'), status.cpuLoad, Icons.show_chart),
        ],
      ),
    ];
  }

  void _showValueDetail(BuildContext context, String value) {
    final palette = context.palette;
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.panel,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 18, color: palette.accent),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: AppSectionLabel(tr('monitorDetailTitle'))),
                    AppTopbarIconButton(
                      icon: Icons.close,
                      tooltip: tr('close'),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppPanel(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  color: palette.raised,
                  child: SelectableText(
                    value,
                    style: TextStyle(
                      fontSize: AppFontSize.subtitle,
                      fontFamily: 'Noto Sans Mono',
                      color: palette.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProcesses(BuildContext context, List<ProcessStatus> processes) {
    final palette = context.palette;
    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_list_numbered,
                  size: 16, color: palette.accent),
              const SizedBox(width: AppSpacing.xs),
              AppSectionLabel(tr('monitorTopProcesses')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (processes.isEmpty)
            Text(tr('monitorNoData'),
                style: TextStyle(
                    fontSize: AppFontSize.body, color: palette.textDisabled))
          else
            ...processes
                .asMap()
                .entries
                .map((e) => _buildProcessCard(context, e.key, e.value)),
        ],
      ),
    );
  }

  Widget _buildProcessCard(
      BuildContext context, int index, ProcessStatus process) {
    final palette = context.palette;
    final cpuNum = _parsePercent(process.cpu);
    final memNum = _parsePercent(process.memory);
    final displayName =
        process.name.isNotEmpty ? process.name : process.command;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm, horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: palette.raised,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.activeNav,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: AppFontSize.sm,
                      fontWeight: FontWeight.w700,
                      color: palette.accent,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    displayName,
                    style: TextStyle(
                        fontSize: AppFontSize.body,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Noto Sans Mono',
                        color: palette.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('PID ${process.pid}',
                    style: TextStyle(
                        fontSize: AppFontSize.sm,
                        color: palette.textDisabled)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text('CPU',
                      style: TextStyle(
                          fontSize: AppFontSize.sm,
                          color: palette.textDisabled)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    child: LinearProgressIndicator(
                      value: (cpuNum / 100).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: palette.panel,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          _heatColor(cpuNum, palette)),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                SizedBox(
                  width: 42,
                  child: Text(
                    process.cpu.isEmpty ? '--' : process.cpu,
                    style: TextStyle(
                      fontSize: AppFontSize.md,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Noto Sans Mono',
                      color: _heatColor(cpuNum, palette),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 36,
                  child: Text('MEM',
                      style: TextStyle(
                          fontSize: AppFontSize.sm,
                          color: palette.textDisabled)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    child: LinearProgressIndicator(
                      value: (memNum / 100).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: palette.panel,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          _heatColor(memNum, palette)),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                SizedBox(
                  width: 42,
                  child: Text(
                    process.memory.isEmpty ? '--' : process.memory,
                    style: TextStyle(
                      fontSize: AppFontSize.md,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Noto Sans Mono',
                      color: _heatColor(memNum, palette),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _parsePercent(String value) {
    final cleaned = value.replaceAll('%', '').trim();
    final parsed = double.tryParse(cleaned);
    return parsed ?? 0;
  }

  Color _heatColor(double value, AppPalette palette) {
    if (value >= 50) return palette.red;
    if (value >= 25) return palette.orange;
    return palette.accent;
  }

  int _gridColumns(double width, {required int maxColumns}) {
    if (width >= 1100) return maxColumns;
    if (width >= 760) return maxColumns >= 3 ? 3 : maxColumns;
    if (width >= 520) return maxColumns >= 2 ? 2 : maxColumns;
    return 1;
  }

  String _value(String value, {String suffix = ''}) {
    if (value.trim().isEmpty) return tr('unknown');
    if (suffix.isNotEmpty && !value.endsWith(suffix)) return '$value$suffix';
    return value;
  }

  String _join(List<String> values) {
    return values.where((e) => e.trim().isNotEmpty).join(' · ');
  }
}
