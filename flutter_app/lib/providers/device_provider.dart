import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/device.dart';
import '../db/database.dart';
import '../services/api_client.dart';

enum DeviceTransportType { usb, wifi, unknown }

class DeviceTransportSummary {
  final String adbSerial;
  final DeviceTransportType type;
  final String state;

  const DeviceTransportSummary({
    required this.adbSerial,
    required this.type,
    required this.state,
  });

  bool get isOnline => state == 'device';
}

DeviceTransportType transportTypeForSerial(String serial) {
  if (serial.isEmpty) return DeviceTransportType.unknown;
  if (serial.contains(':')) return DeviceTransportType.wifi;
  // Android 14+ wireless debugging uses mDNS-resolved TLS-paired
  // transports named like `adb-<serial>.<fingerprint>._adb-tls-connect._tcp`.
  // The adb daemon connects to them automatically once the user enables
  // wireless debugging on the device. They don't contain `:` so we have
  // to detect them by suffix — otherwise they'd be mis-classified as USB
  // and the wireless disconnect button would route to the wrong transport.
  if (serial.endsWith('._tcp') || serial.contains('._tcp.')) {
    return DeviceTransportType.wifi;
  }
  return DeviceTransportType.usb;
}

int _transportRank(Device device) {
  switch (transportTypeForSerial(device.serial)) {
    case DeviceTransportType.usb:
      return 0;
    case DeviceTransportType.wifi:
      return 1;
    case DeviceTransportType.unknown:
      return 2;
  }
}

String stableIdentityFor(Device device) {
  return device.hardwareSerial.isNotEmpty
      ? device.hardwareSerial
      : device.serial;
}

/// Identity carried into per-device screens via `Provider<DeviceSerialScope>`.
///
/// `serial` is the **stable identity** — the device's ro.serialno. It
/// survives wireless reconnects (which churn the adb address), so
/// it's the right value for any state key, saved-state restore, or
/// cross-screen matching. The adb-level address (ip:port) needed for
/// `?serial=...` adb command URLs is **not** here — `ApiClient`
/// resolves it on demand via the injected `DeviceProvider`. Screens
/// hand the stable identity to every API method and never look at
/// adb addresses themselves.
class DeviceSerialScope {
  final String? serial;
  const DeviceSerialScope(this.serial);
}

class DeviceScreenActiveScope {
  final bool active;
  const DeviceScreenActiveScope(this.active);
}

/// Emitted whenever a device that was previously online disappears from
/// the poll results (USB unplugged, WiFi disconnect, etc.).
///
/// Carries both identifiers because consumers need different ones:
///   * [serial]          — the adb-level address (ip:port for wireless).
///                         MirrorStateProvider compares it against
///                         _status.serial (the adb-serial the scrcpy
///                         subprocess was launched against) to decide
///                         whether to auto-stop.
///   * [hardwareSerial]  — the stable identity (ro.serialno). Database
///                         lookups against saved_devices.serial need
///                         this because v8→v9 keyed the table on
///                         ro.serialno, not on adb-serial. May be
///                         empty when the backend can't read props.
class DeviceOfflineEvent {
  final String serial;
  final String? hardwareSerial;
  final String? displayName; // from the SavedDevice row if available
  const DeviceOfflineEvent({
    required this.serial,
    this.hardwareSerial,
    this.displayName,
  });
}

class DeviceProvider extends ChangeNotifier {
  List<Device> _onlineDevices = [];
  List<SavedDevice> _savedDevices = [];
  bool _online = true;
  String? _activeSerial;
  DateTime? _lastSuccessfulRefresh;
  String? _lastDbError;

  StreamSubscription<List<SavedDevice>>? _savedDevicesSub;
  final AppDatabase _db;

  Future<void>? _refreshing;

  // ── Offline event stream ────────────────────────────────────────────
  final _offlineController = StreamController<DeviceOfflineEvent>.broadcast();
  Set<String> _previousOnlineSerials = {};
  // Per-serial snapshot of the previous online list, kept around so
  // the offline event can resolve the now-gone adb-serial back to
  // its hardwareSerial (the ro.serialno consumers like
  // TestSessionProvider need for DB lookups). Map key is the
  // adb-serial — same keyspace as _previousOnlineSerials.
  Map<String, Device> _previousOnlineDevicesBySerial = {};

  /// Public stream of per-device offline events. Consumed by
  /// TestSessionProvider (to auto-stop recording + show dialog) and
  /// other listeners that care about device disappearance.
  Stream<DeviceOfflineEvent> get onDeviceOffline => _offlineController.stream;

  List<Device> get devices => _onlineDevices;
  List<SavedDevice> get savedDevices => _savedDevices;
  bool get online => _online;
  String? get activeSerial => _activeSerial;
  DateTime? get lastSuccessfulRefresh => _lastSuccessfulRefresh;
  String? get lastDbError => _lastDbError;

  /// Exposed for backwards compatibility. Prefer GetIt injection in new code.
  AppDatabase get db => _db;

  DeviceProvider({required AppDatabase db}) : _db = db {
    _init();
  }

  Future<void> _init() async {
    // Watch saved devices for changes - auto-updates when DB changes
    _savedDevicesSub =
        db.savedDevicesDao.watchAllSavedDevices().listen((devices) {
      _savedDevices = devices;
      notifyListeners();
    });
  }

  /// Check if a device is currently connected. Accepts either the
  /// stable identity (ro.serialno) or the adb address — the new
  /// DeviceSerialScope carries the stable identity, so this is the
  /// common call shape. For adb-serial callers, the fallback
  /// `d.serial == serial` clause still matches.
  bool isDeviceConnected(String? stableSerial) {
    if (stableSerial == null) return false;
    return _onlineDevices
        .any((d) => d.isOnline && d.matchesIdentity(stableSerial));
  }

  List<Device> transportsFor(String stableSerial) {
    final transports = _onlineDevices
        .where((d) => d.isOnline && d.matchesIdentity(stableSerial))
        .toList();
    transports.sort((a, b) => _transportRank(a).compareTo(_transportRank(b)));
    return transports;
  }

  List<DeviceTransportSummary> transportSummariesFor(String stableSerial) {
    return transportsFor(stableSerial)
        .map((d) => DeviceTransportSummary(
              adbSerial: d.serial,
              type: transportTypeForSerial(d.serial),
              state: d.state,
            ))
        .toList();
  }

  /// Resolve a stable identity to the currently preferred online adb
  /// transport address (USB > Wi-Fi > unknown). Returns `null` if the
  /// device has no live transport — callers should treat that as
  /// "device offline" and refuse to issue adb commands.
  ///
  /// Callers MUST go through `ApiClient.deviceQueryParameters(...)` /
  /// `ApiClient.resolveAdbSerial(...)` instead of calling this
  /// directly. The API boundary exists so screens never need to know
  /// about adb addresses.
  String? onlineAddressFor(String stableSerial) {
    final transports = transportsFor(stableSerial);
    if (transports.isEmpty) return null;
    return transports.first.serial;
  }

  /// The current Wi-Fi transport of [stableSerial], or `null` if the
  /// device is only reachable over USB / offline / unknown.
  ///
  /// Use this for **Wi-Fi-specific** operations (e.g. wireless
  /// disconnect, which must target the `ip:port` transport — calling
  /// `adb disconnect <usb-serial>` fails with "no such device").
  /// For ordinary adb command routing keep using `onlineAddressFor`
  /// (USB preferred).
  ///
  /// When the device exposes multiple Wi-Fi transports (e.g. the
  /// user manually `adb connect <ip:port>` on top of the auto-created
  /// mDNS `adb-<serial>._adb-tls-connect._tcp` one) the **legacy
  /// `ip:port` transport is preferred** — that's the one the user
  /// actually created with `adb connect`, so disconnecting it is the
  /// expected behavior. Disconnecting the mDNS one would just have
  /// the device re-create it a moment later. If only the mDNS one
  /// exists, that one is returned (best effort — disconnecting it
  /// may be transient).
  Device? wifiTransportFor(String stableSerial) {
    final wifiTransports = transportsFor(stableSerial)
        .where(
            (d) => transportTypeForSerial(d.serial) == DeviceTransportType.wifi)
        .toList();
    // Prefer the legacy `ip:port` form (user-initiated) over the
    // mDNS `_tcp` form (system-initiated, re-created on disconnect).
    return wifiTransports
        .where((d) => d.serial.contains(':'))
        .followedBy(wifiTransports.where((d) => !d.serial.contains(':')))
        .firstOrNull;
  }

  /// Whether [stableSerial] currently has a live Wi-Fi transport.
  /// Cheap alternative to `wifiTransportFor(stable) != null` for UI
  /// gating (e.g. show / hide the "disconnect wireless" button).
  ///
  /// Intentionally bypasses [transportsFor] (which sorts by transport
  /// rank and copies the list) — gating is called once per device
  /// node per build, and the only thing we need is a boolean.
  bool hasWifiTransport(String stableSerial) {
    return _onlineDevices.any((d) =>
        d.isOnline &&
        d.matchesIdentity(stableSerial) &&
        transportTypeForSerial(d.serial) == DeviceTransportType.wifi);
  }

  String? modelFor(String stableSerial) {
    final online = transportsFor(stableSerial).firstOrNull;
    if (online != null && online.model.isNotEmpty) return online.model;
    final saved =
        _savedDevices.where((d) => d.serial == stableSerial).firstOrNull;
    if (saved != null && saved.model.isNotEmpty) return saved.model;
    return null;
  }

  String? brandFor(String stableSerial) {
    final online = transportsFor(stableSerial).firstOrNull;
    if (online != null && online.brand.isNotEmpty) return online.brand;
    final saved =
        _savedDevices.where((d) => d.serial == stableSerial).firstOrNull;
    if (saved != null && saved.brand.isNotEmpty) return saved.brand;
    return null;
  }

  String? displayNameFor(String stableSerial) {
    final saved =
        _savedDevices.where((d) => d.serial == stableSerial).firstOrNull;
    if (saved != null && saved.displayName.isNotEmpty) return saved.displayName;
    final model = modelFor(stableSerial);
    if (model != null && model.isNotEmpty) return model;
    final brand = brandFor(stableSerial);
    if (brand != null && brand.isNotEmpty) return brand;
    return stableSerial.isEmpty ? null : stableSerial;
  }

  void select(String? serial) {
    if (_activeSerial == serial) return;
    _activeSerial = serial;
    db.appStatesDao.updateAppState(activeSerial: serial);
    notifyListeners();
  }

  Future<void> _saveDevice({
    required String stableSerial,
    required String adbAddress,
    required Device device,
  }) async {
    await db.savedDevicesDao.upsertSavedDevice(
      serial: stableSerial,
      model: device.model,
      brand: device.brand,
      sdk: device.sdk,
      isConnected: device.isOnline,
      address: adbAddress,
    );
  }

  /// Resolve a stable identity (saved_devices.serial = ro.serialno) for
  /// an online [device] and either reuse the existing row or create a
  /// new one.
  ///
  /// Three cases, in priority order:
  ///
  /// 1. **Exact match on hardwareSerial.** The device's ro.serialno
  ///    already exists as a saved row. Just refresh the address
  ///    (ip:port may have changed on wireless reconnect) and the
  ///    connection state. No PK change needed.
  ///
  /// 2. **Legacy match by adb-serial on the `address` column.** The
  ///    row predates the v8→v9 identity split: its PK is still the
  ///    old `ip:port` (because the device was offline when the
  ///    migration ran, so we couldn't read its ro.serialno). Now
  ///    that the device is back online and the backend reports its
  ///    real ro.serialno, do the PK rename in a single transaction
  ///    (with the test_sessions / scrcpy_options FKs updated
  ///    atomically).
  ///
  /// 3. **No match.** Brand-new device, no history. Insert a new
  ///    row keyed by hardwareSerial (= ro.serialno) with the current
  ///    adb-serial in the `address` column. If the backend failed to
  ///    report ro.serialno (e.g. unauthorized / props unavailable),
  ///    we fall back to the adb-serial as the PK; the next
  ///    reconcile pass once props are readable will fix it up via
  ///    case 2.
  Future<void> _reconcileOnlineDevice(Device device) async {
    if (!device.isOnline) return;

    final hardwareSerial = device.hardwareSerial;
    final adbSerial = device.serial;

    // Case 1: stable identity already on file.
    if (hardwareSerial.isNotEmpty) {
      final existing =
          await db.savedDevicesDao.getSavedDeviceBySerial(hardwareSerial);
      if (existing != null) {
        if (existing.address != adbSerial) {
          await db.savedDevicesDao.updateAddress(hardwareSerial, adbSerial);
        }
        if (!existing.isConnected) {
          await db.savedDevicesDao.updateDeviceConnection(hardwareSerial, true);
        }
        return;
      }
    }

    // Case 2: legacy row keyed by the old adb-serial. The
    // device's `address` column carries that legacy value, and
    // only now (online) do we know the real ro.serialno to
    // upgrade the PK to.
    final legacy = await db.savedDevicesDao.getByAddress(adbSerial);
    if (legacy != null) {
      if (hardwareSerial.isNotEmpty && legacy.serial != hardwareSerial) {
        await db.savedDevicesDao.renamePrimaryKey(
          legacy.serial,
          hardwareSerial,
          newAddress: adbSerial,
        );
      } else {
        // Already the right PK; just refresh the connection bit.
        if (!legacy.isConnected) {
          await db.savedDevicesDao.updateDeviceConnection(legacy.serial, true);
        }
        if (legacy.address != adbSerial) {
          await db.savedDevicesDao.updateAddress(legacy.serial, adbSerial);
        }
      }
      return;
    }

    // Case 3: brand-new device, no match anywhere.
    final newSerial = stableIdentityFor(device);
    await _saveDevice(
      stableSerial: newSerial,
      adbAddress: adbSerial,
      device: device,
    );
  }

  /// Remove a device from saved list. Returns true on success, false if
  /// the underlying DAO threw (e.g. unexpected FK constraint). Callers
  /// should show an error UI on false.
  Future<bool> removeDevice(String serial) async {
    try {
      await db.savedDevicesDao.deleteSavedDevice(serial);
    } catch (e, st) {
      debugPrint('[DeviceProvider] removeDevice($serial) failed: $e');
      debugPrint('[DeviceProvider] STACK: $st');
      return false;
    }

    // Clear selection if this was the active device
    if (_activeSerial == serial) {
      _activeSerial = null;
      try {
        await db.appStatesDao.updateAppState(activeSerial: null);
      } catch (e) {
        // Active-serial reset failing shouldn't block the device
        // removal — log and move on.
        debugPrint('[DeviceProvider] updateAppState failed after remove: $e');
      }
    }

    notifyListeners();
    return true;
  }

  Future<void> refresh(ApiClient api) {
    final running = _refreshing;
    if (running != null) return running;

    final future = _refresh(api);
    _refreshing = future;
    return future.whenComplete(() {
      if (identical(_refreshing, future)) {
        _refreshing = null;
      }
    });
  }

  Future<void> _refresh(ApiClient api) async {
    debugPrint('[DeviceProvider] _refresh start');
    try {
      final ready = await api.isReady();
      debugPrint('[DeviceProvider] isReady() -> $ready');
      if (!ready) {
        debugPrint('[DeviceProvider] isReady returned false -> markOffline');
        _markOffline();
        return;
      }

      debugPrint('[DeviceProvider] calling getDevices()...');
      final devices = await api.getDevices();
      debugPrint('[DeviceProvider] getDevices() -> ${devices.length} devices');

      // Backend is healthy — flip UI to online FIRST so the user sees the
      // connected state even if the persistence step below misbehaves.
      // The previous ordering (set flags → db ops → notify) meant a single
      // DB exception rolled the UI back to "offline" even though the Go
      // backend was responding fine.
      final newOnlineSerials =
          devices.where((d) => d.isOnline).map((d) => d.serial).toSet();

      // Emit per-device offline events for anything that dropped out.
      // _previousOnlineSerials is the *adb-serial* set (per
      // line 281-284) — it carries the ip:port, not the stable
      // identity. For consumers that look up the SavedDevice row
      // (e.g. TestSessionProvider stopping an in-flight recording)
      // we resolve to the ro.serialno via the corresponding online
      // snapshot saved in _previousOnlineDevicesBySerial below.
      for (final stale in _previousOnlineSerials.difference(newOnlineSerials)) {
        final saved = _savedDevices.where((d) => d.serial == stale).firstOrNull;
        final onlineStale = _previousOnlineDevicesBySerial[stale];
        _offlineController.add(DeviceOfflineEvent(
          serial: stale,
          hardwareSerial: onlineStale?.hardwareSerial,
          displayName: saved?.displayName,
        ));
      }
      _previousOnlineSerials = newOnlineSerials;
      _previousOnlineDevicesBySerial = {
        for (final d in devices)
          if (d.isOnline) d.serial: d,
      };

      _onlineDevices = devices;
      _online = true;
      _lastSuccessfulRefresh = DateTime.now();

      // Persistence is best-effort: a DB hiccup must never make the
      // backend look disconnected to the user. Capture the failure into
      // _lastDbError so the UI can show a separate, non-fatal warning.
      //
      // notifyListeners is called ONCE at the end (instead of twice —
      // once before persistence and once after), so the UI rebuilds
      // a single time per refresh. Two rebuilds back-to-back were
      // observed to trip the Windows a11y bridge into
      // UNREACHABLE and crash the app when the savedDevices list
      // changed shape (e.g. first device plugged in → empty list
      // becomes a 1-item list, plus 3 transports reconciling in
      // quick succession). The "DB failure must not roll the UI
      // back to offline" contract is preserved because _online and
      // _onlineDevices are set before the persistence try-block
      // runs and stay set even if persistence throws.
      String? dbError;
      try {
        // Wrap the whole reconcile pass in one transaction so a failure
        // mid-way (e.g. one device's PK-rename throws) rolls back every
        // device's writes instead of leaving the table half-reconciled.
        // Nested transaction() calls inside _reconcileOnlineDevice /
        // updateAllDevicesConnection become savepoints — drift handles
        // those transparently.
        await db.transaction(() async {
          for (final device in devices) {
            if (device.isOnline) {
              await _reconcileOnlineDevice(device);
            }
          }

          await db.savedDevicesDao.updateAllDevicesConnection(
            devices.where((d) => d.isOnline).map(stableIdentityFor).toSet(),
          );

          await db.appStatesDao.updateAppState(
            lastSuccessfulRefresh: _lastSuccessfulRefresh,
          );
        });
      } catch (dbErr, dbSt) {
        debugPrint('[DeviceProvider] db persistence failed: $dbErr');
        debugPrint('[DeviceProvider] STACK: $dbSt');
        dbError = dbErr.toString();
        // intentionally do NOT call _markOffline()
      }

      _savedDevices = await db.savedDevicesDao.getAllSavedDevices();

      // Update the DB error indicator (clear it on success, set on failure)
      // and emit a single rebuild for the whole refresh.
      if (_lastDbError != dbError) {
        _lastDbError = dbError;
      }
      notifyListeners();
    } catch (e, st) {
      debugPrint('[DeviceProvider] _refresh EXCEPTION: $e');
      debugPrint('[DeviceProvider] STACK: $st');
      _markOffline();
    }
  }

  void _markOffline() {
    debugPrint('[DeviceProvider] _markOffline() called');
    _online = false;
    _onlineDevices = [];
    _lastSuccessfulRefresh = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _savedDevicesSub?.cancel();
    _offlineController.close();
    // DB is owned by GetIt — do NOT close it here
    super.dispose();
  }
}
