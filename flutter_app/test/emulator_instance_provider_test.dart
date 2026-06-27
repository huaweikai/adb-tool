import 'package:adb_tool/providers/emulator_instance_provider.dart';
import 'package:adb_tool/services/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deleteInstance sends destructive delete confirmation', () async {
    final adapter = _DeleteCaptureAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:9876'));
    dio.httpClientAdapter = adapter;
    final provider = EmulatorInstanceProvider(api: ApiClient('', dio: dio));

    final ok = await provider.deleteInstance('instance-1');

    expect(ok, isTrue);
    expect(adapter.capturedPath, '/api/emulator/instance/delete');
    expect(adapter.capturedQueryParameters, {
      'id': 'instance-1',
      'confirm': 'true',
    });
  });
}

class _DeleteCaptureAdapter implements HttpClientAdapter {
  String? capturedPath;
  Map<String, dynamic>? capturedQueryParameters;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    capturedPath = options.path;
    capturedQueryParameters =
        Map<String, dynamic>.from(options.queryParameters);
    return ResponseBody.fromString(
      '{"ok":true,"data":{"deleted":true}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
