import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../i18n.dart';
import '../models/device.dart';
import '../models/test_config.dart';
import '../models/test_session.dart';
import '../providers/device_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/test_session_provider.dart';
import '../providers/test_config_provider.dart';
import '../services/api_client.dart';
import '../utils/test_flow_text.dart';
import '../utils/time_formatters.dart';
import '../widgets/safe_dialog.dart';
import '../widgets/session_timeline_item.dart';
import '../mixins/screen_capture_mixin.dart';

class TestSessionScreen extends StatefulWidget {
  const TestSessionScreen({super.key});

  @override
  State<TestSessionScreen> createState() => _TestSessionScreenState();
}

class _TestSessionScreenState extends State<TestSessionScreen>
    with ScreenCaptureMixin<TestSessionScreen> {
  bool _busy = false;
  bool _logcatRunning = false;
  int _logcatSeconds = 0;
  int _sessionTick = 0;
  Timer? _logcatTimer;
  Timer? _sessionTimer;

  String? get serial => context.read<DeviceSerialScope>().serial;

  // ── ScreenCaptureMixin 实现 ──────────────────────────────────
  @override
  late bool recording;
  @override
  late bool recordSaving;
  @override
  late int recordSeconds;
  @override
  late bool screenshotting;
  @override
  late Timer? recordTimer;

  ApiClient get apiClient => context.read<ApiClient>();
  TestSessionProvider get sessionProvider =>
      context.read<TestSessionProvider>();

  @override
  Future<void> onScreenshotSaved(Uint8List bytes, String? localPath) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(tr('screenshotSavedToSession')),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2)),
    );
  }

  @override
  Future<void> onVideoSaved(Uint8List bytes) async {
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
    recording = false;
    recordSaving = false;
    recordSeconds = 0;
    screenshotting = false;
    recordTimer = null;
  }

  @override
  void dispose() {
    recordTimer?.cancel();
    _logcatTimer?.cancel();
    _sessionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TestSessionProvider>();
    context.watch<LocaleProvider>();
    final session = provider.currentSession;
    final theme = Theme.of(context);

    if (provider.hasRunningSession) {
      _sessionTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _sessionTick++);
      });
    } else {
      _sessionTimer?.cancel();
      _sessionTimer = null;
      _sessionTick = 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(theme, provider, session),
        Expanded(
          child: session == null
              ? _buildEmpty(theme)
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: _buildTimeline(theme, session)),
                    Expanded(flex: 2, child: _buildSidePanel(theme, session)),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    TestSessionProvider provider,
    TestSession? session,
  ) {
    final running = provider.hasRunningSession;
    final canCapture = session != null && running;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                tr('testSession'),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              if (session != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: session.status == TestSessionStatus.running
                        ? Colors.green.withAlpha(40)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    session.status == TestSessionStatus.running
                        ? tr('sessionRunning')
                        : tr('sessionFinished'),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                if (running) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          fmtElapsed(
                              DateTime.now().difference(session.startedAt)),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _showCreateDialog,
                icon: const Icon(Icons.add, size: 16),
                label: Text(tr('newSession')),
              ),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _showHistoryDialog,
                icon: const Icon(Icons.history, size: 16),
                label: Text(tr('sessionHistory')),
              ),
              if (recording)
                FilledButton.icon(
                  onPressed: recordSaving ? null : stopRecording,
                  icon: const Icon(Icons.stop, size: 16),
                  label: Text(fmtDuration(recordSeconds)),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                  ),
                )
              else
                FilledButton.tonalIcon(
                  onPressed:
                      canCapture && !_busy && serial != null ? startRecording : null,
                  icon: const Icon(Icons.fiber_manual_record, size: 16),
                  label: Text(tr('record')),
                ),
              FilledButton.tonalIcon(
                onPressed:
                    canCapture && !_busy && !screenshotting && serial != null
                        ? takeScreenshot
                        : null,
                icon: screenshotting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.camera_alt_outlined, size: 16),
                label: Text(tr('screenshot')),
              ),
              if (_logcatRunning)
                FilledButton.icon(
                  onPressed: _busy ? null : _stopLogcat,
                  icon: const Icon(Icons.stop, size: 16),
                  label: Text(fmtDuration(_logcatSeconds)),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                  ),
                )
              else
                FilledButton.tonalIcon(
                  onPressed: canCapture && !_busy && serial != null
                      ? _startLogcat
                      : null,
                  icon: const Icon(Icons.list_alt, size: 16),
                  label: Text(tr('logcat')),
                ),
              FilledButton.tonalIcon(
                onPressed: canCapture && !_busy ? _showIssueDialog : null,
                icon: const Icon(Icons.bug_report_outlined, size: 16),
                label: Text(tr('markIssue')),
              ),
              FilledButton.tonalIcon(
                onPressed: canCapture && !_busy ? _showNoteDialog : null,
                icon: const Icon(Icons.note_add_outlined, size: 16),
                label: Text(tr('addNote')),
              ),
              FilledButton.tonalIcon(
                onPressed: session == null || _busy ? null : _exportSession,
                icon: const Icon(Icons.archive_outlined, size: 16),
                label: Text(tr('exportSession')),
              ),
              FilledButton.tonalIcon(
                onPressed: canCapture && !_busy ? _finishSession : null,
                icon: const Icon(Icons.stop_circle_outlined, size: 16),
                label: Text(tr('finishSession')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.assignment_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(80)),
          const SizedBox(height: 16),
          Text(tr('noSession'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            tr('noSessionHint'),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add),
                label: Text(tr('newSession')),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: _showHistoryDialog,
                icon: const Icon(Icons.history),
                label: Text(tr('sessionHistory')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(ThemeData theme, TestSession session) {
    return Container(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: theme.dividerColor)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: session.events.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Text(
              tr('sessionTimeline'),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            );
          }
          final event = session.events[index - 1];
          return _buildTimelineItem(theme, event);
        },
      ),
    );
  }

  Widget _buildTimelineItem(ThemeData theme, TestSessionEvent event) {
    return SessionTimelineItem(
      theme: theme,
      event: event,
      eventTitle: (t) => sessionEventTitle(t, tr),
      eventColor: sessionEventColor,
    );
  }

  Widget _buildSidePanel(ThemeData theme, TestSession session) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle(theme, tr('currentSession')),
        _infoCard(theme, [
          _InfoLine(tr('sessionName'), session.name),
          _InfoLine(tr('sessionType'), session.type),
          _InfoLine(
              tr('device'),
              session.deviceModel.isEmpty
                  ? session.deviceSerial
                  : session.deviceModel),
          _InfoLine(tr('package'),
              session.packageName.isEmpty ? '-' : session.packageName),
          _InfoLine(tr('startedAt'), fmtDateTime(session.startedAt)),
          _InfoLine(tr('sessionDirectory'), session.directoryPath),
        ]),
        const SizedBox(height: 16),
        _sectionTitle(theme, tr('sessionTestPlan')),
        _testPlanList(theme, session),
        const SizedBox(height: 16),
        _sectionTitle(theme, tr('sessionIssues')),
        _issueList(theme, session),
        const SizedBox(height: 16),
        _sectionTitle(theme, tr('sessionArtifacts')),
        _artifactList(theme, session),
        const SizedBox(height: 16),
        _sectionTitle(theme, tr('sessionNotes')),
        if (session.notes.isEmpty)
          Text(tr('noNotes'),
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
        else
          ...session.notes.map((note) => Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fmtDateTime(note.createdAt),
                          style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      Text(note.content),
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  List<TestSessionPlanItem> _buildSessionPlanItems(List<TestFlowConfig> flows) {
    final items = <TestSessionPlanItem>[];
    for (final flow in flows) {
      for (final step in flow.steps) {
        final text = step.trim();
        if (text.isEmpty) continue;
        items.add(TestSessionPlanItem(flowName: flow.name, step: text));
      }
    }
    return items;
  }

  Widget _sectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w600)),
    );
  }

  Widget _infoCard(ThemeData theme, List<_InfoLine> lines) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: lines
            .map((line) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 82,
                        child: Text(line.label,
                            style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant)),
                      ),
                      Expanded(
                        child: Text(
                          line.value,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _testPlanList(ThemeData theme, TestSession session) {
    if (session.testPlan.isEmpty) {
      return Text(
        tr('noTestPlan'),
        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
      );
    }
    final running = session.status == TestSessionStatus.running;
    return Column(
      children: [
        for (var i = 0; i < session.testPlan.length; i++)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _testPlanStatusIcon(theme, session.testPlan[i].status),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.testPlan[i].flowName.isEmpty
                                  ? 'STEP-${(i + 1).toString().padLeft(3, '0')}'
                                  : session.testPlan[i].flowName,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              session.testPlan[i].step,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            if (session.testPlan[i].message.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                session.testPlan[i].message,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (running) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _updateTestPlanItem(
                            session.testPlan[i],
                            TestSessionPlanStatus.passed,
                          ),
                          icon: const Icon(Icons.check, size: 14),
                          label: Text(tr('testPlanPassed')),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _showTestPlanFailDialog(session.testPlan[i]),
                          icon: const Icon(Icons.close, size: 14),
                          label: Text(tr('testPlanFailed')),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _testPlanStatusIcon(ThemeData theme, TestSessionPlanStatus status) {
    return PlanStatusIcon(status);
  }

  Widget _issueList(ThemeData theme, TestSession session) {
    if (session.issues.isEmpty) {
      return Text(
        tr('noIssues'),
        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < session.issues.length; i++)
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _severityColor(session.issues[i].severity)
                              .withAlpha(35),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _severityLabel(session.issues[i].severity, context),
                          style: TextStyle(
                            fontSize: 11,
                            color: _severityColor(session.issues[i].severity),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ISSUE-${(i + 1).toString().padLeft(3, '0')} ${session.issues[i].title}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_issueTypeLabel(session.issues[i].type, context)} · ${fmtDateTime(session.issues[i].createdAt)}',
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                  if (session.issues[i].actual.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(session.issues[i].actual,
                        style: const TextStyle(fontSize: 12)),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _copyIssue(session.issues[i]),
                      icon: const Icon(Icons.copy, size: 14),
                      label: Text(tr('copyIssue')),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _artifactList(ThemeData theme, TestSession session) {
    if (session.artifacts.isEmpty) {
      return Text(tr('noArtifacts'),
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant));
    }
    return Column(
      children: [
        for (final artifact in session.artifacts)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 6),
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(_artifactIcon(artifact.kind),
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(artifact.name,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                        if (artifact.size > 0)
                          Text(fmtBytes(artifact.size),
                              style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => _deleteArtifact(artifact.id, artifact.name),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close,
                          size: 14, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static IconData _artifactIcon(TestSessionArtifactKind kind) => switch (kind) {
        TestSessionArtifactKind.screenshot => Icons.image_outlined,
        TestSessionArtifactKind.video => Icons.videocam_outlined,
        TestSessionArtifactKind.log => Icons.list_alt,
        TestSessionArtifactKind.report => Icons.description_outlined,
      };

  Future<void> _showCreateDialog() async {
    final s = serial;
    if (s == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('selectDevice')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final deviceProvider = context.read<DeviceProvider>();
    Device? device;
    try {
      device = deviceProvider.devices.firstWhere(
        (d) => d.serial == s,
      );
    } catch (_) {
      device = null;
    }
    final displayName = device?.displayName ?? s;
    final nameCtrl = TextEditingController(text: tr('defaultSessionName'));
    final currentApp = context.read<TestConfigProvider>().currentApp;
    final configPkg = currentApp?.packageName ?? '';
    final flowsCtrl = TextEditingController(
      text: currentApp == null ? '' : formatTestFlowText(currentApp.testFlows),
    );
    final packageCtrl = TextEditingController(text: configPkg);
    final noteCtrl = TextEditingController();
    final safeCtrls = [nameCtrl, packageCtrl, noteCtrl, flowsCtrl];
    String type = tr('sessionTypeBug');
    final result = await showDialog<_CreateSessionResult>(
      context: context,
      builder: (ctx) => SafeDialog(
        controllers: safeCtrls,
        builder: (_) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            scrollable: true,
            title: Text(tr('newSession')),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(labelText: tr('sessionName')),
                  ),
                  const SizedBox(height: 12),
                  _readonlyField(tr('device'), displayName),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: InputDecoration(labelText: tr('sessionType')),
                    items: [
                      tr('sessionTypeBug'),
                      tr('sessionTypeSmoke'),
                      tr('sessionTypeRegression'),
                      tr('sessionTypeCompatibility'),
                      tr('sessionTypeOther'),
                    ]
                        .map((item) =>
                            DropdownMenuItem(value: item, child: Text(item)))
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => type = value ?? type),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: packageCtrl,
                    decoration: InputDecoration(labelText: tr('packageName')),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: tr('sessionNote')),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: flowsCtrl,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: tr('configTestFlows'),
                      hintText: tr('configTestFlowsHint'),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  ctx,
                  _CreateSessionResult(
                    name: nameCtrl.text,
                    type: type,
                    packageName: packageCtrl.text,
                    note: noteCtrl.text,
                    testFlows: flowsCtrl.text,
                  ),
                ),
                child: Text(tr('startSession')),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    final sessionProvider = context.read<TestSessionProvider>();
    setState(() => _busy = true);
    try {
      await sessionProvider.startSession(
        name: result.name,
        type: result.type,
        serial: s,
        model: device?.model ?? '',
        brand: device?.brand ?? '',
        sdk: device?.sdk ?? '',
        deviceDisplayName: displayName,
        packageName: result.packageName,
        note: result.note,
        testPlanItems:
            _buildSessionPlanItems(parseTestFlowText(result.testFlows)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _readonlyField(String label, String value) {
    return TextFormField(
      initialValue: value,
      enabled: false,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.lock_outline, size: 16),
      ),
    );
  }

  Future<void> _startLogcat() async {
    final s = serial;
    if (s == null || _logcatRunning) return;
    final api = context.read<ApiClient>();
    final sessionProvider = context.read<TestSessionProvider>();
    final session = sessionProvider.currentSession;
    if (session == null) return;
    try {
      await api.sessionLogcatAction(
        'start',
        serial: s,
        sessionDir: session.directoryPath,
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
    final api = context.read<ApiClient>();
    final sessionProvider = context.read<TestSessionProvider>();
    if (!_logcatRunning) return;
    _logcatTimer?.cancel();
    try {
      final resp = await api.sessionLogcatAction(
        'stop',
        serial: '',
        sessionDir: '',
      );
      if (!mounted) return;
      setState(() {
        _logcatRunning = false;
        _logcatSeconds = 0;
      });
      if (!mounted) return;
      final path = resp['path']?.toString();
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

  Future<void> _updateTestPlanItem(
    TestSessionPlanItem item,
    TestSessionPlanStatus status, {
    String message = '',
  }) async {
    await context.read<TestSessionProvider>().updateTestPlanItem(
          item.id,
          status,
          message: message,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('testPlanUpdated')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showTestPlanFailDialog(TestSessionPlanItem item) async {
    final ctrl = TextEditingController(text: item.message);
    final message = await showDialog<String>(
      context: context,
      builder: (ctx) => SafeDialog(
        controllers: [ctrl],
        builder: (_) => AlertDialog(
          scrollable: true,
          title: Text(tr('testPlanFailed')),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(labelText: tr('testPlanMessage')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: Text(tr('confirm')),
            ),
          ],
        ),
      ),
    );
    if (message == null || !mounted) return;
    await _updateTestPlanItem(
      item,
      TestSessionPlanStatus.failed,
      message: message,
    );
  }

  Future<void> _showNoteDialog() async {
    final ctrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => SafeDialog(
        controllers: [ctrl],
        builder: (_) => AlertDialog(
          scrollable: true,
          title: Text(tr('addNote')),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 5,
            decoration: InputDecoration(labelText: tr('noteContent')),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: Text(tr('cancel'))),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: Text(tr('confirm')),
            ),
          ],
        ),
      ),
    );
    if (note == null || note.trim().isEmpty) return;
    if (!mounted) return;
    await context.read<TestSessionProvider>().addNote(note);
  }

  Future<void> _showIssueDialog() async {
    final titleCtrl = TextEditingController();
    final actualCtrl = TextEditingController();
    final stepsCtrl = TextEditingController();
    final expectedCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    TestSessionIssueSeverity severity = TestSessionIssueSeverity.major;
    TestSessionIssueType type = TestSessionIssueType.crash;
    bool showMore = false;
    final safeCtrls = [
      titleCtrl,
      actualCtrl,
      stepsCtrl,
      expectedCtrl,
      noteCtrl
    ];
    final result = await showDialog<_IssueFormResult>(
      context: context,
      builder: (ctx) => SafeDialog(
        controllers: safeCtrls,
        builder: (_) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            scrollable: true,
            title: Text(tr('markIssue')),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      autofocus: true,
                      decoration: InputDecoration(labelText: tr('issueTitle')),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<TestSessionIssueSeverity>(
                      initialValue: severity,
                      decoration:
                          InputDecoration(labelText: tr('issueSeverity')),
                      items: TestSessionIssueSeverity.values
                          .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(_severityLabel(s, context))))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => severity = v ?? severity),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => setDialogState(() => showMore = !showMore),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              showMore ? Icons.expand_less : Icons.expand_more,
                              size: 18,
                              color: Theme.of(ctx).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(tr('issueMoreFields'),
                                style: TextStyle(
                                    color: Theme.of(ctx).colorScheme.primary)),
                          ],
                        ),
                      ),
                    ),
                    if (showMore) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<TestSessionIssueType>(
                        initialValue: type,
                        decoration: InputDecoration(labelText: tr('issueType')),
                        items: TestSessionIssueType.values
                            .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(_issueTypeLabel(t, context))))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => type = v ?? type),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: actualCtrl,
                        maxLines: 2,
                        decoration:
                            InputDecoration(labelText: tr('issueActual')),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: stepsCtrl,
                        minLines: 2,
                        maxLines: 4,
                        decoration:
                            InputDecoration(labelText: tr('issueSteps')),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: expectedCtrl,
                        maxLines: 2,
                        decoration:
                            InputDecoration(labelText: tr('issueExpected')),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(labelText: tr('issueNote')),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(tr('cancel'))),
              FilledButton(
                onPressed: () => Navigator.pop(
                  ctx,
                  _IssueFormResult(
                    title: titleCtrl.text,
                    type: type,
                    severity: severity,
                    steps: stepsCtrl.text,
                    expected: expectedCtrl.text,
                    actual: actualCtrl.text,
                    note: noteCtrl.text,
                  ),
                ),
                child: Text(tr('confirm')),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    final recentLogContent = await _loadRecentLogcatSnapshot();
    if (!mounted) return;
    final issue = await context.read<TestSessionProvider>().markIssue(
          title: result.title,
          type: result.type,
          severity: result.severity,
          steps: result.steps,
          expected: result.expected,
          actual: result.actual,
          note: result.note,
          recentLogContent: recentLogContent,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('issueMarkedTip', {'title': issue.title})),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<String> _loadRecentLogcatSnapshot() async {
    final s = serial;
    if (s == null || s.isEmpty) return '';
    try {
      return await context
          .read<ApiClient>()
          .getRecentLogcat(s, lines: 1000);
    } catch (_) {
      return '';
    }
  }

  Future<void> _copyIssue(TestSessionIssue issue) async {
    final text =
        context.read<TestSessionProvider>().buildIssueClipboardText(issue);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('issueCopied')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _finishSession() async {
    await context.read<TestSessionProvider>().finishSession();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(tr('sessionFinishedTip')),
          behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _exportSession() async {
    setState(() => _busy = true);
    try {
      final path = await context.read<TestSessionProvider>().exportSession();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('sessionExported', {'path': path})),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr('exportFailed')}: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color _severityColor(TestSessionIssueSeverity severity) {
    return switch (severity) {
      TestSessionIssueSeverity.blocker => Colors.red,
      TestSessionIssueSeverity.major => Colors.deepOrange,
      TestSessionIssueSeverity.normal => Colors.orange,
      TestSessionIssueSeverity.minor => Colors.blueGrey,
    };
  }

  String _severityLabel(TestSessionIssueSeverity s, BuildContext context) =>
      switch (s) {
        TestSessionIssueSeverity.blocker => tr('issueSeverityBlocker'),
        TestSessionIssueSeverity.major => tr('issueSeverityMajor'),
        TestSessionIssueSeverity.normal => tr('issueSeverityNormal'),
        TestSessionIssueSeverity.minor => tr('issueSeverityMinor'),
      };

  String _issueTypeLabel(TestSessionIssueType t, BuildContext context) =>
      switch (t) {
        TestSessionIssueType.crash => tr('issueTypeCrash'),
        TestSessionIssueType.anr => tr('issueTypeAnr'),
        TestSessionIssueType.performance => tr('issueTypePerformance'),
        TestSessionIssueType.ui => tr('issueTypeUi'),
        TestSessionIssueType.api => tr('issueTypeApi'),
        TestSessionIssueType.functional => tr('issueTypeFunctional'),
        TestSessionIssueType.compatibility => tr('issueTypeCompatibility'),
        TestSessionIssueType.other => tr('issueTypeOther'),
      };

  Future<void> _deleteArtifact(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(tr('deleteArtifact')),
        content: Text(tr('deleteArtifactConfirm', {'name': name})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('delete'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<TestSessionProvider>().deleteArtifact(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr('artifactDeleted')),
            behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${tr('saveFailed')}: $e'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _showHistoryDialog() async {
    setState(() => _busy = true);
    final TestSessionProvider provider = context.read<TestSessionProvider>();
    List<TestSession> sessions;
    try {
      sessions = await provider.scanHistory();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${tr('saveFailed')}: $e'),
        behavior: SnackBarBehavior.floating,
      ));
      setState(() => _busy = false);
      return;
    }
    if (!mounted) {
      setState(() => _busy = false);
      return;
    }
    setState(() => _busy = false);
    await showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(tr('sessionHistory')),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 500,
                maxHeight: MediaQuery.sizeOf(context).height * 0.65,
              ),
              child: sessions.isEmpty
                  ? Text(tr('noHistorySessions'),
                      style:
                          TextStyle(color: theme.colorScheme.onSurfaceVariant))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: sessions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final s = sessions[i];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(s.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            [
                              s.type,
                              s.deviceModel.isEmpty
                                  ? s.deviceSerial
                                  : s.deviceModel,
                              fmtDateTime(s.startedAt),
                              tr('historyIssues',
                                  {'count': '${s.issues.length}'}),
                            ].join(' · '),
                            style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.open_in_new, size: 18),
                                tooltip: tr('reopenSession'),
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  await _loadHistorySession(provider, s.id);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline,
                                    size: 18, color: theme.colorScheme.error),
                                tooltip: tr('deleteSession'),
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      scrollable: true,
                                      title: Text(tr('deleteSession')),
                                      content: Text(tr('deleteSessionConfirm',
                                          {'name': s.name})),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, false),
                                            child: Text(tr('cancel'))),
                                        FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(c, true),
                                            child: Text(tr('delete'))),
                                      ],
                                    ),
                                  );
                                  if (confirmed != true) return;
                                  try {
                                    await provider.deleteSession(s.id);
                                    if (!context.mounted) return;
                                    setDialogState(() => sessions.removeAt(i));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(tr('sessionDeleted')),
                                          behavior: SnackBarBehavior.floating),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text('${tr('saveFailed')}: $e'),
                                          behavior: SnackBarBehavior.floating),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(tr('close'))),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadHistorySession(
      TestSessionProvider provider, String id) async {
    setState(() => _busy = true);
    try {
      await provider.loadHistoricalSession(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('sessionReopened')),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${tr('saveFailed')}: $e'),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

}

class _InfoLine {
  final String label;
  final String value;

  const _InfoLine(this.label, this.value);
}

class _IssueFormResult {
  final String title;
  final TestSessionIssueType type;
  final TestSessionIssueSeverity severity;
  final String steps;
  final String expected;
  final String actual;
  final String note;

  const _IssueFormResult({
    required this.title,
    required this.type,
    required this.severity,
    required this.steps,
    required this.expected,
    required this.actual,
    required this.note,
  });
}

class _CreateSessionResult {
  final String name;
  final String type;
  final String packageName;
  final String note;
  final String testFlows;

  const _CreateSessionResult({
    required this.name,
    required this.type,
    required this.packageName,
    required this.note,
    required this.testFlows,
  });
}
