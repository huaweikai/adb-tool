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
import '../design/design_tokens.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import '../widgets/sparkline.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    context.watch<DeviceSerialScope>();
    context.watch<LocaleProvider>();
    if (_selectedSerial == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monitor_heart_outlined,
                size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(tr('selectDeviceSidebar'),
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final status = _status;
    final error = _error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(context, status: status, error: error),
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

  Widget _buildToolbar(
    BuildContext context, {
    required DeviceStatus? status,
    required String? error,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            tr('monitorTitle'),
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          FilledButton.tonalIcon(
            onPressed: _loading ? null : () => _loadStatus(),
            icon: _loading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 16),
            label: Text(tr('refresh')),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: _autoRefresh,
                onChanged: (v) => setState(() => _autoRefresh = v ?? true),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              Text(tr('monitorAutoRefresh'),
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
          if (status?.collectedAt.isNotEmpty == true)
            Text(
              '${tr('monitorLastUpdated')}: ${status?.collectedAt ?? ''}',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (error != null && status != null)
            Text(
              error,
              style: TextStyle(fontSize: 11, color: theme.colorScheme.error),
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
            // Summary header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xs),
                child: _buildSummaryHeader(context, status),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: columns,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childCount: 10,
                itemBuilder: (context, index) =>
                    _buildDashboardItem(context, status, index),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
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
    final theme = Theme.of(context);
    final deviceProvider = context.read<DeviceProvider>();
    final serial = _selectedSerial;
    final device = serial != null
        ? deviceProvider.savedDevices
            .where((d) => d.serial == serial)
            .firstOrNull
        : null;
    final healthOk = status.thermalStatus.toLowerCase().contains('cool') ||
        status.thermalStatus.toLowerCase().contains('normal');

    // Gather summary chips
    final chips = <Widget>[
      _summaryChip(theme, Icons.phone_android, device?.displayName ?? serial ?? '--'),
      if (status.resolution.isNotEmpty)
        _summaryChip(theme, Icons.aspect_ratio, status.resolution),
      if (status.uptime.isNotEmpty)
        _summaryChip(theme, Icons.timer_outlined, status.uptime),
      if (status.batteryStatus.isNotEmpty)
        _summaryChip(theme, Icons.battery_charging_full, status.batteryStatus),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Icon(Icons.monitor_heart_outlined,
              size: 16, color: theme.colorScheme.primary),
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
          // Health status dot
          Tooltip(
            message: status.thermalStatus.isNotEmpty
                ? '${tr('monitorThermalStatus')}: ${status.thermalStatus}'
                : '',
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: healthOk ? Colors.green : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(
      ThemeData theme, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: TextStyle(
            fontSize: AppFontSize.body,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildDashboardItem(
    BuildContext context,
    DeviceStatus status,
    int index,
  ) {
    final cpuPct = _parsePercent(status.cpuUsage) / 100;
    final memPct = _parsePercent(status.memoryUsedPercent) / 100;
    final battPct = _parsePercent(status.batteryLevel) / 100;

    switch (index) {
      case 0:
        return _metricCard(context, tr('monitorBattery'), Icons.battery_full,
            _value(status.batteryLevel, suffix: '%'),
            subtitle: _join([status.batteryStatus, status.batteryTemperature]),
            progress: battPct,
            warningThreshold: 0.3,
            criticalThreshold: 0.15);
      case 1:
        return _metricCard(context, tr('monitorCpuUsage'), Icons.memory,
            _value(status.cpuUsage),
            subtitle: '${tr('monitorCpuLoad')}: ${_value(status.cpuLoad)}',
            progress: cpuPct,
            warningThreshold: 0.5,
            criticalThreshold: 0.8,
            sparkline: _cpuHistory);
      case 2:
        return _metricCard(context, tr('monitorMemory'), Icons.storage,
            _value(status.memoryUsedPercent),
            subtitle:
                '${tr('monitorAvailable')}: ${_value(status.memoryAvailable)} / ${_value(status.memoryTotal)}',
            progress: memPct,
            warningThreshold: 0.5,
            criticalThreshold: 0.8,
            sparkline: _memHistory);
      case 3:
        return _metricCard(context, tr('monitorStorage'), Icons.folder_outlined,
            _value(status.storageUsedPercent),
            subtitle:
                '${_value(status.storageUsed)} / ${_value(status.storageTotal)}',
            progress: _parsePercent(status.storageUsedPercent) / 100);
      case 4:
        return _pairedCard(context, tr('monitorScreenAndFrames'),
            Icons.screenshot_monitor_outlined, [
          _PairItem(
              tr('monitorResolution'), status.resolution, Icons.aspect_ratio),
          _PairItem(tr('monitorDensity'), status.density, Icons.density_medium),
        ]);
      case 5:
        return _pairedCard(context, tr('monitorDisplay'), Icons.refresh, [
          _PairItem(
              tr('monitorRefreshRate'), status.refreshRate, Icons.refresh),
          _PairItem(tr('monitorFrameStats'), status.frameStats, Icons.speed),
        ]);
      case 6:
        return _pairedCard(
            context, tr('monitorNetworkSignal'), Icons.network_wifi, [
          _PairItem(tr('monitorNetworkType'), status.networkType, Icons.wifi),
          _PairItem(tr('monitorWifiSsid'), status.wifiSsid, Icons.wifi_find),
        ]);
      case 7:
        return _pairedCard(
            context, tr('monitorSignal'), Icons.signal_cellular_alt, [
          _PairItem(tr('monitorWifiRssi'), status.wifiRssi,
              Icons.signal_wifi_statusbar_4_bar),
          _PairItem(tr('monitorMobileSignal'), status.mobileSignal,
              Icons.signal_cellular_alt),
        ]);
      case 8:
        return _pairedCard(
            context, tr('monitorNetworkAndUptime'), Icons.language, [
          _PairItem(tr('monitorIpAddress'), status.ipAddress, Icons.language),
          _PairItem(tr('monitorUptime'), status.uptime, Icons.timer_outlined),
        ]);
      case 9:
        return _pairedCard(context, tr('monitorSystemHealth'),
            Icons.health_and_safety_outlined, [
          _PairItem(tr('monitorThermalStatus'), status.thermalStatus,
              Icons.thermostat),
          _PairItem(tr('monitorCpuLoad'), status.cpuLoad, Icons.show_chart),
        ]);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _pairedCard(
    BuildContext context,
    String title,
    IconData icon,
    List<_PairItem> items,
  ) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...items.map((item) => _pairedRow(context, item)),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _pairedRow(BuildContext context, _PairItem item) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(item.icon,
              size: 14, color: theme.colorScheme.primary.withAlpha(180)),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(item.label,
                style: TextStyle(
                    fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: _tappableValue(context, item.value),
          ),
        ],
      ),
    );
  }

  Widget _tappableValue(BuildContext context, String value) {
    final display = _value(value);
    return GestureDetector(
      onTap: value.trim().isNotEmpty
          ? () => _showValueDetail(context, display)
          : null,
      child: Text(
        display,
        style: const TextStyle(
            fontSize: 11, fontFamily: 'Menlo', fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _showValueDetail(BuildContext context, String value) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20),
                    const SizedBox(width: 8),
                    Text(tr('monitorDetailTitle'),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(value,
                      style:
                          const TextStyle(fontSize: 13, fontFamily: 'Menlo')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _metricCard(
    BuildContext context,
    String title,
    IconData icon,
    String value, {
    String subtitle = '',
    double progress = -1,
    double? warningThreshold,
    double? criticalThreshold,
    List<double>? sparkline,
  }) {
    final theme = Theme.of(context);
    final hasProgress = progress >= 0;

    // Threshold-based left border color
    Color borderColor = Colors.transparent;
    if (hasProgress && progress >= 0) {
      if (criticalThreshold != null && progress >= criticalThreshold) {
        borderColor = theme.colorScheme.error;
      } else if (warningThreshold != null && progress >= warningThreshold) {
        borderColor = Colors.orange;
      } else if (warningThreshold != null) {
        borderColor = Colors.green;
      }
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: borderColor != Colors.transparent
            ? BoxDecoration(
                border: Border(left: BorderSide(width: 3, color: borderColor)),
              )
            : null,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
            if (hasProgress) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      _heatColor(progress * 100, theme)),
                ),
              ),
            ],
            // Sparkline
            if (sparkline != null && sparkline.length >= 2) ...[
              const SizedBox(height: AppSpacing.sm),
              Sparkline(
                data: sparkline,
                height: 24,
                color: borderColor != Colors.transparent
                    ? borderColor
                    : theme.colorScheme.primary,
                showArea: true,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              subtitle.isEmpty ? tr('unknown') : subtitle,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcesses(BuildContext context, List<ProcessStatus> processes) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.format_list_numbered,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(tr('monitorTopProcesses'),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            if (processes.isEmpty)
              Text(tr('monitorNoData'),
                  style: TextStyle(
                      fontSize: 12, color: theme.colorScheme.onSurfaceVariant))
            else
              ...processes
                  .asMap()
                  .entries
                  .map((e) => _buildProcessCard(context, e.key, e.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessCard(
      BuildContext context, int index, ProcessStatus process) {
    final theme = Theme.of(context);
    final cpuNum = _parsePercent(process.cpu);
    final memNum = _parsePercent(process.memory);
    final displayName =
        process.name.isNotEmpty ? process.name : process.command;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
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
                  color: theme.colorScheme.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  displayName,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Menlo'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('PID ${process.pid}',
                  style: TextStyle(
                      fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 36,
                child: Text('CPU',
                    style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (cpuNum / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        _heatColor(cpuNum, theme)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 42,
                child: Text(
                  process.cpu.isEmpty ? '--' : process.cpu,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Menlo',
                    color: _heatColor(cpuNum, theme),
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 36,
                child: Text('MEM',
                    style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (memNum / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        _heatColor(memNum, theme)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 42,
                child: Text(
                  process.memory.isEmpty ? '--' : process.memory,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Menlo',
                    color: _heatColor(memNum, theme),
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _parsePercent(String value) {
    final cleaned = value.replaceAll('%', '').trim();
    final parsed = double.tryParse(cleaned);
    return parsed ?? 0;
  }

  Color _heatColor(double value, ThemeData theme) {
    if (value >= 50) return Colors.red;
    if (value >= 25) return Colors.orange;
    if (value >= 10) return Colors.amber.shade700;
    return theme.colorScheme.primary;
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

class _PairItem {
  final String label;
  final String value;
  final IconData icon;

  const _PairItem(this.label, this.value, this.icon);
}
