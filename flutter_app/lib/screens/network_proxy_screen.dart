import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../i18n.dart';
import '../models/device.dart';
import '../models/mock_rule.dart';
import '../models/proxy_session.dart';
import '../providers/device_provider.dart';
import '../services/api_client.dart';

class NetworkProxyScreen extends StatefulWidget {
  const NetworkProxyScreen({super.key});

  @override
  State<NetworkProxyScreen> createState() => _NetworkProxyScreenState();
}

class _NetworkProxyScreenState extends State<NetworkProxyScreen> {
  ApiClient get _api => context.read<ApiClient>();

  bool _loading = false;
  ProxyStatus? _status;
  final TextEditingController _portCtrl = TextEditingController(text: '8899');
  final TextEditingController _searchCtrl = TextEditingController();

  List<ProxySession> _sessions = [];
  ProxySession? _selectedSession;
  String _searchFilter = '';
  bool _onlyMocked = false;

  List<MockRule> _rules = [];
  String _currentDeviceProxy = '';

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSub;
  Timer? _pollTimer;

  int _inspectorTab = 0; // 0: Response, 1: Request, 2: Overview
  bool _prettyJson = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshStatus();
      _loadRules();
      _loadSessions();
      _checkDeviceProxy();
    });

    // Poll status and sessions every 3 seconds as fallback
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        _refreshStatus(silent: true);
        if (_wsChannel == null && (_status?.running ?? false)) {
          _connectWebSocket();
        }
      }
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _wsChannel?.sink.close();
    _pollTimer?.cancel();
    _portCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Device? _getActiveAndroidDevice() {
    if (!mounted) return null;
    final provider = context.read<DeviceProvider>();
    final devices = provider.devices;
    final activeSerial = provider.activeSerial;
    if (activeSerial != null) {
      final match = devices
          .where((d) =>
              d.matchesIdentity(activeSerial) &&
              d.isOnline &&
              d.platform == 'android')
          .firstOrNull;
      if (match != null) return match;
    }
    return devices
        .where((d) => d.isOnline && d.platform == 'android')
        .firstOrNull;
  }

  void _connectWebSocket() {
    _wsSub?.cancel();
    _wsChannel?.sink.close();

    final wsUri = Uri.parse('ws://localhost:9876/ws/proxy/sessions');
    try {
      _wsChannel = WebSocketChannel.connect(wsUri);
      _wsSub = _wsChannel?.stream.listen(
        (data) {
          if (!mounted) return;
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            final session = ProxySession.fromJson(json);
            setState(() {
              final idx = _sessions.indexWhere((s) => s.id == session.id);
              if (idx >= 0) {
                _sessions[idx] = session;
              } else {
                _sessions.insert(0, session);
                if (_sessions.length > 500) {
                  _sessions.removeLast();
                }
              }
              if (_selectedSession?.id == session.id) {
                _selectedSession = session;
              }
            });
          } catch (_) {}
        },
        onError: (_) {
          _wsChannel = null;
        },
        onDone: () {
          _wsChannel = null;
        },
      );
    } catch (_) {
      _wsChannel = null;
    }
  }

  Future<void> _refreshStatus({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final status = await _api.getProxyStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        if (!_loading && _portCtrl.text != status.port.toString()) {
          _portCtrl.text = status.port.toString();
        }
      });
      if (status.running && _wsChannel == null) {
        _connectWebSocket();
      }
    } catch (_) {
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _loadRules() async {
    try {
      final rules = await _api.getMockRules();
      if (mounted) setState(() => _rules = rules);
    } catch (_) {}
  }

  Future<void> _loadSessions() async {
    try {
      final sessions = await _api.getProxySessions();
      if (mounted) {
        setState(() {
          _sessions = sessions;
          if (_selectedSession != null) {
            final found = _sessions.where((s) => s.id == _selectedSession!.id);
            if (found.isNotEmpty) {
              _selectedSession = found.first;
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _checkDeviceProxy() async {
    final device = _getActiveAndroidDevice();
    if (device == null) {
      if (mounted) setState(() => _currentDeviceProxy = '');
      return;
    }
    try {
      final proxy = await _api.getAdbProxyStatus(device.serial);
      if (mounted) setState(() => _currentDeviceProxy = proxy.trim());
    } catch (_) {}
  }

  Future<void> _toggleProxy() async {
    final running = _status?.running ?? false;
    setState(() => _loading = true);
    try {
      if (running) {
        await _api.stopProxy();
        _wsSub?.cancel();
        _wsChannel?.sink.close();
        _wsChannel = null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('networkProxy.proxyStopped'))),
          );
        }
      } else {
        final port = int.tryParse(_portCtrl.text.trim()) ?? 8899;
        await _api.startProxy(port: port);
        _connectWebSocket();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('networkProxy.proxyStarted', {'port': '$port'})),
            ),
          );
        }
      }
      await _refreshStatus(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setDeviceProxy() async {
    final device = _getActiveAndroidDevice();
    if (device == null) return;

    final ips = _status?.ips ?? [];
    if (ips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No local LAN IP detected')),
      );
      return;
    }

    final port = _status?.port ?? 8899;
    final ip = ips.first;

    try {
      await _api.setAdbProxy(device.serial, ip, port);
      await _checkDeviceProxy();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('networkProxy.deviceProxySuccess', {'proxy': '$ip:$port'}),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _clearDeviceProxy() async {
    final device = _getActiveAndroidDevice();
    if (device == null) return;

    try {
      await _api.clearAdbProxy(device.serial);
      await _checkDeviceProxy();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('networkProxy.deviceProxyCleared'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _clearSessions() async {
    try {
      await _api.clearProxySessions();
      setState(() {
        _sessions.clear();
        _selectedSession = null;
      });
    } catch (_) {}
  }

  Future<void> _exportCaCert() async {
    try {
      final pem = await _api.getProxyCaCert();
      final location = await getSaveLocation(
        suggestedName: 'adb-tool-proxy-ca.crt',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Certificate', extensions: ['crt', 'pem']),
        ],
      );
      if (location == null) return;

      await File(location.path).writeAsString(pem);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('networkProxy.caFileSaved'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openCaDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.verified_user, color: Colors.teal),
            const SizedBox(width: 8),
            Text(tr('networkProxy.caTitle')),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('networkProxy.caDesc'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.download, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(
                          tr('networkProxy.caDownloadStep'),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  tr('networkProxy.caIosStep'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  tr('networkProxy.caIosDetail'),
                  style: const TextStyle(fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 16),
                Text(
                  tr('networkProxy.caAndroidStep'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  tr('networkProxy.caAndroidDetail'),
                  style: const TextStyle(fontSize: 12.5, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _exportCaCert();
            },
            icon: const Icon(Icons.save_alt, size: 16),
            label: Text(tr('networkProxy.saveCaFile')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _openRulesManager() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_fix_high, color: Colors.purple),
                    const SizedBox(width: 8),
                    Text(tr('networkProxy.ruleManager')),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final newRule = await _showRuleEditDialog(null);
                    if (newRule != null) {
                      await _loadRules();
                      setDialogState(() {});
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(tr('networkProxy.addRule')),
                ),
              ],
            ),
            content: SizedBox(
              width: 700,
              height: 400,
              child: _rules.isEmpty
                  ? Center(
                      child: Text(
                        tr('networkProxy.noRules'),
                        style: TextStyle(color: Theme.of(context).hintColor),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _rules.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final rule = _rules[i];
                        final isMock = rule.action == 'mock';
                        return ListTile(
                          leading: Icon(
                            isMock ? Icons.reply_all : Icons.find_replace,
                            color: isMock ? Colors.purple : Colors.indigo,
                          ),
                          title: Row(
                            children: [
                              Text(
                                rule.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isMock
                                      ? Colors.purple.withValues(alpha: 0.15)
                                      : Colors.indigo.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isMock
                                      ? 'MOCK (${rule.mockStatus})'
                                      : 'REWRITE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isMock
                                        ? Colors.purple
                                        : Colors.indigo,
                                  ),
                                ),
                              ),
                              if (rule.method.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blueGrey.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    rule.method,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            rule.urlPattern,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: rule.enabled,
                                onChanged: (val) async {
                                  final updated = rule.copyWith(enabled: val);
                                  await _api.saveMockRule(updated);
                                  await _loadRules();
                                  setDialogState(() {});
                                  setState(() {});
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () async {
                                  final edited =
                                      await _showRuleEditDialog(rule);
                                  if (edited != null) {
                                    await _loadRules();
                                    setDialogState(() {});
                                    setState(() {});
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                onPressed: () async {
                                  await _api.deleteMockRule(rule.id);
                                  await _loadRules();
                                  setDialogState(() {});
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<MockRule?> _showRuleEditDialog(MockRule? initial) async {
    final isNew = initial == null;
    final nameCtrl = TextEditingController(text: initial?.name ?? 'Mock Rule');
    final patternCtrl = TextEditingController(text: initial?.urlPattern ?? '');
    final methodCtrl = TextEditingController(text: initial?.method ?? '');
    final statusCtrl = TextEditingController(
      text: (initial?.mockStatus ?? 200).toString(),
    );
    final headersCtrl = TextEditingController(
      text: initial?.mockHeaders.isNotEmpty == true
          ? jsonEncode(initial!.mockHeaders)
          : '{"Content-Type": "application/json"}',
    );
    final bodyCtrl = TextEditingController(
      text: initial?.mockBody ?? '{"code": 0, "message": "success"}',
    );
    final findCtrl = TextEditingController(text: initial?.findText ?? '');
    final replaceCtrl = TextEditingController(text: initial?.replaceText ?? '');

    String action = initial?.action ?? 'mock';
    bool isRegex = initial?.isRegex ?? false;
    bool enabled = initial?.enabled ?? true;

    return showDialog<MockRule>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setEditState) {
          return AlertDialog(
            title: Text(
              isNew ? tr('networkProxy.addRule') : tr('networkProxy.editRule'),
            ),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: tr('networkProxy.ruleName'),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: action,
                            decoration: InputDecoration(
                              labelText: tr('networkProxy.ruleAction'),
                              isDense: true,
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'mock',
                                child: Text(tr('networkProxy.actionMock')),
                              ),
                              DropdownMenuItem(
                                value: 'rewrite',
                                child: Text(tr('networkProxy.actionRewrite')),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) setEditState(() => action = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Row(
                          children: [
                            Text(tr('networkProxy.ruleEnable')),
                            Switch(
                              value: enabled,
                              onChanged: (v) =>
                                  setEditState(() => enabled = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: TextField(
                            controller: methodCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Method',
                              hintText: 'GET/POST',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: patternCtrl,
                            decoration: InputDecoration(
                              labelText: tr('networkProxy.ruleUrlPattern'),
                              hintText: '/api/v1/user',
                              isDense: true,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: isRegex,
                              onChanged: (v) =>
                                  setEditState(() => isRegex = v ?? false),
                            ),
                            Text(tr('networkProxy.ruleIsRegex')),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (action == 'mock') ...[
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: statusCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: tr('networkProxy.ruleMockStatus'),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: headersCtrl,
                        maxLines: 2,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                        decoration: InputDecoration(
                          labelText: tr('networkProxy.ruleMockHeaders'),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: bodyCtrl,
                        maxLines: 6,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                        decoration: InputDecoration(
                          labelText: tr('networkProxy.ruleMockBody'),
                          alignLabelWithHint: true,
                          isDense: true,
                        ),
                      ),
                    ] else ...[
                      TextField(
                        controller: findCtrl,
                        decoration: InputDecoration(
                          labelText: tr('networkProxy.ruleFind'),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: replaceCtrl,
                        decoration: InputDecoration(
                          labelText: tr('networkProxy.ruleReplace'),
                          isDense: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr('networkProxy.cancel')),
              ),
              ElevatedButton(
                onPressed: () async {
                  Map<String, String> parsedHeaders = {};
                  try {
                    final hMap = jsonDecode(headersCtrl.text.trim())
                        as Map<String, dynamic>;
                    parsedHeaders = hMap.map((k, v) => MapEntry(k, v.toString()));
                  } catch (_) {}

                  final rule = MockRule(
                    id: initial?.id ??
                        'rule_${DateTime.now().millisecondsSinceEpoch}',
                    name: nameCtrl.text.trim(),
                    enabled: enabled,
                    urlPattern: patternCtrl.text.trim(),
                    isRegex: isRegex,
                    method: methodCtrl.text.trim().toUpperCase(),
                    action: action,
                    mockStatus: int.tryParse(statusCtrl.text.trim()) ?? 200,
                    mockHeaders: parsedHeaders,
                    mockBody: bodyCtrl.text,
                    findText: findCtrl.text,
                    replaceText: replaceCtrl.text,
                  );

                  await _api.saveMockRule(rule);
                  if (ctx.mounted) Navigator.pop(ctx, rule);
                },
                child: Text(tr('networkProxy.save')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _quickMockSession(ProxySession session) {
    final uri = Uri.tryParse(session.url);
    final defaultPattern = uri != null ? uri.path : session.url;
    final initialRule = MockRule(
      id: 'rule_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Mock: $defaultPattern',
      enabled: true,
      urlPattern: defaultPattern,
      isRegex: false,
      method: session.method,
      action: 'mock',
      mockStatus: session.statusCode > 0 ? session.statusCode : 200,
      mockHeaders: session.responseHeaders,
      mockBody: session.responseBody,
    );
    _showRuleEditDialog(initialRule).then((saved) {
      if (saved != null) {
        _loadRules();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('networkProxy.ruleSaved'))),
          );
        }
      }
    });
  }

  String _formatJsonString(String raw) {
    if (!_prettyJson) return raw;
    try {
      final dynamic decoded = jsonDecode(raw);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(decoded);
    } catch (_) {
      return raw;
    }
  }

  Color _getStatusColor(int code) {
    if (code >= 200 && code < 300) return Colors.green;
    if (code >= 300 && code < 400) return Colors.blue;
    if (code >= 400 && code < 500) return Colors.orange;
    if (code >= 500) return Colors.red;
    return Colors.grey;
  }

  Color _getMethodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return Colors.blue;
      case 'POST':
        return Colors.green;
      case 'PUT':
        return Colors.orange;
      case 'DELETE':
        return Colors.red;
      case 'PATCH':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final running = _status?.running ?? false;
    final port = _status?.port ?? 8899;
    final ips = _status?.ips ?? [];
    final activeDevice = _getActiveAndroidDevice();

    final filteredSessions = _sessions.where((s) {
      if (_onlyMocked && !s.isMocked) return false;
      if (_searchFilter.isEmpty) return true;
      final q = _searchFilter.toLowerCase();
      return s.url.toLowerCase().contains(q) ||
          s.method.toLowerCase().contains(q) ||
          s.statusCode.toString().contains(q);
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.4),
                ),
              ),
            ),
            child: Row(
              children: [
                // Start / Stop Proxy Button
                ElevatedButton.icon(
                  onPressed: _loading ? null : _toggleProxy,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: running ? Colors.red.shade700 : Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  icon: Icon(running ? Icons.stop : Icons.play_arrow, size: 18),
                  label: Text(
                    running
                        ? tr('networkProxy.stop')
                        : tr('networkProxy.start'),
                  ),
                ),
                const SizedBox(width: 12),
                // Port input
                SizedBox(
                  width: 90,
                  height: 36,
                  child: TextField(
                    controller: _portCtrl,
                    enabled: !running,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: tr('networkProxy.port'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // LAN IPs badge
                if (ips.isNotEmpty)
                  PopupMenuButton<String>(
                    tooltip: tr('networkProxy.lanIps'),
                    onSelected: (ip) {
                      Clipboard.setData(ClipboardData(text: '$ip:$port'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$ip:$port ${tr('networkProxy.copied')}'),
                        ),
                      );
                    },
                    itemBuilder: (ctx) => ips
                        .map(
                          (ip) => PopupMenuItem(
                            value: ip,
                            child: Row(
                              children: [
                                const Icon(Icons.wifi, size: 16),
                                const SizedBox(width: 8),
                                Text('$ip:$port'),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.wifi,
                            size: 16,
                            color: running ? Colors.teal : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${ips.first}:$port',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (ips.length > 1)
                            const Icon(Icons.arrow_drop_down, size: 16),
                        ],
                      ),
                    ),
                  ),
                const Spacer(),
                // ADB One-Click Proxy (for connected Android devices)
                if (activeDevice != null) ...[
                  if (_currentDeviceProxy.isNotEmpty &&
                      _currentDeviceProxy != ':0') ...[
                    OutlinedButton.icon(
                      onPressed: _clearDeviceProxy,
                      icon: const Icon(Icons.link_off, size: 16, color: Colors.orange),
                      label: Text(tr('networkProxy.adbProxyClear')),
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      onPressed: running ? _setDeviceProxy : null,
                      icon: const Icon(Icons.link, size: 16),
                      label: Text(tr('networkProxy.adbProxySet')),
                    ),
                  ],
                  const SizedBox(width: 8),
                ],
                // Mock Rules button
                OutlinedButton.icon(
                  onPressed: _openRulesManager,
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  label: Text(
                    '${tr('networkProxy.mockRules')} (${_rules.where((r) => r.enabled).length})',
                  ),
                ),
                const SizedBox(width: 8),
                // CA Certificate guide button
                OutlinedButton.icon(
                  onPressed: _openCaDialog,
                  icon: const Icon(Icons.security, size: 16),
                  label: Text(tr('networkProxy.caGuide')),
                ),
                const SizedBox(width: 8),
                // Clear sessions button
                IconButton(
                  tooltip: tr('networkProxy.clearSessions'),
                  icon: const Icon(Icons.delete_sweep),
                  onPressed: _clearSessions,
                ),
              ],
            ),
          ),

          // Search / Filter Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) =>
                          setState(() => _searchFilter = val.trim()),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, size: 18),
                        hintText: tr('networkProxy.filterHint'),
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        suffixIcon: _searchFilter.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchFilter = '');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  label: Text(tr('networkProxy.mockedBadge')),
                  selected: _onlyMocked,
                  onSelected: (val) => setState(() => _onlyMocked = val),
                  avatar: Icon(
                    Icons.auto_fix_high,
                    size: 14,
                    color: _onlyMocked ? Colors.white : Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  tr(
                    'networkProxy.sessionsCount',
                    {'count': '${filteredSessions.length}'},
                  ),
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                ),
              ],
            ),
          ),

          // Main Body: Split View (List on left, Inspector on right)
          Expanded(
            child: Row(
              children: [
                // Session List
                SizedBox(
                  width: 420,
                  child: filteredSessions.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.wifi_tethering,
                                  size: 48,
                                  color: theme.disabledColor,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  tr('networkProxy.noSessions'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.hintColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  tr('networkProxy.noSessionsHint'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.hintColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filteredSessions.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 8, endIndent: 8),
                          itemBuilder: (ctx, i) {
                            final session = filteredSessions[i];
                            final isSelected =
                                _selectedSession?.id == session.id;
                            final uri = Uri.tryParse(session.url);
                            final path = uri?.path.isNotEmpty == true
                                ? uri!.path
                                : session.url;
                            final host = uri?.host ?? '';

                            return InkWell(
                              onTap: () =>
                                  setState(() => _selectedSession = session),
                              child: Container(
                                color: isSelected
                                    ? theme.colorScheme.primary.withValues(alpha: 0.12)
                                    : null,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        // Status badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(
                                              session.statusCode,
                                            ).withValues(alpha: 0.18),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            session.statusCode > 0
                                                ? '${session.statusCode}'
                                                : '...',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: _getStatusColor(
                                                session.statusCode,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // Method badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getMethodColor(
                                              session.method,
                                            ).withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            session.method,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: _getMethodColor(
                                                session.method,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (session.isMocked) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.purple.withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                            ),
                                            child: Text(
                                              tr('networkProxy.mockedBadge'),
                                              style: const TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.purple,
                                              ),
                                            ),
                                          ),
                                        ],
                                        const Spacer(),
                                        Text(
                                          '${session.durationMs}ms',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.hintColor,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatSize(session.responseSize),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.hintColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      path,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (host.isNotEmpty)
                                      Text(
                                        host,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.hintColor,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Vertical Divider
                const VerticalDivider(width: 1),

                // Inspector Detail Panel
                Expanded(
                  child: _selectedSession == null
                      ? Center(
                          child: Text(
                            tr('networkProxy.overview'),
                            style: TextStyle(color: theme.disabledColor),
                          ),
                        )
                      : _buildInspector(context, _selectedSession!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspector(BuildContext context, ProxySession session) {
    final theme = Theme.of(context);
    final uri = Uri.tryParse(session.url);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Inspector Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: theme.cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _getMethodColor(session.method).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      session.method,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: _getMethodColor(session.method),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      session.url,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: tr('networkProxy.copy'),
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: session.url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr('networkProxy.copied'))),
                      );
                    },
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    onPressed: () => _quickMockSession(session),
                    icon: const Icon(Icons.auto_fix_high, size: 14),
                    label: Text(
                      tr('networkProxy.quickMock'),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
              if (session.isMocked) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.purple.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified,
                        size: 14,
                        color: Colors.purple,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Matched Mock Rule: ${session.matchedRule}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Navigation Tabs for Detail
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Row(
            children: [
              _buildTabButton(0, tr('networkProxy.response')),
              _buildTabButton(1, tr('networkProxy.request')),
              _buildTabButton(2, tr('networkProxy.overview')),
              const Spacer(),
              if (_inspectorTab == 0 || _inspectorTab == 1)
                Row(
                  children: [
                    Text(
                      tr('networkProxy.formatted'),
                      style: const TextStyle(fontSize: 11),
                    ),
                    Switch(
                      value: _prettyJson,
                      onChanged: (v) => setState(() => _prettyJson = v),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // Tab Content
        Expanded(
          child: IndexedStack(
            index: _inspectorTab,
            children: [
              _buildResponseTab(session),
              _buildRequestTab(session, uri),
              _buildOverviewTab(session),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton(int index, String label) {
    final isSelected = _inspectorTab == index;
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => setState(() => _inspectorTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? theme.colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? theme.colorScheme.primary : null,
          ),
        ),
      ),
    );
  }

  Widget _buildResponseTab(ProxySession session) {
    final bodyText = _formatJsonString(session.responseBody);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status code & quick info
          Row(
            children: [
              Text(
                'Status: ${session.statusCode}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(session.statusCode),
                ),
              ),
              const SizedBox(width: 16),
              Text('Size: ${_formatSize(session.responseSize)}'),
              const Spacer(),
              if (session.responseBody.isNotEmpty)
                IconButton(
                  tooltip: tr('networkProxy.copy'),
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: session.responseBody));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr('networkProxy.copied'))),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Headers Expansion
          if (session.responseHeaders.isNotEmpty)
            ExpansionTile(
              title: Text(
                '${tr('networkProxy.headers')} (${session.responseHeaders.length})',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              initiallyExpanded: false,
              tilePadding: EdgeInsets.zero,
              children: [
                _buildHeadersTable(session.responseHeaders),
              ],
            ),
          const SizedBox(height: 8),

          // Body
          Text(
            tr('networkProxy.body'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
              ),
            ),
            child: SelectableText(
              bodyText.isNotEmpty ? bodyText : '(Empty Body)',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestTab(ProxySession session, Uri? uri) {
    final queryParams = uri?.queryParameters ?? {};
    final bodyText = _formatJsonString(session.requestBody);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Query Parameters
          if (queryParams.isNotEmpty) ...[
            Text(
              '${tr('networkProxy.query')} (${queryParams.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            _buildHeadersTable(queryParams),
            const SizedBox(height: 14),
          ],

          // Request Headers
          if (session.requestHeaders.isNotEmpty) ...[
            ExpansionTile(
              title: Text(
                '${tr('networkProxy.headers')} (${session.requestHeaders.length})',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              initiallyExpanded: true,
              tilePadding: EdgeInsets.zero,
              children: [
                _buildHeadersTable(session.requestHeaders),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Request Body
          if (session.requestBody.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tr('networkProxy.body'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                IconButton(
                  tooltip: tr('networkProxy.copy'),
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: session.requestBody));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr('networkProxy.copied'))),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                ),
              ),
              child: SelectableText(
                bodyText,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewTab(ProxySession session) {
    final items = [
      MapEntry('URL', session.url),
      MapEntry('Method', session.method),
      MapEntry('Status Code', '${session.statusCode}'),
      MapEntry('Duration', '${session.durationMs} ms'),
      MapEntry('Response Size', _formatSize(session.responseSize)),
      MapEntry('Client IP', session.clientIp),
      MapEntry(
        'Start Time',
        DateTime.fromMillisecondsSinceEpoch(session.startTime).toLocal().toString(),
      ),
      if (session.isMocked && session.matchedRule != null)
        MapEntry('Mock Rule', session.matchedRule!),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final item = items[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: Text(
                  item.key,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ),
              Expanded(
                child: SelectableText(
                  item.value,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeadersTable(Map<String, String> headers) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Table(
        columnWidths: const {
          0: IntrinsicColumnWidth(),
          1: FlexColumnWidth(),
        },
        children: headers.entries.map((e) {
          return TableRow(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                ),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: SelectableText(
                  e.key,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: SelectableText(
                  e.value,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
