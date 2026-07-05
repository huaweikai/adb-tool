// Active session content — embedded in the hub's right panel.
// Lives in the hub's Row so it automatically disappears when the session
// ends (stream updates → hub rebuilds → right panel switches back to start card).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../db/database.dart';
import '../../db/dao/saved_devices_dao.dart';
import '../../i18n.dart';
import '../../models/test_session.dart';
import '../../providers/device_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/test_session_provider.dart';
import '../../services/api_client.dart';
import '../../utils/time_formatters.dart';
import '../../widgets/safe_dialog.dart';
import '../../widgets/session_timeline_item.dart';
import '../../widgets/offline_guard.dart';
import '../../mixins/screen_capture_mixin.dart';
import 'session_preview_widgets.dart';

/// Embedded session workflow widget for the hub's right panel.
class TestSessionActiveContent extends StatefulWidget {
  /// ID of the session to load and display.
  final String resumeSessionId;

  const TestSessionActiveContent({super.key, required this.resumeSessionId});

  @override
  State<TestSessionActiveContent> createState() =>
      _TestSessionActiveContentState();
}

class _TestSessionActiveContentState extends State<TestSessionActiveContent>
    with ScreenCaptureMixin<TestSessionActiveContent> {
  final bool _busy = false;
  bool _logcatRunning = false;
  int _logcatSeconds = 0;
  Timer? _logcatTimer;
  StreamSubscription<String>? _recordingInterruptedSub;

  // Lazily-instantiated stream-backed section widgets. Cached by identity
  // so a `TestSessionProvider.notifyListeners()` (note / issue / screenshot
  // mutation) rebuilds the toolbar only — the timeline and side panel
  // subscribe to their own drift streams and rebuild independently of the
  // provider's notify cycle. See `_TimelineBody` / `_SidePanelBody`.
  _TimelineBody? _timeline;
  _SidePanelBody? _sidePanel;

  @override
  late bool screenshotting;

  @override
  CaptureMode get captureMode => CaptureMode.testSession;

  /// Stable device identity (ro.serialno). Survives reconnects.
  @override
  String? get serial => context.read<DeviceSerialScope>().serial;

  @override
  ApiClient get apiClient => context.read<ApiClient>();
  @override
  TestSessionProvider get sessionProvider =>
      context.read<TestSessionProvider>();
  @override
  SavedDevicesDao get savedDevicesDao =>
      context.read<AppDatabase>().savedDevicesDao;

  @override
  Future<void> onScreenshotSaved(Uint8List bytes, String? path) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(tr('screenshotSavedToSession')),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2)),
    );
  }

  @override
  Future<void> onVideoSaved(Uint8List bytes, String? path) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(tr('recordSavedToSession')),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2)),
    );
  }

  @override
  void initState() {
    super.initState();
    screenshotting = false;
    initScreenRecordState();
    // Load the session so the provider's currentSession is set
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      sessionProvider.loadHistoricalSession(widget.resumeSessionId);
      // Subscribe to "recording was force-stopped because device went
      // offline" — surface a different snackbar than the normal
      // "saved to session" flow. The recording is dead; no attachment
      // can be pulled from the now-unreachable device.
      _recordingInterruptedSub =
          sessionProvider.onRecordingInterrupted.listen((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('recordingInterruptedOffline')),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      });
    });
  }

  @override
  void didUpdateWidget(covariant TestSessionActiveContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The cached section widgets (_timeline / _sidePanel) bind to a
    // specific session id in their initState — their drift stream
    // subscriptions are keyed on `widget.sessionId` captured once at
    // creation. If the parent ever reuses this State with a different
    // resumeSessionId (rather than disposing + recreating it, which is
    // what the hub currently does via its ValueKey), discard the cache
    // so the next build reconstructs the children against the new
    // session. The ValueKey on each child then forces Flutter to
    // dispose the old element (cancelling its stream sub) and mount a
    // fresh one — without the key the old State would be reused and
    // its late-final stream would stay pinned to the old session.
    if (oldWidget.resumeSessionId != widget.resumeSessionId) {
      _timeline = null;
      _sidePanel = null;
    }
  }

  @override
  void dispose() {
    disposeScreenRecordState();
    _logcatTimer?.cancel();
    _recordingInterruptedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TestSessionProvider>();
    final currentSerial = context.watch<DeviceSerialScope>().serial;
    context.watch<LocaleProvider>();
    final session = provider.currentSession;
    final theme = Theme.of(context);
    // Watch device connection so every toolbar button rebuilds with the
    // correct enabled state when the device goes online/offline.
    final isOnline = currentSerial != null &&
        context.watch<DeviceProvider>().isDeviceConnected(currentSerial);

    if (session == null || session.id != widget.resumeSessionId) {
      return const Center(child: CircularProgressIndicator());
    }

    // Lazily cache the stream-backed section widgets on the first build
    // that sees a loaded session. Subsequent parent rebuilds return the
    // same instances, so TestSessionProvider.notifyListeners() (fired on
    // any mutation) skips these subtrees — only their own drift streams
    // re-render them, and only when the rows they depend on change.
    _timeline ??= _TimelineBody(
      key: ValueKey('timeline:${widget.resumeSessionId}'),
      sessionId: session.id,
      initialEvents: session.events,
      onTapAttachment: _showAttachmentPreview,
    );
    _sidePanel ??= _SidePanelBody(
      key: ValueKey('sidepanel:${widget.resumeSessionId}'),
      sessionId: session.id,
      initialPlan: session.testPlan,
      initialIssues: session.issues,
      initialNotes: session.notes,
      initialArtifacts: session.artifacts,
      onUpdatePlanItem: _updatePlanItem,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Offline banner (only renders when device is offline) ──
        if (currentSerial != null) OfflineBanner(serial: currentSerial),
        // ── Compact toolbar (no hub nav buttons) ─────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Session name + status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(30),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fiber_manual_record,
                        color: Colors.green, size: 10),
                    const SizedBox(width: 4),
                    Text(
                      session.name,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ElapsedLabel(
                startedAt: session.startedAt,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
              // Record
              if (isOtherOwnerRecording())
                _btn(null, Icons.fiber_manual_record,
                    tr('recordInProgressOther'), null, grey: true)
              else if (isOurSaving)
                _btn(null, null, tr('recordSaving'), null, spinner: true)
              else if (isOurRecording)
                _btn(
                    theme.colorScheme.error,
                    Icons.stop,
                    fmtDuration(elapsedSeconds),
                    isOnline ? stopRecording : null)
              else
                _btn(
                    null,
                    Icons.fiber_manual_record,
                    tr('record'),
                    (currentSerial != null && !_busy && isOnline)
                        ? startRecording
                        : null),
              // Screenshot
              _buildScreenshotButton(theme, isOnline: isOnline),
              // Logcat
              if (_logcatRunning)
                _btn(
                    theme.colorScheme.primary,
                    Icons.stop,
                    fmtDuration(_logcatSeconds),
                    (_busy || !isOnline) ? null : _stopLogcat)
              else
                _btn(
                    null,
                    Icons.list_alt,
                    tr('logcat'),
                    (currentSerial != null && !_busy && isOnline)
                        ? _startLogcat
                        : null),
              // Issue
              _btn(null, Icons.bug_report_outlined, tr('markIssue'),
                  (!_busy && isOnline) ? _showIssueDialog : null),
              // Note
              _btn(null, Icons.note_add_outlined, tr('addNote'),
                  (!_busy && isOnline) ? _showNoteDialog : null),
              // Finish — finishSession itself does not need a live
              // device (it just closes the session row), so leave it
              // enabled when offline.
              _btn(Colors.orange, Icons.stop_circle_outlined,
                  tr('finishSession'), !_busy ? _finishSession : null),
            ],
          ),
        ),
        // ── Timeline + side panel ───────────────────────────────
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: _timeline!),
              VerticalDivider(width: 1, color: theme.dividerColor),
              Expanded(flex: 2, child: _sidePanel!),
            ],
          ),
        ),
      ],
    );
  }

  Widget _btn(Color? bg, IconData? icon, String label, VoidCallback? onPressed,
      {bool grey = false, bool spinner = false}) {
    if (onPressed == null) {
      return FilledButton.tonalIcon(
        onPressed: null,
        icon: spinner
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(icon, size: 14, color: grey ? Colors.grey : null),
        label: Text(label,
            style: TextStyle(fontSize: 11, color: grey ? Colors.grey : null)),
        style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
      );
    }
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: spinner
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(icon, size: 14, color: bg != null ? Colors.white : null),
      label: Text(label,
          style:
              TextStyle(fontSize: 11, color: bg != null ? Colors.white : null)),
      style: bg != null
          ? FilledButton.styleFrom(
              backgroundColor: bg,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6))
          : FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
    );
  }

  Widget _buildScreenshotButton(ThemeData theme, {required bool isOnline}) {
    final icon = screenshotting
        ? const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.camera_alt_outlined, size: 14);
    return FilledButton.tonalIcon(
      // Screenshot requires a live adb shell — gate it on isOnline so
      // the user can't kick off a capture that will obviously fail.
      onPressed: (screenshotting || _busy || !isOnline) ? null : takeScreenshot,
      icon: icon,
      label: Text(tr('screenshot'), style: const TextStyle(fontSize: 11)),
      style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
    );
  }

  Future<void> _updatePlanItem(String itemId) async {
    if (_busy) return;
    final session = sessionProvider.currentSession;
    if (session == null) return;
    final current = session.testPlan.firstWhere(
      (p) => p.id == itemId,
      orElse: () => TestSessionPlanItem(
        id: itemId,
        flowName: '',
        step: '',
      ),
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _PlanStatusDialog(initial: current),
    );
    if (result == null || !mounted) return;
    final status = result['status'] as TestSessionPlanStatus;
    final message = (result['message'] as String).trim();

    try {
      await sessionProvider.updateTestPlanItem(itemId, status,
          message: message);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _startLogcat() async {
    final deviceSerial = serial;
    if (deviceSerial == null || _logcatRunning) return;
    final session = sessionProvider.currentSession;
    if (session == null) return;
    final sessionDir = await sessionProvider.currentSessionLogcatDir();
    if (sessionDir == null || sessionDir.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('logcatCaptureFailed')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      await apiClient.sessionLogcatAction(
        'start',
        serial: deviceSerial,
        sessionDir: sessionDir,
        packageName: session.packageName,
      );
      await sessionProvider.markLogcatStarted();
      if (!mounted) return;
      setState(() {
        _logcatRunning = true;
        _logcatSeconds = 0;
      });
      _logcatTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _logcatSeconds++);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr('logcatCaptureStarted')),
            behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${tr('logcatCaptureFailed')}: $e'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _stopLogcat() async {
    if (!_logcatRunning) return;
    _logcatTimer?.cancel();
    try {
      final resp1 = await apiClient.sessionLogcatAction('stop',
          serial: '', sessionDir: '');
      // Backend's stop action returns the file path of the captured log.
      // Don't double-stop (which would create an empty second file).
      final path = resp1['path']?.toString();
      if (!mounted) return;
      setState(() {
        _logcatRunning = false;
        _logcatSeconds = 0;
      });
      // Always record a "logcat stopped" event so the timeline has a
      // matching end for the start. saveLogcatFile below will additionally
      // insert a "logcat saved" event when the file actually exists.
      await sessionProvider.markLogcatStopped();
      if (path != null && path.isNotEmpty) {
        await sessionProvider.saveLogcatFile(path);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr('logcatSavedToSession', {'path': path})),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _logcatRunning = false;
        _logcatSeconds = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${tr('logcatCaptureFailed')}: $e'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _showIssueDialog() async {
    final titleCtrl = TextEditingController();
    final actualCtrl = TextEditingController();
    final safeCtrls = [titleCtrl, actualCtrl];
    TestSessionIssueSeverity severity = TestSessionIssueSeverity.major;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SafeDialog(
        controllers: safeCtrls,
        builder: (_) => StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text(tr('markIssue')),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: titleCtrl,
                      autofocus: true,
                      decoration: InputDecoration(labelText: tr('issueTitle'))),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<TestSessionIssueSeverity>(
                    decoration: InputDecoration(labelText: tr('issueSeverity')),
                    value: severity,
                    items: TestSessionIssueSeverity.values
                        .map((s) => DropdownMenuItem(
                            value: s, child: Text(_severityLabel(s))))
                        .toList(),
                    onChanged: (v) => setState(() => severity = v ?? severity),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                      controller: actualCtrl,
                      maxLines: 2,
                      decoration:
                          InputDecoration(labelText: tr('issueActual'))),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(tr('cancel'))),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, {
                  'title': titleCtrl.text,
                  'severity': severity,
                  'actual': actualCtrl.text,
                }),
                child: Text(tr('confirm')),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    final logResult = await _loadRecentLogcatSnapshot();
    final issue = await sessionProvider.markIssue(
      title: result['title'],
      type: TestSessionIssueType.crash,
      severity: result['severity'],
      steps: '',
      expected: '',
      actual: result['actual'],
      note: '',
      recentLogContent: logResult.content,
    );
    if (!mounted) return;
    final msg = logResult.captured
        ? tr('issueMarkedTipWithLog', {'title': issue.title})
        : tr('issueMarkedTip', {'title': issue.title});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<({String content, bool captured})> _loadRecentLogcatSnapshot() async {
    final deviceSerial = serial;
    if (deviceSerial == null) return (content: '', captured: false);
    try {
      final content = await apiClient.getRecentLogcat(deviceSerial, lines: 500);
      return (content: content, captured: content.isNotEmpty);
    } catch (_) {
      return (content: '', captured: false);
    }
  }

  String _severityLabel(TestSessionIssueSeverity s) => switch (s) {
        TestSessionIssueSeverity.blocker => tr('issueSeverityBlocker'),
        TestSessionIssueSeverity.major => tr('issueSeverityMajor'),
        TestSessionIssueSeverity.normal => tr('issueSeverityNormal'),
        TestSessionIssueSeverity.minor => tr('issueSeverityMinor'),
      };

  Future<void> _showNoteDialog() async {
    final ctrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => SafeDialog(
        controllers: [ctrl],
        builder: (_) => AlertDialog(
          title: Text(tr('addNote')),
          content: TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 4,
              decoration: InputDecoration(labelText: tr('noteContent'))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: Text(tr('cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                child: Text(tr('confirm'))),
          ],
        ),
      ),
    );
    if (note == null || note.trim().isEmpty || !mounted) return;
    await sessionProvider.addNote(note);
  }

  Future<void> _finishSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('finishSession')),
        content: Text(tr('finishSessionConfirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('confirm'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await sessionProvider.finishSession();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(tr('sessionFinishedTip')),
          behavior: SnackBarBehavior.floating),
    );
    // Stream update will cause hub to rebuild and switch back to start card
  }

  Future<void> _showAttachmentPreview(TestSessionEvent event) async {
    if (event.filePath == null) return;
    final theme = Theme.of(context);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(sessionEventTitle(event.type, tr)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.detail.isNotEmpty) ...[
              Text(event.detail, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
            ],
            SelectableText(
              event.filePath!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(tr('close'))),
        ],
      ),
    );
  }
}

// ── Test-plan status dialog ──────────────────────────────────────────────────

class _PlanStatusDialog extends StatefulWidget {
  final TestSessionPlanItem initial;

  const _PlanStatusDialog({required this.initial});

  @override
  State<_PlanStatusDialog> createState() => _PlanStatusDialogState();
}

class _PlanStatusDialogState extends State<_PlanStatusDialog> {
  late TestSessionPlanStatus _status;
  late final TextEditingController _msgCtrl;

  @override
  void initState() {
    super.initState();
    _status = widget.initial.status;
    _msgCtrl = TextEditingController(text: widget.initial.message);
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(tr('updateTestPlanItem')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.initial.flowName.isNotEmpty) ...[
              Text(
                widget.initial.flowName,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              widget.initial.step,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
            const SizedBox(height: 16),
            SegmentedButton<TestSessionPlanStatus>(
              segments: [
                ButtonSegment(
                  value: TestSessionPlanStatus.passed,
                  label: Text(tr('testPlanPassed')),
                  icon: const Icon(Icons.check_circle, size: 16),
                ),
                ButtonSegment(
                  value: TestSessionPlanStatus.failed,
                  label: Text(tr('testPlanFailed')),
                  icon: const Icon(Icons.cancel, size: 16),
                ),
                ButtonSegment(
                  value: TestSessionPlanStatus.pending,
                  label: Text(tr('testPlanPending')),
                  icon: const Icon(Icons.radio_button_unchecked, size: 16),
                ),
              ],
              selected: {_status},
              onSelectionChanged: (s) => setState(() {
                _status = s.first;
                if (_status != TestSessionPlanStatus.failed) {
                  _msgCtrl.clear();
                }
              }),
            ),
            if (_status == TestSessionPlanStatus.failed) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _msgCtrl,
                maxLines: 3,
                decoration: InputDecoration(labelText: tr('testPlanMessage')),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            'status': _status,
            'message': _msgCtrl.text,
          }),
          child: Text(tr('confirm')),
        ),
      ],
    );
  }
}

/// Self-ticking elapsed-time label. Owns its own 1-second timer so the
/// parent widget tree doesn't rebuild just to update this one label.
class _ElapsedLabel extends StatefulWidget {
  final DateTime startedAt;
  final TextStyle? style;

  const _ElapsedLabel({required this.startedAt, this.style});

  @override
  State<_ElapsedLabel> createState() => _ElapsedLabelState();
}

class _ElapsedLabelState extends State<_ElapsedLabel> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      fmtElapsed(DateTime.now().difference(widget.startedAt)),
      style: widget.style,
    );
  }
}

// ── Row → model converters (mirror TestSessionProvider._rowToModel) ──────
// The provider hydrates a whole TestSession from these rows; the
// stream-backed sections below rehydrate each child list independently so
// a note mutation no longer rebuilds the event list / issues / plan.
TestSessionEvent _eventFromRow(TestSessionEventRow e) => TestSessionEvent(
      id: e.id,
      type: e.type,
      time: e.time,
      title: e.title,
      detail: e.detail,
      filePath: e.filePath,
    );

TestSessionArtifact _artifactFromRow(TestSessionArtifactRow a) =>
    TestSessionArtifact(
      id: a.id,
      kind: a.kind,
      name: a.name,
      path: a.path,
      createdAt: a.createdAt,
      size: a.size,
    );

TestSessionNote _noteFromRow(TestSessionNoteRow n) => TestSessionNote(
      id: n.id,
      createdAt: n.createdAt,
      content: n.content,
    );

TestSessionIssue _issueFromRow(TestSessionIssueRow i) => TestSessionIssue(
      id: i.id,
      createdAt: i.createdAt,
      title: i.title,
      type: i.type,
      severity: i.severity,
      steps: i.steps,
      expected: i.expected,
      actual: i.actual,
      note: i.note,
      relatedArtifactIds: const [],
    );

TestSessionPlanItem _planItemFromRow(TestSessionPlanItemRow p) =>
    TestSessionPlanItem(
      id: p.id,
      flowName: p.flowName,
      step: p.step,
      status: p.status,
      message: p.message,
      startedAt: p.startedAt,
      updatedAt: p.updatedAt,
    );

/// Stream-driven, virtualized timeline. Subscribes to
/// `watchEventsForSession` once (in initState) so the parent's
/// `TestSessionProvider.notifyListeners()` — fired on every note / issue /
/// screenshot mutation — does NOT rebuild this list. Only an actual
/// change to the events table re-renders it.
class _TimelineBody extends StatefulWidget {
  final String sessionId;
  final List<TestSessionEvent> initialEvents;
  final void Function(TestSessionEvent) onTapAttachment;

  const _TimelineBody({
    super.key,
    required this.sessionId,
    required this.initialEvents,
    required this.onTapAttachment,
  });

  @override
  State<_TimelineBody> createState() => _TimelineBodyState();
}

class _TimelineBodyState extends State<_TimelineBody> {
  late final Stream<List<TestSessionEvent>> _stream;

  @override
  void initState() {
    super.initState();
    final provider = context.read<TestSessionProvider>();
    _stream = provider
        .watchEventsForSession(widget.sessionId)
        .map((rows) => rows.map(_eventFromRow).toList());
  }

  @override
  Widget build(BuildContext context) {
    // Watch locale HERE (not only in the parent): the parent caches this
    // widget by identity, so without its own LocaleProvider dependency
    // its translations would go stale on a language toggle.
    context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    return StreamBuilder<List<TestSessionEvent>>(
      initialData: widget.initialEvents,
      stream: _stream,
      builder: (context, snapshot) {
        final events = snapshot.data ?? widget.initialEvents;
        final total = events.length;
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: total + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            if (i == 0) {
              return Text(tr('sessionTimeline'),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600));
            }
            final event = events[i - 1];
            return SessionTimelineItem(
              theme: theme,
              event: event,
              canDelete: false,
              eventTitle: (t) => sessionEventTitle(t, tr),
              eventColor: sessionEventColor,
              onTapAttachment: event.filePath != null
                  ? () => widget.onTapAttachment(event)
                  : null,
            );
          },
        );
      },
    );
  }
}

/// Stream-driven, virtualized side panel. Each section subscribes to its
/// own drift stream, so adding a note rebuilds only the notes sliver —
/// not the timeline, toolbar, issues, or plan items. Rendered as a
/// `CustomScrollView` of `SliverList`s so 100+ items stay virtualized
/// (the previous `ListView(children: [...spread...])` rendered every
/// item eagerly).
class _SidePanelBody extends StatefulWidget {
  final String sessionId;
  final List<TestSessionPlanItem> initialPlan;
  final List<TestSessionIssue> initialIssues;
  final List<TestSessionNote> initialNotes;
  final List<TestSessionArtifact> initialArtifacts;
  final void Function(String itemId) onUpdatePlanItem;

  const _SidePanelBody({
    super.key,
    required this.sessionId,
    required this.initialPlan,
    required this.initialIssues,
    required this.initialNotes,
    required this.initialArtifacts,
    required this.onUpdatePlanItem,
  });

  @override
  State<_SidePanelBody> createState() => _SidePanelBodyState();
}

class _SidePanelBodyState extends State<_SidePanelBody> {
  late final Stream<List<TestSessionPlanItem>> _planStream;
  late final Stream<List<TestSessionIssue>> _issuesStream;
  late final Stream<List<TestSessionNote>> _notesStream;
  late final Stream<List<TestSessionArtifact>> _artifactsStream;

  @override
  void initState() {
    super.initState();
    final provider = context.read<TestSessionProvider>();
    final id = widget.sessionId;
    _planStream = provider
        .watchPlanItemsForSession(id)
        .map((rows) => rows.map(_planItemFromRow).toList());
    _issuesStream = provider
        .watchIssuesForSession(id)
        .map((rows) => rows.map(_issueFromRow).toList());
    _notesStream = provider
        .watchNotesForSession(id)
        .map((rows) => rows.map(_noteFromRow).toList());
    _artifactsStream = provider
        .watchArtifactsForSession(id)
        .map((rows) => rows.map(_artifactFromRow).toList());
  }

  /// Builds one section as a single `SliverList` whose index 0 is the
  /// (live-count) title and index 1..N are the items (or an empty hint).
  /// Wrapping title + items in one sliver keeps the count in sync with
  /// the stream without a second subscription.
  Widget _sectionSliver<T>({
    required Stream<List<T>> stream,
    required List<T> initial,
    required String titleKey,
    required String emptyKey,
    required Widget Function(ThemeData, T) itemBuilder,
    required ThemeData theme,
  }) {
    return StreamBuilder<List<T>>(
      initialData: initial,
      stream: stream,
      builder: (context, snap) {
        final items = snap.data ?? initial;
        final empty = items.isEmpty;
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              if (i == 0) {
                return previewSectionTitle(
                    theme, '${tr(titleKey)} (${items.length})');
              }
              if (empty) {
                return Text(tr(emptyKey),
                    style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12));
              }
              return itemBuilder(theme, items[i - 1]);
            },
            childCount: empty ? 2 : items.length + 1,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    // CustomScrollView has no `padding` param (unlike ListView); wrap in
    // Padding so the 12px outer inset is preserved without per-sliver
    // SliverPadding boilerplate.
    return Padding(
      padding: const EdgeInsets.all(12),
      child: CustomScrollView(
        slivers: [
          _sectionSliver(
            stream: _planStream,
            initial: widget.initialPlan,
            titleKey: 'sessionTestPlan',
            emptyKey: 'noTestPlan',
            theme: theme,
            itemBuilder: (theme, item) => previewPlanItem(theme, item,
                onStatusChange: () => widget.onUpdatePlanItem(item.id)),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          _sectionSliver(
            stream: _issuesStream,
            initial: widget.initialIssues,
            titleKey: 'sessionIssues',
            emptyKey: 'noIssues',
            theme: theme,
            itemBuilder: previewIssueItem,
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          _sectionSliver(
            stream: _notesStream,
            initial: widget.initialNotes,
            titleKey: 'sessionNotes',
            emptyKey: 'noNotes',
            theme: theme,
            itemBuilder: previewNoteItem,
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          _sectionSliver(
            stream: _artifactsStream,
            initial: widget.initialArtifacts,
            titleKey: 'sessionArtifacts',
            emptyKey: 'noArtifacts',
            theme: theme,
            itemBuilder: (theme, a) =>
                previewArtifactItem(theme, a, sessionId: widget.sessionId),
          ),
        ],
      ),
    );
  }
}
