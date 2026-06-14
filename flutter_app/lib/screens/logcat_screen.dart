import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device.dart';
import '../services/api_client.dart';
import '../i18n.dart';
import '../services/log_stream.dart';

class LogcatScreen extends StatefulWidget {
  final String? selectedSerial;

  const LogcatScreen({
    super.key,
    required this.selectedSerial,
  });

  @override
  State<LogcatScreen> createState() => _LogcatScreenState();
}

class _LogcatScreenState extends State<LogcatScreen> {
  String? _packagePid;

  String _priority = 'D';
  String _tag = '';
  String _keyword = '';
  String _packageName = '';

  final List<LogEntry> _allEntries = [];
  final List<LogEntry> _displayedEntries = [];
  final List<LogEntry> _pendingEntries = [];
  Timer? _flushTimer;
  StreamSubscription<List<LogEntry>>? _logSub;
  StreamSubscription<bool>? _connSub;
  bool _isStreaming = false;
  bool _isPaused = false;
  bool _wsConnected = false;

  bool get _hasLogs =>
      _allEntries.isNotEmpty ||
      _displayedEntries.isNotEmpty ||
      _pendingEntries.isNotEmpty;

  final ScrollController _scrollCtrl = ScrollController();
  bool _autoScroll = true;
  bool _stickToBottomScheduled = false;
  bool _autoScrollSuspendedByUser = false;

  late final TextEditingController _tagCtrl;
  late final TextEditingController _kwCtrl;
  late final TextEditingController _pkgCtrl;

  @override
  void initState() {
    super.initState();
    _tagCtrl = TextEditingController();
    _kwCtrl = TextEditingController();
    _pkgCtrl = TextEditingController();
  }

  void _onUserScroll() {
    if (!_scrollCtrl.hasClients) return;
    final distanceFromBottom =
        _scrollCtrl.position.maxScrollExtent - _scrollCtrl.position.pixels;
    if (distanceFromBottom > 80 && _autoScroll) {
      setState(() {
        _autoScroll = false;
        _autoScrollSuspendedByUser = true;
      });
    } else if (distanceFromBottom <= 24 && _autoScrollSuspendedByUser) {
      setState(() {
        _autoScroll = true;
        _autoScrollSuspendedByUser = false;
      });
      _stickToBottom();
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
        await context.read<ApiClient>().getPackagePid(widget.selectedSerial!, _packageName);
    if (!mounted) return;
    setState(() => _packagePid = pid);
    _restartIfNeeded();
  }

  void _restartIfNeeded() {
    if (_isStreaming) {
      _flushPendingEntries();
      _stopAndStart();
    }
  }

  void _stopAndStart() {
    _logSub?.cancel();
    _flushTimer?.cancel();
    context.read<LogStreamService>().stop();
    setState(() {
      _isStreaming = false;
      _allEntries.clear();
      _displayedEntries.clear();
      _pendingEntries.clear();
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _startLogs();
    });
  }

  void _startLogs() {
    if (widget.selectedSerial == null) return;
    _allEntries.clear();
    _displayedEntries.clear();
    _pendingEntries.clear();
    _flushTimer?.cancel();
    _logSub?.cancel();

    final filter = _buildFilter();
    context.read<LogStreamService>().connect(widget.selectedSerial!, filter);
    _connSub?.cancel();
    _connSub = context.read<LogStreamService>().connectionState.listen(
      (connected) {
        if (!mounted) return;
        setState(() => _wsConnected = connected);
      },
    );
    _flushTimer = Timer.periodic(
      const Duration(milliseconds: 80),
      (_) => _flushPendingEntries(),
    );
    _logSub = context.read<LogStreamService>().logStream.listen(
      (entries) {
        if (!mounted || entries.isEmpty) return;
        _pendingEntries.addAll(entries);
        if (_pendingEntries.length >= 300) {
          _flushPendingEntries();
        }
      },
    );

    setState(() {
      _isStreaming = true;
      _isPaused = false;
    });
  }

  void _flushPendingEntries() {
    if (!mounted || _pendingEntries.isEmpty) return;
    final entries = List<LogEntry>.from(_pendingEntries);
    _pendingEntries.clear();
    setState(() {
      _allEntries.addAll(entries);
      _displayedEntries.addAll(entries);
      if (_allEntries.length > 5000) {
        final extra = _allEntries.length - 5000;
        final removed = _allEntries.sublist(0, extra);
        _allEntries.removeRange(0, extra);
        for (final entry in removed) {
          final index = _displayedEntries.indexOf(entry);
          if (index >= 0) {
            _displayedEntries.removeAt(index);
          }
        }
      }
    });
    _tryAutoScroll();
  }

  void _refreshDisplayedEntries() {
    final filter = _buildFilter();
    setState(() {
      _displayedEntries
        ..clear()
        ..addAll(_allEntries.where((e) => e.matchesFilter(filter)));
    });
  }

  void _tryAutoScroll() {
    if (!_autoScroll) return;
    _stickToBottom();
  }

  void _stickToBottom() {
    if (_stickToBottomScheduled) return;
    _stickToBottomScheduled = true;
    void jumpAfterFrame(int remainingFrames) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          _stickToBottomScheduled = false;
          return;
        }
        if (!_autoScroll || !_scrollCtrl.hasClients) {
          _stickToBottomScheduled = false;
          return;
        }
        final max = _scrollCtrl.position.maxScrollExtent;
        if (max > 0) {
          _scrollCtrl.jumpTo(max);
        }
        if (remainingFrames > 0) {
          jumpAfterFrame(remainingFrames - 1);
        } else {
          _stickToBottomScheduled = false;
        }
      });
    }

    jumpAfterFrame(2);
  }

  void _stopLogs() {
    _flushPendingEntries();
    context.read<LogStreamService>().stop();
    _logSub?.cancel();
    _flushTimer?.cancel();
    setState(() {
      _isStreaming = false;
      _isPaused = false;
    });
  }

  void _pauseLogs() {
    context.read<LogStreamService>().pause();
    setState(() => _isPaused = true);
  }

  void _resumeLogs() {
    context.read<LogStreamService>().resume();
    setState(() => _isPaused = false);
  }

  void _clearLogs() {
    setState(() {
      _allEntries.clear();
      _displayedEntries.clear();
      _pendingEntries.clear();
    });
    if (_isStreaming) {
      context.read<LogStreamService>().clear();
    }
    if (widget.selectedSerial != null) {
      context.read<ApiClient>().clearLogcat(widget.selectedSerial!);
    }
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(context),
        Expanded(child: _buildLogList(context, _displayedEntries)),
        _buildStatusBar(context, _displayedEntries),
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
            _btn(tr('clear'), Icons.delete_outline, _isStreaming || _hasLogs,
                _clearLogs, false),
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
        onChanged: (v) {
          _tag = v;
          _refreshDisplayedEntries();
          if (_isStreaming) context.read<LogStreamService>().updateFilter(_buildFilter());
        },
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
          if (old != _priority) {
            _flushPendingEntries();
            _restartIfNeeded();
          }
        },
      ),
    );
  }

  Widget _buildKeywordFilter() {
    return SizedBox(
      width: 130,
      child: TextField(
        controller: _kwCtrl,
        onChanged: (v) {
          _keyword = v;
          _refreshDisplayedEntries();
          if (_isStreaming) context.read<LogStreamService>().updateFilter(_buildFilter());
        },
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
              setState(() {
                _autoScroll = v ?? true;
                _autoScrollSuspendedByUser = false;
              });
              if (_autoScroll) {
                _stickToBottom();
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
            Text(tr('logcatSelectDevice'),
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
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is UserScrollNotification ||
            (n is ScrollUpdateNotification && n.dragDetails != null)) {
          _onUserScroll();
        }
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
