import 'package:drift/drift.dart';

import '../db/database.dart';
import '../models/test_session.dart';
import '../providers/test_session/attachment_store.dart';
import '../providers/test_session/formatter.dart';

Future<void> attachCrashReport({
  required AppDatabase db,
  required TestSessionIssueRow issue,
  required String name,
  required List<int> bytes,
  SessionAttachmentStore? store,
}) async {
  final attachments = store ?? SessionAttachmentStore();
  final now = DateTime.now();
  final id = SessionFormatters.id(now);
  final report = await attachments.writeReport(
    sessionId: issue.sessionId,
    artifactId: id,
    name: name,
    bytes: bytes,
  );
  try {
    await db.testSessionsDao.insertIssueReport(
      issue.id,
      issue.sessionId,
      TestSessionArtifactsCompanion.insert(
        id: id,
        sessionId: issue.sessionId,
        kind: TestSessionArtifactKind.report,
        name: report.name,
        path: report.relativePath,
        size: Value(report.size),
        createdAt: now,
      ),
    );
  } catch (_) {
    await attachments.deleteFile(report.relativePath);
    rethrow;
  }
}
