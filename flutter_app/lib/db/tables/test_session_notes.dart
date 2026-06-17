// Free-form notes attached to a test session.
import 'package:drift/drift.dart';

import 'test_sessions.dart';

@DataClassName('TestSessionNoteRow')
class TestSessionNotes extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(
        TestSessions,
        #id,
        onDelete: KeyAction.cascade,
      )();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get content => text()();

  @override
  Set<Column> get primaryKey => {id};
}
