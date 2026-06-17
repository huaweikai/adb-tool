// Artifacts attached to a test session: screenshots, screen recordings,
// logcat snapshots, generated reports.
//
// `path` stores a *relative* path under
// `<AppSupport>/.session_artifacts/<sessionId>/`. The base directory is
// resolved at runtime — never persist absolute paths here.
import 'package:drift/drift.dart';

import 'test_sessions.dart';
import '../../models/test_session.dart';

@DataClassName('TestSessionArtifactRow')
class TestSessionArtifacts extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(
        TestSessions,
        #id,
        onDelete: KeyAction.cascade,
      )();
  IntColumn get kind => intEnum<TestSessionArtifactKind>()();
  TextColumn get name => text()();
  TextColumn get path => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get size => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
