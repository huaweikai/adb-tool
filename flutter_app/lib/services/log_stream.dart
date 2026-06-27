import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/device.dart';

/// Per-device WebSocket channel for logcat streaming.
///
/// Each device gets its own channel so switching between devices does not
/// tear down other devices' streams. The backend's `/ws/logs` handler
/// creates a fresh `LogSession` per connection, so multiple parallel
/// channels are fully supported server-side.
class _DeviceLogChannel {
  final String serial;
  LogFilter filter;
  WebSocketChannel? ws;
  StreamSubscription? sub;
  Timer? reconnectTimer;
  int reconnectAttempt = 0;

  final _controller = StreamController<List<LogEntry>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  static const _maxBackoffSeconds = 30;

  _DeviceLogChannel({required this.serial, required this.filter});

  Stream<List<LogEntry>> get stream => _controller.stream;
  Stream<bool> get connectionState => _connectionController.stream;

  void start() {
    _doConnect();
  }

  void _doConnect() {
    const wsUrl = 'ws://127.0.0.1:9876/ws/logs';
    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    ws = channel;

    channel.ready.then((_) {
      reconnectAttempt = 0;
      _send({
        'action': 'start',
        'serial': serial,
        'filters': filter.toJson(),
      });
      _connectionController.add(true);
    }).catchError((_) {
      _connectionController.add(false);
      _scheduleReconnect();
    });

    sub = channel.stream.listen(
      (data) {
        try {
          final msg = json.decode(data as String) as Map<String, dynamic>;
          final f = filter;
          if (msg['type'] == 'log') {
            final entry = LogEntry.parse(msg['data'] as String);
            if (entry.matchesFilter(f)) {
              _controller.add([entry]);
            }
          } else if (msg['type'] == 'logs') {
            final lines = msg['lines'];
            if (lines is! List) return;
            final entries = <LogEntry>[];
            for (final line in lines) {
              if (line is! String) continue;
              final entry = LogEntry.parse(line);
              if (entry.matchesFilter(f)) {
                entries.add(entry);
              }
            }
            if (entries.isNotEmpty) {
              _controller.add(entries);
            }
          }
        } catch (_) {}
      },
      onError: (_) {
        _connectionController.add(false);
        _scheduleReconnect();
      },
      onDone: () {
        _connectionController.add(false);
        _scheduleReconnect();
      },
      cancelOnError: false,
    );
  }

  void _scheduleReconnect() {
    reconnectAttempt++;
    final delaySeconds = min(
      _maxBackoffSeconds,
      1 << reconnectAttempt.clamp(0, 5),
    );
    reconnectTimer?.cancel();
    reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _doConnect();
    });
  }

  void updateFilter(LogFilter newFilter) {
    filter = newFilter;
    _send({'action': 'filter', 'filters': newFilter.toJson()});
  }

  void stop() {
    reconnectTimer?.cancel();
    sub?.cancel();
    _send({'action': 'stop'});
    ws?.sink.close();
    ws = null;
  }

  void pause() => _send({'action': 'pause'});
  void resume() => _send({'action': 'resume'});
  void clear() => _send({'action': 'clear'});

  void _send(Map<String, dynamic> data) {
    try {
      ws?.sink.add(json.encode(data));
    } catch (_) {}
  }

  Future<void> dispose() async {
    stop();
    await _controller.close();
    await _connectionController.close();
  }
}

/// Multi-device logcat stream service.
///
/// Each device gets its own WebSocket channel, filter state, and stream.
/// Switching devices does NOT stop other devices' streams — entries
/// continue accumulating in the background for the device you switch
/// back to.
///
/// Lifecycle: this service is a top-level singleton (registered in di.dart).
/// It lives for the entire app session; channels are created lazily on
/// first `connect()` and torn down on `stop(serial)`.
class LogStreamService {
  final Map<String, _DeviceLogChannel> _channels = {};

  /// Returns the live entry stream for a specific device.
  /// Empty stream if the device has not been connected yet.
  Stream<List<LogEntry>> streamFor(String serial) =>
      _channels[serial]?.stream ?? const Stream.empty();

  /// Returns the WebSocket connection-state stream for a specific device.
  Stream<bool> connectionStateFor(String serial) =>
      _channels[serial]?.connectionState ?? const Stream<bool>.empty();

  /// Open a stream for the given device with the given filter.
  /// If a channel already exists for this serial, the filter is updated
  /// and the existing connection is reused.
  void connect(String serial, LogFilter filter) {
    final existing = _channels[serial];
    if (existing != null) {
      existing.updateFilter(filter);
      return;
    }
    final channel = _DeviceLogChannel(serial: serial, filter: filter);
    _channels[serial] = channel;
    channel.start();
  }

  /// Update the filter for an existing channel without restart.
  /// No-op if the device has not been connected.
  void updateFilter(String serial, LogFilter filter) {
    _channels[serial]?.updateFilter(filter);
  }

  /// Pause a specific device's stream.
  void pause(String serial) => _channels[serial]?.pause();

  /// Resume a specific device's stream.
  void resume(String serial) => _channels[serial]?.resume();

  /// Send "clear" to a specific device's backend session.
  void clear(String serial) => _channels[serial]?.clear();

  /// Stop and dispose a specific device's channel.
  void stop(String serial) {
    final ch = _channels.remove(serial);
    ch?.dispose();
  }

  /// Whether a device currently has an active channel.
  bool isConnected(String serial) => _channels.containsKey(serial);

  /// Dispose all channels. Called only on app shutdown.
  Future<void> dispose() async {
    final channels = _channels.values.toList();
    _channels.clear();
    await Future.wait(channels.map((c) => c.dispose()));
  }
}