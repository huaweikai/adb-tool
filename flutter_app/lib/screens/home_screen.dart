import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../db/database.dart';
import '../services/api_client.dart';
import '../services/device_stream.dart';
import '../providers/device_provider.dart'
    show DeviceSerialScope, DeviceScreenActiveScope, DeviceProvider;
import '../providers/locale_provider.dart';
import '../providers/test_session_provider.dart';
import '../providers/emulator_engine_provider.dart';
import '../providers/emulator_java_provider.dart';
import '../i18n.dart';
import '../design/design_tokens.dart';
import '../widgets/recording_fab.dart';
import 'device_status_screen.dart';
import 'logcat_screen.dart';
import 'file_browser_screen.dart';
import 'app_manager_screen.dart';
import 'device_info_screen.dart';
import 'clipboard_screen.dart';
import 'backend_log_screen.dart';
import 'adb_command_screen.dart';
import 'test_session/test_session_hub_screen.dart';
import 'test_config_screen.dart';
import '../widgets/wireless_adb_dialog.dart';
import '../widgets/command_palette.dart';
import '../widgets/empty_state.dart';
import 'screen_mirror_screen.dart';
import 'view_hierarchy_screen.dart';
import 'emulator_settings_screen.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/app_sidebar.dart';
import 'dashboard_view.dart';

/// Nav entries shown in the new [AppSidebar]. Each [id] maps to either a
/// per-device screen (via [NavItem]), a global screen, the settings dialog,
/// or the dashboard landing.
class _NavEntry {
  const _NavEntry(this.id, this.icon, this.labelKey, this.group);
  final String id;
  final IconData icon;
  final String labelKey;
  final AppNavGroup group;
}

const List<_NavEntry> _navEntries = [
  _NavEntry('dashboard', Icons.dashboard, 'dashboard', AppNavGroup.mainMenu),
  _NavEntry('status', Icons.phone_android, 'status', AppNavGroup.mainMenu),
  _NavEntry('apps', Icons.android, 'apps', AppNavGroup.mainMenu),
  _NavEntry('files', Icons.folder_open, 'files', AppNavGroup.mainMenu),
  _NavEntry('info', Icons.info_outline, 'info', AppNavGroup.mainMenu),
  _NavEntry('logcat', Icons.list_alt, 'logcat', AppNavGroup.debug),
  _NavEntry('command', Icons.terminal, 'command', AppNavGroup.debug),
  _NavEntry('clipboard', Icons.content_paste, 'clipboard', AppNavGroup.debug),
  _NavEntry('hierarchy', Icons.account_tree, 'viewHierarchy', AppNavGroup.debug),
  _NavEntry('mirror', Icons.cast, 'screenMirror', AppNavGroup.debug),
  _NavEntry('session', Icons.assignment_outlined, 'testSession', AppNavGroup.advanced),
  _NavEntry('backendLogs', Icons.terminal, 'backendLogs', AppNavGroup.advanced),
  _NavEntry('testConfig', Icons.tune, 'testConfigCenter', AppNavGroup.advanced),
  _NavEntry('emulator', Icons.smartphone, 'emulatorSettings', AppNavGroup.advanced),
  _NavEntry('settings', Icons.settings, 'settings', AppNavGroup.advanced),
];

const Set<String> _globalKeys = {'backendLogs', 'testConfig', 'emulator'};
const String _backendLogKey = 'backendLogs';
const String _testConfigKey = 'testConfig';
const String _emulatorKey = 'emulator';
const String _settingsKey = 'settings';
const String _dashboardKey = 'dashboard';

const List<String> _deviceNavIds = [
  'status',
  'apps',
  'files',
  'info',
  'logcat',
  'command',
  'clipboard',
  'hierarchy',
  'mirror',
  'session',
];

/// Digit keys for keyboard navigation (Cmd/Ctrl+1~9).
const _navDigitKeys = <LogicalKeyboardKey>[
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.digit8,
  LogicalKeyboardKey.digit9,
];

class _CachedScreen extends StatelessWidget {
  const _CachedScreen({super.key, required this.serial, required this.child});

  final String? serial;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // NOTE: do NOT `context.watch<TestConfigProvider>()` here. Every cached
    // screen in the IndexedStack is kept alive; a watch here would rebuild
    // *all* of them on every TestConfigProvider notify. Each screen watches
    // the providers it needs itself.
    return Provider<DeviceSerialScope>.value(
      value: DeviceSerialScope(serial),
      child: child,
    );
  }
}

/// Narrow value class for [HomeScreen]'s dependency on [DeviceProvider].
///
/// `context.select` compares the returned value with `==`. By overriding
/// `==` here the screen rebuilds only when the device list *contents*
/// actually change — not on every 5s `notifyListeners()` that reassigns the
/// list to a fresh instance holding identical data.
class _HomeSnapshot {
  const _HomeSnapshot(this.savedDevices, this.online, this.lastDbError);

  final List<SavedDevice> savedDevices;
  final bool online;
  final String? lastDbError;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _HomeSnapshot &&
          online == other.online &&
          lastDbError == other.lastDbError &&
          listEquals(savedDevices, other.savedDevices);

  @override
  int get hashCode =>
      Object.hash(online, lastDbError, Object.hashAll(savedDevices));
}

enum NavItem {
  status,
  logcat,
  files,
  apps,
  info,
  clipboard,
  hierarchy,
  command,
  session,
  mirror,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onShutdown, this.onRestart});

  final VoidCallback? onShutdown;
  final VoidCallback? onRestart;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final DeviceStreamService _deviceStream = DeviceStreamService();

  final Map<String, _CachedScreen> _screens = {};
  String? _activeKey = _dashboardKey;
  bool _restoredFromState = false;

  static const int _maxCachedScreens = 20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreState();
    _connectDeviceStream();
  }

  void _connectDeviceStream() {
    final dp = context.read<DeviceProvider>();
    final api = context.read<ApiClient>();
    dp.connectDeviceStream(_deviceStream, api);
    _deviceStream.connect();
  }

  Future<void> _restoreState() async {
    final dp = context.read<DeviceProvider>();
    final db = dp.db;

    final state = await db.appStatesDao.getAppState();
    if (!mounted) return;

    if (state.activeSerial != null && state.activeSerial!.isNotEmpty) {
      dp.select(state.activeSerial);
    }
    setState(() {
      _activeKey =
          state.activeKey?.isNotEmpty == true ? state.activeKey : _dashboardKey;
    });

    // Restore emulator toolchain selections from DB
    if (!mounted) return;
    try {
      final emulatorEngineProvider = context.read<EmulatorEngineProvider>();
      final emulatorJavaProvider = context.read<EmulatorJavaProvider>();

      await emulatorEngineProvider.restoreFromDB();
      if (!mounted) return;
      await emulatorJavaProvider.restoreFromDB();
    } catch (e) {
      debugPrint('[HomeScreen] Failed to restore emulator state: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final dp = context.read<DeviceProvider>();
    dp.disconnectDeviceStream();
    _deviceStream.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final dp = context.read<DeviceProvider>();
    if (state == AppLifecycleState.paused) {
      dp.pauseStream();
      _deviceStream.pause();
    } else if (state == AppLifecycleState.resumed) {
      dp.resumeStream();
      _deviceStream.resume();
    }
  }

  /// Sidebar highlight id derived from the persisted [_activeKey].
  String get _activeNavId {
    final k = _activeKey;
    if (k == null) return _dashboardKey;
    if (k == _dashboardKey) return _dashboardKey;
    if (_globalKeys.contains(k)) return k;
    final idx = k.lastIndexOf('_');
    if (idx < 0) return _dashboardKey;
    return k.substring(idx + 1);
  }

  String? get _selectedSerial => context.read<DeviceProvider>().activeSerial;

  NavItem? _deviceNavItem(String id) {
    switch (id) {
      case 'status':
        return NavItem.status;
      case 'apps':
        return NavItem.apps;
      case 'files':
        return NavItem.files;
      case 'info':
        return NavItem.info;
      case 'logcat':
        return NavItem.logcat;
      case 'command':
        return NavItem.command;
      case 'clipboard':
        return NavItem.clipboard;
      case 'hierarchy':
        return NavItem.hierarchy;
      case 'mirror':
        return NavItem.mirror;
      case 'session':
        return NavItem.session;
      default:
        return null;
    }
  }

  Widget _globalScreen(String id) {
    switch (id) {
      case _backendLogKey:
        return const BackendLogScreen();
      case _testConfigKey:
        return const TestConfigScreen();
      case _emulatorKey:
        return const EmulatorSettingsScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  String _navLabel(String id) {
    final e = _navEntries.where((x) => x.id == id).firstOrNull;
    return e == null ? id : tr(e.labelKey);
  }

  IconData _navIcon(String id) {
    final e = _navEntries.where((x) => x.id == id).firstOrNull;
    return e?.icon ?? Icons.circle;
  }

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
        case NavItem.hierarchy:
          screen = const ViewHierarchyScreen();
        case NavItem.command:
          screen = const AdbCommandScreen();
        case NavItem.session:
          screen = const TestSessionHubScreen();
        case NavItem.mirror:
          screen = const ScreenMirrorScreen();
      }
      _screens[key] = _CachedScreen(
        key: ValueKey(key),
        serial: serial,
        child: KeyedSubtree(
          key: ValueKey('screen:$key'),
          child: screen,
        ),
      );
      _evictCache();
    }
    setState(() => _activeKey = key);
    _persistState();
  }

  void _evictCache() {
    if (_screens.length <= _maxCachedScreens) return;
    final toRemove = _screens.length - _maxCachedScreens;
    final keys = _screens.keys.toList();
    int removed = 0;
    for (final k in keys) {
      if (removed >= toRemove) break;
      if (k == _activeKey || _globalKeys.contains(k)) continue;
      _screens.remove(k);
      removed++;
    }
  }

  /// Route by sidebar nav id. device screens need a selected serial.
  void _navigateToId(String id) {
    if (id == _dashboardKey) {
      setState(() => _activeKey = _dashboardKey);
      _persistState();
      return;
    }
    if (id == _settingsKey) {
      _openSettings();
      return;
    }
    final deviceNav = _deviceNavItem(id);
    if (deviceNav != null) {
      final serial = _selectedSerial;
      if (serial == null) return;
      _navigateTo(serial, deviceNav);
      return;
    }
    if (!_screens.containsKey(id)) {
      _screens[id] = _CachedScreen(serial: null, child: _globalScreen(id));
    }
    setState(() => _activeKey = id);
    _persistState();
  }

  void _navigateToRecord(String serial, NavItem item) => _navigateTo(serial, item);

  void _onQuickAction(String id) {
    if (id == 'wireless') {
      _showWirelessAdbDialog();
      return;
    }
    final serial = _selectedSerial;
    if (serial == null) return;
    _navigateToId(id);
  }

  void _selectDevice(String serial) {
    if (serial.isEmpty) {
      _showDeviceSwitcher();
      return;
    }
    context.read<DeviceProvider>().select(serial);
    setState(() => _activeKey = _dashboardKey);
    _persistState();
  }

  Future<void> _showDeviceSwitcher() async {
    final devices = context.read<DeviceProvider>().savedDevices;
    if (devices.isEmpty) return;
    final chosen = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(tr('selectDevice')),
        children: devices
            .map(
              (d) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, d.serial),
                child: Text(d.displayName),
              ),
            )
            .toList(),
      ),
    );
    if (chosen != null && mounted) _selectDevice(chosen);
  }

  void _openSettings() {
    showSettingsDialog(
      context,
      onRestartBackend: () async => widget.onRestart?.call(),
    );
  }

  Future<void> _persistState() async {
    final dp = context.read<DeviceProvider>();
    await dp.db.appStatesDao.updateAppState(
      activeKey: _activeKey,
      activeSerial: dp.activeSerial,
    );
  }

  void _restoreActiveKey(List<SavedDevice> savedDevices) {
    final key = _activeKey;
    if (key == null || key == _dashboardKey) return;
    if (_globalKeys.contains(key)) {
      _navigateToId(key);
      return;
    }
    final idx = key.lastIndexOf('_');
    if (idx < 0) {
      setState(() => _activeKey = _dashboardKey);
      return;
    }
    final serial = key.substring(0, idx);
    final navName = key.substring(idx + 1);
    final navItem =
        NavItem.values.where((n) => n.name == navName).firstOrNull;
    if (navItem == null) {
      setState(() => _activeKey = _dashboardKey);
      return;
    }
    if (!savedDevices.any((d) => d.serial == serial)) {
      setState(() => _activeKey = _dashboardKey);
      return;
    }
    _navigateTo(serial, navItem);
  }

  void _digitNavigate(int i) {
    if (i < 0 || i >= _navEntries.length) return;
    final id = _navEntries[i].id;
    if (_deviceNavItem(id) != null && _selectedSerial == null) return;
    _navigateToId(id);
  }

  void _openCommandPalette() {
    final dp = context.read<DeviceProvider>();
    final devices = dp.savedDevices;
    final list = <PaletteItem>[];

    for (final d in devices) {
      for (final id in _deviceNavIds) {
        list.add(PaletteItem(
          title: _navLabel(id),
          subtitle: d.displayName,
          icon: _navIcon(id),
          onSelect: () {
            dp.select(d.serial);
            _navigateToId(id);
          },
        ));
      }
    }

    list.add(PaletteItem(
      title: tr('testConfigCenter'),
      subtitle: tr('config'),
      icon: Icons.tune,
      onSelect: () => _navigateToId(_testConfigKey),
    ));
    list.add(PaletteItem(
      title: tr('emulatorSettings.title'),
      subtitle: 'Android',
      icon: Icons.smartphone,
      onSelect: () => _navigateToId(_emulatorKey),
    ));
    list.add(PaletteItem(
      title: tr('settings.title'),
      subtitle: 'Settings',
      icon: Icons.settings,
      onSelect: _openSettings,
    ));
    list.add(PaletteItem(
      title: tr('backendLogs'),
      subtitle: 'Go',
      icon: Icons.terminal,
      onSelect: () => _navigateToId(_backendLogKey),
    ));
    list.add(PaletteItem(
      title: tr('wirelessAdb'),
      subtitle: '',
      icon: Icons.wifi_tethering,
      onSelect: _showWirelessAdbDialog,
    ));

    CommandPalette.show(context, items: list);
  }

  Widget _buildContent() {
    if (_activeNavId == _dashboardKey) {
      return Stack(
        children: [
          DashboardView(
            serial: _selectedSerial,
            onQuickAction: _onQuickAction,
            onSelectDevice: _selectDevice,
          ),
          RecordingOverlay(
            db: context.read<AppDatabase>(),
            sessionProvider: context.read<TestSessionProvider>(),
            onNavigateToRecord: _navigateToRecord,
          ),
        ],
      );
    }

    if (_activeKey == null || !_screens.containsKey(_activeKey)) {
      return _buildWelcome();
    }
    final entries = _screens.entries.toList();
    final activeIndex = entries.indexWhere((e) => e.key == _activeKey);
    if (activeIndex < 0) return _buildWelcome();

    return Stack(
      children: [
        IndexedStack(
          index: activeIndex,
          children: entries.map((entry) {
            final active = entry.key == _activeKey;
            return TickerMode(
              enabled: active,
              child: IgnorePointer(
                ignoring: !active,
                child: ExcludeSemantics(
                  excluding: !active,
                  child: Provider<DeviceScreenActiveScope>.value(
                    value: DeviceScreenActiveScope(active),
                    child: SizedBox.expand(child: entry.value),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        RecordingOverlay(
          db: context.read<AppDatabase>(),
          sessionProvider: context.read<TestSessionProvider>(),
          onNavigateToRecord: _navigateToRecord,
        ),
      ],
    );
  }

  Widget _buildWelcome() {
    return EmptyState(
      icon: Icons.android,
      title: tr('appTitle'),
      subtitle: tr('welcome'),
    );
  }

  Widget _buildOfflineBanner(BuildContext context) {
    final theme = Theme.of(context);
    final api = context.read<ApiClient>();
    final deviceProvider = context.read<DeviceProvider>();

    return MaterialBanner(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
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
            child: Text(
              tr('restart'),
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        TextButton(
          onPressed: () => deviceProvider.refresh(api),
          child: Text(
            tr('refresh'),
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
        ),
      ],
    );
  }

  /// Warning (not error) banner for DB persistence failures. Backend is
  /// healthy, so this is rendered in amber instead of red and offers a
  /// Copy button so the user can paste the actual error to share/grep.
  Widget _buildDbErrorBanner(BuildContext context, String error) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onErrorContainer;
    return MaterialBanner(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      backgroundColor: const Color(0xFFFFE0B2), // amber 100 — distinct from red
      leading: Icon(Icons.warning_amber_rounded, color: fg),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 96),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('dbErrorTitle'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tr('dbErrorBody', {'error': error}),
                style: TextStyle(fontSize: 11, color: fg),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: error));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(tr('copyError')),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: Text(
            tr('copyError'),
            style: TextStyle(fontSize: 12, color: fg),
          ),
        ),
      ],
    );
  }

  void _clearAllState() {
    // Don't pause the device stream here — the WS will handle
    // disconnection/reconnection automatically when the backend
    // restarts. Pausing it here would permanently kill the stream
    // because nothing resumes it.
    _screens.clear();
    _activeKey = _dashboardKey;
    context.read<DeviceProvider>().select(null);
  }

  Future<void> _showWirelessAdbDialog() async {
    final api = context.read<ApiClient>();
    final deviceProvider = context.read<DeviceProvider>();
    await showDialog<void>(
      context: context,
      builder: (_) => WirelessAdbDialog(api: api, deviceProvider: deviceProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = context.select<DeviceProvider, _HomeSnapshot>(
      (p) => _HomeSnapshot(p.savedDevices, p.online, p.lastDbError),
    );
    context.watch<LocaleProvider>();
    final savedDevices = snapshot.savedDevices;
    final backendOnline = snapshot.online;
    final selectedSerial =
        context.select<DeviceProvider, String?>((p) => p.activeSerial);

    // Restore page from saved state when devices are loaded.
    if (savedDevices.isNotEmpty && _activeKey != null && !_restoredFromState) {
      _restoredFromState = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreActiveKey(savedDevices);
      });
    }

    final isMacOS = defaultTargetPlatform == TargetPlatform.macOS;
    final selDevice = selectedSerial == null
        ? null
        : savedDevices.where((d) => d.serial == selectedSerial).firstOrNull;

    final sidebarItems = _navEntries
        .map(
          (e) => AppNavItemData(
            id: e.id,
            icon: e.icon,
            label: tr(e.labelKey),
            group: e.group,
          ),
        )
        .toList();

    return CallbackShortcuts(
      bindings: {
        // Command palette: Cmd/Ctrl+K
        SingleActivator(
          LogicalKeyboardKey.keyK,
          meta: isMacOS,
          control: !isMacOS,
        ): _openCommandPalette,
        // Navigate to nav item: Cmd/Ctrl+1~9
        for (int i = 0; i < _navEntries.length && i < _navDigitKeys.length; i++)
          SingleActivator(
            _navDigitKeys[i],
            meta: isMacOS,
            control: !isMacOS,
          ): () => _digitNavigate(i),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          // Transparent: the global AppBackground (theme base + glow) shows
          // through the whole content area.
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              if (!backendOnline) _buildOfflineBanner(context),
              if (snapshot.lastDbError != null)
                _buildDbErrorBanner(context, snapshot.lastDbError!),
              Expanded(
                child: Row(
                  children: [
                    AppSidebar(
                      items: sidebarItems,
                      activeNavId: _activeNavId,
                      onNavTap: _navigateToId,
                      deviceName: selDevice?.displayName ?? tr('noDevice'),
                      deviceStatus: selDevice?.isConnected == true
                          ? tr('deviceOnline')
                          : tr('deviceOffline'),
                      deviceOnline: selDevice?.isConnected ?? false,
                      onDeviceSwitcherTap: _showDeviceSwitcher,
                      backendOnline: backendOnline,
                    ),
                    Expanded(child: _buildContent()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
