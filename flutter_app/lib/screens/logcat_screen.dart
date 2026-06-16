import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device.dart';
import '../models/test_config.dart';
import '../services/api_client.dart';
import '../i18n.dart';
import '../services/log_stream.dart';
import '../providers/locale_provider.dart';
import '../providers/device_provider.dart';
import '../providers/test_session_provider.dart';
import '../providers/test_config_provider.dart';

class _HighlightRule {
  final String label;
  final String pattern;
  final Color color;
  final bool builtin;
  bool enabled;

  _HighlightRule({
    required this.label,
    required this.pattern,
    required this.color,
    required this.builtin,
    required this.enabled,
  });

  bool matches(LogEntry entry) {
    final target = entry.raw.isEmpty ? entry.message : entry.raw;
    return target.toLowerCase().contains(pattern.toLowerCase());
  }
}

class LogcatScreen extends StatefulWidget {
  const LogcatScreen({
    super.key,
  });

  @override
  State<LogcatScreen> createState() => _LogcatScreenState();
}

class _LogcatScreenState extends State<LogcatScreen> {
  String? get _selectedSerial => context.read<DeviceSerialScope>().serial;

  String? _packagePid;

  String _priority = 'D';
  String _tag = '';
  String _keyword = '';
  String _packageName = '';

  final List<_HighlightRule> _highlightRules = [
    _HighlightRule(
      label: 'Crash',
      pattern: 'FATAL EXCEPTION',
      color: Colors.red,
      builtin: true,
      enabled: true,
    ),
    _HighlightRule(
      label: 'AndroidRuntime',
      pattern: 'AndroidRuntime',
      color: Colors.redAccent,
      builtin: true,
      enabled: true,
    ),
    _HighlightRule(
      label: 'Network',
      pattern: 'http',
      color: Colors.cyan,
      builtin: true,
      enabled: true,
    ),
    _HighlightRule(
      label: 'OkHttp',
      pattern: 'okhttp',
      color: Colors.lightBlue,
      builtin: true,
      enabled: true,
    ),
  ];

  final List<Color> _customRuleColors = [
    Colors.amber,
    Colors.pinkAccent,
    Colors.deepPurpleAccent,
    Colors.tealAccent,
    Colors.limeAccent,
    Colors.orangeAccent,
  ];

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
  Timer? _autoScrollTimer;
  bool _autoScrollSuspendedByUser = false;

  late final TextEditingController _tagCtrl;
  late final TextEditingController _kwCtrl;
  late final TextEditingController _pkgCtrl;
  late final TextEditingController _ruleCtrl;
  String? _lastAppliedConfigId;

  @override
  void initState() {
    super.initState();
    _tagCtrl = TextEditingController();
    _kwCtrl = TextEditingController();
    _pkgCtrl = TextEditingController();
    _ruleCtrl = TextEditingController();
  }

  void _applyConfig(TestAppConfig config) {
    final pkgChanged = config.packageName.isNotEmpty;
    _pkgCtrl.text = config.packageName;
    _packageName = config.packageName;
    _tagCtrl.text = config.logcat.tags.join(', ');
    _tag = config.logcat.tags.join(', ');
    _kwCtrl.text = config.logcat.keywords.join(', ');
    _keyword = config.logcat.keywords.join(', ');
    if (config.logcat.defaultLevel.isNotEmpty) {
      _priority = config.logcat.defaultLevel;
    }
    if (pkgChanged) {
      _resolvePackage();
    }
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
      _jumpToBottomAfterFrame();
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
    final serial = _selectedSerial;
    if (_packageName.isEmpty || serial == null) {
      setState(() => _packagePid = null);
      _restartIfNeeded();
      return;
    }
    final pid =
        await context.read<ApiClient>().getPackagePid(serial, _packageName);
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
    final serial = _selectedSerial;
    if (serial == null) return;
    _allEntries.clear();
    _displayedEntries.clear();
    _pendingEntries.clear();
    _flushTimer?.cancel();
    _logSub?.cancel();

    final filter = _buildFilter();
    context.read<LogStreamService>().connect(serial, filter);
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

  bool _isCrashEntry(LogEntry entry) {
    final raw = entry.raw.toLowerCase();
    final message = entry.message.toLowerCase();
    return raw.contains('fatal exception') ||
        raw.contains('androidruntime') ||
        raw.contains('exception') ||
        raw.contains('error') ||
        message.startsWith('caused by:') ||
        message.startsWith('at ') ||
        entry.priority == 'E' ||
        entry.priority == 'F';
  }

  bool _isNetworkEntry(LogEntry entry) {
    final raw = entry.raw.toLowerCase();
    return raw.contains('http://') ||
        raw.contains('https://') ||
        raw.contains(' okhttp') ||
        raw.contains('okhttp') ||
        raw.contains('retrofit') ||
        raw.contains('volley') ||
        raw.contains('grpc') ||
        raw.contains('socket') ||
        raw.contains('dns') ||
        raw.contains('response') ||
        raw.contains('request');
  }

  _HighlightRule? _matchingHighlightRule(LogEntry entry) {
    for (final rule in _highlightRules) {
      if (rule.enabled &&
          rule.pattern.trim().isNotEmpty &&
          rule.matches(entry)) {
        return rule;
      }
    }
    if (_isCrashEntry(entry)) {
      return _HighlightRule(
        label: tr('logRuleCrash'),
        pattern: 'crash',
        color: Colors.red,
        builtin: true,
        enabled: true,
      );
    }
    if (_isNetworkEntry(entry)) {
      return _HighlightRule(
        label: tr('logRuleNetwork'),
        pattern: 'network',
        color: Colors.cyan,
        builtin: true,
        enabled: true,
      );
    }
    return null;
  }

  void _tryAutoScroll() {
    if (!_autoScroll) return;
    _autoScrollTimer ??= Timer(const Duration(milliseconds: 120), () {
      _autoScrollTimer = null;
      _jumpToBottomAfterFrame();
    });
  }

  void _jumpToBottomAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_autoScroll || !_scrollCtrl.hasClients) return;
      final max = _scrollCtrl.position.maxScrollExtent;
      if (max > 0 && _scrollCtrl.position.pixels != max) {
        _scrollCtrl.jumpTo(max);
      }
    });
  }

  void _animateToBottomAfterFrame() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      final max = _scrollCtrl.position.maxScrollExtent;
      if (max <= 0) return;
      _scrollCtrl.animateTo(
        max,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
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

  Future<void> _saveLogsToSession() async {
    _flushPendingEntries();
    if (_allEntries.isEmpty) return;
    final content = _allEntries.map((entry) => entry.raw).join('\n');
    try {
      final path =
          await context.read<TestSessionProvider>().saveLogcat(content);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('logcatSavedToSession', {'path': path})),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr('saveFailed')}: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
    final serial = _selectedSerial;
    if (serial != null) {
      context.read<ApiClient>().clearLogcat(serial);
    }
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    _tagCtrl.dispose();
    _kwCtrl.dispose();
    _pkgCtrl.dispose();
    _ruleCtrl.dispose();
    _scrollCtrl.dispose();
    _logSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
    final config = context.watch<TestConfigProvider>().currentApp;
    final configId = config?.id;
    if (configId != null && configId != _lastAppliedConfigId) {
      _lastAppliedConfigId = configId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyConfig(config!);
      });
    } else if (configId == null) {
      _lastAppliedConfigId = null;
    }
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
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _btn(tr('start'), Icons.play_arrow, !_isStreaming,
              _selectedSerial == null ? null : _startLogs, true),
          _btn(tr('stop'), Icons.stop, _isStreaming, _stopLogs, false),
          _btn(tr('pause'), Icons.pause, _isStreaming && !_isPaused, _pauseLogs,
              false),
          _btn(tr('resume'), Icons.play_arrow, _isPaused, _resumeLogs, false),
          _btn(tr('clear'), Icons.delete_outline, _isStreaming || _hasLogs,
              _clearLogs, false),
          _btn(
              tr('saveToSession'),
              Icons.save_alt,
              _hasLogs &&
                  context.watch<TestSessionProvider>().hasRunningSession,
              _saveLogsToSession,
              false),
          _sep(),
          _buildTagFilter(),
          _buildPriortyFilter(),
          _buildKeywordFilter(),
          _sep(),
          _buildPackageFilter(),
          _sep(),
          _buildHighlightRulesButton(),
          _sep(),
          _buildAutoScrollToggle(),
        ],
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
          if (_isStreaming) {
            context.read<LogStreamService>().updateFilter(_buildFilter());
          }
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
          if (_isStreaming) {
            context.read<LogStreamService>().updateFilter(_buildFilter());
          }
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

  Widget _buildHighlightRulesButton() {
    final enabledCount = _highlightRules.where((r) => r.enabled).length;
    return SizedBox(
      height: 32,
      child: FilledButton.tonalIcon(
        onPressed: _showHighlightRulesDialog,
        icon: const Icon(Icons.color_lens_outlined, size: 16),
        label: Text('${tr('highlightRules')} $enabledCount'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(fontSize: 12),
        ),
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
                _animateToBottomAfterFrame();
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

  Future<void> _showHighlightRulesDialog() async {
    _ruleCtrl.clear();
    Color selectedColor = _customRuleColors.first;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              scrollable: true,
              title: Text(tr('highlightRules')),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(tr('builtinRules'),
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 8),
                      ..._highlightRules.map((rule) => _buildRuleTile(
                            rule,
                            setDialogState,
                          )),
                      const SizedBox(height: 16),
                      Text(tr('customRule'),
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _ruleCtrl,
                        decoration: InputDecoration(
                          labelText: tr('customRuleKeyword'),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _customRuleColors
                            .map(
                              (color) => InkWell(
                                onTap: () => setDialogState(() {
                                  selectedColor = color;
                                }),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selectedColor == color
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonalIcon(
                          onPressed: () {
                            final keyword = _ruleCtrl.text.trim();
                            if (keyword.isEmpty) return;
                            setState(() {
                              _highlightRules.add(_HighlightRule(
                                label: keyword,
                                pattern: keyword,
                                color: selectedColor,
                                builtin: false,
                                enabled: true,
                              ));
                            });
                            setDialogState(() => _ruleCtrl.clear());
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(tr('addRule')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(tr('close')),
                ),
              ],
            );
          },
        );
      },
    );
    _refreshDisplayedEntries();
  }

  Widget _buildRuleTile(_HighlightRule rule, StateSetter setDialogState) {
    return CheckboxListTile(
      dense: true,
      value: rule.enabled,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: rule.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${rule.label}  /${rule.pattern}/',
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!rule.builtin)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() => _highlightRules.remove(rule));
                setDialogState(() {});
              },
            ),
        ],
      ),
      onChanged: (v) {
        setState(() => rule.enabled = v ?? true);
        setDialogState(() {});
      },
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
    final highlightRule = _matchingHighlightRule(entry);
    final highlightColor = highlightRule?.color;
    final rowBackground = highlightColor?.withAlpha(26);
    final messageColor = highlightColor ?? theme.colorScheme.onSurface;

    return InkWell(
      onTap: () => Clipboard.setData(ClipboardData(text: entry.raw)),
      child: Container(
        color: rowBackground,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _buildLogEntryContent(
          entry,
          theme,
          mono,
          messageColor,
          highlightColor,
        ),
      ),
    );
  }

  Widget _buildLogEntryContent(
    LogEntry entry,
    ThemeData theme,
    TextStyle mono,
    Color messageColor,
    Color? highlightColor,
  ) {
    if (entry.isContinuation) {
      return Row(children: [
        Text('│ ',
            style: mono.copyWith(fontSize: 12, color: theme.dividerColor)),
        Expanded(
          child: Text(
            entry.message,
            style: mono.copyWith(
              fontSize: 12,
              color: highlightColor ?? theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]);
    }
    if (entry.time.isEmpty) {
      return Text(
        entry.raw,
        style: mono.copyWith(fontSize: 12, color: messageColor),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final prioColor = _prioColor(entry.priority, theme);
    return Row(children: [
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
          style: mono.copyWith(fontSize: 11, color: theme.colorScheme.primary)),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          entry.message,
          style: mono.copyWith(fontSize: 11, color: messageColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ]);
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
    final activeRules = _highlightRules.where((r) => r.enabled).length;
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
        Text('${tr('highlightRules')}: $activeRules',
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
