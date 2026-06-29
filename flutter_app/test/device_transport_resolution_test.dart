import 'package:adb_tool/db/database.dart';
import 'package:adb_tool/models/device.dart';
import 'package:adb_tool/providers/device_provider.dart';
import 'package:adb_tool/services/api_client.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeviceProvider transport resolution', () {
    late AppDatabase db;
    late DeviceProvider provider;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      provider = DeviceProvider(db: db);
    });

    tearDown(() async {
      provider.dispose();
      await db.close();
    });

    test(
        'groups USB and Wi-Fi transports under one stable identity and prefers USB',
        () async {
      await provider.refresh(_DevicesApi([
        const Device(
          serial: '192.168.1.5:42187',
          hardwareSerial: 'R5CT70AHPDR',
          state: 'device',
          model: 'Pixel 8',
          brand: 'Google',
          sdk: '35',
        ),
        const Device(
          serial: 'USB123456',
          hardwareSerial: 'R5CT70AHPDR',
          state: 'device',
          model: 'Pixel 8',
          brand: 'Google',
          sdk: '35',
        ),
      ]));

      expect(provider.transportsFor('R5CT70AHPDR').map((d) => d.serial),
          containsAll(['192.168.1.5:42187', 'USB123456']));
      expect(provider.onlineAddressFor('R5CT70AHPDR'), 'USB123456');

      final saved =
          await db.savedDevicesDao.getSavedDeviceBySerial('R5CT70AHPDR');
      expect(saved, isNotNull);
      expect(saved!.address, 'USB123456');

      final all = await db.savedDevicesDao.getAllSavedDevices();
      expect(all, hasLength(1));
    });

    test(
        'returns null from onlineAddressFor when the device is offline '
        '(do not silently fall back to the last-known saved address)',
        () async {
      await db.savedDevicesDao.upsertSavedDevice(
        serial: 'R5CT70AHPDR',
        model: 'Pixel 8',
        brand: 'Google',
        sdk: '35',
        isConnected: false,
        address: '192.168.1.5:42187',
      );
      await Future<void>.delayed(Duration.zero);

      expect(provider.onlineAddressFor('R5CT70AHPDR'), isNull);
    });

    test(
        'wifiTransportFor returns the Wi-Fi transport even when USB is '
        'also online (used by wireless disconnect, must NOT be '
        'USB-preferred like onlineAddressFor)', () async {
      await provider.refresh(_DevicesApi([
        const Device(
          serial: '192.168.1.5:42187',
          hardwareSerial: 'R5CT70AHPDR',
          state: 'device',
          model: 'Pixel 8',
          brand: 'Google',
          sdk: '35',
        ),
        const Device(
          serial: 'USB123456',
          hardwareSerial: 'R5CT70AHPDR',
          state: 'device',
          model: 'Pixel 8',
          brand: 'Google',
          sdk: '35',
        ),
      ]));

      // Sanity: onlineAddressFor still picks USB (this is the
      // contract — adb command routing prefers USB).
      expect(provider.onlineAddressFor('R5CT70AHPDR'), 'USB123456');

      // wifiTransportFor must return the Wi-Fi one even though
      // transportsFor sorts USB first. Otherwise wireless disconnect
      // would call `adb disconnect USB123456` and silently no-op.
      final wifi = provider.wifiTransportFor('R5CT70AHPDR');
      expect(wifi, isNotNull,
          reason: 'device has a live Wi-Fi transport, helper must find it');
      expect(wifi!.serial, '192.168.1.5:42187');
      expect(provider.hasWifiTransport('R5CT70AHPDR'), isTrue);
    });

    test(
        'wifiTransportFor returns null when the device only has a USB '
        'transport (no Wi-Fi to disconnect from)', () async {
      await provider.refresh(_DevicesApi([
        const Device(
          serial: 'USB123456',
          hardwareSerial: 'R5CT70AHPDR',
          state: 'device',
          model: 'Pixel 8',
          brand: 'Google',
          sdk: '35',
        ),
      ]));

      expect(provider.wifiTransportFor('R5CT70AHPDR'), isNull);
      expect(provider.hasWifiTransport('R5CT70AHPDR'), isFalse);
    });

    test(
        'wifiTransportFor returns null when the device is offline '
        '(do not pretend a Wi-Fi transport still exists)', () async {
      // No refresh() call — the device was never seen online in this
      // test. Even if there's a saved row pointing at an old
      // ip:port, we must not surface it as a "current Wi-Fi
      // transport" because it isn't reachable.
      expect(provider.wifiTransportFor('R5CT70AHPDR'), isNull);
      expect(provider.hasWifiTransport('R5CT70AHPDR'), isFalse);
    });

    test(
        'transportTypeForSerial classifies the Android 14+ '
        '`._adb-tls-connect._tcp` mDNS form as Wi-Fi (regression: '
        'was previously mis-classified as USB because it has no `:`)',
        () async {
      expect(transportTypeForSerial('adb-499d1b6e-KhoFQX._adb-tls-connect._tcp'),
          DeviceTransportType.wifi);
      expect(transportTypeForSerial('adb-499d1b6e-KhoFQX (2)._adb-tls-connect._tcp'),
          DeviceTransportType.wifi,
          reason: 'parens / space in name must still classify as wifi');
      // The trailing-._tcp form is the documented Android 14+ form;
      // the .contains('._tcp.') form is a defensive match for any
      // adb naming variant that has `_tcp.` mid-string.
      expect(transportTypeForSerial('something._tcp.other'),
          DeviceTransportType.wifi);
      // Legacy form still works.
      expect(transportTypeForSerial('192.168.31.116:39239'),
          DeviceTransportType.wifi);
      // Plain USB still works.
      expect(transportTypeForSerial('USB123456'), DeviceTransportType.usb);
    });

    test(
        'wifiTransportFor prefers the legacy ip:port transport over '
        'the mDNS one (so wireless disconnect targets the '
        'user-initiated connect, not the system one)', () async {
      await provider.refresh(_DevicesApi([
        const Device(
          serial: 'adb-499d1b6e-KhoFQX._adb-tls-connect._tcp',
          hardwareSerial: 'R5CT70AHPDR',
          state: 'device',
          model: 'Pixel 8',
          brand: 'Google',
          sdk: '35',
        ),
        const Device(
          serial: '192.168.31.116:39239',
          hardwareSerial: 'R5CT70AHPDR',
          state: 'device',
          model: 'Pixel 8',
          brand: 'Google',
          sdk: '35',
        ),
      ]));

      final wifi = provider.wifiTransportFor('R5CT70AHPDR');
      expect(wifi, isNotNull);
      expect(wifi!.serial, '192.168.31.116:39239',
          reason: 'legacy ip:port transport must be chosen over mDNS one');
    });

    test(
        'wifiTransportFor falls back to the mDNS transport when no '
        'legacy ip:port transport exists', () async {
      await provider.refresh(_DevicesApi([
        const Device(
          serial: 'adb-499d1b6e-KhoFQX._adb-tls-connect._tcp',
          hardwareSerial: 'R5CT70AHPDR',
          state: 'device',
          model: 'Pixel 8',
          brand: 'Google',
          sdk: '35',
        ),
      ]));

      final wifi = provider.wifiTransportFor('R5CT70AHPDR');
      expect(wifi, isNotNull,
          reason: 'mDNS transport should still be findable as a fallback');
      expect(wifi!.serial, 'adb-499d1b6e-KhoFQX._adb-tls-connect._tcp');
      expect(provider.hasWifiTransport('R5CT70AHPDR'), isTrue);
    });
  });

  group('ApiClient stable identity boundary', () {
    test(
        'resolves stable serial to preferred online adb address before request',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final provider = DeviceProvider(db: db);
      final dio = _CaptureDio();
      final api = ApiClient('http://localhost:9876',
          dio: dio, deviceProvider: provider);

      addTearDown(() async {
        provider.dispose();
        await db.close();
      });

      await provider.refresh(_DevicesApi([
        const Device(
          serial: '192.168.1.5:42187',
          hardwareSerial: 'R5CT70AHPDR',
          state: 'device',
        ),
        const Device(
          serial: 'R5CT70AHPDR',
          hardwareSerial: 'R5CT70AHPDR',
          state: 'device',
        ),
      ]));

      await api.getDeviceStatus('R5CT70AHPDR');

      expect(dio.lastPath, '/api/device-status');
      expect(dio.lastQueryParameters?['serial'], 'R5CT70AHPDR');
    });

    test('throws local offline exception instead of using stale saved address',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final provider = DeviceProvider(db: db);
      final dio = _CaptureDio();
      final api = ApiClient('http://localhost:9876',
          dio: dio, deviceProvider: provider);

      addTearDown(() async {
        provider.dispose();
        await db.close();
      });

      await db.savedDevicesDao.upsertSavedDevice(
        serial: 'R5CT70AHPDR',
        model: 'Pixel 8',
        brand: 'Google',
        sdk: '35',
        isConnected: false,
        address: '192.168.1.5:42187',
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        () => api.getDeviceStatus('R5CT70AHPDR'),
        throwsA(isA<DeviceOfflineException>()),
      );
      expect(dio.lastPath, isNull);
    });

    test(
        'wireless port change: stable identity is unchanged, '
        'API picks up the new adb-serial after a DeviceProvider refresh',
        () async {
      // Regression test for the v8→v9 identity split. The frontend
      // hands a STABLE identity (ro.serialno) to the API. When the
      // wireless device reconnects on a new port, DeviceProvider
      // re-reports the device under the same hardwareSerial but a
      // different adb-serial. The API must transparently pick up the
      // new adb-serial — screens never see the churn.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final provider = DeviceProvider(db: db);
      final dio = _CaptureDio();
      final api = ApiClient('http://localhost:9876',
          dio: dio, deviceProvider: provider);

      addTearDown(() async {
        provider.dispose();
        await db.close();
      });

      // First poll: device on the old port.
      await provider.refresh(_DevicesApi([
        const Device(
          serial: '192.168.1.5:42187',
          hardwareSerial: 'R5CT70AHPDR',
          state: 'device',
        ),
      ]));
      await api.getDeviceStatus('R5CT70AHPDR');
      expect(dio.lastQueryParameters?['serial'], '192.168.1.5:42187');

      // Second poll: device reconnect on a new port. Frontend keeps
      // handing the same stable identity to the API; backend now
      // sees the new adb-serial in the URL.
      await provider.refresh(_DevicesApi([
        const Device(
          serial: '192.168.1.5:55555',
          hardwareSerial: 'R5CT70AHPDR',
          state: 'device',
        ),
      ]));
      await api.getDeviceStatus('R5CT70AHPDR');
      expect(dio.lastQueryParameters?['serial'], '192.168.1.5:55555');
    });
  });
}

class _DevicesApi extends ApiClient {
  final List<Device> result;

  _DevicesApi(this.result) : super('http://localhost:9876');

  @override
  Future<bool> isReady() async => true;

  @override
  Future<List<Device>> getDevices() async => result;
}

class _CaptureDio extends DioForNative {
  String? lastPath;
  Map<String, dynamic>? lastQueryParameters;

  _CaptureDio() : super(BaseOptions(baseUrl: 'http://localhost:9876'));

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    lastPath = path;
    lastQueryParameters = Map<String, dynamic>.from(queryParameters ?? {});
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: {
        'ok': true,
        'data': {
          'status': {
            'topProcesses': [],
          },
        },
      } as T,
    );
  }
}
