import 'package:flutter/material.dart';
import '../services/api_client.dart';

const _quickGroups = [
  _ActionGroup(
    title: '设备信息',
    icon: Icons.phone_android,
    actions: [
      _QuickAction('基础信息', 'shell getprop ro.product.model', Icons.info_outline),
      _QuickAction('Android 版本', 'shell getprop ro.build.version.release', Icons.android),
      _QuickAction('设备序列号', 'get-serialno', Icons.confirmation_number_outlined),
      _QuickAction('电池状态', 'shell dumpsys battery', Icons.battery_full),
    ],
  ),
  _ActionGroup(
    title: '屏幕控制',
    icon: Icons.screenshot_monitor,
    actions: [
      _QuickAction('分辨率', 'shell wm size', Icons.aspect_ratio),
      _QuickAction('屏幕密度', 'shell wm density', Icons.density_medium),
      _QuickAction('点亮屏幕', 'shell input keyevent 224', Icons.light_mode),
      _QuickAction('锁屏/电源键', 'shell input keyevent 26', Icons.power_settings_new),
    ],
  ),
  _ActionGroup(
    title: '按键模拟',
    icon: Icons.touch_app,
    actions: [
      _QuickAction('Home', 'shell input keyevent 3', Icons.home),
      _QuickAction('返回', 'shell input keyevent 4', Icons.arrow_back),
      _QuickAction('最近任务', 'shell input keyevent 187', Icons.dynamic_feed),
      _QuickAction('菜单键', 'shell input keyevent 82', Icons.menu),
    ],
  ),
  _ActionGroup(
    title: '调试诊断',
    icon: Icons.bug_report,
    actions: [
      _QuickAction('当前 Activity', 'shell dumpsys activity top', Icons.layers),
      _QuickAction('当前焦点', 'shell sh -c "dumpsys window | grep -E \'mCurrentFocus|mFocusedApp\'"', Icons.center_focus_strong),
      _QuickAction('CPU Top', 'shell top -n 1 -m 10', Icons.memory),
      _QuickAction('进程列表', 'shell ps -A', Icons.account_tree),
    ],
  ),
  _ActionGroup(
    title: '存储网络',
    icon: Icons.storage,
    actions: [
      _QuickAction('存储空间', 'shell df -h', Icons.sd_storage),
      _QuickAction('网络地址', 'shell ip addr show', Icons.wifi),
      _QuickAction('路由信息', 'shell ip route', Icons.route),
      _QuickAction('连接状态', 'shell dumpsys connectivity', Icons.hub),
    ],
  ),
  _ActionGroup(
    title: '维护操作',
    icon: Icons.build_circle,
    actions: [
      _QuickAction('清空 Logcat', 'logcat -c', Icons.cleaning_services, confirm: true),
      _QuickAction('ADB over WiFi', 'tcpip 5555', Icons.wifi_tethering, confirm: true),
      _QuickAction('恢复 USB ADB', 'usb', Icons.usb, confirm: true),
      _QuickAction('重启设备', 'reboot', Icons.restart_alt, confirm: true, destructive: true),
    ],
  ),
];

class AdbCommandScreen extends StatefulWidget {
  final ApiClient api;
  final String? selectedSerial;

  const AdbCommandScreen({
    super.key,
    required this.api,
    required this.selectedSerial,
  });

  @override
  State<AdbCommandScreen> createState() => _AdbCommandScreenState();
}

class _AdbCommandScreenState extends State<AdbCommandScreen> {
  final TextEditingController _commandCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<_CommandRecord> _records = [];
  bool _running = false;
  String? _error;

  @override
  void dispose() {
    _commandCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  List<String> _parseCommand(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return [];
    final adbPrefix = RegExp(r'^adb(\.exe)?\s+');
    text = text.replaceFirst(adbPrefix, '').trim();
    final tokens = <String>[];
    final buffer = StringBuffer();
    var quote = '';
    var escaped = false;

    for (final codeUnit in text.codeUnits) {
      final ch = String.fromCharCode(codeUnit);
      if (escaped) {
        buffer.write(ch);
        escaped = false;
        continue;
      }
      if (ch == '\\') {
        escaped = true;
        continue;
      }
      if (quote.isNotEmpty) {
        if (ch == quote) {
          quote = '';
        } else {
          buffer.write(ch);
        }
        continue;
      }
      if (ch == '"' || ch == "'") {
        quote = ch;
        continue;
      }
      if (ch.trim().isEmpty) {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        continue;
      }
      buffer.write(ch);
    }

    if (escaped) buffer.write('\\');
    if (buffer.isNotEmpty) tokens.add(buffer.toString());
    if (tokens.isNotEmpty && tokens.first == '-s') {
      if (tokens.length > 2) return tokens.sublist(2);
      return [];
    }
    return tokens;
  }

  Future<void> _runCommand() async {
    await _executeCommand(_commandCtrl.text.trim(), fillInput: false);
  }

  Future<void> _executeCommand(String raw, {bool fillInput = true}) async {
    if (_running || widget.selectedSerial == null) return;
    final command = raw.trim();
    final args = _parseCommand(command);
    if (args.isEmpty) {
      setState(() => _error = '请输入 adb 指令，例如 shell getprop ro.product.model');
      return;
    }

    if (fillInput) {
      _commandCtrl.text = command;
      _commandCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _commandCtrl.text.length),
      );
    }

    setState(() {
      _running = true;
      _error = null;
    });

    try {
      final result = await widget.api.executeAdbCommand(widget.selectedSerial!, args);
      if (!mounted) return;
      setState(() {
        _records.add(_CommandRecord(
          command: command,
          output: result.output,
          error: result.error,
          ok: result.ok,
          time: DateTime.now(),
        ));
        _running = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _running = false;
      });
    }
  }

  Future<void> _runQuickAction(_QuickAction action) async {
    if (action.confirm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(action.destructive ? '确认危险操作' : '确认执行'),
          content: Text('即将对当前设备执行：\n\nadb -s ${widget.selectedSerial} ${action.command}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: action.destructive
                  ? FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error)
                  : null,
              child: const Text('执行'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _executeCommand(action.command);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearRecords() {
    setState(() => _records.clear());
  }

  void _fillExample(String command) {
    _commandCtrl.text = command;
    _commandCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _commandCtrl.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.selectedSerial == null) {
      return Center(
        child: Text('请先选择设备',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('ADB 指令',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(widget.selectedSerial!, style: const TextStyle(fontSize: 11)),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _records.isEmpty ? null : _clearRecords,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('清空输出'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('输入 adb 参数即可执行，系统会自动绑定当前设备；也可以直接粘贴以 adb 开头的完整指令。',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _commandCtrl,
                  minLines: 1,
                  maxLines: 3,
                  onSubmitted: (_) => _runCommand(),
                  decoration: InputDecoration(
                    hintText: 'shell getprop ro.product.model',
                    prefixText: 'adb -s ${widget.selectedSerial} ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _running ? null : _runCommand,
                icon: _running
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow, size: 18),
                label: Text(_running ? '执行中...' : '执行'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
          ],
          const SizedBox(height: 14),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 390,
                  child: _buildQuickPanel(theme),
                ),
                const SizedBox(width: 14),
                Expanded(child: _buildOutputPanel(theme)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleChip(String label, String command) {
    return ActionChip(
      label: Text(label),
      avatar: const Icon(Icons.bolt, size: 14),
      onPressed: () => _fillExample(command),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildQuickPanel(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('一键小功能',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(10),
              itemCount: _quickGroups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _buildActionGroup(theme, _quickGroups[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionGroup(ThemeData theme, _ActionGroup group) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(group.icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(group.title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: group.actions.map((action) => _buildActionButton(theme, action)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(ThemeData theme, _QuickAction action) {
    final color = action.destructive ? theme.colorScheme.error : theme.colorScheme.primary;
    return OutlinedButton.icon(
      onPressed: _running ? null : () => _runQuickAction(action),
      icon: Icon(action.icon, size: 15, color: action.destructive ? color : null),
      label: Text(action.label),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        textStyle: const TextStyle(fontSize: 11),
        foregroundColor: action.destructive ? color : null,
        side: action.destructive ? BorderSide(color: color.withAlpha(160)) : null,
      ),
    );
  }

  Widget _buildOutputPanel(ThemeData theme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _records.isEmpty
          ? Center(
              child: Text('执行结果会显示在这里',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            )
          : ListView.separated(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(12),
              itemCount: _records.length,
              separatorBuilder: (_, __) => Divider(color: theme.dividerColor),
              itemBuilder: (ctx, i) => _buildRecord(theme, _records[i]),
            ),
    );
  }

  Widget _buildRecord(ThemeData theme, _CommandRecord record) {
    final color = record.ok ? Colors.green : theme.colorScheme.error;
    final content = record.output.isNotEmpty
        ? record.output
        : record.error.isNotEmpty
            ? record.error
            : '(无输出)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(record.ok ? Icons.check_circle : Icons.error_outline, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text('adb -s ${widget.selectedSerial} ${record.command}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
            Text(_formatTime(record.time),
                style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 8),
        SelectableText(
          content,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            height: 1.35,
            color: record.ok ? theme.colorScheme.onSurface : theme.colorScheme.error,
          ),
        ),
        if (!record.ok && record.output.isNotEmpty && record.error.isNotEmpty) ...[
          const SizedBox(height: 8),
          SelectableText(
            record.error,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              height: 1.35,
              color: theme.colorScheme.error.withAlpha(190),
            ),
          ),
        ],
      ],
    );
  }

  String _formatTime(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }
}

class _ActionGroup {
  final String title;
  final IconData icon;
  final List<_QuickAction> actions;

  const _ActionGroup({
    required this.title,
    required this.icon,
    required this.actions,
  });
}

class _QuickAction {
  final String label;
  final String command;
  final IconData icon;
  final bool confirm;
  final bool destructive;

  const _QuickAction(
    this.label,
    this.command,
    this.icon, {
    this.confirm = false,
    this.destructive = false,
  });
}

class _CommandRecord {
  final String command;
  final String output;
  final String error;
  final bool ok;
  final DateTime time;

  _CommandRecord({
    required this.command,
    required this.output,
    required this.error,
    required this.ok,
    required this.time,
  });
}
