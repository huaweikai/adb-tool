import 'dart:async';
import 'dart:convert';

import 'package:adb_tool/models/device.dart';
import 'package:adb_tool/providers/device_provider.dart';
import 'package:adb_tool/services/log_stream.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  test('replays a reconnect boundary by occurrence count', () async {
    final device = _Device();
    final sockets = <_Socket>[];
    final service = LogStreamService(device, openSocket: (_) {
      final socket = _Socket();
      sockets.add(socket);
      return socket;
    });
    addTearDown(() async {
      await service.dispose();
      device.dispose();
    });

    service.connect('stable');
    final received = <LogEntry>[];
    final subscription = service.streamFor('stable').listen(received.addAll);
    addTearDown(subscription.cancel);
    await Future<void>.delayed(Duration.zero);

    final first = sockets.single;
    expect(first.commands.single['serial'], 'wifi:1234');
    expect(first.commands.single['filters'], {'priority': 'V'});
    expect(first.commands.single.containsKey('since'), isFalse);
    const boundary = '2026-11-16 12:00:00.123456';
    const same = '$boundary 100 101 I HTTP: repeated';
    const next = '2026-11-16 12:00:00.123457 100 101 I HTTP: next';
    first.emit({'type': 'status', 'data': 'running'});
    first.emit({
      'type': 'logs',
      'lines': [same, same]
    });
    await Future<void>.delayed(Duration.zero);
    expect(received.map((entry) => entry.raw), [same, same]);

    unawaited(first.incoming.close());
    device.address = 'wifi:4321';
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 1100));

    final resumed = sockets.last;
    expect(sockets.length, 2);
    expect(resumed.commands.single['since'], boundary);
    expect(resumed.commands.single['serial'], 'wifi:4321');
    resumed.emit({
      'type': 'logs',
      'lines': ['--------- beginning of main', same, same, same, next],
    });
    await Future<void>.delayed(Duration.zero);
    expect(received.map((entry) => entry.raw), [same, same, same, next]);

    await subscription.cancel();
    service.stop('stable');
    service.connect('stable');
    await Future<void>.delayed(Duration.zero);
    expect(sockets.last.commands.single['since'], '2026-11-16 12:00:00.123457');
  });
}

class _Device extends ChangeNotifier implements DeviceProvider {
  String address = 'wifi:1234';

  @override
  String? onlineAddressFor(String stableSerial) => address;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Socket implements WebSocketChannel {
  final incoming = StreamController<Object?>.broadcast();
  final commands = <Map<String, dynamic>>[];

  @override
  Stream<Object?> get stream => incoming.stream;

  @override
  Future<void> get ready => Future.value();

  @override
  late final WebSocketSink sink = _Sink(this);

  void emit(Map<String, dynamic> message) => incoming.add(jsonEncode(message));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sink implements WebSocketSink {
  _Sink(this.socket);

  final _Socket socket;

  @override
  void add(dynamic event) =>
      socket.commands.add(jsonDecode(event as String) as Map<String, dynamic>);

  @override
  Future<void> close([int? closeCode, String? closeReason]) =>
      socket.incoming.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
