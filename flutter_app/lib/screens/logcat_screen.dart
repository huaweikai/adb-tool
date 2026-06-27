import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device.dart';
import '../models/test_config.dart';
import '../services/api_client.dart';
import '../i18n.dart';
import '../providers/locale_provider.dart';
import '../providers/device_provider.dart';
import '../providers/logcat_state_provider.dart';
import '../providers/test_session_provider.dart';
import '../providers/test_config_provider.dart';
import '../widgets/logcat/highlight_rule.dart';

/// Logcat screen — entries / filter / streaming state now live in
/// [LogcatStateProvider], keyed by device serial. This widget keeps only
/// the genuinely widget-scoped resources (TextEditingController,
/// ScrollController, flush timer, applied-config marker).
///
/// Per-device state survives screen rebuild AND navigation to other
/// devices' logcat screens: switching to device B does NOT touch
/// device A's entries / filter / scroll.
class LogcatScreen extends StatefulWidget {
  const LogcatScreen({super.key});

  @override
  State<LogcatScreen> createState() => _LogcatScreenState();
}

class _LogcatScreenState extends State<LogcatScreen> {
  String? get _selectedSerial => context.read<DeviceSerialScope>().serial;

  // Highlight rules are global UI tooling (apply across all devices);
  // keeping them widget-scoped is fine — they don't need to survive
  // navigation away from the screen.
  final List<HighlightRule> _highlightRules = HighlightRules.defaults();
  final List<Color> _customRuleColors = HighlightRules.customPalette;

  // Widget-scoped UI resources only. NOT business state.
  final ScrollController _scrollCtrl = ScrollController();
  bool _autoScroll = true;
  Timer? _autoScrollTimer;
  Timer? _flushTimer;
  String? _flushTimerSerial;

  late final TextEditingController _tagCtrl;
  late final TextEditingController _kwCtrl;
  late final TextEditingController _pkgCtrl;
  late final TextEditingController _ruleCtrl;

  // UI ephemeral — tracks which config we've already applied to the
  // filter fields, so we don't re-apply on every build.
  int? _lastAppliedConfigId;

  // The serial whose filter is currently loaded into the input
  // controllers. We hydrate controllers only when this changes (i.e.
  // when the user switches to a different device), NEVER on every
  // rebuild — re-hydrating per-build would clobber whatever the user
  // has typed since the last notifyListeners().
  String? _hydratedSerial;

  @override
  void initState() {
    super.initState();
    _tagCtrl = TextEditingController();
    _kwCtrl = TextEditingController();
    _pkgCtrl = TextEditingController();
    _ruleCtrl = TextEditingController();
    _scrollCtrl.addListener(_onScrollPositionChanged);
    _startFlushTimer();
  }

  /// Owns the periodic flush loop for the currently-active device's
  /// pending entries. Restarted when the active serial changes so
  /// each device gets its own flush cadence.
  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(
      const Duration(milliseconds: 80),
      (_) {
        if (!mounted) return;
        final serial = _selectedSerial;
        if (serial == null) return;
        context.read<LogcatStateProvider>().flushPending(serial);
        if (_autoScroll) _tryAutoScroll();
      },
    );
  }

  void _onScrollPositionChanged() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    final distanceFromBottom = pos.maxScrollExtent - pos.pixels;
    if (distanceFromBottom > 80 && _autoScroll) {
      setState(() {
        _autoScroll = false;
      });
    } else if (distanceFromBottom <= 24 && !_autoScroll) {
      setState(() {
        _autoScroll = true;
      });
      _jumpToBottomAfterFrame();
    }
  }

  /// Pull the current device's filter from the provider and load it
  /// into the input controllers. Called only when [_hydratedSerial]
  /// changes (i.e. first mount, or device switch). Never call from
  /// build() unconditionally — that would clobber in-progress typing.
  void _hydrateControllersFor(String serial) {
    final state = context.read<LogcatStateProvider>().stateFor(serial);
    _tagCtrl.text = state.filter.tag;
    _kwCtrl.text = state.filter.keyword;
    _pkgCtrl.text = state.filter.packageName;
    _hydratedSerial = serial;
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _flushTimer?.cancel();
    _scrollCtrl.removeListener(_onScrollPositionChanged);
    _tagCtrl.dispose();
    _kwCtrl.dispose();
    _pkgCtrl.dispose();
    _ruleCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _resolvePackage() async {
    final serial = _selectedSerial;
    final pkg = _pkgCtrl.text.trim();
    if (pkg.isEmpty || serial == null) {
      context.read<LogcatStateProvider>().setPackagePid(serial ?? '', null);
      if (serial != null) {
        context.read<LogcatStateProvider>().updateField(serial, packageName: '');
      }
      return;
    }
    context.read<LogcatStateProvider>().updateField(serial, packageName: pkg);
    final pid = await context.read<ApiClient>().getPackagePid(serial, pkg);
    if (!mounted) return;
    context.read<LogcatStateProvider>().setPackagePid(serial, pid);
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

  Future<void> _saveLogsToSession() async {
    final serial = _selectedSerial;
    if (serial == null) return;
    final p = context.read<LogcatStateProvider>();
    final state = p.stateFor(serial);
    if (state.entries.isEmpty) return;
    final content = state.entries.map((e) => e.raw).join('\n');
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

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
    final serial = _selectedSerial;
    final config = context.watch<TestConfigProvider>().currentApp;
    final configId = config?.id;

    if (serial == null) {
      return _buildNoDevice();
    }

    // Hydrate the filter input controllers exactly once per device
    // (first mount or after a device switch). Do NOT call this on
    // every build — that would clobber whatever the user has typed
    // since the last stream batch arrived.
    if (_hydratedSerial != serial) {
      _hydrateControllersFor(serial);
    }

    if (configId != null && configId != _lastAppliedConfigId) {
      _lastAppliedConfigId = configId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyConfig(config!);
      });
    } else if (configId == null) {
      _lastAppliedConfigId = null;
    }

    // Restart the flush timer if the active device changed.
    if (_flushTimerSerial != serial) {
      _flushTimerSerial = serial;
      _startFlushTimer();
    }

    final p = context.watch<LogcatStateProvider>();
    final state = p.stateFor(serial);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(context, state, serial),
        Expanded(child: _buildLogList(context, state.displayed, serial)),
        _buildStatusBar(context, state),
      ],
    );
  }

  Widget _buildNoDevice() {
    final theme = Theme.of(context);
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

  void _applyConfig(TestAppConfig config) {
    final serial = _selectedSerial;
    if (serial == null) return;
    final pkg = config.packageName;
    final tag = config.logcat.tags.join(', ');
    final kw = config.logcat.keywords.join(', ');
    final prio = config.logcat.defaultLevel.isNotEmpty
        ? config.logcat.defaultLevel
        : 'D';

    _pkgCtrl.text = pkg;
    _tagCtrl.text = tag;
    _kwCtrl.text = kw;

    context.read<LogcatStateProvider>().updateField(
          serial,
          tag: tag,
          keyword: kw,
          packageName: pkg,
          priority: prio,
        );

    if (pkg.isNotEmpty) {
      _resolvePackage();
    }
  }

  Widget _buildToolbar(BuildContext context, LogcatDeviceState state, String serial) {
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
          _btn(tr('start'), Icons.play_arrow, !state.streaming,
              _selectedSerial == null ? null : () => _startStream(), true),
          _btn(tr('stop'), Icons.stop, state.streaming, _stopStream, false),
          _btn(tr('pause'), Icons.pause, state.streaming && !state.paused,
              _pauseStream, false),
          _btn(tr('resume'), Icons.play_arrow, state.paused, _resumeStream,
              false),
          _btn(tr('clear'), Icons.delete_outline,
              state.streaming || state.hasLogs, _clearLogs, false),
          _btn(
              tr('saveToSession'),
              Icons.save_alt,
              state.hasLogs &&
                  context.watch<TestSessionProvider>().hasRunningSession,
              _saveLogsToSession,
              false),
          _sep(),
          _buildTagFilter(serial),
          _buildPriorityFilter(serial, state),
          _buildKeywordFilter(serial),
          _sep(),
          _buildPackageFilter(serial, state),
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

  void _startStream() {
    final serial = _selectedSerial;
    if (serial == null) return;
    context.read<LogcatStateProvider>().startStream(serial);
  }

  void _stopStream() {
    final serial = _selectedSerial;
    if (serial == null) return;
    context.read<LogcatStateProvider>().stopStream(serial);
  }

  void _pauseStream() {
    final serial = _selectedSerial;
    if (serial == null) return;
    context.read<LogcatStateProvider>().pauseStream(serial);
  }

  void _resumeStream() {
    final serial = _selectedSerial;
    if (serial == null) return;
    context.read<LogcatStateProvider>().resumeStream(serial);
  }

  void _clearLogs() {
    final serial = _selectedSerial;
    if (serial == null) return;
    final p = context.read<LogcatStateProvider>();
    p.clearBuffers(serial);
    context.read<ApiClient>().clearLogcat(serial);
  }

  Widget _buildTagFilter(String serial) {
    return SizedBox(
      width: 120,
      child: TextField(
        controller: _tagCtrl,
        onChanged: (v) => context
            .read<LogcatStateProvider>()
            .updateField(serial, tag: v),
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

  Widget _buildPriorityFilter(String serial, LogcatDeviceState state) {
    const levels = ['', 'V', 'D', 'I', 'W', 'E', 'F'];
    return SizedBox(
      width: 85,
      child: DropdownButtonFormField<String>(
        initialValue: state.filter.priority.isEmpty ? '' : state.filter.priority,
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
          final newPrio = v ?? '';
          context
              .read<LogcatStateProvider>()
              .updateField(serial, priority: newPrio);
        },
      ),
    );
  }

  Widget _buildKeywordFilter(String serial) {
    return SizedBox(
      width: 130,
      child: TextField(
        controller: _kwCtrl,
        onChanged: (v) => context
            .read<LogcatStateProvider>()
            .updateField(serial, keyword: v),
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

  Widget _buildPackageFilter(String serial, LogcatDeviceState state) {
    return SizedBox(
      width: 180,
      child: TextField(
        controller: _pkgCtrl,
        onSubmitted: (_) => _resolvePackage(),
        decoration: InputDecoration(
          labelText: tr('package'),
          labelStyle: const TextStyle(fontSize: 11),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(6))),
          suffixIcon: state.packagePid != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 12, right: 4),
                  child: Text('PID:${state.packagePid}',
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
                              _highlightRules.add(HighlightRule(
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
    if (!mounted) return;
    // Force a rebuild so log rows re-evaluate highlight rules — the
    // dialog mutates _highlightRules in-place, so setState is enough.
    setState(() {});
  }

  Widget _buildRuleTile(HighlightRule rule, StateSetter setDialogState) {
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

  Widget _buildLogList(BuildContext context, List<LogEntry> entries, String serial) {
    final theme = Theme.of(context);
    final serial = _selectedSerial ?? '';
    if (entries.isEmpty) {
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
    return ListView.builder(
      controller: _scrollCtrl,
      // PageStorageKey gives Flutter the signal to retain scroll
      // position across widget unmount/remount. Combined with the
      // per-device Provider state, this means switching devices and
      // coming back finds you exactly where you left off.
      key: PageStorageKey('logcat:$serial'),
      itemCount: entries.length,
      padding: EdgeInsets.zero,
      itemBuilder: (ctx, i) => _buildLogEntry(context, entries[i]),
    );
  }

  Widget _buildLogEntry(BuildContext context, LogEntry entry) {
    final theme = Theme.of(context);
    const mono = TextStyle(fontFamily: 'Menlo', height: 1.5);
    final highlightRule = HighlightRules.match(_highlightRules, entry, tr);
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
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('│ ',
              style: mono.copyWith(fontSize: 12, color: theme.dividerColor)),
          Expanded(
            child: Text(
              entry.message.replaceAll('\n', '\u21B5 '),
              style: mono.copyWith(
                fontSize: 12,
                color: highlightColor ?? theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }
    if (entry.time.isEmpty) {
      return Text(
        entry.raw,
        style: mono.copyWith(fontSize: 12, color: messageColor),
      );
    }

    final prioColor = _prioColor(entry.priority, theme);
    final displayTime = _formatLogTimeWithYear(entry.time);
    final pidTid = '${entry.pid}-${entry.tid}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 175,
          child: Text(
            displayTime,
            style: mono.copyWith(
                fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
            softWrap: false,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 160,
          child: Text(
            entry.tag.replaceAll('\n', '\u21B5 '),
            style:
                mono.copyWith(fontSize: 11, color: theme.colorScheme.primary),
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: Text(
            pidTid,
            style:
                mono.copyWith(fontSize: 11, color: Colors.green.shade300),
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: prioColor.withAlpha(30),
              borderRadius: BorderRadius.circular(3)),
          child: Text(entry.priority,
              style: mono.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: prioColor)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            entry.message.replaceAll('\n', '\u21B5 '),
            style: mono.copyWith(fontSize: 11, color: messageColor),
          ),
        ),
      ],
    );
  }

  String _formatLogTimeWithYear(String raw) {
    final m = RegExp(r'^(\d{2})-(\d{2})\s+\d{2}:\d{2}:\d{2}\.\d+$')
        .firstMatch(raw.trim());
    if (m == null) return raw;
    final month = int.parse(m.group(1)!);
    final day = int.parse(m.group(2)!);
    final now = DateTime.now();
    var year = now.year;
    final parsedThisYear = DateTime(year, month, day);
    if (parsedThisYear.difference(now).inDays > 30) {
      year -= 1;
    }
    return '$year-$raw';
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

  Widget _buildStatusBar(BuildContext context, LogcatDeviceState state) {
    final theme = Theme.of(context);
    final statusStr = state.paused
        ? tr('paused')
        : state.streaming
            ? tr('streaming')
            : tr('idle');
    final wsColor = state.wsConnected ? Colors.green : Colors.red;
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
        Text('${tr('lines')}: ${state.displayed.length}',
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
        if (state.packagePid != null) ...[
          const Spacer(),
          Text('${tr('pid')}: ${state.packagePid}',
              style: TextStyle(fontSize: 11, color: theme.colorScheme.primary)),
        ],
      ]),
    );
  }
}

// (no extension needed — the flush timer is owned by State)