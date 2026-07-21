import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';
import '../i18n.dart';
import '../providers/device_provider.dart' show DeviceScreenActiveScope;
import '../providers/locale_provider.dart';

class BackendLogEntry {
  final String time;
  final String command;
  final String result;
  final String err;
  final String elapsed;

  BackendLogEntry({
    required this.time,
    required this.command,
    required this.result,
    required this.err,
    required this.elapsed,
  });

  factory BackendLogEntry.fromJson(Map<String, dynamic> json) {
    return BackendLogEntry(
      time: json['time'] ?? '',
      command: json['command'] ?? '',
      result: json['result'] ?? '',
      err: json['err'] ?? '',
      elapsed: json['elapsed'] ?? '',
    );
  }

  bool get isError => err.isNotEmpty;
  bool get isBinary => result.startsWith('<') && result.endsWith('>');
}

class BackendLogScreen extends StatefulWidget {
  const BackendLogScreen({super.key});

  @override
  State<BackendLogScreen> createState() => _BackendLogScreenState();
}

class _BackendLogScreenState extends State<BackendLogScreen> {
  List<BackendLogEntry> _logs = [];
  Timer? _pollTimer;
  bool _autoScroll = true;
  bool _serverOnline = false;
  String _serverInfo = '';
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _filterCtrl = TextEditingController();
  String _filterQuery = '';
  bool _showErrorsOnly = false;

  // Consecutive fetch failures. After [_maxConsecutiveErrors] in a row
  // the poll timer is cancelled and the status banner flips to offline —
  // the previous `catch (_) {}` silently retried forever, even with the
  // backend gone. Hitting Refresh after the backend recovers restarts it.
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 3;
  // Debounce for the filter text field — the previous per-keystroke
  // setState re-filtered (and rebuilt the whole log list) on every tap.
  Timer? _filterDebounce;

  @override
  void initState() {
    super.initState();
    _fetch();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _fetch());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _filterDebounce?.cancel();
    _scrollCtrl.dispose();
    _filterCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    // Skip the HTTP round-trip while this tab isn't the active one in
    // the IndexedStack — the screen stays mounted, so without this
    // guard the 2s poll keeps hitting the backend from the background.
    if (!context.read<DeviceScreenActiveScope>().active) return;
    try {
      final api = context.read<ApiClient>();
      final identity = await api.getServerIdentity();
      final list = await api.getBackendLogs();
      final logs = list.map((e) => BackendLogEntry.fromJson(e)).toList();
      if (!mounted) return;
      final wasAtBottom = _scrollCtrl.hasClients &&
          _scrollCtrl.position.pixels >=
              _scrollCtrl.position.maxScrollExtent - 30;
      setState(() {
        _logs = logs;
        _serverOnline = identity != null;
        if (identity != null) {
          final pid = identity['pid']?.toString() ?? '?';
          final started = identity['started']?.toString() ?? '';
          _serverInfo =
              tr('backendServerOnline', {'pid': pid, 'started': started});
        } else {
          _serverInfo = tr('backendServerOffline');
        }
      });
      // Success: reset the failure streak and, if the timer had been
      // stopped (e.g. user hit Refresh after a recovery), restart it.
      _consecutiveErrors = 0;
      _pollTimer ??=
          Timer.periodic(const Duration(seconds: 2), (_) => _fetch());
      if (_autoScroll && wasAtBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
          }
        });
      }
    } catch (_) {
      if (!mounted) return;
      _consecutiveErrors++;
      if (_consecutiveErrors >= _maxConsecutiveErrors) {
        _pollTimer?.cancel();
        _pollTimer = null;
        setState(() {
          _serverOnline = false;
          _serverInfo = tr('backendServerOffline');
        });
      }
    }
  }

  List<BackendLogEntry> get _filteredLogs {
    var list = _logs;
    if (_showErrorsOnly) {
      list = list.where((l) => l.isError).toList();
    }
    if (_filterQuery.isNotEmpty) {
      final q = _filterQuery.toLowerCase();
      list = list
          .where((l) =>
              l.command.toLowerCase().contains(q) ||
              l.result.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
    final entries = _filteredLogs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildServerStatus(context),
        _buildToolbar(context),
        Expanded(child: _buildLogList(context, entries)),
        _buildStatusBar(context),
      ],
    );
  }

  Widget _buildServerStatus(BuildContext context) {
    final theme = Theme.of(context);
    final color = _serverOnline ? Colors.green : Colors.red;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _serverOnline ? Icons.check_circle : Icons.error,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _serverInfo.isEmpty
                      ? tr('backendServerChecking')
                      : _serverInfo,
                  style: TextStyle(
                    fontSize: 11,
                    color: _serverOnline
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            tr('backendLogsContextHint'),
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
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
      child: Row(
        children: [
          FilledButton.tonal(
            onPressed: _fetch,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.refresh, size: 16),
                const SizedBox(width: 4),
                Text(tr('refresh')),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 200,
            child: TextField(
              controller: _filterCtrl,
              onChanged: (v) {
                // Debounce — the previous per-keystroke setState
                // re-filtered the whole log list on every tap.
                _filterDebounce?.cancel();
                _filterDebounce = Timer(const Duration(milliseconds: 200), () {
                  if (mounted) setState(() => _filterQuery = v);
                });
              },
              decoration: InputDecoration(
                hintText: tr('filterCommand'),
                hintStyle: const TextStyle(fontSize: 11),
                prefixIcon: const Icon(Icons.search, size: 16),
                border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(6))),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: _showErrorsOnly,
                  onChanged: (v) =>
                      setState(() => _showErrorsOnly = v ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 4),
              Text(tr('errorsOnly'),
                  style: TextStyle(fontSize: 11, color: Colors.red.shade300)),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: _autoScroll,
                  onChanged: (v) => setState(() => _autoScroll = v ?? true),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 4),
              Text(tr('autoScroll'), style: const TextStyle(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogList(BuildContext context, List<BackendLogEntry> entries) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.terminal, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(tr('noLogs'), style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(tr('backendLogsHint'),
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      itemCount: entries.length,
      padding: EdgeInsets.zero,
      itemBuilder: (ctx, i) => _buildLogRow(context, entries[i]),
    );
  }

  Widget _buildLogRow(BuildContext context, BackendLogEntry entry) {
    final theme = Theme.of(context);
    final bg = entry.isError
        ? Colors.red.withAlpha(15)
        : (entry.isBinary ? Colors.blue.withAlpha(10) : Colors.transparent);

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () => _showDetail(context, entry),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(entry.time,
                  style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'Menlo',
                      color: theme.colorScheme.onSurfaceVariant)),
            ),
            SizedBox(
              width: 50,
              child: Text(entry.elapsed,
                  style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'Menlo',
                      color: entry.elapsed.startsWith('-')
                          ? Colors.red
                          : Colors.green.shade300)),
            ),
            if (entry.isError)
              const SizedBox(
                width: 40,
                child: Text('ERROR',
                    style: TextStyle(fontSize: 9, color: Colors.red)),
              ),
            Expanded(
              child: Text(
                entry.command,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Menlo',
                  color:
                      entry.isError ? Colors.red : theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, BackendLogEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        return Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 700,
              maxHeight: size.height * 0.85,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Text(entry.time,
                        style:
                            const TextStyle(fontSize: 11, fontFamily: 'Menlo')),
                    const Spacer(),
                    Text(entry.elapsed,
                        style:
                            const TextStyle(fontSize: 11, fontFamily: 'Menlo')),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ]),
                  const Divider(),
                  const SizedBox(height: 4),
                  Text(tr('command'),
                      style: Theme.of(ctx).textTheme.labelSmall),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SelectableText(
                      entry.command,
                      style: const TextStyle(fontFamily: 'Menlo', fontSize: 11),
                    ),
                  ),
                  if (entry.isError) ...[
                    const SizedBox(height: 8),
                    Text(tr('error'),
                        style: Theme.of(ctx)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: Colors.red)),
                    const SizedBox(height: 4),
                    SingleChildScrollView(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: SelectableText(
                          entry.err,
                          style: const TextStyle(
                              fontFamily: 'Menlo',
                              fontSize: 11,
                              color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                  if (entry.result.isNotEmpty && !entry.isError) ...[
                    const SizedBox(height: 8),
                    Text(tr('output'),
                        style: Theme.of(ctx).textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            entry.result,
                            style: const TextStyle(
                                fontFamily: 'Menlo', fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBar(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _filteredLogs;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(children: [
        Text(tr('logCount', {'count': entries.length.toString()}),
            style: const TextStyle(fontSize: 11)),
        if (entries.length != _logs.length)
          Text(tr('totalCountLogs', {'total': _logs.length.toString()}),
              style: TextStyle(
                  fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}
