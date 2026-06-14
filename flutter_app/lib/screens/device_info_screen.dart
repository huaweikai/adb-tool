import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';
import '../i18n.dart';
import '../providers/locale_provider.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';

class DeviceInfoScreen extends StatefulWidget {
  final String? selectedSerial;

  const DeviceInfoScreen({
    super.key,
    required this.selectedSerial,
  });

  @override
  State<DeviceInfoScreen> createState() => _DeviceInfoScreenState();
}

class _DeviceInfoScreenState extends State<DeviceInfoScreen> {
  Map<String, String> _props = {};
  bool _loading = false;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    if (widget.selectedSerial == null) {
      setState(() {
        _props = {};
        _error = tr('selectDevice');
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final props = await context.read<ApiClient>().getDeviceDetail(widget.selectedSerial!);
      if (!mounted) return;
      setState(() {
        _props = props;
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

  Future<void> _takeScreenshot() async {
    if (widget.selectedSerial == null) return;
    try {
      final b64 = await context.read<ApiClient>().takeScreenshot(widget.selectedSerial!);
      if (!mounted) return;
      if (b64 != null) {
        showDialog(
          context: context,
          builder: (ctx) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    base64Decode(b64),
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('screenshotFailed'))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr('screenshotFailedWithError', {'error': '$e'}))),
      );
    }
  }

  Map<String, String> get _filteredProps {
    if (_searchQuery.isEmpty) return _props;
    final q = _searchQuery.toLowerCase();
    return _props.entries
        .where((e) =>
            e.key.toLowerCase().contains(q) ||
            e.value.toLowerCase().contains(q))
        .fold({}, (map, e) => map..[e.key] = e.value);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
    if (widget.selectedSerial == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone_android, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(tr('selectDeviceSidebar'),
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(context),
        if (_loading)
          const Expanded(child: LoadingView())
        else if (_error != null)
          Expanded(
            child: ErrorView(
              message: _error!,
              onRetry: _loadInfo,
              retryLabel: tr('retry'),
            ),
          )
        else
          Expanded(child: _buildPropList(context)),
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
          SizedBox(
            width: 250,
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: tr('searchProps'),
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 18),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(6))),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: _takeScreenshot,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.screenshot, size: 16),
                const SizedBox(width: 4),
                Text(tr('screenshot')),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: _loadInfo,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: tr('refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildPropList(BuildContext context) {
    final filtered = _filteredProps;
    if (filtered.isEmpty) {
      return Center(
          child: Text(tr('noMatchingProps'),
              style: const TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final entry = filtered.entries.elementAt(i);
        return _buildPropRow(context, entry.key, entry.value);
      },
    );
  }

  Widget _buildPropRow(BuildContext context, String key, String value) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: '$key: $value'));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr('copied', {'key': key})),
              duration: const Duration(seconds: 1)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 260,
              child: Text(
                key,
                style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Menlo',
                    color: theme.colorScheme.primary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontSize: 11, fontFamily: 'Menlo'),
              ),
            ),
            Icon(Icons.copy,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant.withAlpha(100)),
          ],
        ),
      ),
    );
  }
}
