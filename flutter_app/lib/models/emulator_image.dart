// System image model for Android emulator.
// Represents a downloaded Android system image (e.g., google_apis/arm64-v8a/android-34).
class EmulatorImage {
  final String id;
  final String name;
  final int apiLevel;
  final String arch;
  final String variant;
  final String? sourceUrl;
  final String localPath;
  final Map<String, String> files;
  final int fileSize;
  final String? checksum;
  final EmulatorImageStatus status;
  final double downloadProgress;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  const EmulatorImage({
    required this.id,
    required this.name,
    required this.apiLevel,
    required this.arch,
    this.variant = 'google_apis',
    this.sourceUrl,
    this.localPath = '',
    this.files = const {},
    this.fileSize = 0,
    this.checksum,
    this.status = EmulatorImageStatus.pending,
    this.downloadProgress = 0.0,
    required this.createdAt,
    this.lastUsedAt,
  });

  factory EmulatorImage.fromJson(Map<String, dynamic> json) {
    return EmulatorImage(
      id: json['id'] as String,
      name: json['name'] as String,
      apiLevel: json['apiLevel'] as int,
      arch: json['arch'] as String,
      variant: json['variant'] as String? ?? 'google_apis',
      sourceUrl: json['sourceUrl'] as String?,
      localPath: json['localPath'] as String? ?? '',
      files: Map<String, String>.from(json['files'] as Map? ?? {}),
      fileSize: json['fileSize'] as int? ?? 0,
      checksum: json['checksum'] as String?,
      status: EmulatorImageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => EmulatorImageStatus.pending,
      ),
      downloadProgress: (json['downloadProgress'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.tryParse(json['lastUsedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'apiLevel': apiLevel,
        'arch': arch,
        'variant': variant,
        'sourceUrl': sourceUrl,
        'localPath': localPath,
        'files': files,
        'fileSize': fileSize,
        'checksum': checksum,
        'status': status.name,
        'downloadProgress': downloadProgress,
        'createdAt': createdAt.toIso8601String(),
        'lastUsedAt': lastUsedAt?.toIso8601String(),
      };

  EmulatorImage copyWith({
    String? id,
    String? name,
    int? apiLevel,
    String? arch,
    String? variant,
    String? sourceUrl,
    String? localPath,
    Map<String, String>? files,
    int? fileSize,
    String? checksum,
    EmulatorImageStatus? status,
    double? downloadProgress,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) {
    return EmulatorImage(
      id: id ?? this.id,
      name: name ?? this.name,
      apiLevel: apiLevel ?? this.apiLevel,
      arch: arch ?? this.arch,
      variant: variant ?? this.variant,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      localPath: localPath ?? this.localPath,
      files: files ?? this.files,
      fileSize: fileSize ?? this.fileSize,
      checksum: checksum ?? this.checksum,
      status: status ?? this.status,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  String get displayName =>
      'Android ${apiLevel > 0 ? (apiLevel - 23 + 5) : "?"} (API $apiLevel, $variant, $arch)';

  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  bool get isReady => status == EmulatorImageStatus.ready;
  bool get isDownloading => status == EmulatorImageStatus.downloading;
  bool get hasError => status == EmulatorImageStatus.error;
}

enum EmulatorImageStatus {
  pending,
  downloading,
  ready,
  error,
}
