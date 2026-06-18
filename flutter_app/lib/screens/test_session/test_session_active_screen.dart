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
import '../../mixins/test_session_capture_mixin.dart';

/// Embedded session workflow widget for the hub's right panel.
class TestSessionActiveContent extends StatefulWidget {
  /// ID of the session to load and display.
  final String resumeSessionId;

  const TestSessionActiveContent({super.key, required this.resumeSessionId});

  @override
  State<TestSessionActiveContent> createState() => _TestSessionActiveContentState();
}

class _TestSessionActiveContentState extends State<TestSessionActiveContent>
    with TestSessionCaptureMixin<TestSessionActiveContent> {
  final bool _busy = false;
  bool _logcatRunning = false;
  int _logcatSeconds = 0;
  Timer? _logcatTimer;
  int _tick = 0; // incremented every second to force elapsed-time rebuilds

  @override
  late bool screenshotting;

  String? get serial => context.read<DeviceSerialScope>().serial;
  ApiClient get apiClient => context.read<ApiClient>();
  TestSessionProvider get sessionProvider => context.read<TestSessionProvider>();
  SavedDevicesDao get savedDevicesDao => context.read<AppDatabase>().savedDevicesDao;

  @override
  Future<void> onScreenshotSaved(Uint8List bytes, String? localPath) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('screenshotSavedToSession')),
          behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
    );
  }

  @override
  Future<void> onVideoSaved(Uint8List bytes, String relativePath) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('recordSavedToSession')),
          behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
    );
  }

  @override
  void initState() {
    super.initState();
    screenshotting = false;
    initScreenRecordState();
    // Tick timer to keep elapsed time updated every second
    Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _tick++);
    });
    // Load the session so the provider's currentSession is set
    WidgetsBinding.instance.addPostFrameCallback((_) {
      sessionProvider.loadHistoricalSession(widget.resumeSessionId);
    });
  }

  @override
  void dispose() {
    disposeScreenRecordState();
    _logcatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TestSessionProvider>();
    context.watch<LocaleProvider>();
    final session = provider.currentSession;
    final theme = Theme.of(context);

    if (session == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                    const Icon(Icons.fiber_manual_record, color: Colors.green, size: 10),
                    const SizedBox(width: 4),
                    Text(
                      session.name,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                fmtElapsed(DateTime.now().difference(session.startedAt)),
                style: theme.textTheme.bodySmall,
              ),
              const Spacer(),
              // Record
              if (isOtherOwnerRecording())
                _btn(null, Icons.fiber_manual_record, tr('recordInProgressOther'), null, grey: true)
              else if (isOurSaving)
                _btn(null, null, tr('recordSaving'), null, spinner: true)
              else if (isOurRecording)
                _btn(theme.colorScheme.error, Icons.stop, fmtDuration(elapsedSeconds), stopRecording)
              else
                _btn(null, Icons.fiber_manual_record, tr('record'), serial != null && !_busy ? startRecording : null),
              // Screenshot
              _buildScreenshotButton(theme),
              // Logcat
              if (_logcatRunning)
                _btn(theme.colorScheme.primary, Icons.stop, fmtDuration(_logcatSeconds), _busy ? null : _stopLogcat)
              else
                _btn(null, Icons.list_alt, tr('logcat'), serial != null && !_busy ? _startLogcat : null),
              // Issue
              _btn(null, Icons.bug_report_outlined, tr('markIssue'), !_busy ? _showIssueDialog : null),
              // Note
              _btn(null, Icons.note_add_outlined, tr('addNote'), !_busy ? _showNoteDialog : null),
              // Finish
              _btn(Colors.orange, Icons.stop_circle_outlined, tr('finishSession'), !_busy ? _finishSession : null),
            ],
          ),
        ),
        // ── Timeline + side panel ───────────────────────────────
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: _buildTimeline(theme, session)),
              VerticalDivider(width: 1, color: theme.dividerColor),
              Expanded(flex: 2, child: _buildSidePanel(theme, session)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _btn(Color? bg, IconData? icon, String label, VoidCallback? onPressed, {bool grey = false, bool spinner = false}) {
    if (onPressed == null) {
      return FilledButton.tonalIcon(
        onPressed: null,
        icon: spinner
            ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(icon, size: 14, color: grey ? Colors.grey : null),
        label: Text(label, style: TextStyle(fontSize: 11, color: grey ? Colors.grey : null)),
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
      );
    }
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: spinner
          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(icon, size: 14, color: bg != null ? Colors.white : null),
      label: Text(label, style: TextStyle(fontSize: 11, color: bg != null ? Colors.white : null)),
      style: bg != null
          ? FilledButton.styleFrom(backgroundColor: bg, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6))
          : FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
    );
  }

  Widget _buildScreenshotButton(ThemeData theme) {
    final icon = screenshotting
        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.camera_alt_outlined, size: 14);
    return FilledButton.tonalIcon(
      onPressed: screenshotting || _busy ? null : takeScreenshot,
      icon: icon,
      label: Text(tr('screenshot'), style: const TextStyle(fontSize: 11)),
      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
    );
  }

  Widget _buildTimeline(ThemeData theme, TestSession session) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: session.events.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        if (i == 0) return Text(tr('sessionTimeline'),
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600));
        final event = session.events[i - 1];
        return SessionTimelineItem(
          theme: theme, event: event,
          eventTitle: (t) => sessionEventTitle(t, tr),
          eventColor: sessionEventColor,
        );
      },
    );
  }

  Widget _buildSidePanel(ThemeData theme, TestSession session) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _section(theme, tr('sessionIssues'), session.issues.isEmpty
            ? Text(tr('noIssues'), style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12))
            : Text('${session.issues.length}', style: const TextStyle(fontSize: 12))),
        const SizedBox(height: 8),
        _section(theme, tr('sessionArtifacts'), session.artifacts.isEmpty
            ? Text(tr('noArtifacts'), style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12))
            : Text('${session.artifacts.length}', style: const TextStyle(fontSize: 12))),
        const SizedBox(height: 8),
        _section(theme, tr('sessionNotes'), session.notes.isEmpty
            ? Text(tr('noNotes'), style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12))
            : Text('${session.notes.length}', style: const TextStyle(fontSize: 12))),
      ],
    );
  }

  Widget _section(ThemeData theme, String title, Widget trailing) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(title, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }

  Future<void> _startLogcat() async {
    final s = serial;
    if (s == null || _logcatRunning) return;
    final session = sessionProvider.currentSession;
    if (session == null) return;
    try {
      await apiClient.sessionLogcatAction('start', serial: s, sessionDir: session.directoryPath, packageName: session.packageName);
      await sessionProvider.markLogcatStarted();
      if (!mounted) return;
      setState(() { _logcatRunning = true; _logcatSeconds = 0; });
      _logcatTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _logcatSeconds++);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('logcatCaptureStarted')), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('logcatCaptureFailed')}: $e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _stopLogcat() async {
    if (!_logcatRunning) return;
    _logcatTimer?.cancel();
    try {
      await apiClient.sessionLogcatAction('stop', serial: '', sessionDir: '');
      final path = (await apiClient.sessionLogcatAction('stop', serial: '', sessionDir: ''))['path']?.toString();
      if (!mounted) return;
      setState(() { _logcatRunning = false; _logcatSeconds = 0; });
      if (path != null && path.isNotEmpty) {
        await sessionProvider.saveLogcatFile(path);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('logcatSavedToSession', {'path': path})),
              behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _logcatRunning = false; _logcatSeconds = 0; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('logcatCaptureFailed')}: $e'), behavior: SnackBarBehavior.floating),
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
                  TextField(controller: titleCtrl, autofocus: true,
                      decoration: InputDecoration(labelText: tr('issueTitle'))),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<TestSessionIssueSeverity>(
                    decoration: InputDecoration(labelText: tr('issueSeverity')),
                    value: severity,
                    items: TestSessionIssueSeverity.values.map((s) =>
                        DropdownMenuItem(value: s, child: Text(_severityLabel(s)))).toList(),
                    onChanged: (v) => setState(() => severity = v ?? severity),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: actualCtrl, maxLines: 2,
                      decoration: InputDecoration(labelText: tr('issueActual'))),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('cancel'))),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, {
                  'title': titleCtrl.text, 'severity': severity, 'actual': actualCtrl.text,
                }),
                child: Text(tr('confirm')),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    final log = await _loadRecentLogcatSnapshot();
    final issue = await sessionProvider.markIssue(
      title: result['title'], type: TestSessionIssueType.crash,
      severity: result['severity'], steps: '', expected: '',
      actual: result['actual'], note: '', recentLogContent: log,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('issueMarkedTip', {'title': issue.title})),
          behavior: SnackBarBehavior.floating),
    );
  }

  Future<String> _loadRecentLogcatSnapshot() async {
    final s = serial;
    if (s == null) return '';
    try {
      return await apiClient.getRecentLogcat(s, lines: 500);
    } catch (_) { return ''; }
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
          content: TextField(controller: ctrl, autofocus: true, maxLines: 4,
              decoration: InputDecoration(labelText: tr('noteContent'))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: Text(tr('confirm'))),
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('confirm'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await sessionProvider.finishSession();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('sessionFinishedTip')), behavior: SnackBarBehavior.floating),
    );
    // Stream update will cause hub to rebuild and switch back to start card
  }
}
