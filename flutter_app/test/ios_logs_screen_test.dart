import 'dart:async';
import 'dart:convert';

import 'package:adb_tool/i18n.dart';
import 'package:adb_tool/providers/device_provider.dart';
import 'package:adb_tool/screens/ios_logs_screen.dart';
import 'package:adb_tool/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  testWidgets('reassembles log chunks and closes the stream on Stop',
      (tester) async {
    final previousLanguage = currentLang;
    setLang('en');
    addTearDown(() => setLang(previousLanguage));
    final socket = _Socket();
    Uri? url;
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<DeviceProvider>(create: (_) => _OnlineDevice()),
        Provider<DeviceSerialScope>.value(
            value: const DeviceSerialScope('ios:PHONE-A')),
        Provider<ApiClient>.value(value: ApiClient('http://127.0.0.1:9876')),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: IosLogsScreen(openSocket: (uri) {
            url = uri;
            return socket;
          }),
        ),
      ),
    ));
    await tester.tap(find.text('Start'));
    await tester.pump();
    expect(url?.path, '/ws/ios/logs');
    expect(url?.queryParameters['serial'], 'ios:PHONE-A');

    final line = utf8.encode('原始日志\n');
    socket.incoming.add(line.sublist(0, 2));
    socket.incoming.add(line.sublist(2));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('原始日志'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(socket.incoming.isClosed, isTrue);
    expect(find.text('原始日志'), findsOneWidget);
  });
}

class _OnlineDevice extends ChangeNotifier implements DeviceProvider {
  @override
  bool isDeviceConnected(String? stableSerial) => stableSerial == 'ios:PHONE-A';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Socket implements WebSocketChannel {
  final incoming = StreamController<Object?>();

  @override
  Stream<Object?> get stream => incoming.stream;

  @override
  Future<void> get ready => Future.value();

  @override
  late final WebSocketSink sink = _Sink(incoming);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sink implements WebSocketSink {
  final StreamController<Object?> incoming;

  _Sink(this.incoming);

  @override
  Future<void> close([int? closeCode, String? closeReason]) => incoming.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
