// App-wide UI state singleton. Stores cross-session UI preferences
// (active device, sidebar expansion, last successful refresh).
import 'package:drift/drift.dart';

/// Single-row table holding the user's UI state. We use an auto-increment
/// id even though there's only ever one row — drift doesn't expose a
/// "singleton table" pattern out of the box, so id+manual upsert is the
/// standard workaround.
class AppStates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get activeSerial => text().nullable()();
  TextColumn get activeKey => text().nullable()();
  TextColumn get expandedSerials => text()(); // JSON array
  DateTimeColumn get lastSuccessfulRefresh => dateTime().nullable()();

  // Emulator toolchain selections (SDK and Java paths)
  TextColumn get selectedSDKPath => text().nullable()();
  TextColumn get selectedJavaPath => text().nullable()();

  // Sidebar UI preferences
  IntColumn get sidebarWidth => integer().withDefault(const Constant(240))();
  BoolColumn get sidebarCollapsed => boolean().withDefault(const Constant(false))();
}
