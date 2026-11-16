import 'dart:io';

import 'package:adb_tool/db/database.dart';
import 'package:adb_tool/models/test_session.dart';
import 'package:adb_tool/providers/test_session/attachment_store.dart';
import 'package:adb_tool/usecases/attach_crash_report.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('preserves original report bytes and links them to the chosen issue',
      () async {
    final directory = await Directory.systemTemp.createTemp('ios-report-test');
    final store = _TestAttachmentStore(directory);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async {
      await db.close();
      await directory.delete(recursive: true);
    });
    final dao = db.testSessionsDao;
    final now = DateTime(2026);
    await db.savedDevicesDao.upsertSavedDevice(
      serial: 'ios:PHONE-A',
      model: 'iPhone',
      brand: 'Apple',
      sdk: '',
      isConnected: true,
    );
    await dao.insertSession(TestSessionsCompanion.insert(
      id: 'session',
      name: 'App test',
      type: 'manual',
      status: TestSessionStatus.running,
      startedAt: now,
      deviceSerial: 'ios:PHONE-A',
    ));
    await dao.insertIssue(TestSessionIssuesCompanion.insert(
      id: 'issue',
      sessionId: 'session',
      createdAt: now,
      title: 'App crashed',
      type: TestSessionIssueType.other,
      severity: TestSessionIssueSeverity.major,
    ));
    final target = (await dao.issueAttachmentTargets()).single;
    expect(target.session.name, 'App test');
    const bytes = [0, 10, 255];
    await attachCrashReport(
      db: db,
      issue: target.issue,
      name: 'App.ips',
      bytes: bytes,
      store: store,
    );

    final artifact = (await dao.findArtifactsForIssue('issue')).single;
    expect(artifact.kind, TestSessionArtifactKind.report);
    expect(artifact.name, 'App.ips');
    expect(artifact.size, bytes.length);
    expect(await (await store.resolve(artifact.path)).readAsBytes(), bytes);
  });
}

class _TestAttachmentStore extends SessionAttachmentStore {
  final Directory root;

  _TestAttachmentStore(this.root);

  @override
  Future<Directory> artifactsDir(String sessionId) =>
      Directory(p.join(root.path, sessionId)).create(recursive: true);

  @override
  Future<File> resolve(String relativePath) async =>
      File(p.join(root.path, relativePath));
}
