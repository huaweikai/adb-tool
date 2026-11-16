import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/device.dart';
import '../providers/device_provider.dart';

typedef _LogCheckpoint = ({String time, Map<String, int> occurrences});

/// Per-device WebSocket channel for logcat streaming.
///
/// Each device gets its own channel so switching between devices does not
/// tear down other devices' streams. The backend's `/ws/logs` handler
/// creates a fresh `LogSession` per connection, so multiple parallel
/// channels are fully supported server-side.
class _DeviceLogChannel {
  /// Stable device identity (ro.serialno). The channel keys itself
  /// by this value and re-resolves the live adb-serial via
  /// [DeviceProvider] on every (re)connect — that way a wireless
  /// port change doesn't strand the channel on a dead adb address.
  final String stableSerial;

  /// Resolver for the current adb address. Required because the
  /// backend's `start` action carries the adb-serial in its
  /// payload, and that serial churns on wireless reconnects.
  final DeviceProvider deviceProvider;
  final WebSocketChannel Function(Uri uri) openSocket;

  WebSocketChannel? _socket;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _disposed = false;
  bool _clearing = false;

  // Track occurrences rather than just raw text: two identical entries
  // with the same printed timestamp are valid device logs.
  String? _cursor;
  final _atCursor = <String, int>{};
  Map<String, int>? _replay;

  final _controller = StreamController<List<LogEntry>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  _DeviceLogChannel({
    required this.stableSerial,
    required this.deviceProvider,
    required this.openSocket,
    _LogCheckpoint? checkpoint,
  }) {
    if (checkpoint != null) {
      _cursor = checkpoint.time;
      _atCursor.addAll(checkpoint.occurrences);
    }
  }

  _LogCheckpoint? get checkpoint {
    final cursor = _cursor;
    return cursor == null
        ? null
        : (time: cursor, occurrences: Map.of(_atCursor));
  }

  Stream<List<LogEntry>> get stream => _controller.stream;
  Stream<bool> get connectionState => _connectionController.stream;

  void start() {
    if (_disposed) return;
    final address = deviceProvider.onlineAddressFor(stableSerial);
    if (address == null || address.isEmpty) {
      _retry();
      return;
    }
    const url = 'ws://127.0.0.1:9876/ws/logs';
    final socket = openSocket(Uri.parse(url));
    _socket = socket;
    _subscription = socket.stream.listen(
      (data) {
        if (identical(_socket, socket)) _receive(data);
      },
      onError: (_) => _disconnect(socket),
      onDone: () => _disconnect(socket),
    );
    socket.ready.then<void>((_) {
      if (!identical(_socket, socket)) return;
      _replay = _cursor == null ? null : Map.of(_atCursor);
      _send({
        'action': 'start',
        'serial': address,
        'filters': {'priority': 'V'},
        if (_cursor != null) 'since': _cursor,
      });
    }).catchError((_) => _disconnect(socket));
  }

  void _receive(Object? data) {
    if (data is! String) return;
    try {
      final message = jsonDecode(data);
      if (message is! Map<String, dynamic>) return;
      if (message['type'] == 'status') {
        switch (message['data']) {
          case 'running':
            _reconnectAttempt = 0;
            _connectionController.add(true);
          case 'cleared':
            _clearing = false;
        }
        return;
      }
      if (message['type'] == 'error') {
        _clearing = false;
        return;
      }
      if (_clearing) return;
      final lines = switch (message['type']) {
        'log' => [message['data']],
        'logs' => message['lines'],
        _ => null,
      };
      if (lines is! List) return;
      final batch = <LogEntry>[];
      for (final raw in lines.whereType<String>()) {
        final entry = LogEntry.parse(raw);
        if (entry.time.isNotEmpty) {
          if (_cursor != entry.time) {
            _cursor = entry.time;
            _atCursor.clear();
            _replay = null;
          } else if (_replay?[raw] case final int remaining
              when remaining > 0) {
            _replay![raw] = remaining - 1;
            continue;
          }
          _atCursor.update(raw, (count) => count + 1, ifAbsent: () => 1);
        } else if (_replay != null && raw.startsWith('---------')) {
          continue;
        }
        batch.add(entry);
      }
      if (batch.isNotEmpty) _controller.add(batch);
    } on FormatException {
      // The peer sent an invalid WebSocket envelope.
    }
  }

  void _disconnect(WebSocketChannel socket) {
    if (!identical(_socket, socket)) return;
    _socket = null;
    _clearing = false;
    _subscription?.cancel();
    socket.sink.close();
    _retry();
  }

  void _retry() {
    if (_disposed || _reconnectTimer != null) return;
    _connectionController.add(false);
    final delay = min(30, 1 << _reconnectAttempt.clamp(0, 5));
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      _reconnectTimer = null;
      _reconnectAttempt++;
      start();
    });
  }

  void resetCursor() {
    _cursor = null;
    _atCursor.clear();
    _replay = null;
  }

  void clear() {
    resetCursor();
    _clearing = _socket != null;
    _send({'action': 'clear'});
  }

  void _send(Map<String, dynamic> data) {
    final socket = _socket;
    if (socket == null) return;
    try {
      socket.sink.add(jsonEncode(data));
    } catch (_) {
      _disconnect(socket);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    final socket = _socket;
    _socket = null;
    await _subscription?.cancel();
    await socket?.sink.close();
    await _controller.close();
    await _connectionController.close();
  }
}

/// Raw per-device log streams. View filters and pause live with the history
/// buffer so changing the view never restarts ADB.
class LogStreamService {
  LogStreamService(
    this._deviceProvider, {
    WebSocketChannel Function(Uri uri) openSocket = WebSocketChannel.connect,
  }) : _openSocket = openSocket;

  final DeviceProvider _deviceProvider;
  final WebSocketChannel Function(Uri uri) _openSocket;
  final Map<String, _DeviceLogChannel> _channels = {};
  final Map<String, _LogCheckpoint> _checkpoints = {};

  Stream<List<LogEntry>> streamFor(String serial) =>
      _channels[serial]?.stream ?? const Stream.empty();

  Stream<bool> connectionStateFor(String serial) =>
      _channels[serial]?.connectionState ?? const Stream.empty();

  void connect(String serial) {
    _channels.putIfAbsent(serial, () {
      return _DeviceLogChannel(
        stableSerial: serial,
        deviceProvider: _deviceProvider,
        openSocket: _openSocket,
        checkpoint: _checkpoints.remove(serial),
      )..start();
    });
  }

  void clear(String serial) => _channels[serial]?.clear();

  void resetCursor(String serial) {
    _checkpoints.remove(serial);
    _channels[serial]?.resetCursor();
  }

  void stop(String serial) {
    final channel = _channels.remove(serial);
    if (channel == null) return;
    final checkpoint = channel.checkpoint;
    if (checkpoint != null) _checkpoints[serial] = checkpoint;
    unawaited(channel.dispose());
  }

  bool isConnected(String serial) => _channels.containsKey(serial);

  Future<void> dispose() async {
    final channels = _channels.values.toList();
    _channels.clear();
    _checkpoints.clear();
    await Future.wait(channels.map((channel) => channel.dispose()));
  }
}
