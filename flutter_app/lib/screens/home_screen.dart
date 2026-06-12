import 'dart:async';
import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/api_client.dart';
import '../services/log_stream.dart';

const _L = {
  'zh': {
    'title': 'ADB 工具',
    'devices': '设备',
    'noDevices': '没有连接的设备',
    'noDevicesHint': '通过 USB 或 WiFi 连接设备',
    'unknown': '未知',
    'start': '开始', 'stop': '停止', 'pause': '暂停',
    'resume': '继续', 'clear': '清空',
    'tag': '标签', 'package': '包名', 'level': '级别',
    'keyword': '关键词', 'autoScroll': '自动滚动',
    'status': '状态', 'lines': '行数', 'pid': '进程',
    'idle': '空闲', 'streaming': '采集中', 'paused': '已暂停',
    'stopped': '已停止',
    'online': '在线', 'offline': '离线',
    'selectDevice': '选择设备后点击开始查看日志',
    'logsHint': '日志将实时显示在这里',
    'all': '全部',
    'refresh': '刷新',
    'theme': '主题',
    'lang': '语言',
  },
  'en': {
    'title': 'ADB Tool',
    'devices': 'Devices',
    'noDevices': 'No devices',
    'noDevicesHint': 'Connect via USB or WiFi',
    'unknown': 'Unknown',
    'start': 'Start', 'stop': 'Stop', 'pause': 'Pause',
    'resume': 'Resume', 'clear': 'Clear',
    'tag': 'Tag', 'package': 'Package', 'level': 'Level',
    'keyword': 'Keyword', 'autoScroll': 'Auto-scroll',
    'status': 'Status', 'lines': 'Lines', 'pid': 'PID',
    'idle': 'Idle', 'streaming': 'Streaming', 'paused': 'Paused',
    'stopped': 'Stopped',
    'online': 'Online', 'offline': 'Offline',
    'selectDevice': 'Select a device and click Start',
    'logsHint': 'Logs will appear here in real-time',
    'all': 'All',
    'refresh': 'Refresh',
    'theme': 'Theme',
    'lang': 'Lang',
  },
};

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
  String? _selectedSerial;
  String? _packagePid;

  String _priority = 'W';
  String _tag = '';
  String _keyword = '';
  String _packageName = '';

  final List<LogEntry> _allEntries = [];
  StreamSubscription<LogEntry>? _logSub;
  bool _isStreaming = false;
  bool _isPaused = false;

  final ScrollController _scrollCtrl = ScrollController();
  bool _autoScroll = true;
  DateTime _lastScrollTime = DateTime.now();

  late final TextEditingController _tagCtrl;
  late final TextEditingController _kwCtrl;
  late final TextEditingController _pkgCtrl;

  String tr(String key) => _L[_lang]?[key] ?? key;

  @override
  void initState() {
    super.initState();
    _tagCtrl = TextEditingController();
    _kwCtrl = TextEditingController();
    _pkgCtrl = TextEditingController();
    _refreshDevices();
  }

  void _onUserScroll() {
    if (!_autoScroll || !_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels < _scrollCtrl.position.maxScrollExtent - 50) {
      setState(() => _autoScroll = false);
    }
  }

  Future<void> _refreshDevices() async {
    final devices = await widget.api.getDevices();
    if (!mounted) return;
    setState(() => _devices = devices);
    if (_selectedSerial != null && !devices.any((d) => d.serial == _selectedSerial)) {
      _selectedSerial = null;
      _packagePid = null;
    }
  }

  void _selectDevice(String serial) {
    setState(() {
      _selectedSerial = serial;
      _packagePid = null;
    });
  }

  LogFilter _buildFilter() => LogFilter(
    tag: _tag,
    priority: _priority,
    keyword: _keyword,
    packageName: _packageName,
    packagePid: _packagePid ?? '',
  );

  Future<void> _resolvePackage() async {
    if (_packageName.isEmpty || _selectedSerial == null) {
      setState(() => _packagePid = null);
      _restartIfNeeded();
      return;
    }
    final pid = await widget.api.getPackagePid(_selectedSerial!, _packageName);
    if (!mounted) return;
    setState(() => _packagePid = pid);
    _restartIfNeeded();
  }

  void _restartIfNeeded() {
    if (_isStreaming) {
      _stopAndStart();
    }
  }

  void _stopAndStart() {
    _logSub?.cancel();
    widget.logStream.stop();
    setState(() {
      _isStreaming = false;
      _allEntries.clear();
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _startLogs();
    });
  }

  void _startLogs() {
    if (_selectedSerial == null) return;
    _allEntries.clear();
    _logSub?.cancel();

    final filter = _buildFilter();
    _lastScrollTime = DateTime.now();
    widget.logStream.connect(_selectedSerial!, filter);
    _logSub = widget.logStream.logStream.listen(
      (entry) {
        if (!mounted) return;
        if (_allEntries.length >= 5000) {
          _allEntries.removeRange(0, 500);
        }
        setState(() => _allEntries.add(entry));
        _tryAutoScroll();
      },
    );

    setState(() {
      _isStreaming = true;
      _isPaused = false;
    });
  }

  void _tryAutoScroll() {
    if (!_autoScroll) return;
    final now = DateTime.now();
    if (now.difference(_lastScrollTime).inMilliseconds < 50) return;
    _lastScrollTime = now;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      final max = _scrollCtrl.position.maxScrollExtent;
      if (max > 0) _scrollCtrl.jumpTo(max);
    });
  }

  void _stopLogs() {
    widget.logStream.stop();
    _logSub?.cancel();
    setState(() {
      _isStreaming = false;
      _isPaused = false;
    });
  }

  void _pauseLogs() {
    widget.logStream.pause();
    setState(() => _isPaused = true);
  }

  void _resumeLogs() {
    widget.logStream.resume();
    setState(() => _isPaused = false);
  }

  void _clearLogs() {
    widget.logStream.clear();
    if (_selectedSerial != null) widget.api.clearLogcat(_selectedSerial!);
    setState(() => _allEntries.clear());
  }

  List<LogEntry> get _displayedEntries {
    return _allEntries
        .where((e) => e.matchesFilter(_buildFilter()))
        .toList();
  }

  @override
  void dispose() {
    _tagCtrl.dispose();
    _kwCtrl.dispose();
    _pkgCtrl.dispose();
    _scrollCtrl.dispose();
    _logSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _displayedEntries;
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(context),
          Expanded(
            child: Column(
              children: [
                _buildToolbar(context),
                Expanded(child: _buildLogList(context, entries)),
                _buildStatusBar(context, entries),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(right: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text(tr('devices'),
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.brightness_6, size: 18),
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
          ),
          const Divider(height: 1),
          Expanded(
            child: _devices.isEmpty
                ? Center(
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
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _devices.length,
                    itemBuilder: (ctx, i) => _buildDeviceCard(context, _devices[i], theme),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, Device d, ThemeData theme) {
    final isSelected = d.serial == _selectedSerial;
    return Card(
      elevation: 0,
      color: isSelected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _selectDevice(d.serial),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d.serial,
                  style: const TextStyle(fontSize: 12, fontFamily: 'Menlo'),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(d.displayName,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: d.isOnline ? Colors.green.withAlpha(30) : Colors.red.withAlpha(30),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(tr(d.isOnline ? 'online' : 'offline'),
                        style: TextStyle(fontSize: 10,
                            color: d.isOnline ? Colors.green : Colors.red)),
                  ),
                  if (d.sdk.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('SDK ${d.sdk}',
                          style: TextStyle(fontSize: 10, color: theme.colorScheme.primary)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Wrap(
        spacing: 6, runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _btn(tr('start'), Icons.play_arrow,
              !_isStreaming, _selectedSerial == null ? null : _startLogs, true),
          _btn(tr('stop'), Icons.stop, _isStreaming, _stopLogs, false),
          _btn(tr('pause'), Icons.pause, _isStreaming && !_isPaused, _pauseLogs, false),
          _btn(tr('resume'), Icons.play_arrow, _isPaused, _resumeLogs, false),
          _btn(tr('clear'), Icons.delete_outline,
              _isStreaming || _allEntries.isNotEmpty, _clearLogs, false),
          const SizedBox(width: 4),
          _sep(),
          _buildTagFilter(),
          _buildPriortyFilter(),
          _buildKeywordFilter(),
          _sep(),
          _buildPackageFilter(),
          _sep(),
          _buildAutoScrollToggle(),
        ],
      ),
    );
  }

  Widget _sep() => Container(width: 1, height: 20, color: Theme.of(context).dividerColor);

  Widget _btn(String label, IconData icon, bool enabled, VoidCallback? onTap, bool primary) {
    final child = Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16), const SizedBox(width: 4), Text(label),
    ]);
    return SizedBox(
      height: 32,
      child: primary
          ? FilledButton(
              onPressed: enabled ? onTap : null,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), textStyle: const TextStyle(fontSize: 12)),
              child: child,
            )
          : FilledButton.tonal(
              onPressed: enabled ? onTap : null,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), textStyle: const TextStyle(fontSize: 12)),
              child: child,
            ),
    );
  }

  Widget _buildTagFilter() {
    return SizedBox(
      width: 120,
      child: TextField(
        controller: _tagCtrl,
        onChanged: (v) => setState(() => _tag = v),
        decoration: InputDecoration(
          labelText: tr('tag'),
          labelStyle: const TextStyle(fontSize: 11),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6))),
        ),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildPriortyFilter() {
    const levels = ['', 'V', 'D', 'I', 'W', 'E', 'F'];
    return SizedBox(
      width: 85,
      child: DropdownButtonFormField<String>(
        value: _priority,
        decoration: InputDecoration(
          labelText: tr('level'),
          labelStyle: const TextStyle(fontSize: 11),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6))),
        ),
        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
        dropdownColor: Theme.of(context).colorScheme.surface,
        items: levels.map((l) => DropdownMenuItem(
              value: l,
              child: Text(l.isEmpty ? tr('all') : l,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface)),
            )).toList(),
        onChanged: (v) {
          final old = _priority;
          setState(() => _priority = v ?? '');
          if (old != _priority) _restartIfNeeded();
        },
      ),
    );
  }

  Widget _buildKeywordFilter() {
    return SizedBox(
      width: 130,
      child: TextField(
        controller: _kwCtrl,
        onChanged: (v) => setState(() => _keyword = v),
        decoration: InputDecoration(
          labelText: tr('keyword'),
          labelStyle: const TextStyle(fontSize: 11),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6))),
        ),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildPackageFilter() {
    return SizedBox(
      width: 180,
      child: TextField(
        controller: _pkgCtrl,
        onSubmitted: (v) {
          setState(() => _packageName = v.trim());
          _resolvePackage();
        },
        decoration: InputDecoration(
          labelText: tr('package'),
          labelStyle: const TextStyle(fontSize: 11),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6))),
          suffixIcon: _packagePid != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 12, right: 4),
                  child: Text('PID:$_packagePid',
                      style: TextStyle(fontSize: 9, color: Colors.green.shade300)),
                )
              : null,
        ),
        style: const TextStyle(fontSize: 11, fontFamily: 'Menlo'),
      ),
    );
  }

  Widget _buildAutoScrollToggle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 24, width: 24,
          child: Checkbox(
            value: _autoScroll,
            onChanged: (v) {
              setState(() => _autoScroll = v ?? true);
              if (_autoScroll && _scrollCtrl.hasClients) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final max = _scrollCtrl.position.maxScrollExtent;
                  if (max > 0) _scrollCtrl.jumpTo(max);
                });
              }
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 4),
        Text(tr('autoScroll'), style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildLogList(BuildContext context, List<LogEntry> entries) {
    final theme = Theme.of(context);
    if (!_isStreaming && entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, size: 48,
                color: theme.colorScheme.onSurfaceVariant.withAlpha(80)),
            const SizedBox(height: 12),
            Text(tr('selectDevice'),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(tr('logsHint'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant.withAlpha(150))),
          ],
        ),
      );
    }
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (n) {
        if (n.dragDetails != null) _onUserScroll();
        return false;
      },
      child: ListView.builder(
        controller: _scrollCtrl,
        itemCount: entries.length,
        padding: EdgeInsets.zero,
        itemBuilder: (ctx, i) => _buildLogEntry(context, entries[i]),
      ),
    );
  }

  Widget _buildLogEntry(BuildContext context, LogEntry entry) {
    final theme = Theme.of(context);
    final mono = const TextStyle(fontFamily: 'Menlo', height: 1.5);

    if (entry.isContinuation) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Text('│ ', style: mono.copyWith(fontSize: 12, color: theme.dividerColor)),
          Expanded(child: Text(entry.message, style: mono.copyWith(fontSize: 12, color: theme.colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
      );
    }
    if (entry.time.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(entry.raw, style: mono.copyWith(fontSize: 12, color: theme.colorScheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
      );
    }

    final prioColor = _prioColor(entry.priority, theme);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        SizedBox(width: 130, child: Text(entry.time, style: mono.copyWith(fontSize: 11, color: theme.colorScheme.onSurfaceVariant))),
        SizedBox(width: 70, child: Text('${entry.pid} ${entry.tid}', style: mono.copyWith(fontSize: 11, color: Colors.green.shade300))),
        Container(
          width: 24, alignment: Alignment.center,
          decoration: BoxDecoration(color: prioColor.withAlpha(30), borderRadius: BorderRadius.circular(3)),
          child: Text(entry.priority, style: mono.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: prioColor)),
        ),
        const SizedBox(width: 4),
        Text(entry.tag, style: mono.copyWith(fontSize: 11, color: theme.colorScheme.primary)),
        const SizedBox(width: 4),
        Expanded(child: Text(entry.message, style: mono.copyWith(fontSize: 11, color: theme.colorScheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Color _prioColor(String prio, ThemeData theme) {
    switch (prio) {
      case 'V': return theme.colorScheme.onSurfaceVariant;
      case 'D': return Colors.blue;
      case 'I': return Colors.green;
      case 'W': return Colors.orange;
      case 'E': return Colors.red;
      case 'F': return Colors.purple;
      default:  return theme.colorScheme.onSurfaceVariant;
    }
  }

  Widget _buildStatusBar(BuildContext context, List<LogEntry> entries) {
    final theme = Theme.of(context);
    final statusStr = _isPaused ? tr('paused') : _isStreaming ? tr('streaming') : tr('idle');
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(children: [
        Text('${tr('status')}: $statusStr', style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 16),
        Text('${tr('lines')}: ${entries.length}', style: const TextStyle(fontSize: 11)),
        if (_packagePid != null) ...[
          const Spacer(),
          Text('${tr('pid')}: $_packagePid', style: TextStyle(fontSize: 11, color: theme.colorScheme.primary)),
        ],
      ]),
    );
  }
}
