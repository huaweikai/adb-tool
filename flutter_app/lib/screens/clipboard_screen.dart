import 'package:flutter/material.dart';
import '../services/api_client.dart';

class ClipboardScreen extends StatefulWidget {
  final ApiClient api;
  final String? selectedSerial;

  const ClipboardScreen({
    super.key,
    required this.api,
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
  void didUpdateWidget(ClipboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSerial != widget.selectedSerial) {
      _checkInstalled();
    }
  }

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
          await widget.api.checkClipboardInstalled(widget.selectedSerial!);
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
      _status = '正在安装剪贴板服务...';
    });

    try {
      await widget.api.installClipboardHelper(widget.selectedSerial!);
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
        _status = '安装失败: ${e.toString()}';
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
      await widget.api.sendClipboard(widget.selectedSerial!, text);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _status = '已发送到设备剪贴板';
        _success = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _status = '发送失败: ${e.toString()}';
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
      await widget.api.uninstallClipboardHelper(widget.selectedSerial!);
      if (!mounted) return;
      setState(() {
        _helperInstalled = false;
        _uninstalling = false;
        _status = '剪贴板服务已卸载';
        _success = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uninstalling = false;
        _status = '卸载失败: ${e.toString()}';
        _success = false;
      });
    }
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
          Text('发送文本到设备剪贴板',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('剪贴板服务: ',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              if (_checkingInstalled)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_helperInstalled)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.green),
                    SizedBox(width: 4),
                    Text('已安装', style: TextStyle(fontSize: 12, color: Colors.green)),
                  ],
                )
              else
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                    SizedBox(width: 4),
                    Text('未安装（发送时自动安装）',
                        style: TextStyle(fontSize: 12, color: Colors.orange)),
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
                hintText: '在此输入要发送的文本...',
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
                label: Text(_installing ? '安装中...' : (_sending ? '发送中...' : '发送到剪贴板')),
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
                  label: Text(_uninstalling ? '卸载中...' : '卸载服务'),
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
