// Table definition for the saved-devices list. Persists device info across
// app restarts so the sidebar can show offline devices and remember their
// brand/model/sdk.
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

  @override
  Set<Column> get primaryKey => {serial};
}
