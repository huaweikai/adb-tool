import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';
import '../i18n.dart';
import '../providers/locale_provider.dart';
import '../providers/device_provider.dart';
import '../providers/test_config_provider.dart';

const _quickGroups = [
  _ActionGroup(
    titleKey: 'quickGroupDeviceInfo',
    icon: Icons.phone_android,
    actions: [
      _QuickAction('quickActionBasicInfo', 'shell getprop ro.product.model',
          Icons.info_outline),
      _QuickAction('quickActionAndroidVersion',
          'shell getprop ro.build.version.release', Icons.android),
      _QuickAction('quickActionDeviceSerial', 'get-serialno',
          Icons.confirmation_number_outlined),
      _QuickAction('quickActionBatteryStatus', 'shell dumpsys battery',
          Icons.battery_full),
    ],
  ),
  _ActionGroup(
    titleKey: 'quickGroupScreenControl',
    icon: Icons.screenshot_monitor,
    actions: [
      _QuickAction(
          'quickActionResolution', 'shell wm size', Icons.aspect_ratio),
      _QuickAction(
          'quickActionScreenDensity', 'shell wm density', Icons.density_medium),
      _QuickAction('quickActionWakeScreen', 'shell input keyevent 224',
          Icons.light_mode),
      _QuickAction('quickActionPowerKey', 'shell input keyevent 26',
          Icons.power_settings_new),
    ],
  ),
  _ActionGroup(
    titleKey: 'quickGroupKeySimulation',
    icon: Icons.touch_app,
    actions: [
      _QuickAction('quickActionHome', 'shell input keyevent 3', Icons.home),
      _QuickAction(
          'quickActionBack', 'shell input keyevent 4', Icons.arrow_back),
      _QuickAction(
          'quickActionRecents', 'shell input keyevent 187', Icons.dynamic_feed),
      _QuickAction('quickActionMenuKey', 'shell input keyevent 82', Icons.menu),
    ],
  ),
  _ActionGroup(
    titleKey: 'quickGroupDebugDiagnostics',
    icon: Icons.bug_report,
    actions: [
      _QuickAction('quickActionCurrentActivity', 'shell dumpsys activity top',
          Icons.layers),
      _QuickAction(
          'quickActionCurrentFocus',
          'shell sh -c "dumpsys window | grep -E \'mCurrentFocus|mFocusedApp\'"',
          Icons.center_focus_strong),
      _QuickAction('quickActionCpuTop', 'shell top -n 1 -m 10', Icons.memory),
      _QuickAction('quickActionProcessList', 'shell ps -A', Icons.account_tree),
    ],
  ),
  _ActionGroup(
    titleKey: 'quickGroupStorageNetwork',
    icon: Icons.storage,
    actions: [
      _QuickAction('quickActionStorageSpace', 'shell df -h', Icons.sd_storage),
      _QuickAction(
          'quickActionNetworkAddress', 'shell ip addr show', Icons.wifi),
      _QuickAction('quickActionRouteInfo', 'shell ip route', Icons.route),
      _QuickAction('quickActionConnectionStatus', 'shell dumpsys connectivity',
          Icons.hub),
    ],
  ),
  _ActionGroup(
    titleKey: 'quickGroupMaintenance',
    icon: Icons.build_circle,
    actions: [
      _QuickAction(
          'quickActionClearLogcat', 'logcat -c', Icons.cleaning_services,
          confirm: true),
      _QuickAction('quickActionAdbOverWifi', 'tcpip 5555', Icons.wifi_tethering,
          confirm: true),
      _QuickAction('quickActionRestoreUsbAdb', 'usb', Icons.usb, confirm: true),
      _QuickAction('quickActionRebootDevice', 'reboot', Icons.restart_alt,
          confirm: true, destructive: true),
    ],
  ),
  _ActionGroup(
    titleKey: 'quickGroupIntent',
    icon: Icons.open_in_browser,
    actions: [
      _QuickAction('quickActionViewUrl', '', Icons.language,
          dialog: true),
      _QuickAction('quickActionDeepLink', '', Icons.link,
          dialog: true),
      _QuickAction('quickActionCustomIntent', '', Icons.tune,
          customIntent: true),
    ],
  ),
];

class AdbCommandScreen extends StatefulWidget {
  const AdbCommandScreen({
    super.key,
  });

  @override
  State<AdbCommandScreen> createState() => _AdbCommandScreenState();
}

class _AdbCommandScreenState extends State<AdbCommandScreen> {
  String? get _selectedSerial => context.read<DeviceSerialScope>().serial;

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
    if (_running || _selectedSerial == null) return;
    final command = raw.trim();
    final args = _parseCommand(command);
    if (args.isEmpty) {
      setState(() => _error = tr('commandHint'));
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
      final result =
          await context.read<ApiClient>().executeAdbCommand(_selectedSerial!, args);
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
    if (action.customIntent) {
      _showCustomIntentDialog();
      return;
    }
    if (action.dialog) {
      final input = await _showTextInputDialog(action.labelKey);
      if (input == null || input.isEmpty) return;
      final cmd = action.labelKey == 'quickActionViewUrl'
          ? 'shell am start -a android.intent.action.VIEW -d $input'
          : 'shell am start -a android.intent.action.VIEW -d "$input"';
      await _executeCommand(cmd);
      return;
    }
    if (action.confirm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title:
              Text(action.destructive ? tr('dangerousOp') : tr('confirmExec')),
          content: Text(
              '${tr('confirmBody')}\n\nadb -s $_selectedSerial ${action.command}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: action.destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(ctx).colorScheme.error)
                  : null,
              child: Text(tr('execute')),
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

  Future<String?> _showTextInputDialog(String labelKey) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(labelKey)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: labelKey == 'quickActionViewUrl' ? 'https://...' : 'yourapp://...',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(tr('execute')),
          ),
        ],
      ),
    );
  }

  void _showCustomIntentDialog() {
    final actionCtrl = TextEditingController();
    final dataCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final extrasCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('quickActionCustomIntent')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: actionCtrl,
                decoration: InputDecoration(
                  labelText: tr('intentAction'),
                  hintText: 'android.intent.action.VIEW',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dataCtrl,
                decoration: InputDecoration(
                  labelText: tr('intentData'),
                  hintText: 'https://... 或 yourapp://...',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryCtrl,
                decoration: InputDecoration(
                  labelText: tr('intentCategory'),
                  hintText: 'android.intent.category.DEFAULT',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: extrasCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: tr('intentExtras'),
                  hintText: 'key1=val1\nkey2=val2\nboolKey true',
                  border: const OutlineInputBorder(),
                  isDense: true,
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
            onPressed: () {
              Navigator.pop(ctx);
              final parts = <String>['shell', 'am', 'start'];
              final action = actionCtrl.text.trim();
              final data = dataCtrl.text.trim();
              final category = categoryCtrl.text.trim();
              final extras = extrasCtrl.text.trim();
              if (action.isNotEmpty) {
                parts.addAll(['-a', action]);
              }
              if (data.isNotEmpty) {
                parts.addAll(['-d', "'$data'"]);
              }
              if (category.isNotEmpty) {
                parts.addAll(['-c', category]);
              }
              for (final line in extras.split('\n')) {
                final trimmed = line.trim();
                if (trimmed.isEmpty) continue;
                final spaceIdx = trimmed.lastIndexOf(' ');
                if (spaceIdx > 0) {
                  final val = trimmed.substring(spaceIdx + 1);
                  if (val == 'true' || val == 'false') {
                    parts.addAll(['--ez', trimmed.substring(0, spaceIdx), val]);
                  } else {
                    parts.addAll(['-e', trimmed.substring(0, spaceIdx), val]);
                  }
                }
              }
              _executeCommand(parts.join(' '));
            },
            child: Text(tr('execute')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
    context.watch<TestConfigProvider>();
    final theme = Theme.of(context);

    if (_selectedSerial == null) {
      return Center(
        child: Text(tr('selectDevice'),
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
              Text(tr('adbCommand'),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(_selectedSerial!,
                    style: const TextStyle(fontSize: 11)),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _records.isEmpty ? null : _clearRecords,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: Text(tr('clearOutput')),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(tr('commandHint'),
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
                    hintText: tr('adbInputHint'),
                    prefixText: 'adb -s $_selectedSerial ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
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
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow, size: 18),
                label: Text(_running ? tr('executing') : tr('execute')),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
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

  Widget _buildQuickPanel(ThemeData theme) {
    final config = context.read<TestConfigProvider>().currentApp;
    final groups = List<_ActionGroup>.from(_quickGroups);
    if (config != null && config.deepLinks.isNotEmpty) {
      groups.insert(
        0,
        _ActionGroup(
          titleKey: 'quickGroupConfigDeepLinks',
          icon: Icons.link,
          actions: config.deepLinks
              .map((dl) => _QuickAction(
                    dl.name,
                    'shell am start -a android.intent.action.VIEW -d "${dl.value}"',
                    Icons.open_in_browser,
                    confirm: false,
                  ))
              .toList(),
        ),
      );
    }
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
                Icon(Icons.auto_awesome,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(tr('quickActions'),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(10),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) =>
                  _buildActionGroup(theme, groups[i]),
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
              Text(tr(group.titleKey),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: group.actions
                .map((action) => _buildActionButton(theme, action))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(ThemeData theme, _QuickAction action) {
    final color = action.destructive
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    return OutlinedButton.icon(
      onPressed: _running ? null : () => _runQuickAction(action),
      icon:
          Icon(action.icon, size: 15, color: action.destructive ? color : null),
      label: Text(tr(action.labelKey)),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        textStyle: const TextStyle(fontSize: 11),
        foregroundColor: action.destructive ? color : null,
        side:
            action.destructive ? BorderSide(color: color.withAlpha(160)) : null,
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
              child: Text(tr('resultsHere'),
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
            : tr('noOutput');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(record.ok ? Icons.check_circle : Icons.error_outline,
                size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text('adb -s $_selectedSerial ${record.command}',
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
            Text(_formatTime(record.time),
                style: TextStyle(
                    fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 8),
        SelectableText(
          content,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            height: 1.35,
            color: record.ok
                ? theme.colorScheme.onSurface
                : theme.colorScheme.error,
          ),
        ),
        if (!record.ok &&
            record.output.isNotEmpty &&
            record.error.isNotEmpty) ...[
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
  final String titleKey;
  final IconData icon;
  final List<_QuickAction> actions;

  const _ActionGroup({
    required this.titleKey,
    required this.icon,
    required this.actions,
  });
}

class _QuickAction {
  final String labelKey;
  final String command;
  final IconData icon;
  final bool confirm;
  final bool destructive;
  final bool dialog;
  final bool customIntent;

  const _QuickAction(
    this.labelKey,
    this.command,
    this.icon, {
    this.confirm = false,
    this.destructive = false,
    this.dialog = false,
    this.customIntent = false,
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
