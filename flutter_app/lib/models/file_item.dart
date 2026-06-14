class FileStat {
  final String name;
  final String path;
  final int size;
  final bool isDir;
  final String permissions;
  final String modified;
  final String raw;

  FileStat({
    required this.name,
    required this.path,
    required this.size,
    required this.isDir,
    required this.permissions,
    required this.modified,
    required this.raw,
  });

  factory FileStat.fromJson(Map<String, dynamic> json) {
    return FileStat(
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      isDir: json['isDir'] ?? false,
      permissions: json['permissions'] ?? '',
      modified: json['modified'] ?? '',
      raw: json['raw'] ?? '',
    );
  }

  String get sizeFormatted => formatFileSize(size, isDir: isDir);
}

String formatFileSize(int size, {bool isDir = false}) {
  if (isDir) return '';
  if (size < 1024) return '$size B';
  if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
  if (size < 1024 * 1024 * 1024) {
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

class FileItem {
  final String name;
  final String path;
  final int size;
  final bool isDir;
  final String permissions;
  final String modified;

  FileItem({
    required this.name,
    required this.path,
    required this.size,
    required this.isDir,
    required this.permissions,
    required this.modified,
  });

  factory FileItem.fromJson(Map<String, dynamic> json) {
    return FileItem(
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      isDir: json['isDir'] ?? false,
      permissions: json['permissions'] ?? '',
      modified: json['modified'] ?? '',
    );
  }

  String get sizeFormatted => formatFileSize(size, isDir: isDir);
}
