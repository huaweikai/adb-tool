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
      size: (json['size'] ?? 0) as int,
      isDir: json['isDir'] ?? false,
      permissions: json['permissions'] ?? '',
      modified: json['modified'] ?? '',
    );
  }

  String get sizeFormatted {
    if (isDir) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
