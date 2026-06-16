// File I/O for session attachments: logs / screenshots / videos /
// per-issue recent-log snapshots. The provider hands us the current session
// and we return a TestSessionArtifact describing what we wrote.
import 'dart:io';

import 'package:adb_tool/models/test_session.dart';
import 'package:adb_tool/providers/test_session/formatter.dart';

class SessionAttachmentStore {
  Future<TestSessionArtifact> writeLogcat(
    TestSession session,
    String content,
    DateTime now,
  ) async {
    final name = '${SessionFormatters.fileDate(now)}.log';
    final file = File('${session.directoryPath}/logs/$name');
    await file.writeAsString(content);
    return _describe(
      kind: TestSessionArtifactKind.log,
      name: name,
      path: file.path,
      now: now,
    );
  }

  Future<TestSessionArtifact> writeScreenshot(
    TestSession session,
    List<int> bytes,
    DateTime now,
  ) async {
    final name = '${SessionFormatters.fileDate(now)}.png';
    final file = File('${session.directoryPath}/screenshots/$name');
    await file.writeAsBytes(bytes);
    return _describe(
      kind: TestSessionArtifactKind.screenshot,
      name: name,
      path: file.path,
      now: now,
    );
  }

  Future<TestSessionArtifact> writeVideo(
    TestSession session,
    List<int> bytes,
    DateTime now,
  ) async {
    final name = '${SessionFormatters.fileDate(now)}.mp4';
    final file = File('${session.directoryPath}/videos/$name');
    await file.writeAsBytes(bytes);
    return _describe(
      kind: TestSessionArtifactKind.video,
      name: name,
      path: file.path,
      now: now,
    );
  }

  /// Snapshots the last ~1000 lines of logcat at the moment an issue is
  /// marked, so the report has fresh context even if the user later clears
  /// the live log buffer.
  Future<TestSessionArtifact> writeIssueRecentLog(
    TestSession session,
    String issueId,
    String content,
    DateTime now,
  ) async {
    final dir = Directory('${session.directoryPath}/issue_logs');
    await dir.create(recursive: true);
    final name =
        '${issueId}_last_1000_${SessionFormatters.fileDate(now)}.log';
    final file = File('${dir.path}/$name');
    await file.writeAsString(content.trimRight());
    return _describe(
      kind: TestSessionArtifactKind.log,
      name: name,
      path: file.path,
      now: now,
    );
  }

  /// Removes the on-disk file for an artifact. Best-effort: missing files
  /// are silently ignored.
  Future<void> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<TestSessionArtifact> _describe({
    required TestSessionArtifactKind kind,
    required String name,
    required String path,
    required DateTime now,
  }) async {
    final file = File(path);
    return TestSessionArtifact(
      id: SessionFormatters.id(now),
      kind: kind,
      name: name,
      path: path,
      createdAt: now,
      size: await file.exists() ? await file.length() : 0,
    );
  }
}
