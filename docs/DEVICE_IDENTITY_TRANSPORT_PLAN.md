# Device identity and transport plan

## Problem

Wireless ADB exposes the connection address as the adb serial, for example `192.168.1.5:42187`. When the IP or port changes, `adb devices -l` reports a different adb serial even though the physical phone is the same. A phone can also be connected by USB and Wi-Fi at the same time, in which case ADB correctly exposes two transports for one physical device.

The app should not treat every adb transport as a separate product-level device. User-facing state such as saved devices, sessions, screenshots, scrcpy options, file browser state, and logcat state should belong to the physical device, not to a transient adb address.

## Core model

Use two distinct concepts everywhere:

- Stable identity: the physical device identity, preferably `ro.serialno`. This is the key used by UI state, database records, sessions, and per-device configuration.
- Transport address: the current adb target, such as USB adb serial or wireless `ip:port`. This is only needed when issuing adb commands.

Current naming target:

- `Device.serial`: adb transport address from the backend `adb devices` list.
- `Device.hardwareSerial`: stable identity from `ro.serialno`.
- `SavedDevice.serial`: stable identity.
- `SavedDevice.address`: preferred or last-known adb transport address, not the full list of transports.
- `DeviceSerialScope.serial`: stable identity.

## Short-term plan

### 1. Keep one saved row per physical device

When an online backend device arrives:

1. Let `adbAddress = device.serial`.
2. Let `stableSerial = device.hardwareSerial` when non-empty, otherwise fallback to `adbAddress`.
3. If a saved row already exists for `stableSerial`, update metadata, connection state, and current address.
4. If a legacy row exists for `adbAddress`, rename the primary key to `stableSerial` once `hardwareSerial` is available.
5. Otherwise insert one row with `serial = stableSerial` and `address = adbAddress`.

Do not keep separate long-lived rows for `ip:port` and `ro.serialno`. An adb-address row is only a temporary legacy/fallback row until the stable identity becomes known.

### 2. Group simultaneous USB and Wi-Fi transports by stable identity

The online list may contain both:

- USB transport: `R5CT70AHPDR`
- Wi-Fi transport: `192.168.1.5:42187`

If both report the same `hardwareSerial`, the UI should display one physical device with multiple connection channels:

- USB
- Wi-Fi
- USB + Wi-Fi

The transport list should be derived from the current online devices, not from `saved_devices.address`.

### 3. Resolve adb address only at the API boundary

Screens, providers, mixins, and persisted state should pass stable serials. `ApiClient` should resolve the stable serial to the current preferred online adb address before calling backend endpoints that execute adb commands.

Device operations should fail early with a local offline error if no online transport exists. They should not fallback to a stale saved `address` for adb commands.

### 4. Use deterministic transport preference

When multiple online transports exist for one stable identity:

1. Prefer USB.
2. Then prefer Wi-Fi.
3. Then use the first online unknown transport.

This is the default policy because USB is usually faster and more stable. The chosen adb address may be stored into `saved_devices.address` as the current preferred or last-used address, but this field should not be interpreted as the full list of active transports.

### 5. Clean up UI serial leakage

Remove screen-level `_adbSerial` getters where possible. Screens should use `DeviceSerialScope.serial` as the stable serial and let `ApiClient` or a domain provider resolve transports.

Special attention:

- Screen mirror state must hide backend adb serial comparisons inside `MirrorStateProvider`.
- Logcat state should use stable serial as the state key.
- Capture mixins should pass stable serial to `ApiClient` and use the same stable serial for DB/session keys.

## Long-term plan

### 1. Introduce explicit transport models

Add a frontend model such as:

```dart
class DeviceTransport {
  final String adbSerial;
  final DeviceTransportType type;
  final String state;
  final DateTime? lastSeenAt;
}
```

And a physical-device view model such as:

```dart
class DeviceView {
  final String stableSerial;
  final String displayName;
  final List<DeviceTransport> transports;
  final String? preferredAdbSerial;
}
```

The left device list should render `DeviceView`, not raw backend `Device` rows.

### 2. Add optional transport preference

If users need manual control, add a preference such as:

- preferred transport type: USB / Wi-Fi / automatic
- or preferred adb serial when currently online

Automatic mode should remain the default.

### 3. Add transport history only if needed

A future `device_transports` table can track connection history:

- stable device serial
- adb serial/address
- transport type
- first seen time
- last seen time
- last state

This is not required for the current bugfix. The immediate problem is identity/address mixing, not lack of historical transport storage.

### 4. Improve backend transport metadata

Short term, Wi-Fi can be identified by `serial.contains(':')`. Long term, the backend can parse more detail from `adb devices -l`, such as `usb:` or `transport_id`, and return a transport type explicitly.

## Acceptance criteria

- Wireless reconnect with a changed `ip:port` updates one saved device row instead of creating a new device.
- USB and Wi-Fi connected at the same time display as one physical device with two transports.
- ADB operations from screens pass stable serials and resolve to the preferred online transport internally.
- When both USB and Wi-Fi are online, ADB operations prefer USB by default.
- Offline devices do not issue adb commands through stale saved addresses.
- Existing session and scrcpy references continue to follow the stable serial after legacy rows are renamed.

## Status (v2 — screen-side migration landed)

The short-term plan (sections 1–5) is **shipped**. The long-term
plan (sections 1–4) is intentionally not implemented yet — it is
the next round of work, not a prerequisite for the v2 migration.

Concretely the codebase now satisfies the contract the design
intended:

- `DeviceProvider.onlineAddressFor(stable)` is the only public
  adb-resolution entry point. There is no `addressFor` /
  `AdbSerialResolution` extension anymore — screens literally
  cannot ask for the adb address.
- `ApiClient.deviceQueryParameters(stable, …)` /
  `deviceBodyParameters(stable, …)` is the only path from screen
  to backend; it resolves stable → preferred adb-serial and
  throws `DeviceOfflineException` if the device isn't online.
- `LogcatStateProvider` keys its per-device state by stable
  identity; a wireless port change preserves the user's filter,
  scroll position, and pause state.
- `LogStreamService` keys WebSocket channels by stable identity
  and re-resolves the live adb address on every (re)connect.
- `MirrorStateProvider` tracks the stable identity it was started
  against and exposes an `isOurs(stable)` predicate so the screen
  can render the Start/Stop button without ever seeing an
  adb-serial.
- The home-screen `_disconnect` action (the one place the user
  must point at a specific adb transport) calls
  `onlineAddressFor(stable)` directly — it is the lone exception
  to the "stable in, no adb out" rule, and that's intentional.

Regression coverage:

- `saved_devices_reconcile_test.dart` — three reconcile cases
  (wireless port change, legacy PK upgrade, brand-new device).
- `device_transport_resolution_test.dart` — USB/Wi-Fi transport
  grouping + USB preference + the v8→v9 stale-address guard.
  The "wireless port change" test added in v2 is the smoking gun:
  it asserts the API transparently picks up the new adb-serial
  when DeviceProvider sees a new adb address under the same
  hardwareSerial.
