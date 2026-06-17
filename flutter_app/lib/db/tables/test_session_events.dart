// Timeline events for a test session. Append-only — events are never edited
// or deleted, just inserted. Cascades on parent session delete.
import 'package:drift/drift.dart';

import 'test_sessions.dart';
import '../../models/test_session.dart';

@DataClassName('TestSessionEventRow')
class TestSessionEvents extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(
        TestSessions,
        #id,
        onDelete: KeyAction.cascade,
      )();
  IntColumn get type => intEnum<TestSessionEventType>()();
  DateTimeColumn get time => dateTime()();
  TextColumn get title => text()();
  TextColumn get detail => text().withDefault(const Constant(''))();
  TextColumn get filePath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
