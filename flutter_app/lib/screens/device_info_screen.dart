import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';

class DeviceInfoScreen extends StatefulWidget {
  final ApiClient api;
  final String? selectedSerial;

  const DeviceInfoScreen({
    super.key,
    required this.api,
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
  String? _screenshotBase64;

  final _keyGroups = [
    _KeyGroup('设备信息', ['ro.product.model', 'ro.product.brand', 'ro.product.name',
                          'ro.product.manufacturer', 'ro.product.board', 'ro.product.device']),
    _KeyGroup('系统版本', ['ro.build.version.sdk', 'ro.build.version.release',
                          'ro.build.version.codename', 'ro.build.version.incremental',
                          'ro.build.display.id']),
    _KeyGroup('硬件信息', ['ro.hardware', 'ro.arch', 'ro.board.platform',
                          'ro.serialno', 'ro.boot.serialno']),
    _KeyGroup('网络信息', ['ro.build.version.sdk', 'gsm.network.type',
                          'gsm.operator.alpha', 'wifi.interface']),
    _KeyGroup('存储与内存', ['ro.product.ram', 'ro.product.storage',
                            'ro.config.low_ram', 'dalvik.vm.heapsize']),
    _KeyGroup('构建信息', ['ro.build.fingerprint', 'ro.build.description',
                          'ro.build.type', 'ro.build.tags', 'ro.build.date.utc']),
  ];

  @override
  void didUpdateWidget(DeviceInfoScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSerial != widget.selectedSerial) {
      _loadInfo();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    if (widget.selectedSerial == null) {
      setState(() {
        _props = {};
        _error = '请先选择设备';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final props = await widget.api.getDeviceDetail(widget.selectedSerial!);
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
      final b64 = await widget.api.takeScreenshot(widget.selectedSerial!);
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
          const SnackBar(content: Text('截图失败')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('截图失败: $e')),
      );
    }
  }

  Map<String, String> get _filteredProps {
    if (_searchQuery.isEmpty) return _props;
    final q = _searchQuery.toLowerCase();
    return _props.entries
        .where((e) => e.key.toLowerCase().contains(q) || e.value.toLowerCase().contains(q))
        .fold({}, (map, e) => map..[e.key] = e.value);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedSerial == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone_android, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('请先在侧边栏选择设备', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(context),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Expanded(child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                const SizedBox(height: 12),
                FilledButton.tonal(onPressed: _loadInfo, child: const Text('重试')),
              ],
            ),
          ))
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
                hintText: '搜索属性...',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6))),
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
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.screenshot, size: 16),
                SizedBox(width: 4),
                Text('截图'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: _loadInfo,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: '刷新',
          ),
        ],
      ),
    );
  }

  Widget _buildPropList(BuildContext context) {
    final filtered = _filteredProps;
    if (filtered.isEmpty) {
      return const Center(child: Text('没有匹配的属性', style: TextStyle(color: Colors.grey)));
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
          SnackBar(content: Text('已复制: $key'), duration: const Duration(seconds: 1)),
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
                style: TextStyle(fontSize: 11, fontFamily: 'Menlo', color: theme.colorScheme.primary),
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
            Icon(Icons.copy, size: 14, color: theme.colorScheme.onSurfaceVariant.withAlpha(100)),
          ],
        ),
      ),
    );
  }
}

class _KeyGroup {
  final String name;
  final List<String> keys;
  const _KeyGroup(this.name, this.keys);
}
