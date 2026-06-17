// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test_sessions_dao.dart';

// ignore_for_file: type=lint
mixin _$TestSessionsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SavedDevicesTable get savedDevices => attachedDatabase.savedDevices;
  $TestSessionsTable get testSessions => attachedDatabase.testSessions;
  $TestSessionEventsTable get testSessionEvents =>
      attachedDatabase.testSessionEvents;
  $TestSessionArtifactsTable get testSessionArtifacts =>
      attachedDatabase.testSessionArtifacts;
  $TestSessionNotesTable get testSessionNotes =>
      attachedDatabase.testSessionNotes;
  $TestSessionIssuesTable get testSessionIssues =>
      attachedDatabase.testSessionIssues;
  $TestSessionPlanItemsTable get testSessionPlanItems =>
      attachedDatabase.testSessionPlanItems;
  $TestSessionIssueArtifactsTable get testSessionIssueArtifacts =>
      attachedDatabase.testSessionIssueArtifacts;
  TestSessionsDaoManager get managers => TestSessionsDaoManager(this);
}

class TestSessionsDaoManager {
  final _$TestSessionsDaoMixin _db;
  TestSessionsDaoManager(this._db);
  $$SavedDevicesTableTableManager get savedDevices =>
      $$SavedDevicesTableTableManager(_db.attachedDatabase, _db.savedDevices);
  $$TestSessionsTableTableManager get testSessions =>
      $$TestSessionsTableTableManager(_db.attachedDatabase, _db.testSessions);
  $$TestSessionEventsTableTableManager get testSessionEvents =>
      $$TestSessionEventsTableTableManager(
          _db.attachedDatabase, _db.testSessionEvents);
  $$TestSessionArtifactsTableTableManager get testSessionArtifacts =>
      $$TestSessionArtifactsTableTableManager(
          _db.attachedDatabase, _db.testSessionArtifacts);
  $$TestSessionNotesTableTableManager get testSessionNotes =>
      $$TestSessionNotesTableTableManager(
          _db.attachedDatabase, _db.testSessionNotes);
  $$TestSessionIssuesTableTableManager get testSessionIssues =>
      $$TestSessionIssuesTableTableManager(
          _db.attachedDatabase, _db.testSessionIssues);
  $$TestSessionPlanItemsTableTableManager get testSessionPlanItems =>
      $$TestSessionPlanItemsTableTableManager(
          _db.attachedDatabase, _db.testSessionPlanItems);
  $$TestSessionIssueArtifactsTableTableManager get testSessionIssueArtifacts =>
      $$TestSessionIssueArtifactsTableTableManager(
          _db.attachedDatabase, _db.testSessionIssueArtifacts);
}
