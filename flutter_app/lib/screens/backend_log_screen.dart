import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_client.dart';

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
  final ApiClient api;

  const BackendLogScreen({super.key, required this.api});

  @override
  State<BackendLogScreen> createState() => _BackendLogScreenState();
}

class _BackendLogScreenState extends State<BackendLogScreen> {
  List<BackendLogEntry> _logs = [];
  Timer? _pollTimer;
  bool _autoScroll = true;
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _filterCtrl = TextEditingController();
  String _filterQuery = '';
  bool _showErrorsOnly = false;

  @override
  void initState() {
    super.initState();
    _fetch();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _fetch());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollCtrl.dispose();
    _filterCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final resp = await http
          .get(Uri.parse('${widget.api.baseUrl}/api/backend-logs'))
          .timeout(const Duration(seconds: 3));
      if (resp.statusCode != 200) return;
      final data = json.decode(resp.body);
      final list = data['logs'] as List? ?? [];
      final logs = list.map((e) => BackendLogEntry.fromJson(e)).toList();
      if (!mounted) return;
      final wasAtBottom = _scrollCtrl.hasClients &&
          _scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 30;
      setState(() => _logs = logs);
      if (_autoScroll && wasAtBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
          }
        });
      }
    } catch (_) {}
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
    final entries = _filteredLogs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(context),
        Expanded(child: _buildLogList(context, entries)),
        _buildStatusBar(context),
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
      child: Row(
        children: [
          FilledButton.tonal(
            onPressed: _fetch,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, size: 16),
                SizedBox(width: 4),
                Text('刷新'),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 200,
            child: TextField(
              controller: _filterCtrl,
              onChanged: (v) => setState(() => _filterQuery = v),
              decoration: InputDecoration(
                hintText: '过滤命令...',
                hintStyle: const TextStyle(fontSize: 11),
                prefixIcon: const Icon(Icons.search, size: 16),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6))),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 24, width: 24,
                child: Checkbox(
                  value: _showErrorsOnly,
                  onChanged: (v) => setState(() => _showErrorsOnly = v ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 4),
              Text('仅错误', style: TextStyle(fontSize: 11, color: Colors.red.shade300)),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 24, width: 24,
                child: Checkbox(
                  value: _autoScroll,
                  onChanged: (v) => setState(() => _autoScroll = v ?? true),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 4),
              const Text('自动滚动', style: TextStyle(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogList(BuildContext context, List<BackendLogEntry> entries) {
    if (entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.terminal, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('没有日志记录', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 4),
            Text('切换回文件/应用等页面操作后日志会显示在这里',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
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
                  style: TextStyle(fontSize: 10, fontFamily: 'Menlo',
                      color: theme.colorScheme.onSurfaceVariant)),
            ),
            SizedBox(
              width: 50,
              child: Text(entry.elapsed,
                  style: TextStyle(fontSize: 10, fontFamily: 'Menlo',
                      color: entry.elapsed.startsWith('-') ? Colors.red : Colors.green.shade300)),
            ),
            if (entry.isError)
              const SizedBox(
                width: 40,
                child: Text('ERROR', style: TextStyle(fontSize: 9, color: Colors.red)),
              ),
            Expanded(
              child: Text(
                entry.command,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Menlo',
                  color: entry.isError ? Colors.red : theme.colorScheme.onSurface,
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
      builder: (ctx) => Dialog(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 500),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Text(entry.time, style: const TextStyle(fontSize: 11, fontFamily: 'Menlo')),
                const Spacer(),
                Text(entry.elapsed, style: const TextStyle(fontSize: 11, fontFamily: 'Menlo')),
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
              Text('命令', style: Theme.of(ctx).textTheme.labelSmall),
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
                Text('错误', style: Theme.of(ctx).textTheme.labelSmall?.copyWith(color: Colors.red)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    entry.err,
                    style: const TextStyle(fontFamily: 'Menlo', fontSize: 11, color: Colors.red),
                  ),
                ),
              ],
              if (entry.result.isNotEmpty && !entry.isError) ...[
                const SizedBox(height: 8),
                Text('输出', style: Theme.of(ctx).textTheme.labelSmall),
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
                        style: const TextStyle(fontFamily: 'Menlo', fontSize: 11),
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
        Text('日志: ${entries.length}', style: const TextStyle(fontSize: 11)),
        if (entries.length != _logs.length)
          Text(' (共 ${_logs.length})', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}
