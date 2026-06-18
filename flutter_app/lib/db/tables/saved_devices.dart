// Table definition for the saved-devices list. Persists device info across
// app restarts so the sidebar can show offline devices and remember their
// brand/model/sdk.
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
/// key (it's unique per device). Connection status is updated on every poll
/// of the backend.
class SavedDevices extends Table {
  TextColumn get serial => text()();
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
