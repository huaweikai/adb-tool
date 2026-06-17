import 'dart:async';

import 'package:flutter/material.dart';

import '../i18n.dart';
import '../models/device.dart';
import '../services/api_client.dart';
import '../providers/device_provider.dart';

/// 无线 ADB 连接对话框（配对 + 扫码 + 直连）。
class WirelessAdbDialog extends StatefulWidget {
  final ApiClient api;
  final DeviceProvider deviceProvider;

  const WirelessAdbDialog({
    super.key,
    required this.api,
    required this.deviceProvider,
  });

  @override
  State<WirelessAdbDialog> createState() => WirelessAdbDialogState();
}

class WirelessAdbDialogState extends State<WirelessAdbDialog> {
  final _pairAddressCtrl = TextEditingController();
  final _pairCodeCtrl = TextEditingController();
  final _connectIpCtrl = TextEditingController();
  final _connectPortCtrl = TextEditingController(text: '5555');
  bool _running = false;
  bool _scanning = false;
  String? _result;
  List<WirelessAdbDevice> _scanDevices = [];

  @override
  void dispose() {
    _pairAddressCtrl.dispose();
    _pairCodeCtrl.dispose();
    _connectIpCtrl.dispose();
    _connectPortCtrl.dispose();
    super.dispose();
  }

  String _hostFromAddress(String address) {
    final trimmed = address.trim();
    final portIndex = trimmed.lastIndexOf(':');
    if (portIndex <= 0) return trimmed;
    return trimmed.substring(0, portIndex);
  }

  String get _connectAddress =>
      '${_connectIpCtrl.text.trim()}:${_connectPortCtrl.text.trim()}';

  bool get _canPair =>
      _pairAddressCtrl.text.trim().isNotEmpty &&
      _pairCodeCtrl.text.trim().isNotEmpty;

  bool get _canConnect =>
      _connectIpCtrl.text.trim().isNotEmpty &&
      _connectPortCtrl.text.trim().isNotEmpty;

  Future<bool> _runAction(Future<AdbCommandResult> Function() action) async {
    setState(() {
      _running = true;
      _result = null;
    });
    try {
      final res = await action();
      if (res.ok) {
        await widget.deviceProvider.refresh(widget.api);
        if (mounted) {
          setState(() => _result = null);
        }
        return true;
      }
      if (mounted) {
        setState(() {
          _result = res.error.isEmpty ? res.output : res.error;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _result = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _running = false);
      }
    }
    return false;
  }

  Future<void> _pair() async {
    final ok = await _runAction(
      () => widget.api.pairWirelessAdb(
        _pairAddressCtrl.text.trim(),
        _pairCodeCtrl.text.trim(),
      ),
    );
    if (!ok || !mounted) return;
    final host = _hostFromAddress(_pairAddressCtrl.text);
    setState(() {
      _connectIpCtrl.text = host;
      _connectPortCtrl.text = '5555';
      _result = tr('pairSuccessReadyToConnect');
    });
    FocusScope.of(context).nextFocus();
  }

  Future<void> _connect() async {
    final ok = await _runAction(
      () => widget.api.connectWirelessAdb(_connectAddress),
    );
    if (ok && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _result = null;
    });
    try {
      final devices = await widget.api.scanWirelessAdb();
      if (!mounted) return;
      setState(() {
        _scanDevices = devices;
        if (devices.isEmpty) {
          _result = tr('wirelessScanEmpty');
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _scanDevices = [];
          _result = tr('wirelessScanEmpty');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _scanning = false);
      }
    }
  }

  void _useScannedDevice(WirelessAdbDevice device) {
    setState(() {
      _connectIpCtrl.text = device.host;
      if (device.connectPort.isNotEmpty) {
        _connectPortCtrl.text = device.connectPort;
      }
      if (device.pairAddress.isNotEmpty) {
        _pairAddressCtrl.text = device.pairAddress;
      }
      _result = null;
    });
  }

  void _close() {
    Navigator.of(context).pop();
  }

  Widget _buildScannedDevice(WirelessAdbDevice device) {
    final title = device.name.isEmpty ? device.host : device.name;
    final pairText = device.pairPort.isEmpty
        ? tr('wirelessPairPortMissing')
        : tr('wirelessPairPort', {'port': device.pairPort});
    final connectText = device.connectPort.isEmpty
        ? tr('wirelessConnectPortMissing')
        : tr('wirelessConnectPort', {'port': device.connectPort});
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.phone_android, size: 20),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${device.host} · $pairText · $connectText'),
        trailing: TextButton(
          onPressed:
              _running || _scanning ? null : () => _useScannedDevice(device),
          child: Text(tr('fill')),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Row(
        children: [
          const Icon(Icons.wifi_tethering, size: 22),
          const SizedBox(width: 8),
          Text(tr('wirelessAdb')),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('wirelessAdbHint'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _running || _scanning ? null : _scan,
                  icon: _scanning
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.radar, size: 16),
                  label: Text(
                    _scanning ? tr('wirelessScanning') : tr('wirelessScan'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('wirelessScanHint'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
            if (_scanDevices.isNotEmpty) ...[
              const SizedBox(height: 10),
              ..._scanDevices.map(_buildScannedDevice),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _pairAddressCtrl,
              enabled: !_running && !_scanning,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: tr('pairAddress'),
                helperText: tr('pairAddressHint'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _pairCodeCtrl,
              enabled: !_running && !_scanning,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: tr('pairCode'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: _running || _scanning || !_canPair ? null : _pair,
                icon: const Icon(Icons.link, size: 16),
                label: Text(tr('pair')),
              ),
            ),
            const Divider(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _connectIpCtrl,
                    enabled: !_running,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    decoration: InputDecoration(
                      labelText: tr('connectIp'),
                      helperText: tr('connectIpHint'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _connectPortCtrl,
                    enabled: !_running && !_scanning,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: _canConnect ? (_) => _connect() : null,
                    decoration: InputDecoration(
                      labelText: tr('connectPort'),
                      helperText: tr('connectPortHint'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed:
                    _running || _scanning || !_canConnect ? null : _connect,
                icon: const Icon(Icons.wifi, size: 16),
                label: Text(tr('connect')),
              ),
            ),
            if (_running) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(tr('running')),
                ],
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _result!,
                  style: const TextStyle(fontSize: 12, fontFamily: 'Menlo'),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _running || _scanning ? null : _close,
          child: Text(tr('close')),
        ),
      ],
    );
  }
}
