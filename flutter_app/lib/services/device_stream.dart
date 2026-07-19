import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket client for the backend's `/ws/devices` endpoint.
///
/// Maintains a single persistent connection that pushes device-list
/// snapshots and incremental changes. Reconnects automatically with
/// exponential backoff on any connection error.
///
/// Protocol (server → client):
///   - {"type":"snapshot","devices":[...]}   — full device list on connect
///   - {"type":"change","current":[...],"added":[...],"removed":[...]}
class DeviceStreamService {
  static const _maxBackoffSeconds = 30;

  WebSocketChannel? _ws;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _reconnecting = false;
  bool _disposed = false;
  bool _paused = false;

  final _controller = StreamController<DeviceStreamEvent>.broadcast();

  /// Stream of device-list events. Subscribe once; events keep coming
  /// as long as the connection lives or until [dispose].
  Stream<DeviceStreamEvent> get stream => _controller.stream;

  /// Whether the WebSocket is currently connected.
  bool get isConnected => _ws != null;

  /// Open the WebSocket connection to `ws://127.0.0.1:9876/ws/devices`.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops while
  /// already connected or connecting.
  void connect() {
    if (_disposed) return;
    if (_ws != null || _reconnecting) return;
    _doConnect();
  }

  void _doConnect() {
    if (_disposed) return;

    const wsUrl = 'ws://127.0.0.1:9876/ws/devices';
    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _ws = channel;

    channel.ready.then((_) {
      if (_disposed) return;
      _reconnectAttempt = 0;
      debugPrint('[DeviceStream] connected');
    }).catchError((e) {
      debugPrint('[DeviceStream] connect error: $e');
      _scheduleReconnect();
    });

    _sub = channel.stream.listen(
      (data) {
        try {
          final msg = json.decode(data as String) as Map<String, dynamic>;
          final type = msg['type'] as String?;
          debugPrint('[DeviceStream] received: type=$type');
          if (type == 'snapshot') {
            final devices = _parseDeviceList(msg['devices']);
            debugPrint('[DeviceStream] snapshot: ${devices.length} devices');
            _controller.add(DeviceSnapshot(devices));
          } else if (type == 'change') {
            final current = _parseDeviceList(msg['current']);
            final added = _toStringList(msg['added']);
            final removed = _toStringList(msg['removed']);
            debugPrint('[DeviceStream] change: current=${current.length} added=$added removed=$removed');
            _controller.add(DeviceChange(
              current: current,
              added: added,
              removed: removed,
            ));
          }
        } catch (e) {
          debugPrint('[DeviceStream] parse error: $e');
        }
      },
      onError: (e) {
        debugPrint('[DeviceStream] stream error: $e');
        _scheduleReconnect();
      },
      onDone: () {
        debugPrint('[DeviceStream] disconnected');
        _scheduleReconnect();
      },
      cancelOnError: false,
    );
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnecting) return;
    _reconnecting = true;
    _ws = null;
    _sub?.cancel();
    _sub = null;

    final delaySeconds = min(
      _maxBackoffSeconds,
      1 << _reconnectAttempt.clamp(0, 5),
    );
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _reconnectAttempt++;
      _reconnecting = false;
      if (!_disposed && !_paused) {
        _doConnect();
      }
    });
  }

  /// Pause reconnection. Called when the app goes to background.
  void pause() {
    _paused = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnecting = false;
    _ws?.sink.close();
    _sub?.cancel();
    _ws = null;
    _sub = null;
  }

  /// Resume after pause. Reconnects automatically.
  void resume() {
    if (!_paused) return;
    _paused = false;
    if (!_disposed) {
      _doConnect();
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _ws?.sink.close();
    await _controller.close();
  }

  List<WsDevice> _parseDeviceList(dynamic raw) {
    if (raw is! List) return [];
    return raw.map<WsDevice>((e) {
      if (e is Map<String, dynamic>) {
        return WsDevice(
          serial: e['serial']?.toString() ?? '',
          state: e['state']?.toString() ?? '',
          model: e['model']?.toString() ?? '',
        );
      }
      return const WsDevice();
    }).toList();
  }

  List<String> _toStringList(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => e.toString()).toList();
  }
}

/// Base class for device stream events.
sealed class DeviceStreamEvent {}

/// Full device snapshot, received on initial connect or reconnect.
class DeviceSnapshot extends DeviceStreamEvent {
  final List<WsDevice> devices;
  DeviceSnapshot(this.devices);
}

/// Incremental change: added/removed serials plus the full current list.
class DeviceChange extends DeviceStreamEvent {
  final List<WsDevice> current;
  final List<String> added;
  final List<String> removed;
  DeviceChange({
    required this.current,
    required this.added,
    required this.removed,
  });
}

/// Lightweight device representation from the WS stream.
///
/// Only carries serial + state + model (what `host:track-devices`
/// provides). The full Device details (hardwareSerial, brand, sdk)
/// are fetched via HTTP when a change is detected.
class WsDevice {
  final String serial;
  final String state;
  final String model;

  const WsDevice({
    this.serial = '',
    this.state = '',
    this.model = '',
  });
}
