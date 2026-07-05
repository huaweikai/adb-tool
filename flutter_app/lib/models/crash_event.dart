/// Mirrors the Go [CrashEvent] emitted by the logcat stream manager.
///
/// Reachable over every /ws/logs connection as a `"type": "crash"` frame.
enum CrashKind { crash, anr, native }

const _crashKindMap = <String, CrashKind>{
  'crash': CrashKind.crash,
  'anr': CrashKind.anr,
  'native': CrashKind.native,
};

class CrashEvent {
  final CrashKind kind;
  final String serial;
  final String packageName;
  final String summary;
  final String stackTrace;
  final DateTime detectedAt;

  const CrashEvent({
    required this.kind,
    required this.serial,
    this.packageName = '',
    required this.summary,
    this.stackTrace = '',
    required this.detectedAt,
  });

  factory CrashEvent.fromJson(Map<String, dynamic> json) {
    return CrashEvent(
      kind: _crashKindMap[json['type'] as String?] ?? CrashKind.crash,
      serial: json['serial'] as String? ?? '',
      packageName: json['package'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      stackTrace: json['stackTrace'] as String? ?? '',
      detectedAt: json['detectedAt'] != null
          ? DateTime.tryParse(json['detectedAt'] as String)
              ?.toLocal() ??
              DateTime.now()
          : DateTime.now(),
    );
  }
}
