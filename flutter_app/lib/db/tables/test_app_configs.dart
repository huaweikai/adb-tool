import 'package:drift/drift.dart';

/// One row per test app config. Nested collections (logcat, deep links,
/// file paths, test texts, test flows) are stored as JSON-encoded TEXT
/// columns — this matches the shape of `TestAppConfig` 1:1 and the data
/// is small (a handful of apps, a dozen entries per list at most), so
/// paying the cost of normalized child tables would be more code than
/// the saved join queries are worth.
///
/// `is_checked` is the "current" config the rest of the app reads from
/// — at most one row has it set at any time, the rest are false. Kept
/// as a column on the row itself (not a singleton settings table) so
/// copy / delete / import don't need a second table to keep in sync.
@DataClassName('TestAppConfigRow')
class TestAppConfigs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get appName => text()();
  TextColumn get packageName => text()();
  TextColumn get appType => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get logcatJson => text()();
  TextColumn get deepLinksJson => text()();
  TextColumn get filePathsJson => text()();
  TextColumn get testTextsJson => text()();
  TextColumn get testFlowsJson => text()();
  BoolColumn get isChecked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
