// Test session master table. One row per session, regardless of how many
// events / artifacts / notes it accumulates.
//
// Status semantics:
//   running    - in progress, accepts new artifacts/notes
//   finished   - tester explicitly finished it (UI button or API call)
//   abandoned  - device went offline and tester chose to force-end it,
//                or the session was forcibly closed (e.g. quit-while-running)
//
// Indexes (created in onCreate / onUpgrade migration, not here):
//   idx_one_running_per_device  — UNIQUE WHERE status=0
//   idx_sessions_device_started — (device_serial, started_at DESC)
import 'package:drift/drift.dart';

import 'saved_devices.dart';
import '../../models/test_session.dart';

/// Master record for one test session. The device_serial FK cascades nothing
/// — if the device is removed from SavedDevices we keep the session
/// (referential integrity is enforced by the FK constraint, but a deleted
/// device row will be blocked while any session still references it).
@DataClassName('TestSessionRow')
class TestSessions extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  IntColumn get status => intEnum<TestSessionStatus>()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  TextColumn get deviceSerial =>
      text().references(SavedDevices, #serial)();
  TextColumn get deviceModel => text().withDefault(const Constant(''))();
  TextColumn get deviceBrand => text().withDefault(const Constant(''))();
  TextColumn get deviceSdk => text().withDefault(const Constant(''))();

  TextColumn get packageName => text().withDefault(const Constant(''))();
  TextColumn get note => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}
