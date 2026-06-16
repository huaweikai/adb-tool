// Disk I/O for the session state file (session.json) and the data root.
import 'dart:convert';
import 'dart:io';

import 'package:adb_tool/models/test_session.dart';

class SessionRepository {
  final Directory? baseDirectory;
  SessionRepository(this.baseDirectory);

  Future<Directory> rootDirectory() async {
    if (baseDirectory != null) return baseDirectory!;
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    final dir = Directory('$home/ADBToolData');
    await dir.create(recursive: true);
    return dir;
  }

  /// Writes the current session state to `<sessionDir>/session.json`.
  Future<void> persist(TestSession session) async {
    final file = File('${session.directoryPath}/session.json');
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(session.toJson()));
  }

  /// Scans [ADBToolData/sessions/] and returns parsed [TestSession] instances
  /// sorted by start time (newest first).
  Future<List<TestSession>> scanHistory() async {
    final root = await rootDirectory();
    final sessionsDir = Directory('${root.path}/sessions');
    if (!await sessionsDir.exists()) return [];
    final results = <TestSession>[];
    await for (final entity in sessionsDir.list()) {
      if (entity is! Directory) continue;
      final jsonFile = File('${entity.path}/session.json');
      if (!await jsonFile.exists()) continue;
      try {
        final json =
            jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;
        results.add(TestSession.fromJson(json));
      } catch (_) {
        // Skip corrupted / unreadable session directories.
      }
    }
    results.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return results;
  }

  /// Loads a single historical session from disk by ID.
  Future<TestSession> loadHistorical(String sessionId) async {
    final root = await rootDirectory();
    final sessionDir = Directory('${root.path}/sessions/$sessionId');
    if (!await sessionDir.exists()) {
      throw Exception('日志文件不存在: $sessionDir');
    }
    final jsonFile = File('${sessionDir.path}/session.json');
    if (!await jsonFile.exists()) {
      throw Exception('日志文件不存在: $jsonFile');
    }
    final json =
        jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;
    return TestSession.fromJson(json);
  }

  /// Removes the directory for a session (recursively — wipes all artifacts).
  Future<void> deleteSessionDir(String sessionId) async {
    final root = await rootDirectory();
    final sessionDir = Directory('${root.path}/sessions/$sessionId');
    if (await sessionDir.exists()) {
      await sessionDir.delete(recursive: true);
    }
  }
}
