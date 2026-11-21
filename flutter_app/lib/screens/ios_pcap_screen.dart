import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n.dart';
import '../models/device.dart';
import '../providers/device_provider.dart';
import '../services/api_client.dart';

class IosPcapScreen extends StatefulWidget {
  const IosPcapScreen({super.key});

  @override
  State<IosPcapScreen> createState() => _IosPcapScreenState();
}

class _IosPcapScreenState extends State<IosPcapScreen> {
  String? _serial;
  IosPcapStatus? _status;
  bool _busy = false;
  Timer? _pollTimer;

  final TextEditingController _processController = TextEditingController();
  String _selectedInterface = 'all';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final serial = context.watch<DeviceSerialScope>().serial;
    final devices = context.watch<DeviceProvider>();
    final target = devices.isDeviceConnected(serial) ? serial : null;
    if (target != _serial) {
      _serial = target;
      _status = null;
      _stopTimer();
      if (target != null) {
        _fetchStatus(target);
      }
    }
  }

  @override
  void dispose() {
    _stopTimer();
    _processController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final serial = _serial;
      if (serial != null) {
        _fetchStatus(serial, background: true);
      }
    });
  }

  void _stopTimer() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _fetchStatus(String serial, {bool background = false}) async {
    try {
      final status = await context.read<ApiClient>().getIosPcapStatus(serial);
      if (!mounted) return;
      setState(() {
        _status = status;
        if (status.isCapturing) {
          if (_pollTimer == null) _startTimer();
        } else {
          _stopTimer();
        }
      });
    } catch (_) {
      if (!background && mounted) {
        setState(() => _status = null);
      }
    }
  }

  Future<void> _startCapture() async {
    final serial = _serial;
    if (serial == null || _busy) return;
    setState(() => _busy = true);
    try {
      final iface = _selectedInterface == 'all' ? null : _selectedInterface;
      final process = _processController.text.trim().isEmpty
          ? null
          : _processController.text.trim();
      final status = await context.read<ApiClient>().startIosPcap(
            serial,
            process: process,
            interface: iface,
          );
      if (!mounted) return;
      setState(() {
        _status = status;
        _startTimer();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('iosPcapActionFailed')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopCapture() async {
    final serial = _serial;
    if (serial == null || _busy) return;
    setState(() => _busy = true);
    try {
      final status = await context.read<ApiClient>().stopIosPcap(serial);
      if (!mounted) return;
      setState(() {
        _status = status;
        _stopTimer();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('iosPcapActionFailed')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openWireshark() async {
    final serial = _serial;
    if (serial == null || _busy) return;
    setState(() => _busy = true);
    try {
      await context.read<ApiClient>().openIosPcapInWireshark(
            serial,
            path: _status?.filePath,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('iosPcapWiresharkSuccess'))),
        );
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        final msg = errStr.contains('Wireshark was not found')
            ? tr('iosPcapWiresharkNotFound')
            : '${tr('iosPcapActionFailed')}: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportPcap() async {
    final serial = _serial;
    if (serial == null || _busy) return;
    final defaultName = _status?.filePath.isNotEmpty == true
        ? _status!.filePath.split(RegExp(r'[/\\]')).last
        : 'capture.pcapng';

    final location = await getSaveLocation(suggestedName: defaultName);
    if (location == null) return;

    setState(() => _busy = true);
    try {
      final bytes = await context.read<ApiClient>().downloadIosPcap(
            serial,
            path: _status?.filePath,
          );
      await File(location.path).writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('iosPcapExportSuccess')}: ${location.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('iosPcapActionFailed')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatDuration(double seconds) {
    final totalSec = seconds.round();
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    final h = totalSec ~/ 3600;
    if (h > 0) {
      return '$h:$m:$s';
    }
    return '$m:$s';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final serial = _serial;

    if (serial == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone_iphone, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(tr('iosPcapOffline'), style: theme.textTheme.titleMedium),
          ],
        ),
      );
    }

    final isCapturing = _status?.isCapturing ?? false;
    final hasFile = (_status?.filePath.isNotEmpty ?? false) &&
        (_status?.packets ?? 0) >= 0;

    final deviceProvider = context.watch<DeviceProvider>();
    final currentDevice = deviceProvider.devices
        .where((d) => d.matchesIdentity(serial))
        .firstOrNull;
    final isWifi = currentDevice?.transport == 'wifi';

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('iosPcapTitle')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: tr('refresh'),
            onPressed: _busy ? null : () => _fetchStatus(serial),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (isWifi) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade400),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('iosPcapWifiWarningTitle'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('iosPcapWifiWarningBody'),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.amber.shade900,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_status?.error?.isNotEmpty == true) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('iosPcapErrorBanner'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          _status!.error!,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: Colors.red.shade800,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          // 1. Capture Dashboard Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isCapturing
                    ? Colors.green.withOpacity(0.5)
                    : theme.dividerColor.withOpacity(0.2),
                width: isCapturing ? 1.5 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCapturing
                              ? Colors.green.withOpacity(0.15)
                              : (_status?.status == 'stopped'
                                  ? Colors.orange.withOpacity(0.15)
                                  : theme.colorScheme.surfaceVariant),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCapturing
                                    ? Colors.green
                                    : (_status?.status == 'stopped'
                                        ? Colors.orange
                                        : Colors.grey),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isCapturing
                                  ? tr('iosPcapStatusCapturing')
                                  : (_status?.status == 'stopped'
                                      ? tr('iosPcapStatusStopped')
                                      : tr('iosPcapStatusIdle')),
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isCapturing
                                    ? Colors.green.shade700
                                    : (_status?.status == 'stopped'
                                        ? Colors.orange.shade800
                                        : null),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (_status?.startTime.isNotEmpty ?? false)
                        Text(
                          _status!.startTime.split('.').first.replaceFirst('T', ' '),
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Live Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          icon: Icons.timer_outlined,
                          title: tr('iosPcapDuration'),
                          value: _formatDuration(_status?.duration ?? 0),
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatBox(
                          icon: Icons.alt_route,
                          title: tr('iosPcapPackets'),
                          value: '${_status?.packets ?? 0}',
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatBox(
                          icon: Icons.storage_outlined,
                          title: tr('iosPcapDataSize'),
                          value: _formatBytes(_status?.bytes ?? 0),
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Action Button Toolbar
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      if (!isCapturing)
                        Tooltip(
                          message: isWifi ? tr('iosPcapWifiWarningTitle') : '',
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.fiber_manual_record, color: Colors.white, size: 18),
                            label: Text(tr('iosPcapStart')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            ),
                            onPressed: (_busy || isWifi) ? null : _startCapture,
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          icon: const Icon(Icons.stop, color: Colors.white, size: 18),
                          label: Text(tr('iosPcapStop')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          ),
                          onPressed: _busy ? null : _stopCapture,
                        ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.insights, size: 18),
                        label: Text(tr('iosPcapOpenWireshark')),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onPressed: (_busy || !hasFile) ? null : _openWireshark,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.download, size: 18),
                        label: Text(tr('iosPcapExportFile')),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onPressed: (_busy || !hasFile) ? null : _exportPcap,
                      ),
                    ],
                  ),
                  if (_status?.filePath.isNotEmpty ?? false) ...[
                    const SizedBox(height: 16),
                    Text(
                      '${tr('file')}: ${_status!.filePath}',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 2. Filters Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('iosPcapFilterTitle'),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _processController,
                    enabled: !isCapturing && !_busy,
                    decoration: InputDecoration(
                      labelText: tr('iosPcapFilterProcess'),
                      hintText: tr('iosPcapFilterProcessHint'),
                      prefixIcon: const Icon(Icons.tune),
                      suffixIcon: _processController.text.isNotEmpty && !isCapturing
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _processController.clear()),
                            )
                          : null,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Text(tr('iosPcapFilterInterface'), style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'all',
                        label: Text(tr('iosPcapFilterInterfaceAll')),
                        icon: const Icon(Icons.all_inclusive, size: 16),
                      ),
                      ButtonSegment(
                        value: 'en0',
                        label: Text(tr('iosPcapFilterInterfaceWifi')),
                        icon: const Icon(Icons.wifi, size: 16),
                      ),
                      ButtonSegment(
                        value: 'pdp_ip0',
                        label: Text(tr('iosPcapFilterInterfaceCellular')),
                        icon: const Icon(Icons.signal_cellular_alt, size: 16),
                      ),
                    ],
                    selected: {_selectedInterface},
                    onSelectionChanged: isCapturing
                        ? null
                        : (selected) {
                            setState(() => _selectedInterface = selected.first);
                          },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 3. Informational Highlights
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HighlightItem(
                    icon: Icons.verified_user_outlined,
                    color: Colors.green,
                    text: tr('iosPcapTipNoProxy'),
                  ),
                  const Divider(height: 20),
                  _HighlightItem(
                    icon: Icons.tag,
                    color: Colors.blue,
                    text: tr('iosPcapTipProcess'),
                  ),
                  const Divider(height: 20),
                  _HighlightItem(
                    icon: Icons.lan_outlined,
                    color: Colors.purple,
                    text: tr('iosPcapTipAllProtocols'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatBox({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(title, style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey.shade700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _HighlightItem({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
        ),
      ],
    );
  }
}
