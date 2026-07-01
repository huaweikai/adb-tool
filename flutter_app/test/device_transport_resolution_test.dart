import 'package:adb_tool/db/database.dart';
import 'package:adb_tool/models/device.dart';
import 'package:adb_tool/providers/device_provider.dart';
import 'package:adb_tool/services/api_client.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────
  // NOTE on test coverage of the a11y / crash fix
  // ─────────────────────────────────────────────────────────────────
  // The full fix was three pieces:
  //   1. DeviceProvider._refresh emits notifyListeners() exactly once
  //      (was: twice — before and after persistence).
  //   2. HomeScreen's device tree is factored into a top-level
  //      `_DeviceTreeArea` that uses Consumer<DeviceProvider>, so
  //      only the device tree rebuilds on provider notify — not the
  //      IndexedStack of per-device screens or the top toolbar.
  //   3. ListView children go through KeyedSubtree keyed by
  //      SavedDevice.serial, so per-row element state can't drift
  //      on list-shape changes (the 0→1 first-plug-in case).
  //
  // (1) is the highest-leverage piece — once the emit count is
  // pinned, the a11y UNREACHABLE crash from rapid back-to-back
  // rebuilds cannot return. That's what the
  // "DeviceProvider refresh emit budget" group below covers.
  //
  // (2) and (3) aren't pinned by a widget test because:
  //   - `_DeviceTreeArea` is a private top-level class in
  //     `home_screen.dart`. Exposing it (or building a HomeScreen
  //     widget test) requires mocking 9 providers that the screen
  //     pulls from the tree (DeviceProvider, ApiClient,
  //     LocaleProvider, ThemeProvider, TestConfigProvider,
  //     TestSessionProvider, EmulatorEngineProvider,
  //     EmulatorJavaProvider, AppDatabase). Cost-to-value is bad.
  //   - KeyedSubtree's "row state stays put on list-shape change"
  //     behavior is a Flutter framework guarantee, not something
  //     worth re-testing in our code.
  //
  // If the HomeScreen test scaffolding ever gets cheaper (e.g. a
  // shared `pumpHomeScreen(tester, ...)` helper), adding a test
  // for "IndexedStack content does NOT rebuild on
  // DeviceProvider.notifyListeners" would be a worthwhile follow-up.

  group('DeviceProvider refresh emit budget', () {
    // Regression for the Windows a11y UNREACHABLE crash: the
    // previous ordering emitted notifyListeners() once before
    // persistence and once after. Two rebuilds back-to-back (the
    // first flipping the device tree from "no devices" → "1 device"
    // mid-reconcile, the second delivering the final state) tripped
    // UI Automation into UNREACHABLE. The fix collapses the two
    // emits into one at the end of _refresh. This test pins the
    // count so a future "let me just split this for cleanliness"
    // refactor can't silently bring the crash back.

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

    test('refresh() on a healthy backend emits notifyListeners exactly once',
        () async {
      // _init() subscribes to db.savedDevicesDao.watchAllSavedDevices(),
      // which fires its initial value on subscribe and re-fires on every
      // DAO write. Those emits are intentional (they're how the UI
      // learns about saved-row changes) but they would mask the budget
      // we're testing here: the *synchronous* emit from the bottom of
      // _refresh. We take a baseline AFTER draining the stream's
      // initial emit and then count only the emits that happen during
      // refresh().
      await provider.refresh(_DevicesApi([
        const Device(
          serial: '192.168.1.5:42187',
          hardwareSerial: 'R5CT70AHPDR',
          state: 'device',
        ),
      ]));
      // First refresh drains _init's stream + the DAO writes it
      // triggers. After pumpEventQueue the listener count is the
      // baseline.
      await pumpEventQueue();
      var baseline = 0;
      provider.addListener(() => baseline++);
      // Register the listener AFTER the baseline is established so it
      // only counts emits that happen during the second refresh.

      await provider.refresh(_DevicesApi([
        const Device(
          serial: '192.168.1.5:42187',
          hardwareSerial: 'R5CT70AHPDR',
          state: 'device',
        ),
      ]));
      await pumpEventQueue();

      // The previous broken implementation emitted notifyListeners()
      // *twice* in _refresh — once after setting _onlineDevices (so
      // the UI flipped to "online" before persistence) and once at
      // the end. With the fix there's exactly one direct emit.
      // Stream-driven emits from DAO writes are an inherent part of
      // the architecture (the UI needs them) and we already paid
      // their cost during the first refresh — they don't double on
      // the second refresh because no rows actually change.
      //
      // (The DB-failure path shares the same single-emit invariant
      // because the only difference is the `if (_lastDbError != dbError)
      // { _lastDbError = dbError; }` line just before the final
      // notifyListeners() — the final emit is unconditional. We don't
      // have a cheap way to force a DAO throw in a unit test without
      // a full mock framework, so the happy-path test pins the
      // invariant by itself; the failure-path code is short enough
      // to read alongside this test.)
      expect(baseline, 1,
          reason:
              'Two back-to-back notifies triggered the Windows a11y '
              'UNREACHABLE crash when the device tree shape changed '
              'mid-rebuild. Keep this at exactly 1.');
    });
  });

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
