// Snapshot of the test plan (flow + step list) at session-start time. The
// step statuses get updated as the tester marks each one passed/failed.
// `sortOrder` preserves the original ordering from the configured flows.
import 'package:drift/drift.dart';

import 'test_sessions.dart';
import '../../models/test_session.dart';

@DataClassName('TestSessionPlanItemRow')
class TestSessionPlanItems extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(
        TestSessions,
        #id,
        onDelete: KeyAction.cascade,
      )();
  TextColumn get flowName => text()();
  TextColumn get step => text()();
  IntColumn get status => intEnum<TestSessionPlanStatus>()();
  TextColumn get message => text().withDefault(const Constant(''))();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
