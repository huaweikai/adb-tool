// Bug reports / issues raised during a test session. Each row captures
// reproduction info (steps / expected / actual) and links to related
// artifacts via the TestSessionIssueArtifacts m:n table.
import 'package:drift/drift.dart';

import 'test_sessions.dart';
import '../../models/test_session.dart';

@DataClassName('TestSessionIssueRow')
class TestSessionIssues extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(
        TestSessions,
        #id,
        onDelete: KeyAction.cascade,
      )();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get title => text()();
  IntColumn get type => intEnum<TestSessionIssueType>()();
  IntColumn get severity => intEnum<TestSessionIssueSeverity>()();
  TextColumn get steps => text().withDefault(const Constant(''))();
  TextColumn get expected => text().withDefault(const Constant(''))();
  TextColumn get actual => text().withDefault(const Constant(''))();
  TextColumn get note => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}
