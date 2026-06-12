class AppPackage {
  final String packageName;
  final String sourceDir;

  AppPackage({
    required this.packageName,
    required this.sourceDir,
  });

  factory AppPackage.fromJson(Map<String, dynamic> json) {
    return AppPackage(
      packageName: json['packageName'] ?? '',
      sourceDir: json['sourceDir'] ?? '',
    );
  }

  String get shortName {
    final parts = packageName.split('.');
    return parts.isNotEmpty ? parts.last : packageName;
  }
}
