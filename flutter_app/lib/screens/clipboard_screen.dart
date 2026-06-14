import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';
import '../i18n.dart';
import '../providers/locale_provider.dart';

class ClipboardScreen extends StatefulWidget {
  final String? selectedSerial;

  const ClipboardScreen({
    super.key,
    required this.selectedSerial,
  });

  @override
  State<ClipboardScreen> createState() => _ClipboardScreenState();
}

class _ClipboardScreenState extends State<ClipboardScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  bool _helperInstalled = false;
  bool _checkingInstalled = true;
  bool _sending = false;
  bool _installing = false;
  bool _uninstalling = false;
  String? _status;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _checkInstalled();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkInstalled() async {
    if (widget.selectedSerial == null) {
      setState(() {
        _checkingInstalled = false;
        _helperInstalled = false;
      });
      return;
    }
    setState(() => _checkingInstalled = true);
    try {
      final installed =
          await context.read<ApiClient>().checkClipboardInstalled(widget.selectedSerial!);
      if (!mounted) return;
      setState(() {
        _helperInstalled = installed;
        _checkingInstalled = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _helperInstalled = false;
        _checkingInstalled = false;
      });
    }
  }

  Future<bool> _ensureInstalled() async {
    if (_helperInstalled) return true;
    if (widget.selectedSerial == null) return false;

    setState(() {
      _installing = true;
      _status = tr('installing');
    });

    try {
      await context.read<ApiClient>().installClipboardHelper(widget.selectedSerial!);
      if (!mounted) return false;
      setState(() {
        _helperInstalled = true;
        _installing = false;
        _status = null;
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _installing = false;
        _status = '${tr('installFailed')}: ${e.toString()}';
        _success = false;
      });
      return false;
    }
  }

  Future<void> _sendToClipboard() async {
    final text = _textCtrl.text;
    if (text.isEmpty || widget.selectedSerial == null) return;

    final installed = await _ensureInstalled();
    if (!installed || !mounted) return;

    setState(() {
      _sending = true;
      _status = null;
    });

    try {
      await context.read<ApiClient>().sendClipboard(widget.selectedSerial!, text);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _status = tr('sentToClipboard');
        _success = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _status = '${tr('sendFailed')}: ${e.toString()}';
        _success = false;
      });
    }
  }

  Future<void> _uninstallHelper() async {
    if (widget.selectedSerial == null) return;

    setState(() {
      _uninstalling = true;
      _status = null;
    });

    try {
      await context.read<ApiClient>().uninstallClipboardHelper(widget.selectedSerial!);
      if (!mounted) return;
      setState(() {
        _helperInstalled = false;
        _uninstalling = false;
        _status = tr('uninstalled');
        _success = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uninstalling = false;
        _status = '${tr('uninstallFailed')}: ${e.toString()}';
        _success = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    if (widget.selectedSerial == null) {
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
          Text(tr('sendToDeviceClipboard'),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(tr('clipboardService'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              if (_checkingInstalled)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_helperInstalled)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle,
                        size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(tr('installed'),
                        style:
                            const TextStyle(fontSize: 12, color: Colors.green)),
                  ],
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber,
                        size: 16, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(tr('notInstalledHint'),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.orange)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TextField(
              controller: _textCtrl,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: tr('clipboardInputHint'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: (_sending || _installing) ? null : _sendToClipboard,
                icon: (_sending || _installing)
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send, size: 18),
                label: Text(_installing
                    ? tr('installingText')
                    : (_sending ? tr('sending') : tr('sendToClipboard'))),
              ),
              const SizedBox(width: 8),
              if (_helperInstalled)
                OutlinedButton.icon(
                  onPressed: _uninstalling ? null : _uninstallHelper,
                  icon: _uninstalling
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline, size: 18),
                  label: Text(_uninstalling
                      ? tr('uninstalling')
                      : tr('uninstallService')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              const SizedBox(width: 12),
              if (_status != null)
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _success ? Icons.check_circle : Icons.error,
                        size: 18,
                        color: _success ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _status!,
                          style: TextStyle(
                            fontSize: 13,
                            color: _success ? Colors.green : Colors.red,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
