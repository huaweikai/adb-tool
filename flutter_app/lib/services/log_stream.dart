import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/device.dart';

class LogStreamService {
  WebSocketChannel? _channel;
  final _controller = StreamController<List<LogEntry>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  StreamSubscription? _subscription;
  String _serial = '';
  LogFilter? _filter;

  Stream<List<LogEntry>> get logStream => _controller.stream;
  Stream<bool> get connectionState => _connectionController.stream;
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
      _connectionController.add(true);
    });

    _subscription = _channel!.stream.listen(
      (data) {
        try {
          final msg = json.decode(data as String) as Map<String, dynamic>;
          final filter = _filter;
          if (filter == null) return;
          if (msg['type'] == 'log') {
            final entry = LogEntry.parse(msg['data'] as String);
            if (entry.matchesFilter(filter)) {
              _controller.add([entry]);
            }
          } else if (msg['type'] == 'logs') {
            final lines = msg['lines'];
            if (lines is! List) return;
            final entries = <LogEntry>[];
            for (final line in lines) {
              if (line is! String) continue;
              final entry = LogEntry.parse(line);
              if (entry.matchesFilter(filter)) {
                entries.add(entry);
              }
            }
            if (entries.isNotEmpty) {
              _controller.add(entries);
            }
          }
        } catch (_) {}
      },
      onError: (e) {
        _controller.addError(e);
        _connectionController.add(false);
      },
      onDone: () {
        _connectionController.add(false);
      },
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
    _channel = null;
  }

  void pause() => _send({'action': 'pause'});
  void resume() => _send({'action': 'resume'});

  void clear() {
    _send({'action': 'clear'});
  }

  void _send(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(json.encode(data));
    } catch (_) {}
  }

  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    _controller.close();
    _connectionController.close();
  }
}
