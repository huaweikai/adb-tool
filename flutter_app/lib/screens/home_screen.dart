import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device.dart';
import '../services/api_client.dart';
import '../providers/theme_provider.dart';
import '../providers/device_provider.dart';
import '../providers/locale_provider.dart';
import '../i18n.dart';
import 'device_status_screen.dart';
import 'logcat_screen.dart';
import 'file_browser_screen.dart';
import 'app_manager_screen.dart';
import 'device_info_screen.dart';
import 'clipboard_screen.dart';
import 'backend_log_screen.dart';
import 'adb_command_screen.dart';

enum NavItem { status, logcat, files, apps, info, clipboard, command }

const _navConfig = {
  NavItem.status: _NavConfig(Icons.phone_android, 'status'),
  NavItem.logcat: _NavConfig(Icons.list_alt, 'logcat'),
  NavItem.files: _NavConfig(Icons.folder_open, 'files'),
  NavItem.apps: _NavConfig(Icons.android, 'apps'),
  NavItem.info: _NavConfig(Icons.info_outline, 'info'),
  NavItem.clipboard: _NavConfig(Icons.content_paste, 'clipboard'),
  NavItem.command: _NavConfig(Icons.terminal, 'command'),
};

class _NavConfig {
  final IconData icon;
  final String label;
  const _NavConfig(this.icon, this.label);
}

const _backendLogKey = '_backend_logs';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onShutdown;
  final VoidCallback? onRestart;

  const HomeScreen({
    super.key,
    this.onShutdown,
    this.onRestart,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _refreshTimer;

  final Set<String> _expandedSerials = {};
  final Map<String, Widget> _screens = {};
  String? _activeKey;

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiClient>();
    context.read<DeviceProvider>().refresh(api);
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      context.read<DeviceProvider>().refresh(context.read<ApiClient>());
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String navLabel(NavItem item) {
    final c = _navConfig[item]!;
    return tr(c.label);
  }

  void _toggleExpand(String serial) {
    setState(() {
      if (_expandedSerials.contains(serial)) {
        _expandedSerials.remove(serial);
      } else {
        _expandedSerials.add(serial);
        if (_screens.isEmpty) {
          _navigateTo(serial, NavItem.status);
        }
      }
    });
  }

  static const int _maxCachedScreens = 20;

  void _navigateTo(String serial, NavItem item) {
    context.read<DeviceProvider>().select(serial);
    final key = '${serial}_${item.name}';
    if (!_screens.containsKey(key)) {
      Widget screen;
      switch (item) {
        case NavItem.status:
          screen = Provider<DeviceSerialScope>.value(
              value: DeviceSerialScope(serial), child: const DeviceStatusScreen());
        case NavItem.logcat:
          screen = Provider<DeviceSerialScope>.value(
              value: DeviceSerialScope(serial), child: const LogcatScreen());
        case NavItem.files:
          screen = Provider<DeviceSerialScope>.value(
              value: DeviceSerialScope(serial),
              child: const FileBrowserScreen());
        case NavItem.apps:
          screen = Provider<DeviceSerialScope>.value(
              value: DeviceSerialScope(serial),
              child: const AppManagerScreen());
        case NavItem.info:
          screen = Provider<DeviceSerialScope>.value(
              value: DeviceSerialScope(serial),
              child: const DeviceInfoScreen());
        case NavItem.clipboard:
          screen = Provider<DeviceSerialScope>.value(
              value: DeviceSerialScope(serial), child: const ClipboardScreen());
        case NavItem.command:
          screen = Provider<DeviceSerialScope>.value(
              value: DeviceSerialScope(serial),
              child: const AdbCommandScreen());
      }
      _screens[key] = screen;
      _evictCache();
    }
    setState(() => _activeKey = key);
  }

  void _evictCache() {
    if (_screens.length <= _maxCachedScreens) return;
    final toRemove = _screens.length - _maxCachedScreens;
    final keys = _screens.keys.toList();
    int removed = 0;
    for (final k in keys) {
      if (removed >= toRemove) break;
      if (k == _activeKey || k == _backendLogKey) continue;
      _screens.remove(k);
      removed++;
    }
  }

  void _openBackendLogs() {
    if (!_screens.containsKey(_backendLogKey)) {
      _screens[_backendLogKey] = const BackendLogScreen();
    }
    setState(() => _activeKey = _backendLogKey);
  }

  @override
  Widget build(BuildContext context) {
    final deviceProvider = context.watch<DeviceProvider>();
    context.watch<LocaleProvider>();
    final devices = deviceProvider.devices;
    final backendOnline = deviceProvider.online;

    return Scaffold(
      body: Column(
        children: [
          if (!backendOnline) _buildOfflineBanner(context),
          Expanded(
            child: Row(
              children: [
                _buildSidebar(context, devices, backendOnline),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_activeKey == null || !_screens.containsKey(_activeKey)) {
      final theme = Theme.of(context);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.android,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant.withAlpha(60)),
            const SizedBox(height: 16),
            Text(tr('welcome'),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return Stack(
      children: _screens.entries.map((entry) {
        return Offstage(
          offstage: entry.key != _activeKey,
          child: SizedBox.expand(child: entry.value),
        );
      }).toList(),
    );
  }

  Widget _buildSidebar(
      BuildContext context, List<Device> devices, bool online) {
    final theme = Theme.of(context);
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(right: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme),
          const Divider(height: 1),
          Expanded(child: _buildDeviceTree(theme, devices)),
          const Divider(height: 1),
          _buildBackendLogsEntry(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final deviceProvider = context.read<DeviceProvider>();
    final api = context.read<ApiClient>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.adb, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('ADB Tool',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              GestureDetector(
                onTap: () => context.read<LocaleProvider>().toggle(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                      context.read<LocaleProvider>().currentLang == 'zh'
                          ? 'EN'
                          : '文',
                      style: const TextStyle(fontSize: 10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _headerAction(
                theme,
                icon: Icons.sync,
                label: tr('refresh'),
                onTap: () => deviceProvider.refresh(api),
              ),
              _headerAction(
                theme,
                icon: Icons.wifi_tethering,
                label: tr('wirelessAdb'),
                onTap: _showWirelessAdbDialog,
              ),
              if (widget.onRestart != null)
                _headerAction(
                  theme,
                  icon: Icons.refresh,
                  label: tr('restart'),
                  onTap: () {
                    widget.onRestart!();
                    _clearAllState();
                  },
                ),
              if (widget.onShutdown != null)
                _headerAction(
                  theme,
                  icon: Icons.power_settings_new,
                  label: tr('shutdown'),
                  color: theme.colorScheme.error,
                  onTap: () => _confirmShutdown(context),
                ),
              _headerAction(
                theme,
                icon: Icons.brightness_6,
                label: tr('theme'),
                onTap: () => context.read<ThemeProvider>().toggle(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerAction(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final foreground = color ?? theme.colorScheme.onSurfaceVariant;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: foreground),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(fontSize: 11, color: foreground)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineBanner(BuildContext context) {
    final theme = Theme.of(context);
    final api = context.read<ApiClient>();
    final deviceProvider = context.read<DeviceProvider>();

    return MaterialBanner(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      backgroundColor: theme.colorScheme.errorContainer,
      leading: Icon(Icons.cloud_off, color: theme.colorScheme.onErrorContainer),
      content: Text(
        tr('backendOffline'),
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => deviceProvider.refresh(api),
          child: Text(tr('refresh'),
              style: TextStyle(
                  fontSize: 12, color: theme.colorScheme.onErrorContainer)),
        ),
      ],
    );
  }

  void _clearAllState() {
    _refreshTimer?.cancel();
    _screens.clear();
    _expandedSerials.clear();
    _activeKey = null;
    context.read<DeviceProvider>().select(null);
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      context.read<DeviceProvider>().refresh(context.read<ApiClient>());
    });
  }

  Future<void> _showWirelessAdbDialog() async {
    final pairAddressCtrl = TextEditingController();
    final pairCodeCtrl = TextEditingController();
    final connectAddressCtrl = TextEditingController();
    var running = false;
    String? result;
    final api = context.read<ApiClient>();
    final deviceProvider = context.read<DeviceProvider>();

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> runAction(
                Future<AdbCommandResult> Function() action) async {
              setDialogState(() {
                running = true;
                result = null;
              });
              try {
                final res = await action();
                setDialogState(() {
                  result = res.ok
                      ? (res.output.isEmpty ? 'OK' : res.output)
                      : (res.error.isEmpty ? res.output : res.error);
                });
                if (res.ok) deviceProvider.refresh(api);
              } catch (e) {
                setDialogState(() => result = e.toString());
              } finally {
                setDialogState(() => running = false);
              }
            }

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.wifi_tethering, size: 22),
                  const SizedBox(width: 8),
                  Text(tr('wirelessAdb')),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: pairAddressCtrl,
                      enabled: !running,
                      decoration: InputDecoration(
                        labelText: tr('pairAddress'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: pairCodeCtrl,
                      enabled: !running,
                      decoration: InputDecoration(
                        labelText: tr('pairCode'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonalIcon(
                        onPressed: running
                            ? null
                            : () => runAction(() => api.pairWirelessAdb(
                                  pairAddressCtrl.text.trim(),
                                  pairCodeCtrl.text.trim(),
                                )),
                        icon: const Icon(Icons.link, size: 16),
                        label: Text(tr('pair')),
                      ),
                    ),
                    const Divider(height: 28),
                    TextField(
                      controller: connectAddressCtrl,
                      enabled: !running,
                      decoration: InputDecoration(
                        labelText: tr('connectAddress'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: running
                            ? null
                            : () => runAction(() => api.connectWirelessAdb(
                                  connectAddressCtrl.text.trim(),
                                )),
                        icon: const Icon(Icons.wifi, size: 16),
                        label: Text(tr('connect')),
                      ),
                    ),
                    if (running) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(tr('running')),
                        ],
                      ),
                    ],
                    if (result != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          result!,
                          style: const TextStyle(
                              fontSize: 12, fontFamily: 'Menlo'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      running ? null : () => Navigator.pop(dialogContext),
                  child: Text(tr('close')),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      pairAddressCtrl.dispose();
      pairCodeCtrl.dispose();
      connectAddressCtrl.dispose();
    }
  }

  void _confirmShutdown(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('confirmShutdown')),
        content: Text(tr('shutdownHint')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clearAllState();
              widget.onShutdown!();
            },
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(tr('shutdown')),
          ),
        ],
      ),
    );
  }

  Widget _buildBackendLogsEntry(ThemeData theme) {
    final isActive = _activeKey == _backendLogKey;
    return Material(
      color: isActive ? theme.colorScheme.primaryContainer : Colors.transparent,
      child: InkWell(
        onTap: _openBackendLogs,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.terminal,
                  size: 16,
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Text(
                tr('backendLogs'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Go', style: TextStyle(fontSize: 9)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceTree(ThemeData theme, List<Device> devices) {
    if (devices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.phone_android,
                  size: 40,
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(100)),
              const SizedBox(height: 8),
              Text(tr('noDevices'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(tr('noDevicesHint'),
                  style: TextStyle(
                      fontSize: 10,
                      color:
                          theme.colorScheme.onSurfaceVariant.withAlpha(150))),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children:
          devices.map((d) => _buildDeviceNode(context, d, theme)).toList(),
    );
  }

  Widget _buildDeviceNode(BuildContext context, Device d, ThemeData theme) {
    final isExpanded = _expandedSerials.contains(d.serial);
    final hasActiveScreen =
        _screens.keys.any((k) => k.startsWith('${d.serial}_'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: hasActiveScreen
              ? theme.colorScheme.primaryContainer.withAlpha(80)
              : Colors.transparent,
          child: InkWell(
            onTap: () => _toggleExpand(d.serial),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.expand_more : Icons.chevron_right,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: d.isOnline ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      d.displayName,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    d.serial.length > 12
                        ? '...${d.serial.substring(d.serial.length - 8)}'
                        : d.serial,
                    style: TextStyle(
                        fontSize: 9, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  if (d.isOnline &&
                      (d.serial.contains(':') || d.serial.contains('_tcp')))
                    _disconnectButton(context, d),
                ],
              ),
            ),
          ),
        ),
        if (isExpanded)
          ...NavItem.values
              .where((item) => item != NavItem.info)
              .map((item) => _buildFunctionItem(context, d, item, theme)),
      ],
    );
  }

  Widget _disconnectButton(BuildContext context, Device d) {
    return Tooltip(
      message: tr('disconnect'),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => _disconnect(context, d),
        child: const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Icon(Icons.close, size: 14),
        ),
      ),
    );
  }

  Future<void> _disconnect(BuildContext context, Device d) async {
    final api = context.read<ApiClient>();
    final deviceProvider = context.read<DeviceProvider>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('disconnectConfirm')),
        content: Text(tr('disconnectConfirmBody', {'name': d.displayName})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('disconnect')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final result = await api.disconnectWirelessAdb(d.serial);
    if (!mounted || !context.mounted) return;
    if (result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('disconnectSuccess', {'name': d.displayName})),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error.isNotEmpty
              ? result.error
              : tr('disconnectFailed', {'name': d.displayName})),
          duration: const Duration(seconds: 3),
        ),
      );
    }
    deviceProvider.refresh(api);
  }

  Widget _buildFunctionItem(
      BuildContext context, Device d, NavItem item, ThemeData theme) {
    final key = '${d.serial}_${item.name}';
    final c = _navConfig[item]!;
    final isActive = _activeKey == key;

    return Material(
      color: isActive ? theme.colorScheme.primaryContainer : Colors.transparent,
      child: InkWell(
        onTap: () => _navigateTo(d.serial, item),
        child: Padding(
          padding:
              const EdgeInsets.only(left: 42, right: 12, top: 6, bottom: 6),
          child: Row(
            children: [
              Icon(c.icon,
                  size: 16,
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Text(
                navLabel(item),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
