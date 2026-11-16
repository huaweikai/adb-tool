import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../i18n.dart';
import '../providers/device_provider.dart';
import '../services/api_client.dart';

class IosLogsScreen extends StatefulWidget {
  const IosLogsScreen({super.key, this.openSocket = WebSocketChannel.connect});

  final WebSocketChannel Function(Uri) openSocket;

  @override
  State<IosLogsScreen> createState() => _IosLogsScreenState();
}

class _IosLogsScreenState extends State<IosLogsScreen> {
  static const _lineLimit = 2000;
  final _tail = Queue<String>();
  List<String> _visible = const [];
  WebSocketChannel? _socket;
  StreamSubscription<String>? _subscription;
  Timer? _refresh;
  bool _failed = false;
  bool _receiving = false;
  bool _online = false;
  String? _serial;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final serial = context.watch<DeviceSerialScope>().serial;
    final devices = context.watch<DeviceProvider>();
    final active = context.watch<DeviceScreenActiveScope?>()?.active ?? true;
    _online = devices.isDeviceConnected(serial);
    if (serial != _serial) {
      _close();
      _tail.clear();
      _visible = const [];
      _failed = false;
      _serial = serial;
    } else if (!active || !_online) {
      _close();
    }
  }

  void _start() {
    final serial = _serial;
    if (serial == null || !_online || _socket != null) return;
    final base = Uri.parse(context.read<ApiClient>().baseUrl);
    final socket = widget.openSocket(base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/ios/logs',
      queryParameters: {'serial': serial},
    ));
    setState(() {
      _socket = socket;
      _receiving = false;
      _failed = false;
    });
    _subscription = const Utf8Decoder(allowMalformed: true)
        .bind(socket.stream.cast<List<int>>())
        .transform(const LineSplitter())
        .listen(
      (line) {
        if (!identical(_socket, socket)) return;
        _tail.addLast(line);
        if (_tail.length > _lineLimit) _tail.removeFirst();
        _refresh ??= Timer(const Duration(milliseconds: 100), () {
          _refresh = null;
          setState(() {
            _receiving = true;
            _visible = _tail.toList(growable: false);
          });
        });
      },
      onError: (Object _) => _ended(socket, failed: true),
      onDone: () => _ended(socket, failed: socket.closeCode != 1000),
    );
    unawaited(socket.ready.then<void>((_) {},
        onError: (Object _) => _ended(socket, failed: true)));
  }

  void _ended(WebSocketChannel socket, {required bool failed}) {
    if (!mounted || !identical(_socket, socket)) return;
    setState(() {
      _close();
      _failed = failed;
    });
  }

  void _close() {
    final socket = _socket;
    _socket = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    if (socket != null) {
      unawaited(
          socket.sink.close(1000).then<void>((_) {}, onError: (Object _) {}));
    }
    _refresh?.cancel();
    _refresh = null;
    _receiving = false;
    _visible = _tail.toList(growable: false);
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final running = _socket != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: Text(tr('iosLiveLogs')),
          subtitle: Text(tr(!_online
              ? 'iosCrashReportsOffline'
              : _failed
                  ? 'iosLiveLogsFailed'
                  : running
                      ? (_receiving ? 'streaming' : 'iosLiveLogsConnecting')
                      : 'stopped')),
          trailing: Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => setState(() {
                  _tail.clear();
                  _visible = const [];
                }),
                child: Text(tr('clear')),
              ),
              FilledButton(
                onPressed: running
                    ? () => setState(_close)
                    : (_online ? _start : null),
                child: Text(tr(running ? 'stop' : 'start')),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SelectionArea(
            child: ListView.builder(
              reverse: true,
              itemCount: _visible.length,
              itemBuilder: (context, index) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Text(
                  _visible[_visible.length - index - 1],
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
