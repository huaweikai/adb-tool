import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/device.dart';

class LogStreamService {
  WebSocketChannel? _channel;
  final _controller = StreamController<LogEntry>.broadcast();
  StreamSubscription? _subscription;
  String _serial = '';
  LogFilter? _filter;

  Stream<LogEntry> get logStream => _controller.stream;
  String get serial => _serial;

  void connect(String serial, LogFilter filter) {
    _subscription?.cancel();
    _channel?.sink.close();

    _serial = serial;
    _filter = filter;

    const wsUrl = 'ws://localhost:9876/ws/logs';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    _channel!.ready.then((_) {
      _send({
        'action': 'start',
        'serial': serial,
        'filters': filter.toJson(),
      });
    });

    _subscription = _channel!.stream.listen(
      (data) {
        try {
          final msg = json.decode(data as String);
          if (msg['type'] == 'log') {
            final entry = LogEntry.parse(msg['data'] as String);
            if (entry.matchesFilter(_filter!)) {
              _controller.add(entry);
            }
          }
        } catch (_) {}
      },
      onError: (e) {
        _controller.addError(e);
      },
      onDone: () {},
    );
  }

  void updateFilter(LogFilter filter) {
    _filter = filter;
    _send({
      'action': 'filter',
      'filters': filter.toJson(),
    });
  }

  void stop() {
    _send({'action': 'stop'});
    _channel?.sink.close();
  }

  void pause() => _send({'action': 'pause'});
  void resume() => _send({'action': 'resume'});

  void clear() {
    _send({'action': 'clear'});
  }

  void _send(Map<String, dynamic> data) {
    _channel?.sink.add(json.encode(data));
  }

  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    _controller.close();
  }
}
