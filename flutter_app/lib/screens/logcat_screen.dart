import 'dart:async';
import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/api_client.dart';
import '../services/log_stream.dart';

const _loc = {
  'zh': {
    'start': '开始',
    'stop': '停止',
    'pause': '暂停',
    'resume': '继续',
    'clear': '清空',
    'tag': '标签',
    'package': '包名',
    'level': '级别',
    'keyword': '关键词',
    'autoScroll': '自动滚动',
    'status': '状态',
    'lines': '行数',
    'pid': '进程',
    'idle': '空闲',
    'streaming': '采集中',
    'paused': '已暂停',
    'stopped': '已停止',
    'selectDevice': '选择设备后点击开始查看日志',
    'logsHint': '日志将实时显示在这里',
    'all': '全部',
  },
  'en': {
    'start': 'Start',
    'stop': 'Stop',
    'pause': 'Pause',
    'resume': 'Resume',
    'clear': 'Clear',
    'tag': 'Tag',
    'package': 'Package',
    'level': 'Level',
    'keyword': 'Keyword',
    'autoScroll': 'Auto-scroll',
    'status': 'Status',
    'lines': 'Lines',
    'pid': 'PID',
    'idle': 'Idle',
    'streaming': 'Streaming',
    'paused': 'Paused',
    'stopped': 'Stopped',
    'selectDevice': 'Select a device and click Start',
    'logsHint': 'Logs will appear here in real-time',
    'all': 'All',
  },
};

class LogcatScreen extends StatefulWidget {
  final ApiClient api;
  final LogStreamService logStream;
  final String? selectedSerial;

  const LogcatScreen({
    super.key,
    required this.api,
    required this.logStream,
    required this.selectedSerial,
  });

  @override
  State<LogcatScreen> createState() => _LogcatScreenState();
}

class _LogcatScreenState extends State<LogcatScreen> {
  String _lang = 'zh';
  String? _packagePid;

  String _priority = 'W';
  String _tag = '';
  String _keyword = '';
  String _packageName = '';

  final List<LogEntry> _allEntries = [];
  StreamSubscription<LogEntry>? _logSub;
  StreamSubscription<bool>? _connSub;
  bool _isStreaming = false;
  bool _isPaused = false;
  bool _wsConnected = false;

  final ScrollController _scrollCtrl = ScrollController();
  bool _autoScroll = true;
  DateTime _lastScrollTime = DateTime.now();

  late final TextEditingController _tagCtrl;
  late final TextEditingController _kwCtrl;
  late final TextEditingController _pkgCtrl;

  String tr(String key) => _loc[_lang]?[key] ?? key;

  @override
  void initState() {
    super.initState();
    _tagCtrl = TextEditingController();
    _kwCtrl = TextEditingController();
    _pkgCtrl = TextEditingController();
  }

  @override
  void didUpdateWidget(LogcatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSerial != widget.selectedSerial) {
      if (_isStreaming) {
        _stopLogs();
      }
      _packagePid = null;
      _packageName = '';
      _pkgCtrl.clear();
    }
  }

  void _onUserScroll() {
    if (!_autoScroll || !_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels <
        _scrollCtrl.position.maxScrollExtent - 50) {
      setState(() => _autoScroll = false);
    }
  }

  LogFilter _buildFilter() => LogFilter(
        tag: _tag,
        priority: _priority,
        keyword: _keyword,
        packageName: _packageName,
        packagePid: _packagePid ?? '',
      );

  Future<void> _resolvePackage() async {
    if (_packageName.isEmpty || widget.selectedSerial == null) {
      setState(() => _packagePid = null);
      _restartIfNeeded();
      return;
    }
    final pid =
        await widget.api.getPackagePid(widget.selectedSerial!, _packageName);
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
    if (widget.selectedSerial == null) return;
    _allEntries.clear();
    _logSub?.cancel();

    final filter = _buildFilter();
    _lastScrollTime = DateTime.now();
    widget.logStream.connect(widget.selectedSerial!, filter);
    _connSub?.cancel();
    _connSub = widget.logStream.connectionState.listen(
      (connected) {
        if (!mounted) return;
        setState(() => _wsConnected = connected);
      },
    );
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
    if (widget.selectedSerial != null)
      widget.api.clearLogcat(widget.selectedSerial!);
    setState(() => _allEntries.clear());
  }

  List<LogEntry> get _displayedEntries {
    return _allEntries.where((e) => e.matchesFilter(_buildFilter())).toList();
  }

  @override
  void dispose() {
    _tagCtrl.dispose();
    _kwCtrl.dispose();
    _pkgCtrl.dispose();
    _scrollCtrl.dispose();
    _logSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _displayedEntries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(context),
        Expanded(child: _buildLogList(context, entries)),
        _buildStatusBar(context, entries),
      ],
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _btn(tr('start'), Icons.play_arrow, !_isStreaming,
                widget.selectedSerial == null ? null : _startLogs, true),
            const SizedBox(width: 4),
            _btn(tr('stop'), Icons.stop, _isStreaming, _stopLogs, false),
            const SizedBox(width: 4),
            _btn(tr('pause'), Icons.pause, _isStreaming && !_isPaused,
                _pauseLogs, false),
            const SizedBox(width: 4),
            _btn(tr('resume'), Icons.play_arrow, _isPaused, _resumeLogs, false),
            const SizedBox(width: 4),
            _btn(tr('clear'), Icons.delete_outline,
                _isStreaming || _allEntries.isNotEmpty, _clearLogs, false),
            const SizedBox(width: 12),
            _sep(),
            const SizedBox(width: 12),
            _buildTagFilter(),
            const SizedBox(width: 8),
            _buildPriortyFilter(),
            const SizedBox(width: 8),
            _buildKeywordFilter(),
            const SizedBox(width: 16),
            _sep(),
            const SizedBox(width: 12),
            _buildPackageFilter(),
            const SizedBox(width: 12),
            _sep(),
            const SizedBox(width: 12),
            _buildAutoScrollToggle(),
          ],
        ),
      ),
    );
  }

  Widget _sep() =>
      Container(width: 1, height: 20, color: Theme.of(context).dividerColor);

  Widget _btn(String label, IconData icon, bool enabled, VoidCallback? onTap,
      bool primary) {
    final child = Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16),
      const SizedBox(width: 4),
      Text(label),
    ]);
    return SizedBox(
      height: 32,
      child: primary
          ? FilledButton(
              onPressed: enabled ? onTap : null,
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(fontSize: 12)),
              child: child,
            )
          : FilledButton.tonal(
              onPressed: enabled ? onTap : null,
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(fontSize: 12)),
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(6))),
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
        initialValue: _priority,
        decoration: InputDecoration(
          labelText: tr('level'),
          labelStyle: const TextStyle(fontSize: 11),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(6))),
        ),
        style: TextStyle(
            fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
        dropdownColor: Theme.of(context).colorScheme.surface,
        items: levels
            .map((l) => DropdownMenuItem(
                  value: l,
                  child: Text(l.isEmpty ? tr('all') : l,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface)),
                ))
            .toList(),
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(6))),
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(6))),
          suffixIcon: _packagePid != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 12, right: 4),
                  child: Text('PID:$_packagePid',
                      style:
                          TextStyle(fontSize: 9, color: Colors.green.shade300)),
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
          height: 24,
          width: 24,
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
            Icon(Icons.article_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant.withAlpha(80)),
            const SizedBox(height: 12),
            Text(tr('selectDevice'),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(tr('logsHint'),
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(150))),
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
    const mono = TextStyle(fontFamily: 'Menlo', height: 1.5);

    if (entry.isContinuation) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Text('│ ',
              style: mono.copyWith(fontSize: 12, color: theme.dividerColor)),
          Expanded(
              child: Text(entry.message,
                  style: mono.copyWith(
                      fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
        ]),
      );
    }
    if (entry.time.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(entry.raw,
            style:
                mono.copyWith(fontSize: 12, color: theme.colorScheme.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      );
    }

    final prioColor = _prioColor(entry.priority, theme);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        SizedBox(
            width: 130,
            child: Text(entry.time,
                style: mono.copyWith(
                    fontSize: 11, color: theme.colorScheme.onSurfaceVariant))),
        SizedBox(
            width: 70,
            child: Text('${entry.pid} ${entry.tid}',
                style:
                    mono.copyWith(fontSize: 11, color: Colors.green.shade300))),
        Container(
          width: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: prioColor.withAlpha(30),
              borderRadius: BorderRadius.circular(3)),
          child: Text(entry.priority,
              style: mono.copyWith(
                  fontSize: 11, fontWeight: FontWeight.w700, color: prioColor)),
        ),
        const SizedBox(width: 4),
        Text(entry.tag,
            style:
                mono.copyWith(fontSize: 11, color: theme.colorScheme.primary)),
        const SizedBox(width: 4),
        Expanded(
            child: Text(entry.message,
                style: mono.copyWith(
                    fontSize: 11, color: theme.colorScheme.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Color _prioColor(String prio, ThemeData theme) {
    switch (prio) {
      case 'V':
        return theme.colorScheme.onSurfaceVariant;
      case 'D':
        return Colors.blue;
      case 'I':
        return Colors.green;
      case 'W':
        return Colors.orange;
      case 'E':
        return Colors.red;
      case 'F':
        return Colors.purple;
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  Widget _buildStatusBar(BuildContext context, List<LogEntry> entries) {
    final theme = Theme.of(context);
    final statusStr = _isPaused
        ? tr('paused')
        : _isStreaming
            ? tr('streaming')
            : tr('idle');
    final wsColor = _wsConnected ? Colors.green : Colors.red;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(children: [
        Text('${tr('status')}: $statusStr',
            style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 16),
        Text('${tr('lines')}: ${entries.length}',
            style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 16),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: wsColor),
        ),
        if (_packagePid != null) ...[
          const Spacer(),
          Text('${tr('pid')}: $_packagePid',
              style: TextStyle(fontSize: 11, color: theme.colorScheme.primary)),
        ],
      ]),
    );
  }
}
