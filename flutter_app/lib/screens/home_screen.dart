import 'dart:async';
import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/api_client.dart';
import '../services/log_stream.dart';
import 'logcat_screen.dart';
import 'file_browser_screen.dart';
import 'app_manager_screen.dart';
import 'device_info_screen.dart';
import 'backend_log_screen.dart';

enum NavItem { logcat, files, apps, info }

const _navConfig = {
  NavItem.logcat: _NavConfig(Icons.list_alt, 'Logcat', '日志'),
  NavItem.files:  _NavConfig(Icons.folder_open, 'Files', '文件'),
  NavItem.apps:   _NavConfig(Icons.android, 'Apps', '应用'),
  NavItem.info:   _NavConfig(Icons.info_outline, 'Info', '信息'),
};

class _NavConfig {
  final IconData icon;
  final String labelEn;
  final String labelZh;
  const _NavConfig(this.icon, this.labelEn, this.labelZh);
}

const _loc = {
  'zh': {
    'title': 'ADB 工具',
    'devices': '设备',
    'noDevices': '没有连接的设备',
    'noDevicesHint': '通过 USB 或 WiFi 连接设备',
    'unknown': '未知',
    'online': '在线', 'offline': '离线',
    'refresh': '刷新', 'theme': '主题', 'lang': '语言',
    'welcome': '请选择左侧设备和功能',
    'backendLogs': '后端日志',
  },
  'en': {
    'title': 'ADB Tool',
    'devices': 'Devices',
    'noDevices': 'No devices',
    'noDevicesHint': 'Connect via USB or WiFi',
    'unknown': 'Unknown',
    'online': 'Online', 'offline': 'Offline',
    'refresh': 'Refresh', 'theme': 'Theme', 'lang': 'Lang',
    'welcome': 'Select a device and function from the sidebar',
    'backendLogs': 'Backend Logs',
  },
};

const _backendLogKey = '_backend_logs';

class HomeScreen extends StatefulWidget {
  final ApiClient api;
  final LogStreamService logStream;
  final ValueChanged<bool> onThemeToggle;
  final bool isDark;

  const HomeScreen({
    super.key,
    required this.api,
    required this.logStream,
    required this.onThemeToggle,
    required this.isDark,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _lang = 'zh';
  List<Device> _devices = [];
  Timer? _refreshTimer;

  final Set<String> _expandedSerials = {};
  final Map<String, Widget> _screens = {};
  String? _activeKey;

  @override
  void initState() {
    super.initState();
    _refreshDevices();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshDevices());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String tr(String key) => _loc[_lang]?[key] ?? key;
  String navLabel(NavItem item) {
    final c = _navConfig[item]!;
    return _lang == 'zh' ? c.labelZh : c.labelEn;
  }

  Future<void> _refreshDevices() async {
    final devices = await widget.api.getDevices();
    if (!mounted) return;
    setState(() => _devices = devices);
  }

  void _toggleExpand(String serial) {
    setState(() {
      if (_expandedSerials.contains(serial)) {
        _expandedSerials.remove(serial);
      } else {
        _expandedSerials.add(serial);
        if (_screens.isEmpty) {
          _navigateTo(serial, NavItem.logcat);
        }
      }
    });
  }

  void _navigateTo(String serial, NavItem item) {
    final key = '${serial}_${item.name}';
    if (!_screens.containsKey(key)) {
      Widget screen;
      switch (item) {
        case NavItem.logcat:
          screen = LogcatScreen(
            api: widget.api,
            logStream: widget.logStream,
            selectedSerial: serial,
          );
        case NavItem.files:
          screen = FileBrowserScreen(
            api: widget.api,
            selectedSerial: serial,
          );
        case NavItem.apps:
          screen = AppManagerScreen(
            api: widget.api,
            selectedSerial: serial,
          );
        case NavItem.info:
          screen = DeviceInfoScreen(
            api: widget.api,
            selectedSerial: serial,
          );
      }
      _screens[key] = screen;
    }
    setState(() => _activeKey = key);
  }

  void _openBackendLogs() {
    if (!_screens.containsKey(_backendLogKey)) {
      _screens[_backendLogKey] = BackendLogScreen(api: widget.api);
    }
    setState(() => _activeKey = _backendLogKey);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(context),
          Expanded(child: _buildContent()),
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
            Icon(Icons.android, size: 64,
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

  Widget _buildSidebar(BuildContext context) {
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
          Expanded(child: _buildDeviceTree(theme)),
          const Divider(height: 1),
          _buildBackendLogsEntry(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.adb, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text('ADB Tool',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.brightness_6, size: 16),
            onPressed: () => widget.onThemeToggle(!widget.isDark),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: tr('theme'),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => setState(() => _lang = _lang == 'zh' ? 'en' : 'zh'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(_lang == 'zh' ? 'EN' : '文',
                  style: const TextStyle(fontSize: 10)),
            ),
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
              Icon(Icons.terminal, size: 16,
                  color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Text(
                tr('backendLogs'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface,
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

  Widget _buildDeviceTree(ThemeData theme) {
    if (_devices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.phone_android, size: 40,
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(100)),
              const SizedBox(height: 8),
              Text(tr('noDevices'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(tr('noDevicesHint'),
                  style: TextStyle(fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant.withAlpha(150))),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: _devices.map((d) => _buildDeviceNode(context, d, theme)).toList(),
    );
  }

  Widget _buildDeviceNode(BuildContext context, Device d, ThemeData theme) {
    final isExpanded = _expandedSerials.contains(d.serial);
    final hasActiveScreen = _screens.keys.any((k) => k.startsWith('${d.serial}_'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: hasActiveScreen ? theme.colorScheme.primaryContainer.withAlpha(80) : Colors.transparent,
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
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: d.isOnline ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      d.displayName,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    d.serial.length > 12 ? '...${d.serial.substring(d.serial.length - 8)}' : d.serial,
                    style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isExpanded)
          ...NavItem.values.where((item) => item != NavItem.info).map((item) => _buildFunctionItem(context, d, item, theme)),
      ],
    );
  }

  Widget _buildFunctionItem(BuildContext context, Device d, NavItem item, ThemeData theme) {
    final key = '${d.serial}_${item.name}';
    final c = _navConfig[item]!;
    final isActive = _activeKey == key;

    return Material(
      color: isActive ? theme.colorScheme.primaryContainer : Colors.transparent,
      child: InkWell(
        onTap: () => _navigateTo(d.serial, item),
        child: Padding(
          padding: const EdgeInsets.only(left: 42, right: 12, top: 6, bottom: 6),
          child: Row(
            children: [
              Icon(c.icon, size: 16,
                  color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Text(
                navLabel(item),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
