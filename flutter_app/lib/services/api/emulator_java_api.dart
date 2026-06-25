// Java runtime API - status, validation, and download management.
import 'package:adb_tool/services/api_client.dart';

mixin EmulatorJavaApi on ApiBase {
  /// Get current Java runtime status.
  Future<JavaRuntimeStatus> getJavaStatus() async {
    final response = await dio.get('/api/emulator/java/status');
    final data = responseMap(response);
    return JavaRuntimeStatus.fromJson(data);
  }

  /// Validate a specific Java path.
  Future<JavaValidationResult> validateJava(String javaPath) async {
    final response = await dio.post(
      '/api/emulator/java/validate',
      data: {'javaPath': javaPath},
    );
    final data = responseMap(response);
    return JavaValidationResult.fromJson(data);
  }

  /// List all detected Java runtimes plus the persisted selection.
  Future<JavaRuntimeList> listJavaRuntimes() async {
    final response = await dio.get('/api/emulator/java/list');
    final data = responseMap(response);
    return JavaRuntimeList.fromJson(data);
  }

  /// Persist the user-selected Java runtime.
  Future<JavaSelectionResult> selectJava(String javaPath) async {
    final response = await dio.post(
      '/api/emulator/java/select',
      data: {'javaPath': javaPath},
    );
    final data = responseMap(response);
    return JavaSelectionResult.fromJson(data);
  }

  /// Start downloading a Java runtime.
  Future<JavaDownloadResult> downloadJava({
    required String url,
    required String id,
    String? sha256,
    String? name,
  }) async {
    final response = await dio.post(
      '/api/emulator/java/download',
      data: {
        'url': url,
        'id': id,
        if (sha256 != null) 'sha256': sha256,
        if (name != null) 'name': name,
      },
    );
    final data = responseMap(response);
    return JavaDownloadResult.fromJson(data);
  }

  /// Get download progress.
  Future<JavaDownloadProgress> getDownloadProgress(String id) async {
    final response = await dio.get(
      '/api/emulator/java/download-progress',
      queryParameters: {'id': id},
    );
    final data = responseMap(response);
    return JavaDownloadProgress.fromJson(data);
  }

  /// Cancel a download.
  Future<void> cancelDownload(String id) async {
    await dio.post(
      '/api/emulator/java/download-cancel',
      queryParameters: {'id': id},
    );
  }
}

class JavaRuntimeStatus {
  final String status;
  final String? path;
  final String? version;
  final JavaRuntimeInfo? systemJava;
  final List<JavaRuntimeInfo> runtimes;
  final String? selectedPath;
  final List<JavaRuntimeInfo> embedded;
  final List<DownloadInfo> downloads;

  const JavaRuntimeStatus({
    this.status = 'unknown',
    this.path,
    this.version,
    this.systemJava,
    this.runtimes = const [],
    this.selectedPath,
    this.embedded = const [],
    this.downloads = const [],
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
      embedded: (json['embedded'] as List<dynamic>?)
              ?.map((e) => JavaRuntimeInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      downloads: (json['downloads'] as List<dynamic>?)
              ?.map((e) => DownloadInfo.fromJson(e as Map<String, dynamic>))
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
  final String? error;

  const JavaDownloadResult({
    required this.id,
    this.status = 'pending',
    this.progress = 0.0,
    this.error,
  });

  factory JavaDownloadResult.fromJson(Map<String, dynamic> json) {
    return JavaDownloadResult(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
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
