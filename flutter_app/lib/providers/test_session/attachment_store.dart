// Pure file I/O for session attachments: writes PNG/MP4/log files under
// the session's artifact directory and returns a relative path that the
// caller persists to the database.
//
// The DB write is NOT done here — the provider is responsible for
// inserting the TestSessionArtifactRow inside a transaction alongside
// the file write.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'formatter.dart';

class SessionAttachmentStore {
  /// Resolve the session's artifact base directory, creating it if missing.
  Future<Directory> artifactsDir(String sessionId) async {
    final appSupport = await getApplicationSupportDirectory();
    final dir = Directory(
      p.join(appSupport.path, '.session_artifacts', sessionId),
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Absolute filesystem path for a kind/subdir entry, e.g.
  /// `.../screenshots/20260617_205830.png`. Subdirs are created.
  Future<File> _fileFor(
    String sessionId,
    String subdir,
    String fileName,
  ) async {
    final base = await artifactsDir(sessionId);
    final sub = Directory(p.join(base.path, subdir));
    if (!await sub.exists()) await sub.create(recursive: true);
    return File(p.join(sub.path, fileName));
  }

  /// Path stored in the DB is relative to the .session_artifacts root, so
  /// moving the app-support directory (or the user changing the bundle
  /// id) doesn't break existing references. The form is
  /// `<sessionId>/<subdir>/<fileName>`.
  String _relativePath(String sessionId, String subdir, String fileName) {
    return p.join(sessionId, subdir, fileName);
  }

  /// Write a PNG screenshot. Returns the relative path (what to store in
  /// the DB's `path` column).
  Future<TestSessionArtifactDescriptor> writeScreenshot({
    required String sessionId,
    required List<int> bytes,
    required DateTime now,
  }) async {
    final name = '${SessionFormatters.fileDate(now)}.png';
    final file = await _fileFor(sessionId, 'screenshots', name);
    await file.writeAsBytes(bytes);
    return TestSessionArtifactDescriptor(
      name: name,
      relativePath: _relativePath(sessionId, 'screenshots', name),
      size: bytes.length,
    );
  }

  /// Write an MP4 video. Returns the relative path.
  Future<TestSessionArtifactDescriptor> writeVideo({
    required String sessionId,
    required List<int> bytes,
    required DateTime now,
  }) async {
    final name = '${SessionFormatters.fileDate(now)}.mp4';
    final file = await _fileFor(sessionId, 'videos', name);
    await file.writeAsBytes(bytes);
    return TestSessionArtifactDescriptor(
      name: name,
      relativePath: _relativePath(sessionId, 'videos', name),
      size: bytes.length,
    );
  }

  /// Write a raw text logcat snapshot. Returns the relative path.
  Future<TestSessionArtifactDescriptor> writeLogcat({
    required String sessionId,
    required String content,
    required DateTime now,
  }) async {
    final name = '${SessionFormatters.fileDate(now)}.log';
    final file = await _fileFor(sessionId, 'logs', name);
    await file.writeAsString(content);
    return TestSessionArtifactDescriptor(
      name: name,
      relativePath: _relativePath(sessionId, 'logs', name),
      size: content.length,
    );
  }

  /// Snapshot of the last N logcat lines at the moment an issue is marked.
  Future<TestSessionArtifactDescriptor> writeIssueRecentLog({
    required String sessionId,
    required String issueId,
    required String content,
    required DateTime now,
  }) async {
    final name = '${issueId}_last_1000_${SessionFormatters.fileDate(now)}.log';
    final file = await _fileFor(sessionId, 'issue_logs', name);
    await file.writeAsString(content.trimRight());
    return TestSessionArtifactDescriptor(
      name: name,
      relativePath: _relativePath(sessionId, 'issue_logs', name),
      size: content.length,
    );
  }

  /// Resolve a stored relative path back to an absolute File handle.
  Future<File> resolve(String relativePath) async {
    final appSupport = await getApplicationSupportDirectory();
    return File(p.join(appSupport.path, '.session_artifacts', relativePath));
  }

  /// Delete one file. Best-effort: missing files are silently ignored.
  Future<void> deleteFile(String relativePath) async {
    try {
      final file = await resolve(relativePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Recursively remove the entire artifact directory for a session.
  /// Called when the session is hard-deleted.
  Future<void> deleteSessionDir(String sessionId) async {
    try {
      final base = await artifactsDir(sessionId);
      if (await base.exists()) await base.delete(recursive: true);
    } catch (_) {}
  }
}

/// What the attachment store returns after a successful write. The
/// provider wraps this into a `TestSessionArtifactsCompanion.insert(...)`
/// and inserts it inside the same transaction.
class TestSessionArtifactDescriptor {
  final String name;
  final String relativePath;
  final int size;

  const TestSessionArtifactDescriptor({
    required this.name,
    required this.relativePath,
    required this.size,
  });
}
