// Hub screen for the test-session tab.
//
// Layout:
//   - Left panel (flex 3): history list for the current device
//   - Right panel (flex 2): start/resume card, or active session workflow
//
// When a session is active on this device, the right panel switches to
// the full session UI. The session ends → right panel switches back to
// the start card automatically via the stream.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../db/database.dart';
import '../../i18n.dart';
import '../../models/device.dart';
import '../../models/test_config.dart';
import '../../models/test_session.dart';
import '../../providers/device_provider.dart';
import '../../providers/test_config_provider.dart';
import '../../providers/test_session_provider.dart';
import '../../utils/test_flow_text.dart';
import '../../utils/time_formatters.dart';
import '../../widgets/safe_dialog.dart';
import 'test_session_active_screen.dart';
import 'session_preview_widgets.dart';

class TestSessionHubScreen extends StatefulWidget {
  const TestSessionHubScreen({super.key});

  @override
  State<TestSessionHubScreen> createState() => _TestSessionHubScreenState();
}

class _TestSessionHubScreenState extends State<TestSessionHubScreen> {
  String? _lastSerial;

  /// When non-null, the right panel shows a read-only preview of this session
  /// instead of the start card or active session.
  String? _previewSessionId;

  void _openPreview(String sessionId) {
    setState(() => _previewSessionId = sessionId);
  }

  void _closePreview() {
    setState(() => _previewSessionId = null);
  }

  void _openNewSession() {
    final s = context.read<DeviceSerialScope>().serial;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _NewSessionDialog(serial: s ?? ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.watch<DeviceSerialScope>().serial;
    if (_lastSerial != s) {
      _lastSerial = s;
      _previewSessionId = null;
      if (s != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<TestSessionProvider>().clearCurrentSessionIfDifferentDevice(s);
          }
        });
      }
    }

    if (s == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.usb_off,
                size: 56, color: theme.colorScheme.onSurfaceVariant.withAlpha(80)),
            const SizedBox(height: 16),
            Text(tr('selectDevice'), style: theme.textTheme.titleMedium),
          ],
        ),
      );
    }

    final db = context.read<AppDatabase>();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: StreamBuilder<TestSessionRow?>(
        key: ValueKey('active-session:$s'),
        stream: db.testSessionsDao.watchActiveSessionForDevice(s),
        builder: (context, snap) {
          final active = snap.data;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Left: history list (flex 2) ─────────────────────
              Expanded(
                flex: 2,
                child: _HistoryPanel(
                  key: ValueKey('history:$s'),
                  serial: s,
                  onItemTap: _openPreview,
                ),
              ),
              VerticalDivider(width: 1, color: theme.dividerColor),
              // ── Right: preview / active session / start card (flex 5) ──
              Expanded(
                flex: 5,
                child: _buildRightPanel(s, db, active),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRightPanel(String s, AppDatabase db, TestSessionRow? active) {
    // 1. Read-only preview of a history item
    if (_previewSessionId != null) {
      return _SessionPreviewPanel(
        key: ValueKey('preview:$_previewSessionId'),
        sessionId: _previewSessionId!,
        onClose: _closePreview,
      );
    }
    // 2. Active running session
    if (active != null) {
      return TestSessionActiveContent(
        key: ValueKey('$s:${active.id}'),
        resumeSessionId: active.id,
      );
    }
    // 3. Start card (no active session)
    return _StartCard(
      serial: s,
      onNewSession: _openNewSession,
    );
  }
}

// ── Right: start / resume card ──────────────────────────────────────────────

class _StartCard extends StatelessWidget {
  final String serial;
  final VoidCallback onNewSession;

  const _StartCard({required this.serial, required this.onNewSession});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final db = context.read<AppDatabase>();
    final sessionProvider = context.read<TestSessionProvider>();

    return StreamBuilder<TestSessionRow?>(
      key: ValueKey('start-card-active:$serial'),
      stream: db.testSessionsDao.watchActiveSessionForDevice(serial),
      builder: (context, snap) {
        final active = snap.data;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.assignment_outlined,
                  size: 40, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                active != null ? tr('continueSession') : tr('newSession'),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              if (active != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(30),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${tr('sessionRunning')} · ${active.name}',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade300),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ] else ...[
                Text(
                  tr('noSessionHint'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: active != null
                    ? () => sessionProvider.loadHistoricalSession(active.id)
                    : onNewSession,
                icon: Icon(active != null ? Icons.play_arrow : Icons.add),
                label: Text(active != null ? tr('continueSession') : tr('newSession')),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              if (active != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _finishSession(context, sessionProvider),
                  icon: const Icon(Icons.stop_circle_outlined, size: 16),
                  label: Text(tr('finishSession')),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _finishSession(
      BuildContext context, TestSessionProvider provider) async {
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
    if (confirmed != true) return;
    await provider.finishSession();
  }
}

// ── Left: history list ────────────────────────────────────────────────────────

class _HistoryPanel extends StatelessWidget {
  final String serial;
  final void Function(String sessionId) onItemTap;

  const _HistoryPanel({super.key, required this.serial, required this.onItemTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final db = context.read<AppDatabase>();

    return StreamBuilder<List<TestSessionRow>>(
      key: ValueKey('history-stream:$serial'),
      stream: db.testSessionsDao.watchSessionsForDevice(serial),
      builder: (context, snap) {
        // Exclude running sessions from the history list (they're shown in the right panel)
        final sessions = (snap.data ?? [])
            .where((r) => r.status != TestSessionStatus.running)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  Icon(Icons.history, color: theme.colorScheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    tr('sessionHistory'),
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    '${sessions.length}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Expanded(
              child: sessions.isEmpty
                  ? Center(
                      child: Text(
                        tr('noHistorySessions'),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(10),
                      itemCount: sessions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, i) => _HistoryItem(
                        session: sessions[i],
                        onTap: () => onItemTap(sessions[i].id),
                        onDelete: () => _deleteSession(context, sessions[i]),
                        onExport: (type) => _exportSession(context, sessions[i], type),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteSession(BuildContext context, TestSessionRow session) async {
    final provider = context.read<TestSessionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('deleteSession')),
        content: Text(tr('deleteSessionConfirm', {'name': session.name})),
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
    if (confirmed != true) return;
    await provider.deleteSession(session.id);
    messenger.showSnackBar(
      SnackBar(content: Text(tr('sessionDeleted')), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _exportSession(BuildContext context, TestSessionRow session, String exportType) async {
    final provider = context.read<TestSessionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(
        SnackBar(content: Text(tr('exportingSession')), behavior: SnackBarBehavior.floating),
      );

      String? path;
      if (exportType == 'downloads') {
        path = await provider.exportSessionToDownloads(sessionId: session.id);
      } else {
        path = await provider.exportSessionWithPicker(sessionId: session.id);
        if (path == null) {
          messenger.hideCurrentSnackBar();
          return;
        }
      }

      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr('sessionExported', {'path': path})),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${tr('exportFailed')}: $e'), behavior: SnackBarBehavior.floating),
      );
    }
  }
}

class _HistoryItem extends StatelessWidget {
  final TestSessionRow session;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final void Function(String) onExport;

  const _HistoryItem({
    required this.session,
    required this.onTap,
    required this.onDelete,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final elapsed = session.endedAt?.difference(session.startedAt);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: session.status == TestSessionStatus.finished
                      ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 3,
                      children: [
                        _badge(session.type, theme),
                        Text(
                          elapsed != null
                              ? tr('sessionElapsed', {'time': _fmtDuration(elapsed)})
                              : _fmtDate(session.startedAt),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 32),
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.archive_outlined, size: 16,
                      color: theme.colorScheme.primary),
                  tooltip: tr('exportSessionTitle'),
                  onSelected: onExport,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'downloads',
                      child: Row(
                        children: [
                          const Icon(Icons.download, size: 16),
                          const SizedBox(width: 8),
                          Text(tr('exportToDownloads')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'custom',
                      child: Row(
                        children: [
                          const Icon(Icons.folder_open, size: 16),
                          const SizedBox(width: 8),
                          Text(tr('exportToCustom')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 32),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.delete_outline, size: 16,
                      color: theme.colorScheme.error),
                  onPressed: onDelete,
                  tooltip: tr('deleteSession'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, ThemeData theme) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 80),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: theme.colorScheme.onPrimaryContainer),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  String _fmtDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

/// Read-only preview panel shown in the hub's right slot when a history
/// item is tapped. Displays all session details and an "re-open" button.
class _SessionPreviewPanel extends StatefulWidget {
  final String sessionId;
  final VoidCallback onClose;

  const _SessionPreviewPanel({super.key, required this.sessionId, required this.onClose});

  @override
  State<_SessionPreviewPanel> createState() => _SessionPreviewPanelState();
}

class _SessionPreviewPanelState extends State<_SessionPreviewPanel> {
  TestSession? _session;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_SessionPreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final s = await context.read<TestSessionProvider>().loadHistoricalSession(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _session = s;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: Text(tr('retry'))),
          ],
        ),
      );
    }

    final s = _session!;
    final elapsed = s.endedAt != null
        ? s.endedAt!.difference(s.startedAt)
        : DateTime.now().difference(s.startedAt);

    return Column(
      children: [
        // ── Toolbar ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 18),
                onPressed: widget.onClose,
                tooltip: tr('back'),
              ),
              const SizedBox(width: 4),
              Icon(
                s.status == TestSessionStatus.finished
                    ? Icons.check_circle
                    : Icons.pending,
                size: 16,
                color: s.status == TestSessionStatus.finished
                    ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _fmtDuration(elapsed),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {
                  context.read<TestSessionProvider>().loadHistoricalSession(s.id);
                  widget.onClose();
                },
                icon: const Icon(Icons.open_in_new, size: 14),
                label: Text(tr('reopenSession')),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ],
          ),
        ),
        // ── Content ───────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoCard(theme, [
                  _kv(tr('sessionName'), s.name),
                  _kv(tr('sessionType'), s.type),
                  _kv(tr('device'),
                      s.deviceModel.isEmpty ? s.deviceSerial : '${s.deviceModel} (${s.deviceSerial})'),
                  if (s.packageName.isNotEmpty) _kv(tr('package'), s.packageName),
                  _kv(tr('startedAt'), fmtDateTime(s.startedAt)),
                  if (s.endedAt != null) _kv(tr('endedAt'), fmtDateTime(s.endedAt!)),
                  _kv(tr('duration'), _fmtDuration(elapsed)),
                  if (s.note.isNotEmpty) _kv(tr('sessionNote'), s.note),
                ]),
                const SizedBox(height: 20),

                // Test plan
                _sectionTitle(theme, tr('sessionTestPlan')),
                if (s.testPlan.isEmpty)
                  Text(tr('noTestPlan'), style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
                else
                  ...s.testPlan.map((item) => _planItem(theme, item)),

                const SizedBox(height: 16),

                // Issues
                _sectionTitle(theme, '${tr('sessionIssues')} (${s.issues.length})'),
                if (s.issues.isEmpty)
                  Text(tr('noIssues'), style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
                else
                  ...s.issues.map((issue) => _issueItem(theme, issue)),

                const SizedBox(height: 16),

                // Notes
                _sectionTitle(theme, '${tr('sessionNotes')} (${s.notes.length})'),
                if (s.notes.isEmpty)
                  Text(tr('noNotes'), style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
                else
                  ...s.notes.map((note) => _noteItem(theme, note)),

                const SizedBox(height: 16),

                // Artifacts
                _sectionTitle(theme, '${tr('sessionArtifacts')} (${s.artifacts.length})'),
                if (s.artifacts.isEmpty)
                  Text(tr('noArtifacts'), style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
                else
                  ...s.artifacts.map((a) => previewArtifactItem(theme, a, sessionId: s.id)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
    );
  }

  Widget _infoCard(ThemeData theme, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(children: children),
    );
  }

  Widget _kv(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(label,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
          ],
        ),
      );

  Widget _planItem(ThemeData theme, TestSessionPlanItem item) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 6),
        color: theme.colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _planStatusIcon(item.status),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.flowName.isNotEmpty)
                      Text(item.flowName,
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                    Text(item.step, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    if (item.message.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(item.message, style: TextStyle(fontSize: 12, color: theme.colorScheme.error)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _planStatusIcon(TestSessionPlanStatus status) {
    return Icon(
      switch (status) {
        TestSessionPlanStatus.pending => Icons.radio_button_unchecked,
        TestSessionPlanStatus.passed => Icons.check_circle,
        TestSessionPlanStatus.failed => Icons.cancel,
      },
      size: 16,
      color: switch (status) {
        TestSessionPlanStatus.pending => Colors.grey,
        TestSessionPlanStatus.passed => Colors.green,
        TestSessionPlanStatus.failed => Colors.red,
      },
    );
  }

  Widget _issueItem(ThemeData theme, TestSessionIssue issue) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 6),
        color: theme.colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _severityColor(issue.severity).withAlpha(35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(_severityLabel(issue.severity),
                        style: TextStyle(fontSize: 11, color: _severityColor(issue.severity), fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(issue.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                ],
              ),
              if (issue.actual.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(issue.actual, style: const TextStyle(fontSize: 12)),
              ],
              const SizedBox(height: 4),
              Text(fmtDateTime(issue.createdAt),
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );

  Widget _noteItem(ThemeData theme, TestSessionNote note) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 6),
        color: theme.colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fmtDateTime(note.createdAt),
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(note.content),
            ],
          ),
        ),
      );

  Widget _artifactItem(ThemeData theme, TestSessionArtifact a) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 6),
        color: theme.colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Icon(_artifactIcon(a.kind), size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(a.name, style: const TextStyle(fontSize: 12))),
              if (a.size > 0)
                Text(fmtBytes(a.size), style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );

  IconData _artifactIcon(TestSessionArtifactKind k) => switch (k) {
        TestSessionArtifactKind.screenshot => Icons.image,
        TestSessionArtifactKind.video => Icons.videocam,
        TestSessionArtifactKind.log => Icons.list_alt,
        TestSessionArtifactKind.report => Icons.description,
      };

  Color _severityColor(TestSessionIssueSeverity s) => switch (s) {
        TestSessionIssueSeverity.blocker => Colors.red,
        TestSessionIssueSeverity.major => Colors.deepOrange,
        TestSessionIssueSeverity.normal => Colors.orange,
        TestSessionIssueSeverity.minor => Colors.blueGrey,
      };

  String _severityLabel(TestSessionIssueSeverity s) => switch (s) {
        TestSessionIssueSeverity.blocker => tr('issueSeverityBlocker'),
        TestSessionIssueSeverity.major => tr('issueSeverityMajor'),
        TestSessionIssueSeverity.normal => tr('issueSeverityNormal'),
        TestSessionIssueSeverity.minor => tr('issueSeverityMinor'),
      };

  String _fmtDuration(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    return '${m}m ${s}s';
  }
}


// ── New session dialog (shown in hub's right panel) ───────────────────────────

class _NewSessionDialog extends StatefulWidget {
  final String serial;

  const _NewSessionDialog({required this.serial});

  @override
  State<_NewSessionDialog> createState() => _NewSessionDialogState();
}

class _NewSessionDialogState extends State<_NewSessionDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _packageCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _flowsCtrl;
  String _type = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final tr_ = tr;
    final currentApp = context.read<TestConfigProvider>().currentApp;
    _nameCtrl = TextEditingController(text: tr_('defaultSessionName'));
    _packageCtrl = TextEditingController(text: currentApp?.packageName ?? '');
    _noteCtrl = TextEditingController();
    _flowsCtrl = TextEditingController(
      text: currentApp == null ? '' : formatTestFlowText(currentApp.testFlows),
    );
    _type = tr_('sessionTypeBug');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _packageCtrl.dispose();
    _noteCtrl.dispose();
    _flowsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);

    final deviceProvider = context.read<DeviceProvider>();
    Device? device;
    try {
      // widget.serial is the stable identity (ro.serialno); match
      // against either of the Device's two identity fields — adb
      // serial for USB (same as ro.serialno) and the dedicated
      // hardwareSerial for wireless. See Device.matchesIdentity.
      device = deviceProvider.devices
          .firstWhere((d) => d.matchesIdentity(widget.serial));
    } catch (_) {
      device = null;
    }
    final displayName = device?.displayName ?? widget.serial;

    final tr_ = tr;
    try {
      await context.read<TestSessionProvider>().startSession(
        name: _nameCtrl.text,
        type: _type,
        serial: widget.serial,
        model: device?.model ?? '',
        brand: device?.brand ?? '',
        sdk: device?.sdk ?? '',
        deviceDisplayName: displayName,
        packageName: _packageCtrl.text,
        note: _noteCtrl.text,
        testPlanItems: _buildPlanItems(parseTestFlowText(_flowsCtrl.text)),
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr_('startSessionFailed')}: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<TestSessionPlanItem> _buildPlanItems(List<TestFlowConfig> flows) {
    final items = <TestSessionPlanItem>[];
    for (final flow in flows) {
      for (final step in flow.steps) {
        if (step.trim().isEmpty) continue;
        items.add(TestSessionPlanItem(flowName: flow.name, step: step.trim()));
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr_ = tr;
    final deviceProvider = context.read<DeviceProvider>();
    Device? device;
    try {
      // widget.serial is the stable identity (ro.serialno); match
      // against either of the Device's two identity fields — adb
      // serial for USB (same as ro.serialno) and the dedicated
      // hardwareSerial for wireless. See Device.matchesIdentity.
      device = deviceProvider.devices
          .firstWhere((d) => d.matchesIdentity(widget.serial));
    } catch (_) {
      device = null;
    }
    final displayName = device?.displayName ?? widget.serial;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SafeDialog(
          controllers: [_nameCtrl, _packageCtrl, _noteCtrl, _flowsCtrl],
          builder: (_) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Text(
                  tr_('newSession'),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),

                // Session name
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(labelText: tr_('sessionName')),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),

                // Device (read-only)
                TextFormField(
                  initialValue: displayName,
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: tr_('device'),
                    suffixIcon: const Icon(Icons.lock_outline, size: 16),
                  ),
                ),
                const SizedBox(height: 14),

                // Type
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(labelText: tr_('sessionType')),
                  initialValue: _type,
                  items: [
                    tr_('sessionTypeBug'),
                    tr_('sessionTypeSmoke'),
                    tr_('sessionTypeRegression'),
                    tr_('sessionTypeCompatibility'),
                    tr_('sessionTypeOther'),
                  ].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                  onChanged: (value) => setState(() => _type = value ?? _type),
                ),
                const SizedBox(height: 14),

                // Package
                TextField(
                  controller: _packageCtrl,
                  decoration: InputDecoration(labelText: tr_('packageName')),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),

                // Note
                TextField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: tr_('sessionNote')),
                ),
                const SizedBox(height: 14),

                // Test flows
                TextField(
                  controller: _flowsCtrl,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: tr_('configTestFlows'),
                    hintText: tr_('configTestFlowsHint'),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      child: Text(tr_('cancel')),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(tr_('startSession')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
