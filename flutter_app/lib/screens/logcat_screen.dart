import 'dart:async';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:provider/provider.dart';
import '../models/app_package.dart';
import '../models/test_config.dart';
import '../services/api_client.dart';
import '../i18n.dart';
import '../providers/locale_provider.dart';
import '../providers/device_provider.dart';
import '../providers/logcat_state_provider.dart';
import '../providers/test_config_provider.dart';
import '../widgets/logcat/highlight_rule.dart';
import '../widgets/logcat/logcat_list.dart';
import '../widgets/offline_guard.dart';

/// Device log controls and filters. The list and toolbar subscribe to their
/// own state so incoming logs can update without rebuilding the controls.
class LogcatScreen extends StatefulWidget {
  const LogcatScreen({super.key});

  @override
  State<LogcatScreen> createState() => _LogcatScreenState();
}

class _LogcatScreenState extends State<LogcatScreen> {
  /// Stable device identity (ro.serialno). Survives reconnects —
  /// handed to `ApiClient` directly; the API boundary resolves
  /// it to the current adb address on demand.
  String? get _selectedSerial => context.read<DeviceSerialScope>().serial;

  // Highlight rules are global UI tooling (apply across all devices);
  // keeping them widget-scoped is fine — they don't need to survive
  // navigation away from the screen.
  final List<HighlightRule> _highlightRules = HighlightRules.defaults();
  final List<Color> _customRuleColors = HighlightRules.customPalette;

  int _highlightVersion = 0;

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
  int _packageRequest = 0;

  // Subscription for "recording was force-stopped because device went
  // offline" — surface a different snackbar than the normal
  // "saved to file" flow. Null until initState wires it up.
  StreamSubscription<String>? _recordingInterruptedSub;

  @override
  void initState() {
    super.initState();
    _tagCtrl = TextEditingController();
    _kwCtrl = TextEditingController();
    _pkgCtrl = TextEditingController();
    _ruleCtrl = TextEditingController();
    // Subscribe via post-frame so we have a context to read providers
    // and ScaffoldMessenger from. The provider itself was already
    // wired in di.dart; this just hooks the UI-side snackbar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recordingInterruptedSub = context
          .read<LogcatStateProvider>()
          .onRecordingInterrupted
          .listen((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('logcatRecordingInterruptedOffline')),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      });
    });
  }

  /// Pull the current device's filter from the provider and load it
  /// into the input controllers. Called only when [_hydratedSerial]
  /// changes (i.e. first mount, or device switch). Never call from
  /// build() unconditionally — that would clobber in-progress typing.
  void _hydrateControllersFor(String deviceSerial) {
    final state = context.read<LogcatStateProvider>().stateFor(deviceSerial);
    _tagCtrl.text = state.filter.tag;
    _kwCtrl.text = state.filter.keyword;
    _pkgCtrl.text = state.filter.packageName;
    _hydratedSerial = deviceSerial;
  }

  @override
  void dispose() {
    _recordingInterruptedSub?.cancel();
    _tagCtrl.dispose();
    _kwCtrl.dispose();
    _pkgCtrl.dispose();
    _ruleCtrl.dispose();
    super.dispose();
  }

  Future<void> _resolvePackage() async {
    final serial = _selectedSerial;
    if (serial == null) return;
    final request = ++_packageRequest;
    final package = _pkgCtrl.text.trim();
    final provider = context.read<LogcatStateProvider>();
    if (package.isEmpty) {
      provider.setPackagePid(serial, null);
      return;
    }
    provider.updateField(serial, packageName: package);
    String? pid;
    try {
      pid = await context.read<ApiClient>().getPackagePid(serial, package);
    } catch (_) {
      // The same feedback applies if the process is gone or unavailable.
    }
    if (!mounted ||
        request != _packageRequest ||
        serial != _selectedSerial ||
        package != _pkgCtrl.text.trim()) {
      return;
    }
    provider.setPackagePid(serial, pid, clearPackage: false);
    if (pid == null) _showPidNotFound(package);
  }

  void _showPidNotFound(String pkg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('logcatPackagePidNotFound', {'pkg': pkg})),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _startRecording() async {
    final deviceSerial = _selectedSerial;
    if (deviceSerial == null) return;
    final p = context.read<LogcatStateProvider>();
    if (p.isRecording(deviceSerial)) return; // already recording
    try {
      await p.startRecording(deviceSerial);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('logcatRecordFailed', {'error': '$e'})),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _stopAndPromptSave() async {
    final deviceSerial = _selectedSerial;
    if (deviceSerial == null) return;
    final p = context.read<LogcatStateProvider>();
    if (!p.isRecording(deviceSerial)) return;

    RecordingResult? result;
    try {
      result = await p.stopRecording(deviceSerial);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('logcatRecordStopFailed', {'error': '$e'})),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!mounted) return;
    if (result == null || result.path.isEmpty) return;

    // Suggest a stable, sortable file name: device_ts.log
    final ts = _fileTimestamp(DateTime.now());
    final safeSerial = deviceSerial.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final suggested = 'logcat_${safeSerial}_$ts.log';

    final location = await getSaveLocation(
      suggestedName: suggested,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'log', extensions: ['log', 'txt']),
      ],
    );
    if (!mounted) return;
    if (location == null) {
      // User cancelled. The temp file is intentionally left on disk —
      // the OS reaps /tmp periodically and the user can always re-trigger
      // a recording if they change their mind. Copying is the cheap path
      // if they later regret the cancel.
      return;
    }
    try {
      await File(result.path).copy(location.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('logcatSavedToLocal', {'path': location.path})),
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

  void _startStream() {
    final deviceSerial = _selectedSerial;
    if (deviceSerial == null) return;
    context.read<LogcatStateProvider>().startStream(deviceSerial);
  }

  void _stopStream() {
    final deviceSerial = _selectedSerial;
    if (deviceSerial == null) return;
    context.read<LogcatStateProvider>().stopStream(deviceSerial);
  }

  void _pauseStream() {
    final deviceSerial = _selectedSerial;
    if (deviceSerial == null) return;
    context.read<LogcatStateProvider>().pauseStream(deviceSerial);
  }

  void _resumeStream() {
    final deviceSerial = _selectedSerial;
    if (deviceSerial == null) return;
    context.read<LogcatStateProvider>().resumeStream(deviceSerial);
  }

  void _clearLogs() {
    final deviceSerial = _selectedSerial;
    if (deviceSerial == null) return;
    final p = context.read<LogcatStateProvider>();
    p.clearBuffers(deviceSerial);
  }

  void _applyConfig(TestAppConfig config) {
    final deviceSerial = _selectedSerial;
    if (deviceSerial == null) return;
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
          deviceSerial,
          tag: tag,
          keyword: kw,
          packageName: pkg,
          priority: prio,
        );

    if (pkg.isNotEmpty) {
      _resolvePackage();
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<DeviceSerialScope>();
    context.watch<LocaleProvider>();
    // `select` (not `watch`) so the screen rebuilds only when the
    // currentApp instance actually changes (switch / edit), not on
    // every TestConfigProvider notify (e.g. adding a non-current app
    // config to the list).
    final config =
        context.select<TestConfigProvider, TestAppConfig?>((p) => p.currentApp);
    final configId = config?.id;
    final deviceSerial = _selectedSerial;

    if (deviceSerial == null) {
      return _buildNoDevice();
    }

    // Hydrate the filter input controllers exactly once per device
    // (first mount or after a device switch). Do NOT call this on
    // every build — that would clobber whatever the user has typed
    // since the last stream batch arrived.
    if (_hydratedSerial != deviceSerial) {
      _hydrateControllersFor(deviceSerial);
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

    final active = context.watch<DeviceScreenActiveScope?>()?.active ?? true;
    final logState = context.read<LogcatStateProvider>().stateFor(deviceSerial);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OfflineBanner(serial: deviceSerial),
        Selector<DeviceProvider, bool>(
          selector: (_, p) => p.isDeviceConnected(deviceSerial),
          builder: (ctx, isOnline, _) => _LogcatToolbar(
            deviceSerial: deviceSerial,
            isOnline: isOnline,
            tagCtrl: _tagCtrl,
            kwCtrl: _kwCtrl,
            pkgCtrl: _pkgCtrl,
            ruleCtrl: _ruleCtrl,
            highlightRules: _highlightRules,
            customRuleColors: _customRuleColors,
            followLatest: logState.followLatest,
            softWrap: logState.softWrap,
            onStartStream: _startStream,
            onStopStream: _stopStream,
            onPauseStream: _pauseStream,
            onResumeStream: _resumeStream,
            onClearLogs: _clearLogs,
            onStartRecording: _startRecording,
            onStopRecording: _stopAndPromptSave,
            onResolvePackage: _resolvePackage,
            onHighlightRulesChanged: () => setState(() => _highlightVersion++),
          ),
        ),
        Expanded(
          child: LogcatList(
            key: ValueKey(deviceSerial),
            deviceSerial: deviceSerial,
            active: active,
            highlightRules: _highlightRules,
            highlightVersion: _highlightVersion,
          ),
        ),
        _LogcatStatusBar(
          deviceSerial: deviceSerial,
          active: active,
          highlightRules: _highlightRules,
        ),
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
}

/// Toolbar region. Subscribes only to the streaming / paused / filter /
/// pid slice of the per-device provider state. A 12.5 Hz stream batch
/// notify does NOT rebuild this widget because the snapshot is unchanged.
class _LogcatToolbar extends StatelessWidget {
  const _LogcatToolbar({
    required this.deviceSerial,
    required this.isOnline,
    required this.tagCtrl,
    required this.kwCtrl,
    required this.pkgCtrl,
    required this.ruleCtrl,
    required this.highlightRules,
    required this.customRuleColors,
    required this.followLatest,
    required this.softWrap,
    required this.onStartStream,
    required this.onStopStream,
    required this.onPauseStream,
    required this.onResumeStream,
    required this.onClearLogs,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onResolvePackage,
    required this.onHighlightRulesChanged,
  });

  final String deviceSerial;
  final bool isOnline;
  final TextEditingController tagCtrl;
  final TextEditingController kwCtrl;
  final TextEditingController pkgCtrl;
  final TextEditingController ruleCtrl;
  final List<HighlightRule> highlightRules;
  final List<Color> customRuleColors;
  final ValueNotifier<bool> followLatest;
  final ValueNotifier<bool> softWrap;
  final VoidCallback onStartStream;
  final VoidCallback onStopStream;
  final VoidCallback onPauseStream;
  final VoidCallback onResumeStream;
  final VoidCallback onClearLogs;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onResolvePackage;
  final VoidCallback onHighlightRulesChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Selector<LogcatStateProvider, _ToolbarSnapshot>(
      selector: (_, p) {
        final s = p.stateFor(deviceSerial);
        return _ToolbarSnapshot(
          streaming: s.streaming,
          paused: s.paused,
          hasLogs: s.hasLogs,
          historyLimit: s.historyLimit,
          priority: s.filter.priority,
          packagePid: s.packagePid,
          recording: s.recording,
          elapsedLabel: s.recording?.formattedElapsed,
        );
      },
      builder: (ctx, snap, _) {
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
              // Start/stop/pause/resume stream all hit the live adb
              // socket — gate on isOnline so the user can't queue up
              // requests against a dead device.
              _btn(ctx, tr('start'), Icons.play_arrow,
                  !snap.streaming && isOnline, onStartStream, true),
              _btn(ctx, tr('stop'), Icons.stop, snap.streaming && isOnline,
                  onStopStream, false),
              _btn(
                  ctx,
                  tr('pause'),
                  Icons.pause,
                  snap.streaming && !snap.paused && isOnline,
                  onPauseStream,
                  false),
              _btn(ctx, tr('resume'), Icons.play_arrow, snap.paused && isOnline,
                  onResumeStream, false),
              // Clear is local-only (clears the in-memory ring buffer),
              // so it stays enabled even when the device is gone —
              // lets the user wipe the stale entries on the way back.
              _btn(ctx, tr('clear'), Icons.delete_outline,
                  snap.streaming || snap.hasLogs, onClearLogs, false),
              _buildRecordingButton(ctx, snap),
              _sep(ctx),
              _buildTagFilter(ctx),
              _buildPriorityFilter(ctx, snap.priority),
              _buildKeywordFilter(ctx),
              _sep(ctx),
              _buildPackageFilter(ctx, snap.packagePid),
              _sep(ctx),
              _buildHighlightRulesButton(ctx),
              _sep(ctx),
              _buildAutoScrollToggle(),
              _buildSoftWrapToggle(ctx),
              _buildHistoryMenu(ctx, snap.historyLimit),
            ],
          ),
        );
      },
    );
  }

  /// Recording button — three states:
  ///   - idle (no recording):     "Start Recording" with red dot icon
  ///   - recording (active):      red pulse dot + MM:SS, click to stop
  ///   - recording (transition):  same look but disabled while waiting
  ///                               on the backend stop response
  ///
  /// No save-without-record path: this button is the only way to write
  /// a logcat file to disk from the logcat screen, mirroring the test
  /// session's "click to start, click to stop" UX.
  Widget _buildRecordingButton(BuildContext ctx, _ToolbarSnapshot snap) {
    final rec = snap.recording;
    if (rec == null) {
      // Idle. Recording a new file requires a live adb logcat
      // subprocess — gate on isOnline. Note: in normal operation
      // LogcatStateProvider auto-stops an in-flight recording when
      // its device drops offline, so by the time the toolbar rebuilds
      // here the recording will usually already be null. The isOnline
      // gate is the belt-and-braces guard for the brief race between
      // offline event → provider.stopRecordingIfActive → rebuild.
      return _btn(
        ctx,
        tr('startRecording'),
        Icons.fiber_manual_record,
        isOnline,
        onStartRecording,
        true, // primary
      );
    }
    // Recording — show the live elapsed pill. Disabled tap would be a
    // double-click guard; we just route through onStopRecording.
    // isOnline here is for the same race window as above; once the
    // provider has processed the offline event the rec will be null
    // and we'll be back in the idle branch.
    return SizedBox(
      height: 32,
      child: FilledButton(
        onPressed: isOnline ? () => onStopRecording() : null,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.red.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(fontSize: 12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const _PulseDot(),
          const SizedBox(width: 6),
          Text(snap.elapsedLabel ?? '00:00'),
          const SizedBox(width: 6),
          const Icon(Icons.stop, size: 16),
          const SizedBox(width: 4),
          Text(tr('stop')),
        ]),
      ),
    );
  }

  Widget _sep(BuildContext ctx) =>
      Container(width: 1, height: 20, color: Theme.of(ctx).dividerColor);

  Widget _btn(BuildContext ctx, String label, IconData icon, bool enabled,
      VoidCallback? onTap, bool primary) {
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

  Widget _buildTagFilter(BuildContext ctx) {
    return SizedBox(
      width: 120,
      child: TextField(
        controller: tagCtrl,
        onChanged: (v) =>
            ctx.read<LogcatStateProvider>().updateField(deviceSerial, tag: v),
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

  Widget _buildPriorityFilter(BuildContext ctx, String priority) {
    const levels = ['', 'V', 'D', 'I', 'W', 'E', 'F'];
    return SizedBox(
      width: 85,
      child: DropdownButtonFormField<String>(
        initialValue: priority.isEmpty ? '' : priority,
        decoration: InputDecoration(
          labelText: tr('level'),
          labelStyle: const TextStyle(fontSize: 11),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(6))),
        ),
        style:
            TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurface),
        dropdownColor: Theme.of(ctx).colorScheme.surface,
        items: levels
            .map((l) => DropdownMenuItem(
                  value: l,
                  child: Text(l.isEmpty ? tr('all') : l,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(ctx).colorScheme.onSurface)),
                ))
            .toList(),
        onChanged: (v) {
          final newPrio = v ?? '';
          ctx
              .read<LogcatStateProvider>()
              .updateField(deviceSerial, priority: newPrio);
        },
      ),
    );
  }

  Widget _buildKeywordFilter(BuildContext ctx) {
    return SizedBox(
      width: 130,
      child: TextField(
        controller: kwCtrl,
        onChanged: (v) => ctx
            .read<LogcatStateProvider>()
            .updateField(deviceSerial, keyword: v),
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

  Widget _buildPackageFilter(BuildContext ctx, String? pid) {
    // Stateful autocomplete widget — owns the per-deviceSerial package cache
    // with TTL so repeat focus on the same device doesn't hit /api/packages
    // every time. See [_PackageAutocompleteField] for details.
    return _PackageAutocompleteField(
      deviceSerial: deviceSerial,
      controller: pkgCtrl,
      pid: pid,
      onResolve: onResolvePackage,
    );
  }

  Widget _buildHighlightRulesButton(BuildContext ctx) {
    final enabledCount = highlightRules.where((r) => r.enabled).length;
    return SizedBox(
      height: 32,
      child: FilledButton.tonalIcon(
        onPressed: () => _showHighlightRulesDialog(ctx),
        icon: const Icon(Icons.color_lens_outlined, size: 16),
        label: Text('${tr('highlightRules')} $enabledCount'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildAutoScrollToggle() => ValueListenableBuilder<bool>(
        valueListenable: followLatest,
        builder: (_, following, child) => IconButton(
          tooltip: tr(following ? 'logcatPauseFollow' : 'logcatJumpToEnd'),
          icon: const Icon(Icons.vertical_align_bottom, size: 18),
          isSelected: following,
          selectedIcon: const Icon(Icons.vertical_align_bottom,
              size: 18, color: Colors.blue),
          onPressed: () => followLatest.value = !following,
        ),
      );

  Widget _buildSoftWrapToggle(BuildContext context) =>
      ValueListenableBuilder<bool>(
        valueListenable: softWrap,
        builder: (_, enabled, child) => IconButton(
          tooltip: tr('logcatSoftWrap'),
          isSelected: enabled,
          icon: const Icon(Icons.wrap_text, size: 18),
          selectedIcon: Icon(Icons.wrap_text,
              size: 18, color: Theme.of(context).colorScheme.primary),
          onPressed: () =>
              context.read<LogcatStateProvider>().setSoftWrap(!enabled),
        ),
      );

  Widget _buildHistoryMenu(BuildContext context, int limit) =>
      PopupMenuButton<int>(
        tooltip: tr('logcatHistoryLimit'),
        icon: const Icon(Icons.inventory_2_outlined, size: 18),
        initialValue: limit,
        itemBuilder: (_) => [
          for (final value in LogcatDeviceState.historyOptions)
            CheckedPopupMenuItem(
              value: value,
              checked: value == limit,
              child: Text(tr('logcatHistoryLines', {'count': '$value'})),
            ),
        ],
        onSelected: context.read<LogcatStateProvider>().setHistoryLimit,
      );

  Future<void> _showHighlightRulesDialog(BuildContext ctx) async {
    ruleCtrl.clear();
    Color selectedColor = customRuleColors.first;
    await showDialog<void>(
      context: ctx,
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
                      ...highlightRules.map((rule) => _buildRuleTile(
                            ctx,
                            rule,
                            setDialogState,
                          )),
                      const SizedBox(height: 16),
                      Text(tr('customRule'),
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: ruleCtrl,
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
                        children: customRuleColors
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
                            final keyword = ruleCtrl.text.trim();
                            if (keyword.isEmpty) return;
                            highlightRules.add(HighlightRule(
                              label: keyword,
                              pattern: keyword,
                              color: selectedColor,
                              builtin: false,
                              enabled: true,
                            ));
                            setDialogState(() => ruleCtrl.clear());
                            // Tell the screen to rebuild so the log
                            // list picks up the new rule.
                            onHighlightRulesChanged();
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
  }

  Widget _buildRuleTile(
      BuildContext ctx, HighlightRule rule, StateSetter setDialogState) {
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
                highlightRules.remove(rule);
                setDialogState(() {});
                onHighlightRulesChanged();
              },
            ),
        ],
      ),
      onChanged: (v) {
        rule.enabled = v ?? true;
        setDialogState(() {});
        onHighlightRulesChanged();
      },
    );
  }
}

/// Snapshot of the toolbar-relevant provider slice. Custom equality so
/// Selector only triggers a rebuild when one of these actually changed.
class _ToolbarSnapshot {
  const _ToolbarSnapshot({
    required this.streaming,
    required this.paused,
    required this.hasLogs,
    required this.historyLimit,
    required this.priority,
    required this.packagePid,
    required this.recording,
    required this.elapsedLabel,
  });

  final bool streaming;
  final bool paused;
  final bool hasLogs;
  final int historyLimit;
  final String priority;
  final String? packagePid;

  /// Non-null while a save-to-local recording is active for this device.
  /// The same [RecordingState] instance lives across timer ticks; the
  /// elapsedLabel field carries the changing time string.
  final RecordingState? recording;
  final String? elapsedLabel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _ToolbarSnapshot &&
          other.streaming == streaming &&
          other.paused == paused &&
          other.hasLogs == hasLogs &&
          other.historyLimit == historyLimit &&
          other.priority == priority &&
          other.packagePid == packagePid &&
          other.recording == recording &&
          other.elapsedLabel == elapsedLabel);

  @override
  int get hashCode => Object.hash(
        streaming,
        paused,
        hasLogs,
        historyLimit,
        priority,
        packagePid,
        recording,
        elapsedLabel,
      );
}

/// Status bar region. Subscribes only to streaming / paused / WS
/// connected / displayed length / package PID — typical stream-batch
/// notifies don't change any of these, so the row does not rebuild.
class _LogcatStatusBar extends StatelessWidget {
  const _LogcatStatusBar({
    required this.deviceSerial,
    required this.active,
    required this.highlightRules,
  });

  final String deviceSerial;
  final bool active;
  final List<HighlightRule> highlightRules;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final device = context.read<LogcatStateProvider>().stateFor(deviceSerial);
    return Selector<LogcatStateProvider, _StatusSnapshot>(
      selector: (_, p) {
        final s = p.stateFor(deviceSerial);
        return _StatusSnapshot(
          streaming: s.streaming,
          paused: s.paused,
          wsConnected: s.wsConnected,
          displayedCount: active ? s.displayed.length : 0,
          evictedCount: active ? s.evictedRows : 0,
          packagePid: s.packagePid,
        );
      },
      builder: (ctx, snap, _) {
        final statusStr = snap.paused
            ? tr('paused')
            : snap.streaming
                ? tr('streaming')
                : tr('idle');
        final wsColor = snap.wsConnected ? Colors.green : Colors.red;
        final activeRules = highlightRules.where((r) => r.enabled).length;
        return Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              Text('${tr('status')}: $statusStr',
                  style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 16),
              Text('${tr('lines')}: ${snap.displayedCount}',
                  style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 16),
              if (snap.evictedCount > 0) ...[
                Text(tr('logcatEvictedRows', {'count': '${snap.evictedCount}'}),
                    style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 16),
              ],
              if (active)
                ValueListenableBuilder<int>(
                  valueListenable: device.unseenRows,
                  builder: (_, count, child) => count == 0
                      ? const SizedBox.shrink()
                      : TextButton(
                          onPressed: () => device.followLatest.value = true,
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                          child: Text(tr('logcatNewRows', {'count': '$count'})),
                        ),
                ),
              Text('${tr('highlightRules')}: $activeRules',
                  style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 16),
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: wsColor),
              ),
              if (snap.packagePid != null) ...[
                const SizedBox(width: 16),
                Text('${tr('pid')}: ${snap.packagePid}',
                    style: TextStyle(
                        fontSize: 11, color: theme.colorScheme.primary)),
              ],
            ]),
          ),
        );
      },
    );
  }
}

/// Snapshot of the status bar's provider slice.
class _StatusSnapshot {
  const _StatusSnapshot({
    required this.streaming,
    required this.paused,
    required this.wsConnected,
    required this.displayedCount,
    required this.evictedCount,
    required this.packagePid,
  });

  final bool streaming;
  final bool paused;
  final bool wsConnected;
  final int displayedCount;
  final int evictedCount;
  final String? packagePid;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _StatusSnapshot &&
          other.streaming == streaming &&
          other.paused == paused &&
          other.wsConnected == wsConnected &&
          other.displayedCount == displayedCount &&
          other.evictedCount == evictedCount &&
          other.packagePid == packagePid);

  @override
  int get hashCode => Object.hash(
      streaming, paused, wsConnected, displayedCount, evictedCount, packagePid);
}

/// Tiny red blinking dot used as the recording-active indicator in the
/// toolbar pill. Self-contained [AnimationController] so the toolbar
/// doesn't need to wire any animation plumbing in.
class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl.drive(Tween(begin: 0.35, end: 1.0)),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Manual YYYYMMDD_HHMMSS timestamp formatter so we don't pull intl in
/// just for one file name. Mirrors `DateFormat('yyyyMMdd_HHmmss')`.
String _fileTimestamp(DateTime dt) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${dt.year}${two(dt.month)}${two(dt.day)}_${two(dt.hour)}${two(dt.minute)}${two(dt.second)}';
}

/// Package-name autocomplete widget for the logcat toolbar.
///
/// Built on top of `flutter_typeahead`'s [TypeAheadField] (v6.x), which
/// gives us keyboard navigation (↓/↑ to move highlight, Enter to
/// select, Esc to close) and "show all on empty" out of the box.
///
/// Owns:
///   - A static `Map<String, _PackageCacheEntry>` keyed by device
///     deviceSerial, so repeat focuses on the same device don't re-fetch
///     /api/packages. TTL is 30 s — long enough to make typing-flow
///     snappy without leaving the cache stale after the user installs
///     an app.
///
/// Behaviors:
///   - On focus, ensure cache is fresh for current deviceSerial; lazily
///     fetch /api/packages if missing or expired.
///   - Empty text dumps the full cached list (so the user can browse /
///     scroll without typing). On non-empty input, filters with
///     case-insensitive `contains` on both packageName and shortName.
///     Exact match against an installed package returns an empty list
///     so the popup hides and Enter resolves the PID without forcing
///     the user to "select" the already-correct match.
///   - Selecting an option fills the field with the canonical
///     packageName, immediately resolves PID, and keeps focus in the
///     field so the user can keep typing.
///   - Enter on a typed-but-not-highlighted value resolves the PID and
///     re-requests focus, so focus stays in the field instead of
///     advancing to the next focusable widget in the toolbar row.
class _PackageAutocompleteField extends StatefulWidget {
  const _PackageAutocompleteField({
    required this.deviceSerial,
    required this.controller,
    required this.pid,
    required this.onResolve,
  });

  final String deviceSerial;
  final TextEditingController controller;
  final String? pid;
  final VoidCallback onResolve;

  @override
  State<_PackageAutocompleteField> createState() =>
      _PackageAutocompleteFieldState();
}

class _PackageAutocompleteFieldState extends State<_PackageAutocompleteField> {
  static final Map<String, _PackageCacheEntry> _cache = {};
  static const Duration _ttl = Duration(seconds: 30);
  // Sentinel entry rendered as "清除筛选" at the top of the suggestion list.
  static final AppPackage _clearPackage =
      AppPackage(packageName: '', sourceDir: '');

  List<AppPackage> _packages = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final cached = _cache[widget.deviceSerial];
    if (cached != null && DateTime.now().difference(cached.fetchedAt) < _ttl) {
      _packages = cached.packages;
    }
  }

  @override
  void didUpdateWidget(_PackageAutocompleteField old) {
    super.didUpdateWidget(old);
    if (old.deviceSerial != widget.deviceSerial) {
      _packages = const [];
    }
  }

  Future<void> _ensureLoaded() async {
    final cached = _cache[widget.deviceSerial];
    final fresh =
        cached != null && DateTime.now().difference(cached.fetchedAt) < _ttl;
    if (fresh) {
      if (mounted) {
        setState(() => _packages = cached.packages);
      }
      return;
    }
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final api = context.read<ApiClient>();
      final pkgs = await api.getInstalledPackages(widget.deviceSerial);
      _cache[widget.deviceSerial] = _PackageCacheEntry(pkgs, DateTime.now());
      if (!mounted) return;
      setState(() {
        _packages = pkgs;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[_PackageAutocompleteField] fetch failed: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<List<AppPackage>> _computeSuggestions(String pattern) async {
    if (_packages.isEmpty) {
      await _ensureLoaded();
    }
    final typed = pattern.trim();
    if (typed.isEmpty) return [_clearPackage, ..._packages];
    final q = typed.toLowerCase();
    final filtered = _packages
        .where((p) =>
            p.packageName.toLowerCase().contains(q) ||
            p.shortName.toLowerCase().contains(q))
        .toList(growable: false);
    return [_clearPackage, ...filtered];
  }

  @override
  Widget build(BuildContext context) {
    final pid = widget.pid;
    return SizedBox(
      width: 180,
      child: TypeAheadField<AppPackage>(
        controller: widget.controller,
        constraints: const BoxConstraints(maxHeight: 200),
        builder: (context, textController, focusNode) => TextField(
          controller: textController,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) {
            FocusScope.of(context).requestFocus(focusNode);
          },
          decoration: InputDecoration(
            labelText: tr('package'),
            labelStyle: const TextStyle(fontSize: 11),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(6))),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (pid != null
                    ? Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text('PID:$pid',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.green.shade300,
                                fontFamily: 'Menlo')),
                      )
                    : null),
          ),
          style: const TextStyle(fontSize: 12, fontFamily: 'Menlo'),
          onTap: _ensureLoaded,
        ),
        suggestionsCallback: _computeSuggestions,
        hideOnEmpty: false,
        hideOnLoading: false,
        itemBuilder: (context, AppPackage pkg) {
          final theme = Theme.of(context);
          if (pkg.packageName.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                tr('clearFilter'),
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pkg.shortName,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  pkg.packageName,
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'Menlo',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        },
        onSelected: (AppPackage pkg) {
          widget.controller.text = pkg.packageName;
          widget.controller.selection = TextSelection.collapsed(
            offset: widget.controller.text.length,
          );
          widget.onResolve();
          FocusScope.of(context).requestFocus(FocusNode());
        },
        emptyBuilder: (_) => const SizedBox.shrink(),
      ),
    );
  }
}

class _PackageCacheEntry {
  final List<AppPackage> packages;
  final DateTime fetchedAt;
  _PackageCacheEntry(this.packages, this.fetchedAt);
}
