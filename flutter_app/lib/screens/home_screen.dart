import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device.dart';
import '../services/api_client.dart';
import '../providers/theme_provider.dart';
import '../providers/device_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/test_config_provider.dart';
import '../i18n.dart';
import 'device_status_screen.dart';
import 'logcat_screen.dart';
import 'file_browser_screen.dart';
import 'app_manager_screen.dart';
import 'device_info_screen.dart';
import 'clipboard_screen.dart';
import 'backend_log_screen.dart';
import 'adb_command_screen.dart';
import 'test_session_screen.dart';
import 'test_config_screen.dart';
import '../widgets/wireless_adb_dialog.dart';

enum NavItem { status, logcat, files, apps, info, clipboard, command, session }

const _navConfig = {
  NavItem.status: _NavConfig(Icons.phone_android, 'status'),
  NavItem.logcat: _NavConfig(Icons.list_alt, 'logcat'),
  NavItem.files: _NavConfig(Icons.folder_open, 'files'),
  NavItem.apps: _NavConfig(Icons.android, 'apps'),
  NavItem.info: _NavConfig(Icons.info_outline, 'info'),
  NavItem.clipboard: _NavConfig(Icons.content_paste, 'clipboard'),
  NavItem.command: _NavConfig(Icons.terminal, 'command'),
  NavItem.session: _NavConfig(Icons.assignment_outlined, 'testSession'),
};

class _NavConfig {
  final IconData icon;
  final String label;
  const _NavConfig(this.icon, this.label);
}

const _backendLogKey = '_backend_logs';
const _testConfigKey = '_test_config';

class _CachedScreen extends StatelessWidget {
  final String? serial;
  final Widget child;

  const _CachedScreen({required this.serial, required this.child});

  @override
  Widget build(BuildContext context) {
    context.watch<TestConfigProvider>();
    return Provider<DeviceSerialScope>.value(
      value: DeviceSerialScope(serial),
      child: child,
    );
  }
}

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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? _refreshTimer;

  final Set<String> _expandedSerials = {};
  final Map<String, _CachedScreen> _screens = {};
  String? _activeKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final api = context.read<ApiClient>();
    final dp = context.read<DeviceProvider>();
    dp.refresh(api);
    dp.addListener(_onDevicesChanged);
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      context.read<DeviceProvider>().refresh(context.read<ApiClient>());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    context.read<DeviceProvider>().removeListener(_onDevicesChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<DeviceProvider>().refresh(context.read<ApiClient>());
    }
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
          screen = const DeviceStatusScreen();
        case NavItem.logcat:
          screen = const LogcatScreen();
        case NavItem.files:
          screen = const FileBrowserScreen();
        case NavItem.apps:
          screen = const AppManagerScreen();
        case NavItem.info:
          screen = const DeviceInfoScreen();
        case NavItem.clipboard:
          screen = const ClipboardScreen();
        case NavItem.command:
          screen = const AdbCommandScreen();
        case NavItem.session:
          screen = const TestSessionScreen();
      }
      _screens[key] = _CachedScreen(serial: serial, child: screen);
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
      _screens[_backendLogKey] = const _CachedScreen(
        serial: null,
        child: BackendLogScreen(),
      );
    }
    setState(() => _activeKey = _backendLogKey);
  }

  void _openTestConfig() {
    if (!_screens.containsKey(_testConfigKey)) {
      _screens[_testConfigKey] = const _CachedScreen(
        serial: null,
        child: TestConfigScreen(),
      );
    }
    setState(() => _activeKey = _testConfigKey);
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

  void _onDevicesChanged() {
    if (!mounted) return;
    _schedulePruneDisconnectedScreens(context.read<DeviceProvider>().devices);
  }

  void _schedulePruneDisconnectedScreens(List<Device> devices) {
    final onlineSerials = devices
        .where((device) => device.isOnline)
        .map((device) => device.serial)
        .toSet();
    final removedSerials = _screens.values
        .map((screen) => screen.serial)
        .whereType<String>()
        .where((serial) => !onlineSerials.contains(serial))
        .toSet();
    if (removedSerials.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _screens.removeWhere((_, screen) =>
            screen.serial != null && removedSerials.contains(screen.serial));
        _expandedSerials.removeWhere(removedSerials.contains);
        if (_activeKey != null && !_screens.containsKey(_activeKey)) {
          _activeKey = null;
        }
      });
    });
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
        final active = entry.key == _activeKey;
        return Offstage(
          offstage: !active,
          child: Provider<DeviceScreenActiveScope>.value(
            value: DeviceScreenActiveScope(active),
            child: SizedBox.expand(child: entry.value),
          ),
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
          _buildGlobalEntry(
            theme,
            keyName: _testConfigKey,
            icon: Icons.tune,
            label: tr('testConfigCenter'),
            badge: tr('config'),
            onTap: _openTestConfig,
          ),
          _buildGlobalEntry(
            theme,
            keyName: _backendLogKey,
            icon: Icons.terminal,
            label: tr('backendLogs'),
            badge: 'Go',
            onTap: _openBackendLogs,
          ),
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
        if (widget.onRestart != null)
          TextButton(
            onPressed: () {
              widget.onRestart!();
              _clearAllState();
            },
            child: Text(tr('restart'),
                style: TextStyle(
                    fontSize: 12, color: theme.colorScheme.onErrorContainer)),
          ),
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
    _refreshTimer = null;
    _screens.clear();
    _expandedSerials.clear();
    _activeKey = null;
    context.read<DeviceProvider>().select(null);
  }

  Future<void> _showWirelessAdbDialog() async {
    final api = context.read<ApiClient>();
    final deviceProvider = context.read<DeviceProvider>();
    await showDialog<void>(
      context: context,
      builder: (_) =>
          WirelessAdbDialog(api: api, deviceProvider: deviceProvider),
    );
  }

  void _confirmShutdown(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
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

  Widget _buildGlobalEntry(
    ThemeData theme, {
    required String keyName,
    required IconData icon,
    required String label,
    required String badge,
    required VoidCallback onTap,
  }) {
    final isActive = _activeKey == keyName;
    return Material(
      color: isActive ? theme.colorScheme.primaryContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon,
                  size: 16,
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(badge, style: const TextStyle(fontSize: 9)),
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
        scrollable: true,
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
