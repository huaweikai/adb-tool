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

  /// Import a system image from a server-side local path.
  ///
  /// The path may point at either an already-extracted image directory or a
  /// `.zip` archive; the backend figures out which based on the file type.
  /// The server scans the path, registers every image it finds, and returns
  /// the freshly registered entries (one for a single-image dir, possibly
  /// more for a zip containing several API levels or a directory tree of
  /// extracted images).
  Future<List<SystemImage>> importImageFromPath(String path) async {
    final response = await dio.post(
      '/api/emulator/image/import-path',
      data: {'path': path},
    );
    final data = responseMap(response);
    return _parseImportedImages(data);
  }

  /// Import a system image from a local `.zip` file via multipart upload.
  ///
  /// [localPath] is the path on the user's machine; it gets streamed up to
  /// the backend, which extracts and stores it.
  Future<List<SystemImage>> importImageFromZip(String localPath) async {
    final data = await postLocalFile('/api/emulator/image/import', localPath);
    return _parseImportedImages(data);
  }

  /// Parses the import response, which now carries an `images` array plus a
  /// legacy `image` field for backward compatibility. Returns an empty list
  /// if neither field is present.
  List<SystemImage> _parseImportedImages(Map<String, dynamic> data) {
    final list = data['images'] as List<dynamic>?;
    if (list != null) {
      return list
          .whereType<Map>()
          .map((e) => SystemImage.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    final single = data['image'];
    if (single is Map) {
      return [SystemImage.fromJson(Map<String, dynamic>.from(single))];
    }
    return [];
  }

  /// Scan a server-side path for system images and register the discovered
  /// real paths into the persisted registry. Returns the number of images
  /// found. Subsequent listings just validate these stored paths instead of
  /// re-scanning.
  Future<int> scanImagePath(String path) async {
    final response = await dio.post(
      '/api/emulator/image/scan',
      data: {'path': path},
    );
    final data = responseMap(response);
    return (data['found'] as num?)?.toInt() ?? 0;
  }

  /// Get the persisted image-source address book.
  Future<List<ImageSource>> getImageSources() async {
    final response = await dio.get('/api/emulator/image/sources');
    final data = responseMap(response);
    return (data['sources'] as List<dynamic>?)
            ?.map((e) => ImageSource.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
  }

  /// Append a new image-source URL. The backend dedupes by URL and returns the
  /// full updated list.
  Future<List<ImageSource>> addImageSource({
    required String url,
    String? name,
    int? apiLevel,
    String? arch,
    String? variant,
    String? sha256,
  }) async {
    final response = await dio.post(
      '/api/emulator/image/source/add',
      data: {
        'url': url,
        if (name != null) 'name': name,
        if (apiLevel != null) 'apiLevel': apiLevel,
        if (arch != null) 'arch': arch,
        if (variant != null) 'variant': variant,
        if (sha256 != null) 'sha256': sha256,
      },
    );
    final data = responseMap(response);
    return (data['sources'] as List<dynamic>?)
            ?.map((e) => ImageSource.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
  }

  /// Remove an image-source URL from the address book.
  Future<List<ImageSource>> removeImageSource(String url) async {
    final response = await dio.post(
      '/api/emulator/image/source/remove',
      data: {'url': url},
    );
    final data = responseMap(response);
    return (data['sources'] as List<dynamic>?)
            ?.map((e) => ImageSource.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
  }
}

class ImageSource {
  final String url;
  final String name;
  final int apiLevel;
  final String arch;
  final String variant;
  final String sha256;
  final String addedAt;

  const ImageSource({
    required this.url,
    this.name = '',
    this.apiLevel = 0,
    this.arch = '',
    this.variant = '',
    this.sha256 = '',
    this.addedAt = '',
  });

  factory ImageSource.fromJson(Map<String, dynamic> json) {
    return ImageSource(
      url: json['url'] as String? ?? '',
      name: json['name'] as String? ?? '',
      apiLevel: json['apiLevel'] as int? ?? 0,
      arch: json['arch'] as String? ?? '',
      variant: json['variant'] as String? ?? '',
      sha256: json['sha256'] as String? ?? '',
      addedAt: json['addedAt'] as String? ?? '',
    );
  }

  String get displayName => name.isNotEmpty ? name : url;
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
