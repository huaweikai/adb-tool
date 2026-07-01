// Table definition for the saved-devices list. Persists device info across
// app restarts so the sidebar can show offline devices and remember their
// brand/model/sdk.
//
// Identity model (since v9):
//   - `serial` is the **stable identity** — the device's hardware
//     serial (ro.serialno). It survives reconnects, ip:port churn on
//     wireless, and is what the test_sessions / scrcpy_options FKs
//     reference.
//   - `address` is the **transient adb address** — the `ip:port` for
//     wireless, empty for USB. The backend's `GET /api/devices` returns
//     this as the `serial` field (because adb itself identifies the
//     device by it). It gets updated on every reconnect.
//
// In-flight screen recording state lives on the same row (one device has at
// most one active recording). Storing the state on the device row means:
//   - the file-browser and test-session screens can subscribe to a single
//     device-row stream and stay in sync without an in-memory service
//   - app restarts, navigation, and process boundaries all see the same
//     "is anyone recording on this device?" answer
//   - "is anyone recording" is a device-level question, not a session
//     one, so hanging the state off the device (not test_sessions) is
//     the right shape
import 'package:drift/drift.dart';

/// Devices we've ever seen connected to ADB. `serial` is the natural primary
/// key (the device's ro.serialno, stable across reconnects). The current adb
/// address lives in [address] and is updated on every reconnect. Connection
/// status is updated on every poll of the backend.
class SavedDevices extends Table {
  /// Stable hardware identity (`ro.serialno`). Never changes for a given
  /// physical device. PK — referenced by test_sessions.deviceSerial and
  /// scrcpy_options.serial. Set to the device's hardware serial on
  /// first online sighting; on legacy rows from before the v8→v9
  /// migration this is the old adb-serial (typically `ip:port` for
  /// wireless, the same as `ro.serialno` for USB) until the device
  /// comes back online and the row is upgraded.
  TextColumn get serial => text()();

  /// Current adb address — what backend's `GET /api/devices` returns
  /// as the `serial` field, and what `adb -s <address>` accepts.
  /// Empty string for USB (the adb address equals the hardware
  /// serial there, so callers fall back to the PK). Updated on every
  /// online sighting; stale after the device disconnects.
  TextColumn get address => text().nullable()();

  TextColumn get model => text()();
  TextColumn get brand => text()();
  TextColumn get sdk => text()();
  BoolColumn get isConnected => boolean()();
  DateTimeColumn get firstSeenAt => dateTime()();
  DateTimeColumn get lastSeenAt => dateTime().nullable()();

  /// Who owns the in-flight screen recording on this device. One of
  /// `null` (idle) / `'file_browser'` / `'test_session'`. Set when a
  /// recording starts, cleared when it ends (success, failure, or
  /// abandoned).
  TextColumn get recordingOwner => text().nullable()();

  /// Wall-clock time the in-flight recording started. `null` when
  /// [recordingOwner] is null. Used by the UI to compute elapsed
  /// seconds = `DateTime.now() - recordingStartedAt` without needing
  /// a per-second DB write.
  IntColumn get recordingStartedAt => integer().nullable()();

  /// True while the recording has been stopped on the adb side and
  /// the bytes are being pulled / written to disk. While true, the
  /// "停止" button is disabled and shows a "保存中..." spinner.
  BoolColumn get recordingIsSaving =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {serial};
}
