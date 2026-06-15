import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../i18n.dart';
import '../models/device.dart';
import '../models/test_session.dart';
import '../providers/device_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/test_session_provider.dart';
import '../services/api_client.dart';

class TestSessionScreen extends StatefulWidget {
  const TestSessionScreen({super.key});

  @override
  State<TestSessionScreen> createState() => _TestSessionScreenState();
}

class _TestSessionScreenState extends State<TestSessionScreen> {
  bool _busy = false;
  bool _screenshotting = false;
  bool _recording = false;
  bool _recordSaving = false;
  bool _logcatRunning = false;
  int _recordSeconds = 0;
  int _logcatSeconds = 0;
  Timer? _recordTimer;
  Timer? _logcatTimer;

  String? get _serial => context.read<DeviceSerialScope>().serial;

  @override
  void dispose() {
    _recordTimer?.cancel();
    _logcatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TestSessionProvider>();
    context.watch<LocaleProvider>();
    final session = provider.currentSession;
    final theme = Theme.of(context);
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
              if (session != null)
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
              if (_recording)
                FilledButton.icon(
                  onPressed: _recordSaving ? null : _stopRecording,
                  icon: const Icon(Icons.stop, size: 16),
                  label: Text(_fmtDuration(_recordSeconds)),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                  ),
                )
              else
                FilledButton.tonalIcon(
                  onPressed: canCapture && !_busy && _serial != null
                      ? _startRecording
                      : null,
                  icon: const Icon(Icons.fiber_manual_record, size: 16),
                  label: Text(tr('record')),
                ),
              FilledButton.tonalIcon(
                onPressed:
                    canCapture && !_busy && !_screenshotting && _serial != null
                        ? _takeScreenshot
                        : null,
                icon: _screenshotting
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
                  label: Text(_fmtDuration(_logcatSeconds)),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                  ),
                )
              else
                FilledButton.tonalIcon(
                  onPressed: canCapture && !_busy && _serial != null
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
          FilledButton.icon(
            onPressed: _showCreateDialog,
            icon: const Icon(Icons.add),
            label: Text(tr('newSession')),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            _time(event.time),
            style: TextStyle(
                fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 2),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _eventColor(event.type, theme),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_eventTitle(event.type),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                if (event.detail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.detail,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (event.filePath != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.filePath!,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
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
          _InfoLine(tr('startedAt'), _date(session.startedAt)),
          _InfoLine(tr('sessionDirectory'), session.directoryPath),
        ]),
        const SizedBox(height: 16),
        _sectionTitle(theme, tr('sessionIssues')),
        _issueList(theme, session),
        const SizedBox(height: 16),
        _sectionTitle(theme, tr('sessionArtifacts')),
        _artifactSummary(theme, session),
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
                      Text(_date(note.createdAt),
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
                    '${_issueTypeLabel(session.issues[i].type, context)} · ${_date(session.issues[i].createdAt)}',
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

  Widget _artifactSummary(ThemeData theme, TestSession session) {
    final screenshots = _count(session, TestSessionArtifactKind.screenshot);
    final videos = _count(session, TestSessionArtifactKind.video);
    final logs = _count(session, TestSessionArtifactKind.log);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip(theme, Icons.image_outlined, '${tr('screenshot')}: $screenshots'),
        _chip(theme, Icons.videocam_outlined, '${tr('record')}: $videos'),
        _chip(theme, Icons.list_alt, '${tr('logcat')}: $logs'),
      ],
    );
  }

  Widget _chip(ThemeData theme, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _showCreateDialog() async {
    final serial = _serial;
    if (serial == null) {
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
        (d) => d.serial == serial,
      );
    } catch (_) {
      device = null;
    }
    final displayName = device?.displayName ?? serial;
    final nameCtrl = TextEditingController(text: tr('defaultSessionName'));
    final packageCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String type = tr('sessionTypeBug');
    final result = await showDialog<_CreateSessionResult>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
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
                    ),
                  ),
                  child: Text(tr('startSession')),
                ),
              ],
            );
          },
        );
      },
    );
    nameCtrl.dispose();
    packageCtrl.dispose();
    noteCtrl.dispose();
    if (result == null || !mounted) return;
    final sessionProvider = context.read<TestSessionProvider>();
    setState(() => _busy = true);
    try {
      await sessionProvider.startSession(
        name: result.name,
        type: result.type,
        serial: serial,
        model: device?.model ?? '',
        brand: device?.brand ?? '',
        sdk: device?.sdk ?? '',
        deviceDisplayName: displayName,
        packageName: result.packageName,
        note: result.note,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _readonlyField(String label, String value) {
    return TextField(
      controller: TextEditingController(text: value),
      enabled: false,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.lock_outline, size: 16),
      ),
    );
  }

  Future<void> _takeScreenshot() async {
    final serial = _serial;
    if (serial == null) return;
    final api = context.read<ApiClient>();
    final sessionProvider = context.read<TestSessionProvider>();
    setState(() => _screenshotting = true);
    try {
      final b64 = await api.takeScreenshot(serial);
      if (b64 == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${tr('saveFailed')}: screenshot returned null'),
              behavior: SnackBarBehavior.floating),
        );
        return;
      }
      final bytes = base64Decode(b64);
      if (sessionProvider.hasRunningSession) {
        await sessionProvider.saveScreenshotBytes(bytes);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr('screenshotSavedToSession')),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${tr('saveFailed')}: $e'),
            behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _screenshotting = false);
    }
  }

  Future<void> _startRecording() async {
    final serial = _serial;
    if (serial == null || _recording || _recordSaving) return;
    final api = context.read<ApiClient>();
    final sessionProvider = context.read<TestSessionProvider>();
    try {
      await api.screenRecordAction(serial, 'start');
      if (sessionProvider.hasRunningSession) {
        await sessionProvider.markScreenRecordStarted();
      }
      if (!mounted) return;
      setState(() {
        _recording = true;
        _recordSaving = false;
        _recordSeconds = 0;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSeconds++);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr('recordingStarted')),
            behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${tr('recordingFailed')}: $e'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _stopRecording() async {
    final serial = _serial;
    if (serial == null) return;
    final api = context.read<ApiClient>();
    final sessionProvider = context.read<TestSessionProvider>();
    if (_recordSaving || !_recording) return;
    _recordTimer?.cancel();
    setState(() => _recordSaving = true);
    try {
      await api.screenRecordAction(serial, 'stop');
      if (!mounted) return;
      final bytes = await api.pullRecordedVideo(serial);
      if (!mounted) return;
      setState(() {
        _recording = false;
        _recordSaving = false;
        _recordSeconds = 0;
      });
      if (!mounted) return;
      if (sessionProvider.hasRunningSession) {
        await sessionProvider.saveVideoBytes(bytes);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr('recordSavedToSession')),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _recording = false;
        _recordSaving = false;
        _recordSeconds = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${tr('recordingStopFailed')}: $e'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _startLogcat() async {
    final serial = _serial;
    if (serial == null || _logcatRunning) return;
    final api = context.read<ApiClient>();
    final sessionProvider = context.read<TestSessionProvider>();
    final session = sessionProvider.currentSession;
    if (session == null) return;
    try {
      await api.sessionLogcatAction(
        'start',
        serial: serial,
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

  Future<void> _showNoteDialog() async {
    final ctrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
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
    );
    ctrl.dispose();
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
    final result = await showDialog<_IssueFormResult>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
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
        );
      },
    );
    titleCtrl.dispose();
    stepsCtrl.dispose();
    expectedCtrl.dispose();
    actualCtrl.dispose();
    noteCtrl.dispose();
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
    final serial = _serial;
    if (serial == null || serial.isEmpty) return '';
    try {
      return await context
          .read<ApiClient>()
          .getRecentLogcat(serial, lines: 1000);
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

  String _fmtDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int _count(TestSession session, TestSessionArtifactKind kind) {
    return session.artifacts.where((artifact) => artifact.kind == kind).length;
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

  String _eventTitle(TestSessionEventType type) => switch (type) {
        TestSessionEventType.sessionCreated => tr('eventSessionCreated'),
        TestSessionEventType.noteAdded => tr('eventNoteAdded'),
        TestSessionEventType.logcatStarted => tr('eventLogcatStarted'),
        TestSessionEventType.logcatSaved => tr('eventLogcatSaved'),
        TestSessionEventType.screenshotTaken => tr('eventScreenshotSaved'),
        TestSessionEventType.screenRecordStarted =>
          tr('eventScreenRecordStarted'),
        TestSessionEventType.screenRecordStopped =>
          tr('eventScreenRecordSaved'),
        TestSessionEventType.issueMarked => tr('eventIssueMarked'),
        TestSessionEventType.sessionFinished => tr('eventSessionFinished'),
      };

  Color _eventColor(TestSessionEventType type, ThemeData theme) {
    return switch (type) {
      TestSessionEventType.sessionCreated => theme.colorScheme.primary,
      TestSessionEventType.noteAdded => Colors.amber,
      TestSessionEventType.logcatStarted => Colors.green,
      TestSessionEventType.logcatSaved => Colors.green,
      TestSessionEventType.screenshotTaken => Colors.blue,
      TestSessionEventType.screenRecordStarted => Colors.purple,
      TestSessionEventType.screenRecordStopped => Colors.purpleAccent,
      TestSessionEventType.issueMarked => Colors.deepOrange,
      TestSessionEventType.sessionFinished => theme.colorScheme.error,
    };
  }

  String _time(DateTime time) =>
      '${_two(time.hour)}:${_two(time.minute)}:${_two(time.second)}';

  String _date(DateTime time) {
    return '${time.year}-${_two(time.month)}-${_two(time.day)} ${_time(time)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
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

  const _CreateSessionResult({
    required this.name,
    required this.type,
    required this.packageName,
    required this.note,
  });
}
