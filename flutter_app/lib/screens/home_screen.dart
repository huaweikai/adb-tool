import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../db/database.dart';
import '../services/api_client.dart';
import '../providers/theme_provider.dart';
import '../providers/device_provider.dart'
    show DeviceSerialScope, DeviceScreenActiveScope, DeviceProvider;
import '../providers/locale_provider.dart';
import '../providers/test_config_provider.dart';
import '../providers/test_session_provider.dart';
import '../providers/emulator_engine_provider.dart';
import '../providers/emulator_java_provider.dart';
import '../i18n.dart';
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
import 'screen_mirror_screen.dart';
import 'emulator_settings_screen.dart';
import 'settings_screen.dart';

enum NavItem {
  status,
  logcat,
  files,
  apps,
  info,
  clipboard,
  command,
  session,
  mirror,
}

const _navConfig = {
  NavItem.status: _NavConfig(Icons.phone_android, 'status'),
  NavItem.logcat: _NavConfig(Icons.list_alt, 'logcat'),
  NavItem.files: _NavConfig(Icons.folder_open, 'files'),
  NavItem.apps: _NavConfig(Icons.android, 'apps'),
  NavItem.info: _NavConfig(Icons.info_outline, 'info'),
  NavItem.clipboard: _NavConfig(Icons.content_paste, 'clipboard'),
  NavItem.command: _NavConfig(Icons.terminal, 'command'),
  NavItem.session: _NavConfig(Icons.assignment_outlined, 'testSession'),
  NavItem.mirror: _NavConfig(Icons.cast, 'screenMirror'),
};

class _NavConfig {
  final IconData icon;
  final String label;
  const _NavConfig(this.icon, this.label);
}

const _backendLogKey = '_backend_logs';
const _testConfigKey = '_test_config';
const _emulatorKey = '_emulator_settings';
const _settingsKey = '_settings';

class _CachedScreen extends StatelessWidget {
  final String? serial;
  final Widget child;

  const _CachedScreen({super.key, required this.serial, required this.child});

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
  bool _restoredFromState = false;

  // Sidebar resize state. _sidebarWidth lives in a ValueNotifier so per-frame
  // drag updates don't setState() the whole HomeScreen (which would also rebuild
  // every keep-mounted screen inside IndexedStack — commit 18b0ca5). The sidebar
  // rebuilds itself via ValueListenableBuilder + RepaintBoundary.
  final ValueNotifier<double> _sidebarWidth = ValueNotifier(240);
  bool _sidebarCollapsed = false;
  bool _isDragging = false;
  static const double _defaultSidebarWidth = 240;
  static const double _minSidebarWidth = 200;
  static const double _maxSidebarWidth = 400;
  static const double _collapsedSidebarWidth = 56;
  static const Duration _sidebarAnimDuration = Duration(milliseconds: 150);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreState();
    _startRefresh();
  }

  Future<void> _restoreState() async {
    final dp = context.read<DeviceProvider>();
    final db = dp.db;

    final activeKey = await db.appStatesDao.getActiveKey();
    final expandedSerials = await db.appStatesDao.getExpandedSerials();
    final sidebarWidth = await db.appStatesDao.getSidebarWidth();
    final sidebarCollapsed = await db.appStatesDao.getSidebarCollapsed();

    if (!mounted) return;

    setState(() {
      if (activeKey != null && activeKey.isNotEmpty) {
        _activeKey = activeKey;
      }
      _expandedSerials
        ..clear()
        ..addAll(expandedSerials);
      _sidebarWidth.value =
          sidebarWidth.toDouble().clamp(_minSidebarWidth, _maxSidebarWidth);
      _sidebarCollapsed = sidebarCollapsed;
    });

    // Restore emulator toolchain selections from DB
    // Import the providers to use them
    if (!mounted) return;
    try {
      final emulatorEngineProvider = context.read<EmulatorEngineProvider>();
      final emulatorJavaProvider = context.read<EmulatorJavaProvider>();

      // Restore SDK selection first, then Java
      await emulatorEngineProvider.restoreFromDB();
      if (!mounted) return;
      await emulatorJavaProvider.restoreFromDB();
    } catch (e) {
      debugPrint('[HomeScreen] Failed to restore emulator state: $e');
    }
  }

  Future<void> _startRefresh() async {
    final api = context.read<ApiClient>();
    final dp = context.read<DeviceProvider>();
    dp.refresh(api);
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      context.read<DeviceProvider>().refresh(context.read<ApiClient>());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _sidebarWidth.dispose();
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
    _persistState();
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
    // Also expand the device in the sidebar so the user can see where they are.
    if (!_expandedSerials.contains(serial)) {
      _expandedSerials.add(serial);
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
      if (k == _activeKey || k == _backendLogKey || k == _emulatorKey || k == _settingsKey) continue;
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

  void _openEmulatorSettings() {
    if (!_screens.containsKey(_emulatorKey)) {
      _screens[_emulatorKey] = _CachedScreen(
        serial: null,
        child: const EmulatorSettingsScreen(),
      );
    }
    setState(() => _activeKey = _emulatorKey);
  }

  void _openSettings() {
    if (!_screens.containsKey(_settingsKey)) {
      _screens[_settingsKey] = const _CachedScreen(
        serial: null,
        child: SettingsScreen(),
      );
    }
    setState(() => _activeKey = _settingsKey);
  }

  /// Restore the active page from saved _activeKey
  void _restoreActivePage(List<SavedDevice> savedDevices) {
    if (_activeKey == null) return;

    // Check if it's a backend log or test config page
    if (_activeKey == _backendLogKey) {
      _openBackendLogs();
      return;
    }
    if (_activeKey == _testConfigKey) {
      _openTestConfig();
      return;
    }
    if (_activeKey == _emulatorKey) {
      _openEmulatorSettings();
      return;
    }
    if (_activeKey == _settingsKey) {
      _openSettings();
      return;
    }

    // Parse device serial and nav item from _activeKey (format: "serial_itemName")
    final parts = _activeKey!.split('_');
    if (parts.length < 2) return;

    final serial = parts.sublist(0, parts.length - 1).join('_');
    final itemName = parts.last;

    // Check if the device still exists in saved devices
    final deviceExists = savedDevices.any((d) => d.serial == serial);
    if (!deviceExists) {
      // Device no longer exists, clear the state
      setState(() {
        _activeKey = null;
        _restoredFromState = false;
      });
      return;
    }

    // Find the NavItem
    final navItem =
        NavItem.values.where((item) => item.name == itemName).firstOrNull;
    if (navItem == null) return;

    // Expand the device in sidebar
    if (!_expandedSerials.contains(serial)) {
      setState(() {
        _expandedSerials.add(serial);
      });
    }

    // Navigate to the page
    _navigateTo(serial, navItem);
  }

  @override
  Widget build(BuildContext context) {
    final deviceProvider = context.watch<DeviceProvider>();
    context.watch<LocaleProvider>();
    final savedDevices = deviceProvider.savedDevices;
    final backendOnline = deviceProvider.online;

    // Restore page from saved state when devices are loaded
    if (savedDevices.isNotEmpty && _activeKey != null && !_restoredFromState) {
      _restoredFromState = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreActivePage(savedDevices);
      });
    }

    return Scaffold(
      body: Column(
        children: [
          if (!backendOnline) _buildOfflineBanner(context),
          if (deviceProvider.lastDbError != null)
            _buildDbErrorBanner(context, deviceProvider.lastDbError!),
          Expanded(
            child: Row(
              children: [
                _buildResizableSidebar(context, savedDevices, backendOnline),
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
      return _buildWelcome();
    }

    final entries = _screens.entries.toList();
    final activeIndex = entries.indexWhere((entry) => entry.key == _activeKey);
    if (activeIndex < 0) {
      return _buildWelcome();
    }

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

  void _navigateToRecord(String serial, NavItem item) {
    _navigateTo(serial, item);
  }

  Widget _buildWelcome() {
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

  void _removeDevice(String serial) async {
    final sessionProvider = context.read<TestSessionProvider>();
    final deviceProvider = context.read<DeviceProvider>();
    try {
      if (sessionProvider.hasRunningSession) {
        await sessionProvider.finishSession();
      }
    } catch (_) {}
    final ok = await deviceProvider.removeDevice(serial);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('removeDeviceFailed')),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    setState(() {
      _screens.removeWhere((_, screen) => screen.serial == serial);
      _expandedSerials.remove(serial);
      if (_activeKey != null && !_screens.containsKey(_activeKey)) {
        _activeKey = null;
      }
    });
    _persistState();
  }

  Future<void> _persistState() async {
    final dp = context.read<DeviceProvider>();
    await dp.db.appStatesDao.updateAppState(
      activeKey: _activeKey,
      expandedSerials: _expandedSerials.toList(),
      sidebarWidth: _sidebarWidth.value.round(),
      sidebarCollapsed: _sidebarCollapsed,
    );
  }

  void _toggleSidebarCollapsed() {
    setState(() {
      _sidebarCollapsed = !_sidebarCollapsed;
    });
    _persistState();
  }

  void _onDragStart(DragStartDetails details) {
    setState(() => _isDragging = true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    // No setState: updates ValueNotifier directly so only the sidebar
    // subtree rebuilds (via ValueListenableBuilder below).
    _sidebarWidth.value = (_sidebarWidth.value + details.delta.dx)
        .clamp(_minSidebarWidth, _maxSidebarWidth);
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() => _isDragging = false);
    _persistState();
  }

  void _resetSidebarWidth() {
    _sidebarWidth.value = _defaultSidebarWidth;
    if (_sidebarCollapsed) {
      setState(() => _sidebarCollapsed = false);
    }
    _persistState();
  }

  Widget _buildResizableSidebar(
      BuildContext context, List<SavedDevice> devices, bool online) {
    final theme = Theme.of(context);
    return RepaintBoundary(
      child: ValueListenableBuilder<double>(
        valueListenable: _sidebarWidth,
        builder: (context, width, _) {
          final currentWidth =
              _sidebarCollapsed ? _collapsedSidebarWidth : width;
          // Duration: 0 during drag (instant feedback), 150ms on collapse toggle
          // so the width animates smoothly without per-frame lag while dragging.
          return AnimatedContainer(
            duration: _isDragging ? Duration.zero : _sidebarAnimDuration,
            curve: Curves.easeOutCubic,
            width: currentWidth,
            child: Stack(
              children: [
                _sidebarCollapsed
                    ? _buildCollapsedSidebar(theme, devices)
                    : _buildSidebar(context, devices, online),
                if (!_sidebarCollapsed)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: _buildDragHandle(theme),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDragHandle(ThemeData theme) {
    return Tooltip(
      message: tr('resizeSidebarHint'),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        onDoubleTap: _resetSidebarWidth,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: Container(
            width: 6,
            color: _isDragging
                ? theme.colorScheme.primary.withAlpha(60)
                : Colors.transparent,
          ),
        ),
      ),
    );
  }

  // Theme-aware connection status dot color. Green is kept hardcoded (universal
  // "online" semantic) but uses a slightly desaturated shade; red falls back to
  // theme.error so it respects dark/light mode.
  Color _statusDotColor(ThemeData theme, bool isConnected) =>
      isConnected ? Colors.green.shade400 : theme.colorScheme.error;

  Widget _buildCollapsedSidebar(ThemeData theme, List<SavedDevice> devices) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(right: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        children: [
          // Expand button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Tooltip(
              message: tr('expandSidebar'),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _toggleSidebarCollapsed,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.chevron_right,
                      size: 20, color: theme.colorScheme.primary),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          // Device icons
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: devices.map((d) {
                final isConnected =
                    context.read<DeviceProvider>().isDeviceConnected(d.serial);
                final isActiveDevice = _screens[_activeKey]?.serial == d.serial;
                return Tooltip(
                  message: d.displayName,
                  preferBelow: false,
                  child: InkWell(
                    onTap: () => _collapsedDeviceTap(d.serial),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      color: isActiveDevice
                          ? theme.colorScheme.primaryContainer
                          : null,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.phone_android,
                              size: 20,
                              color: isActiveDevice
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 2),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _statusDotColor(theme, isConnected),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          // Global entries as icon-only
          _buildCollapsedGlobalEntry(
            theme,
            icon: Icons.tune,
            tooltip: tr('testConfigCenter'),
            isActive: _activeKey == _testConfigKey,
            onTap: () => _expandAndOpen(_openTestConfig),
          ),
          _buildCollapsedGlobalEntry(
            theme,
            icon: Icons.smartphone,
            tooltip: tr('emulatorSettings.title'),
            isActive: _activeKey == _emulatorKey,
            onTap: () => _expandAndOpen(_openEmulatorSettings),
          ),
          _buildCollapsedGlobalEntry(
            theme,
            icon: Icons.settings,
            tooltip: tr('settings.title'),
            isActive: _activeKey == _settingsKey,
            onTap: () => _expandAndOpen(_openSettings),
          ),
          _buildCollapsedGlobalEntry(
            theme,
            icon: Icons.terminal,
            tooltip: tr('backendLogs'),
            isActive: _activeKey == _backendLogKey,
            onTap: () => _expandAndOpen(_openBackendLogs),
          ),
        ],
      ),
    );
  }

  // Click a device icon while sidebar is collapsed: expand sidebar and ensure
  // the device is in the expanded set, in a single setState + single
  // _persistState (previously each helper triggered its own — two DB writes
  // per tap, plus a brief inconsistent intermediate frame).
  void _collapsedDeviceTap(String serial) {
    if (_expandedSerials.isEmpty) {
      // First device ever: expand + auto-navigate to status so the user
      // immediately has something on screen (matches old _toggleExpand).
      setState(() => _sidebarCollapsed = false);
      _navigateTo(serial, NavItem.status);
      return;
    }
    setState(() {
      _sidebarCollapsed = false;
      _expandedSerials.add(serial); // Set.add is no-op if already present.
    });
    _persistState();
  }

  // Click a global entry while sidebar is collapsed: expand sidebar and open
  // the target page in a single persist (collapsed=false + activeKey together).
  VoidCallback _expandAndOpen(VoidCallback openFn) {
    return () {
      if (_sidebarCollapsed) {
        setState(() => _sidebarCollapsed = false);
      }
      openFn(); // openFn does its own setState(_activeKey); Flutter coalesces
      _persistState();
    };
  }

  Widget _buildCollapsedGlobalEntry(
    ThemeData theme, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: Material(
        color:
            isActive ? theme.colorScheme.primaryContainer : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Icon(icon,
                size: 20,
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(
      BuildContext context, List<SavedDevice> devices, bool online) {
    final theme = Theme.of(context);
    return Container(
      width: _sidebarWidth.value,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(right: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme),
          const Divider(height: 1),
          Expanded(
            child: _DeviceTreeArea(
              expandedSerials: _expandedSerials,
              activeDeviceSerials: {
                for (final entry in _screens.entries)
                  if (entry.value.serial != null) entry.value.serial!,
              },
              activeKey: _activeKey,
              onToggleExpand: _toggleExpand,
              onRemoveDevice: _removeDevice,
              onNavigateTo: _navigateTo,
            ),
          ),
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
            keyName: _emulatorKey,
            icon: Icons.smartphone,
            label: tr('emulatorSettings.title'),
            badge: 'Android',
            // Beta tag: emulator Phase 1-4 is feature-incomplete
            // (no AVD hot-resize, no snapshot UI, no multi-display, see
            // docs/code-review-feature-emulator-prep.md). Drawing a
            // visible BETA so users know to expect rough edges.
            extraBadge: 'BETA',
            onTap: _openEmulatorSettings,
          ),
          _buildGlobalEntry(
            theme,
            keyName: _settingsKey,
            icon: Icons.settings,
            label: tr('settings.title'),
            badge: 'Settings',
            onTap: _openSettings,
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
              // Expanded (not Spacer + loose Text): the title must shrink first
              // when sidebar is narrow (during drag toward min=200px), otherwise
              // the right-side language toggle + collapse chevron overflow the row.
              Expanded(
                child: Text(
                  'ADB Tool',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
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
              const SizedBox(width: 4),
              Tooltip(
                message: tr('collapseSidebar'),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: _toggleSidebarCollapsed,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.chevron_left,
                        size: 18, color: theme.colorScheme.onSurfaceVariant),
                  ),
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
                    fontSize: 12, fontWeight: FontWeight.w600, color: fg),
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
    String? extraBadge,
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
              if (extraBadge != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    // Amber so it pops against the primary-tinted 'Android'
                    // chip and reads as "in-progress" rather than "stable".
                    color: Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    extraBadge,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
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
}

/// Sidebar list of saved devices. Split out from [_HomeScreenState] so
/// `DeviceProvider.notifyListeners()` only rebuilds *this* subtree
/// instead of the whole `HomeScreen` (which would also rebuild the
/// `IndexedStack` of per-device screens, the top toolbar, the
/// backend-log/test-config entries, etc.). On Windows the previous
/// "rebuild everything" pattern combined with rapid list-shape changes
/// (e.g. first device plugged in flipping the empty-state branch into
/// a non-empty `ListView` mid-rebuild) tripped the a11y bridge into
/// `UNREACHABLE` and crashed the app.
///
/// State owned by [_HomeScreenState] (parent) is passed in as
/// immutable inputs + callbacks; the widget itself does not hold any
/// mutable state — the consumer-driven rebuild path is enough for
/// what this widget needs to do.
class _DeviceTreeArea extends StatelessWidget {
  const _DeviceTreeArea({
    required this.expandedSerials,
    required this.activeDeviceSerials,
    required this.activeKey,
    required this.onToggleExpand,
    required this.onRemoveDevice,
    required this.onNavigateTo,
  });

  /// Stable identities (SavedDevice.serial = ro.serialno) whose
  /// function-item list is currently expanded.
  final Set<String> expandedSerials;

  /// Stable identities that own a cached screen in the right-hand
  /// `IndexedStack` — used to highlight the active device row.
  /// Derived from the parent's `_screens` map.
  final Set<String> activeDeviceSerials;

  /// The currently focused screen key (`${serial}_${item.name}`).
  /// Used to render the per-row active highlight for function items.
  final String? activeKey;

  final void Function(String serial) onToggleExpand;
  final void Function(String serial) onRemoveDevice;
  final void Function(String serial, NavItem item) onNavigateTo;

  // Static dot color helper — kept here to avoid leaking theme
  // coloring into the parent. Mirrors the original
  // _HomeScreenState._statusDotColor.
  static Color _statusDotColor(ThemeData theme, bool isConnected) =>
      isConnected ? Colors.green.shade400 : theme.colorScheme.error;

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, deviceProvider, _) {
        final devices = deviceProvider.savedDevices;
        final theme = Theme.of(context);

        if (devices.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_android,
                      size: 40,
                      color: theme.colorScheme.onSurfaceVariant
                          .withAlpha(100)),
                  const SizedBox(height: 8),
                  Text(tr('noDevices'),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(tr('noDevicesHint'),
                      style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant
                              .withAlpha(150))),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 4),
          // KeyedSubtree around each child: without an explicit Key,
          // Flutter falls back to position-based matching for
          // ListView's direct children. When the savedDevices list
          // changes shape (insert / remove / reorder) the lack of a
          // stable key causes the per-row element/state to drift to
          // the wrong row — on Windows that combination with rapid
          // rebuilds can trip the a11y tree into UNREACHABLE and
          // crash the app. Stable keys tie each row to its
          // SavedDevice.serial (= stable identity) so expanded /
          // active / cached-screen state stays correct.
          children: devices
              .map((d) => KeyedSubtree(
                    key: ValueKey('device-node:${d.serial}'),
                    child: _buildDeviceNode(context, d, theme),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildDeviceNode(
      BuildContext context, SavedDevice d, ThemeData theme) {
    final isExpanded = expandedSerials.contains(d.serial);
    final hasActiveScreen = activeDeviceSerials.contains(d.serial);
    final isConnected = d.isConnected;
    // SavedDevice.serial is the stable identity (ro.serialno, e.g.
    // 'R5CT70AHPDR'); its current Wi-Fi transport (if any) lives on
    // the DeviceProvider's online list. We must NOT gate the
    // disconnect button on the serial string itself (e.g. `contains(':')`)
    // — the stable identity never contains ':' once the row is
    // upgraded past v9 migration, so the button would vanish.
    final hasWifi =
        context.read<DeviceProvider>().hasWifiTransport(d.serial);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: hasActiveScreen
              ? theme.colorScheme.primaryContainer.withAlpha(80)
              : Colors.transparent,
          child: InkWell(
            onTap: () => onToggleExpand(d.serial),
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
                      color: _statusDotColor(theme, isConnected),
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
                  // ConstrainedBox caps the serial so it can't push
                  // the row past available width when the sidebar is
                  // at its min (200px) and the row has
                  // sync_problem/remove/disconnect icons attached.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 80),
                    child: Text(
                      d.serial.length > 12
                          ? '...${d.serial.substring(d.serial.length - 8)}'
                          : d.serial,
                      style: TextStyle(
                          fontSize: 9,
                          color: theme.colorScheme.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (!isConnected)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.sync_problem,
                        size: 14,
                        color: Colors.orange.withAlpha(200),
                      ),
                    ),
                  // Remove device button (only show when disconnected)
                  if (!isConnected)
                    Tooltip(
                      message: tr('removeDevice'),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () => onRemoveDevice(d.serial),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.close, size: 14),
                        ),
                      ),
                    ),
                  // Disconnect wireless button — show only when the
                  // device currently has a live Wi-Fi transport to
                  // disconnect from. The disconnect target is the
                  // `ip:port` of that transport, not the saved PK.
                  if (isConnected && hasWifi)
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

  Widget _disconnectButton(BuildContext context, SavedDevice d) {
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

  Future<void> _disconnect(BuildContext context, SavedDevice d) async {
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
    // adb-wireless-disconnect takes the **Wi-Fi transport address**
    // (ip:port), not the saved device's PK (ro.serialno) and not
    // `onlineAddressFor` (which is USB-preferred and would hand back
    // a USB serial — `adb disconnect <usb-serial>` is a no-op or an
    // error). Resolve the current Wi-Fi transport explicitly.
    if (!context.mounted) return;
    final wifiTransport =
        context.read<DeviceProvider>().wifiTransportFor(d.serial);
    if (wifiTransport == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('disconnectFailed', {'name': d.displayName})),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    final result = await api.disconnectWirelessAdb(wifiTransport.serial);
    if (!context.mounted) return;
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
      BuildContext context, SavedDevice d, NavItem item, ThemeData theme) {
    final key = '${d.serial}_${item.name}';
    final c = _navConfig[item]!;
    final isActive = activeKey == key;

    return Material(
      color: isActive ? theme.colorScheme.primaryContainer : Colors.transparent,
      child: InkWell(
        onTap: () => onNavigateTo(d.serial, item),
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
              // Expanded with ellipsis: at min sidebar width (200px)
              // the available width is ~146px; long labels like
              // "Test Session Hub" / "Screen Mirror" would otherwise
              // overflow the row.
              Expanded(
                child: Text(
                  tr(_navConfig[item]!.label),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
