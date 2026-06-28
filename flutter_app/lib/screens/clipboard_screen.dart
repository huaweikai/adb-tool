import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../db/database.dart';
import '../services/api_client.dart';
import '../i18n.dart';
import '../providers/locale_provider.dart';
import '../providers/device_provider.dart';
import '../providers/clipboard_history_provider.dart';
import '../widgets/offline_guard.dart';

class ClipboardScreen extends StatefulWidget {
  const ClipboardScreen({super.key});

  @override
  State<ClipboardScreen> createState() => _ClipboardScreenState();
}

class _ClipboardScreenState extends State<ClipboardScreen> {
  String? get _selectedSerial => context.read<DeviceSerialScope>().serial;

  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
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
    _textCtrl.addListener(_onTextChanged);
    _checkInstalled();
  }

  @override
  void dispose() {
    _textCtrl.removeListener(_onTextChanged);
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  Future<void> _checkInstalled() async {
    if (_selectedSerial == null) {
      setState(() {
        _checkingInstalled = false;
        _helperInstalled = false;
      });
      return;
    }
    setState(() => _checkingInstalled = true);
    try {
      final installed = await context
          .read<ApiClient>()
          .checkClipboardInstalled(_selectedSerial!);
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
    if (_selectedSerial == null) return false;

    setState(() {
      _installing = true;
      _status = tr('installing');
    });

    try {
      await context.read<ApiClient>().installClipboardHelper(_selectedSerial!);
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
    if (text.isEmpty || _selectedSerial == null) return;

    final installed = await _ensureInstalled();
    if (!installed || !mounted) return;

    setState(() {
      _sending = true;
      _status = null;
    });

    try {
      await context.read<ApiClient>().sendClipboard(_selectedSerial!, text);
      if (!mounted) return;
      // Persist to history (DB-backed). Dedup + favorite-preserve is
      // handled inside the DAO; we just fire and forget.
      await context.read<ClipboardHistoryProvider>().recordSent(text);
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
    if (_selectedSerial == null) return;

    setState(() {
      _uninstalling = true;
      _status = null;
    });

    try {
      await context
          .read<ApiClient>()
          .uninstallClipboardHelper(_selectedSerial!);
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

  void _clearInput() {
    _textCtrl.clear();
    _focusNode.requestFocus();
  }

  void _useHistory(String text) {
    _textCtrl.text = text;
    _textCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
    _focusNode.requestFocus();
  }

  Future<void> _toggleFavorite(SentClipboardEntryData item) async {
    await context.read<ClipboardHistoryProvider>().toggleFavorite(item.id);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final entries = context.watch<ClipboardHistoryProvider>().entries;

    if (_selectedSerial == null) {
      return Center(
        child: Text(tr('selectDevice'),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      );
    }

    // Watch device connection so the input card / buttons reflect the
    // disabled state when the device goes offline mid-edit.
    final isOnline =
        context.watch<DeviceProvider>().isDeviceConnected(_selectedSerial!);

    return CustomScrollView(
      slivers: [
        // Banner spans the full screen width — no horizontal padding
        // here, unlike the rest of the slivers below which use 20px.
        SliverToBoxAdapter(
          child: OfflineBanner(serial: _selectedSerial!),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _buildHeader(theme),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _buildInputCard(theme, isOnline: isOnline),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          sliver: SliverToBoxAdapter(
            child: _buildButtonsAndStatus(theme, isOnline: isOnline),
          ),
        ),
        if (entries.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            sliver: SliverToBoxAdapter(
              child: _buildSentHistory(theme, entries),
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.content_paste, size: 22, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('sendToDeviceClipboard'),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              _buildServiceStatus(theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServiceStatus(ThemeData theme) {
    if (_checkingInstalled) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 6),
          Text(tr('checking'),
              style: TextStyle(
                  fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
        ],
      );
    }
    if (_helperInstalled) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 14, color: Colors.green),
          const SizedBox(width: 4),
          Text(tr('installed'),
              style: const TextStyle(fontSize: 11, color: Colors.green)),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.warning_amber, size: 14, color: Colors.orange),
        const SizedBox(width: 4),
        Text(tr('notInstalledHint'),
            style: const TextStyle(fontSize: 11, color: Colors.orange)),
      ],
    );
  }

  Widget _buildInputCard(ThemeData theme, {required bool isOnline}) {
    final busy = _sending || _installing;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(tr('clipboardInputHint'),
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant)),
                const Spacer(),
                if (_textCtrl.text.isNotEmpty)
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: (busy || !isOnline) ? null : _clearInput,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      child: Text(tr('clearInput'),
                          style: TextStyle(
                              fontSize: 11, color: theme.colorScheme.primary)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: TextField(
                controller: _textCtrl,
                focusNode: _focusNode,
                maxLines: null,
                readOnly: busy || !isOnline,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: tr('clipboardInputHint'),
                  isDense: true,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                        color: theme.colorScheme.primary, width: 1.5),
                  ),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonsAndStatus(ThemeData theme, {required bool isOnline}) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: (_sending || _installing || !isOnline)
                ? null
                : _sendToClipboard,
            icon: (_sending || _installing)
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send, size: 16),
            label: Text(_installing
                ? tr('installingText')
                : (_sending ? tr('sending') : tr('sendToClipboard'))),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          if (_helperInstalled)
            OutlinedButton.icon(
              onPressed: (_uninstalling || !isOnline) ? null : _uninstallHelper,
              icon: _uninstalling
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.delete_outline, size: 16),
              label: Text(
                  _uninstalling ? tr('uninstalling') : tr('uninstallService')),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          if (_status != null) ...[
            const SizedBox(width: 12),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _success ? Icons.check_circle : Icons.error,
                    size: 16,
                    color: _success ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _status!,
                      style: TextStyle(
                        fontSize: 12,
                        color: _success ? Colors.green : Colors.red,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSentHistory(
      ThemeData theme, List<SentClipboardEntryData> entries) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, size: 16),
                const SizedBox(width: 6),
                Text(tr('history'),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Flexible(
                  child: Text(tr('historyTapHint'),
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...entries.take(10).map((item) => _buildHistoryItem(theme, item)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(ThemeData theme, SentClipboardEntryData item) {
    final time = item.sentAt;
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => _useHistory(item.content),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 52,
              child: Text(timeStr,
                  style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFamily: 'Menlo')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.content,
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: item.favorite
                  ? tr('clipboardUnfavorite')
                  : tr('clipboardFavorite'),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _toggleFavorite(item),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    item.favorite ? Icons.star : Icons.star_border,
                    size: 18,
                    color: item.favorite
                        ? Colors.amber
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
