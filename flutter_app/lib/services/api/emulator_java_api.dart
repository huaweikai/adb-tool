// Java runtime API - status, validation, and download management.
import 'dart:io' show Platform;

import 'package:dio/dio.dart' show FormData, MultipartFile, Options;

import 'package:adb_tool/services/api_client.dart';

mixin EmulatorJavaApi on ApiBase {
  /// Get current Java runtime status.
  Future<JavaRuntimeStatus> getJavaStatus() async {
    final response = await dio.get('/api/emulator/java/status');
    // Fix (code-review B10): envelope guard, same as EmulatorApi.
    if (!isOk(response)) throw Exception(errorMessage(response));
    return JavaRuntimeStatus.fromJson(responseMap(response));
  }

  /// Validate a specific Java path.
  Future<JavaValidationResult> validateJava(String javaPath) async {
    final response = await dio.post(
      '/api/emulator/java/validate',
      data: {'javaPath': javaPath},
    );
    if (!isOk(response)) throw Exception(errorMessage(response));
    return JavaValidationResult.fromJson(responseMap(response));
  }

  /// List all detected Java runtimes plus the persisted selection.
  Future<JavaRuntimeList> listJavaRuntimes() async {
    final response = await dio.get('/api/emulator/java/list');
    if (!isOk(response)) throw Exception(errorMessage(response));
    return JavaRuntimeList.fromJson(responseMap(response));
  }

  /// Persist the user-selected Java runtime.
  Future<JavaSelectionResult> selectJava(String javaPath) async {
    final response = await dio.post(
      '/api/emulator/java/select',
      data: {'javaPath': javaPath},
    );
    if (!isOk(response)) throw Exception(errorMessage(response));
    return JavaSelectionResult.fromJson(responseMap(response));
  }

  /// Start downloading a Java runtime.
  ///
  /// If [url] is empty, the backend fills in a default Adoptium Temurin
  /// build for the requested [version] (defaults to 17). [id] doubles as
  /// the managed-runtime directory name on disk and must be filesystem-safe
  /// (the backend sanitizes it).
  Future<JavaDownloadResult> downloadJava({
    required String id,
    String? url,
    String? version,
    String? sha256,
    String? name,
  }) async {
    final response = await dio.post(
      '/api/emulator/java/download',
      data: {
        'id': id,
        if (url != null && url.isNotEmpty) 'url': url,
        if (version != null) 'version': version,
        if (sha256 != null) 'sha256': sha256,
        if (name != null) 'name': name,
      },
    );
    if (!isOk(response)) throw Exception(errorMessage(response));
    return JavaDownloadResult.fromJson(responseMap(response));
  }

  /// Import a Java runtime from a local `.zip` archive. [localPath] is
  /// uploaded as a multipart/form-data POST (the standard contract for
  /// Go's `r.FormFile`). The backend extracts the archive into the
  /// managed runtime dir keyed by [id].
  ///
  /// Note: we deliberately do NOT use the shared `postLocalFile` octet-
  /// stream helper here. Dio 5.9.2 + `data: file.openRead()` Stream
  /// bodies send with `Transfer-Encoding: chunked`, which on Windows
  /// sometimes aborts mid-upload with WSAECONNABORTED (10053) before
  /// the body fully drains. Multipart has a deterministic Content-Length
  /// and dodges the issue.
  Future<JavaImportResult> importJava({
    required String id,
    required String localPath,
  }) async {
    final form = FormData.fromMap({
      'id': id,
      'file': await MultipartFile.fromFile(
        localPath,
        filename: localPath.split(Platform.pathSeparator).last,
      ),
    });
    final response = await dio.post(
      '/api/emulator/java/import',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    if (!isOk(response)) {
      throw Exception(errorMessage(response));
    }
    return JavaImportResult.fromJson(responseMap(response));
  }

  /// Delete a managed (downloaded / imported) Java runtime by id.
  /// Has no effect on system Java or other detected runtimes.
  Future<void> deleteJava(String id) async {
    final response = await dio.post('/api/emulator/java/delete', data: {'id': id});
    if (!isOk(response)) throw Exception(errorMessage(response));
  }

  /// Get download progress.
  ///
  /// Hits the unified `/api/emulator/download/progress` endpoint. The
  /// legacy `/api/emulator/java/download-progress` route was removed when
  /// progress was consolidated — calling it now hits the webFS fallback
  /// and returns "404 page not found" text, which then explodes in the
  /// JSON decoder.
  Future<JavaDownloadProgress> getDownloadProgress(String id) async {
    final response = await dio.get(
      '/api/emulator/download/progress',
      queryParameters: {'id': id},
    );
    if (!isOk(response)) throw Exception(errorMessage(response));
    return JavaDownloadProgress.fromJson(responseMap(response));
  }

  /// Cancel a download.
  Future<void> cancelDownload(String id) async {
    final response = await dio.post(
      '/api/emulator/download/cancel',
      queryParameters: {'id': id},
    );
    if (!isOk(response)) throw Exception(errorMessage(response));
  }
}

class JavaRuntimeStatus {
  final String status;
  final String? path;
  final String? version;
  final JavaRuntimeInfo? systemJava;
  final List<JavaRuntimeInfo> runtimes;
  final String? selectedPath;
  final bool selectedInvalid;
  final List<JavaRuntimeInfo> embedded;
  final List<DownloadInfo> downloads;
  final List<JavaDownloadOption> defaultDownloads;

  const JavaRuntimeStatus({
    this.status = 'unknown',
    this.path,
    this.version,
    this.systemJava,
    this.runtimes = const [],
    this.selectedPath,
    this.selectedInvalid = false,
    this.embedded = const [],
    this.downloads = const [],
    this.defaultDownloads = const [],
  });

  factory JavaRuntimeStatus.fromJson(Map<String, dynamic> json) {
    return JavaRuntimeStatus(
      status: json['status'] as String? ?? 'unknown',
      path: json['path'] as String?,
      version: json['version'] as String?,
      systemJava: json['systemJava'] != null
          ? JavaRuntimeInfo.fromJson(json['systemJava'] as Map<String, dynamic>)
          : null,
      runtimes: (json['runtimes'] as List<dynamic>?)
              ?.map((e) => JavaRuntimeInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      selectedPath: json['selectedPath'] as String?,
      selectedInvalid: json['selectedInvalid'] as bool? ?? false,
      embedded: (json['embedded'] as List<dynamic>?)
              ?.map((e) => JavaRuntimeInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      downloads: (json['downloads'] as List<dynamic>?)
              ?.map((e) => DownloadInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      defaultDownloads: (json['defaultDownloads'] as List<dynamic>?)
              ?.map((e) =>
                  JavaDownloadOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool get isFound => status == 'found';
  bool get hasJava => systemJava != null;
}

class JavaRuntimeList {
  final List<JavaRuntimeInfo> runtimes;
  final String? selectedPath;

  const JavaRuntimeList({
    this.runtimes = const [],
    this.selectedPath,
  });

  factory JavaRuntimeList.fromJson(Map<String, dynamic> json) {
    return JavaRuntimeList(
      runtimes: (json['runtimes'] as List<dynamic>?)
              ?.map((e) => JavaRuntimeInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      selectedPath: json['selectedPath'] as String?,
    );
  }
}

class JavaSelectionResult {
  final bool selected;
  final String? path;
  final String? version;
  final String? vendor;
  final String? error;

  const JavaSelectionResult({
    this.selected = false,
    this.path,
    this.version,
    this.vendor,
    this.error,
  });

  factory JavaSelectionResult.fromJson(Map<String, dynamic> json) {
    return JavaSelectionResult(
      selected: json['selected'] as bool? ?? false,
      path: json['path'] as String?,
      version: json['version'] as String?,
      vendor: json['vendor'] as String?,
      error: json['error'] as String?,
    );
  }
}

class JavaRuntimeInfo {
  final String id;
  final String path;
  final String? version;
  final String? vendor;
  final String? arch;
  final bool isEmbedded;
  final bool isDownloading;
  final double downloadProgress;

  const JavaRuntimeInfo({
    this.id = '',
    required this.path,
    this.version,
    this.vendor,
    this.arch,
    this.isEmbedded = false,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
  });

  factory JavaRuntimeInfo.fromJson(Map<String, dynamic> json) {
    return JavaRuntimeInfo(
      id: json['id'] as String? ?? '',
      path: json['path'] as String? ?? '',
      version: json['version'] as String?,
      vendor: json['vendor'] as String?,
      arch: json['arch'] as String?,
      isEmbedded: json['isEmbedded'] as bool? ?? false,
      isDownloading: json['isDownloading'] as bool? ?? false,
      downloadProgress: (json['downloadProgress'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class JavaValidationResult {
  final bool valid;
  final String? path;
  final String? version;
  final String? error;

  const JavaValidationResult({
    this.valid = false,
    this.path,
    this.version,
    this.error,
  });

  factory JavaValidationResult.fromJson(Map<String, dynamic> json) {
    return JavaValidationResult(
      valid: json['valid'] as bool? ?? false,
      path: json['path'] as String?,
      version: json['version'] as String?,
      error: json['error'] as String?,
    );
  }
}

class JavaDownloadResult {
  final String id;
  final String status;
  final double progress;
  final String? url;
  final String? error;

  const JavaDownloadResult({
    required this.id,
    this.status = 'pending',
    this.progress = 0.0,
    this.url,
    this.error,
  });

  factory JavaDownloadResult.fromJson(Map<String, dynamic> json) {
    return JavaDownloadResult(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      url: json['url'] as String?,
      error: json['error'] as String?,
    );
  }
}

class JavaDownloadProgress {
  final String id;
  final String status;
  final double progress;
  final int downloaded;
  final int size;
  final String? error;

  const JavaDownloadProgress({
    required this.id,
    this.status = 'unknown',
    this.progress = 0.0,
    this.downloaded = 0,
    this.size = 0,
    this.error,
  });

  factory JavaDownloadProgress.fromJson(Map<String, dynamic> json) {
    return JavaDownloadProgress(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      downloaded: json['downloaded'] as int? ?? 0,
      size: json['size'] as int? ?? 0,
      error: json['error'] as String?,
    );
  }

  bool get isComplete => status == 'completed';
  bool get isDownloading => status == 'downloading';
  bool get isPaused => status == 'paused';
  bool get hasError => status == 'error';
}

class DownloadInfo {
  final String id;
  final String status;
  final double progress;

  const DownloadInfo({
    required this.id,
    this.status = 'unknown',
    this.progress = 0.0,
  });

  factory DownloadInfo.fromJson(Map<String, dynamic> json) {
    return DownloadInfo(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// A pre-resolved default download target that the backend knows how to
/// fetch. The status endpoint exposes one entry per supported Java major
/// version, so the "Download Java" dialog can offer a one-click button
/// without the user having to paste an Adoptium URL.
class JavaDownloadOption {
  final String version;
  final String id;
  final String name;
  final String url;

  const JavaDownloadOption({
    required this.version,
    required this.id,
    required this.name,
    required this.url,
  });

  factory JavaDownloadOption.fromJson(Map<String, dynamic> json) {
    return JavaDownloadOption(
      version: json['version'] as String? ?? '',
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
    );
  }
}

/// Result of importing a Java runtime zip — the resolved path, version and
/// vendor that the backend discovered during validation.
class JavaImportResult {
  final bool success;
  final String id;
  final String path;
  final String? version;
  final String? vendor;
  final String? error;

  const JavaImportResult({
    this.success = false,
    this.id = '',
    this.path = '',
    this.version,
    this.vendor,
    this.error,
  });

  factory JavaImportResult.fromJson(Map<String, dynamic> json) {
    return JavaImportResult(
      success: json['success'] as bool? ?? false,
      id: json['id'] as String? ?? '',
      path: json['path'] as String? ?? '',
      version: json['version'] as String?,
      vendor: json['vendor'] as String?,
      error: json['error'] as String?,
    );
  }
}
