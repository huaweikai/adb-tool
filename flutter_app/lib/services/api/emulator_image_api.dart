// Emulator image API - system image listing and management.
import 'package:adb_tool/services/api_client.dart';

mixin EmulatorImageApi on ApiBase {
  /// Get list of system images.
  Future<List<SystemImage>> getImages() async {
    final response = await dio.get('/api/emulator/images');
    final data = responseMap(response);
    final images = (data['images'] as List<dynamic>?)
            ?.map((e) => SystemImage.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return images;
  }

  /// Get a specific system image.
  Future<SystemImage?> getImage(String id) async {
    final response = await dio.get(
      '/api/emulator/image/get',
      queryParameters: {'id': id},
    );
    final data = responseMap(response);
    if (data['id'] == null) return null;
    return SystemImage.fromJson(data);
  }

  /// Add a new system image for download.
  Future<ImageDownloadResult> addImage({
    required String url,
    required String id,
    required String name,
    String? sha256,
    int? apiLevel,
    String? arch,
    String? variant,
  }) async {
    final response = await dio.post(
      '/api/emulator/image/add',
      data: {
        'url': url,
        'id': id,
        'name': name,
        if (sha256 != null) 'sha256': sha256,
        if (apiLevel != null) 'apiLevel': apiLevel,
        if (arch != null) 'arch': arch,
        if (variant != null) 'variant': variant,
      },
    );
    final data = responseMap(response);
    return ImageDownloadResult.fromJson(data);
  }
}

class SystemImage {
  final String id;
  final String name;
  final int apiLevel;
  final String androidVersion;
  final String arch;
  final String variant;
  final String localPath;
  final Map<String, String> files;
  final int fileSize;
  final SystemImageStatus status;
  final double progress;

  const SystemImage({
    required this.id,
    required this.name,
    required this.apiLevel,
    required this.androidVersion,
    required this.arch,
    required this.variant,
    this.localPath = '',
    this.files = const {},
    this.fileSize = 0,
    this.status = SystemImageStatus.pending,
    this.progress = 0.0,
  });

  factory SystemImage.fromJson(Map<String, dynamic> json) {
    return SystemImage(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      apiLevel: json['apiLevel'] as int? ?? 0,
      androidVersion: json['androidVersion'] as String? ?? '',
      arch: json['arch'] as String? ?? '',
      variant: json['variant'] as String? ?? '',
      localPath: json['localPath'] as String? ?? '',
      files: Map<String, String>.from(json['files'] as Map? ?? {}),
      fileSize: json['fileSize'] as int? ?? 0,
      status: SystemImageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SystemImageStatus.pending,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String get displayName => 'Android $androidVersion (API $apiLevel) - $variant - $arch';

  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  bool get isReady => status == SystemImageStatus.ready;
  bool get isDownloading => status == SystemImageStatus.downloading;
}

enum SystemImageStatus {
  pending,
  downloading,
  ready,
  error,
}

class ImageDownloadResult {
  final String id;
  final String status;
  final double progress;
  final String? error;

  const ImageDownloadResult({
    required this.id,
    this.status = 'pending',
    this.progress = 0.0,
    this.error,
  });

  factory ImageDownloadResult.fromJson(Map<String, dynamic> json) {
    return ImageDownloadResult(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      error: json['error'] as String?,
    );
  }
}
