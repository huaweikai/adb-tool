// Many-to-many join: which artifacts are attached to which issue. Cascades
// on either parent (issue or artifact) delete. Composite primary key means
// the same (issue, artifact) pair cannot be linked twice.
import 'package:drift/drift.dart';

import 'test_session_artifacts.dart';
import 'test_session_issues.dart';

@DataClassName('TestSessionIssueArtifactRow')
class TestSessionIssueArtifacts extends Table {
  TextColumn get issueId => text().references(
        TestSessionIssues,
        #id,
        onDelete: KeyAction.cascade,
      )();
  TextColumn get artifactId => text().references(
        TestSessionArtifacts,
        #id,
        onDelete: KeyAction.cascade,
      )();

  @override
  Set<Column> get primaryKey => {issueId, artifactId};
}
