// Emulator instance (AVD) model.
// Represents a created emulator instance based on a system image.
class EmulatorInstance {
  final String id;
  final String imageId;
  final String avdName;
  final String avdPath;
  final EmulatorInstanceConfig config;
  final EmulatorInstanceStatus status;
  final int consolePort;
  final int adbPort;
  final int? pid;
  final String serial;
  final String? snapshotId;
  final DateTime createdAt;
  final DateTime? lastStartedAt;
  // Live boot progress fields, populated by the backend while the
  // instance is in StatusStarting / StatusRunning. Empty / 0 outside
  // those states.
  final String bootStage;
  final int bootProgress;
  final String bootMessage;

  const EmulatorInstance({
    required this.id,
    required this.imageId,
    required this.avdName,
    this.avdPath = '',
    this.config = const EmulatorInstanceConfig(),
    this.status = EmulatorInstanceStatus.stopped,
    this.consolePort = 5554,
    this.adbPort = 5555,
    this.pid,
    this.serial = '',
    this.snapshotId,
    required this.createdAt,
    this.lastStartedAt,
    this.bootStage = '',
    this.bootProgress = 0,
    this.bootMessage = '',
  });

  factory EmulatorInstance.fromJson(Map<String, dynamic> json) {
    return EmulatorInstance(
      id: json['id'] as String? ?? '',
      imageId: json['imageId'] as String? ?? '',
      avdName: (json['avdName'] ?? json['name']) as String? ?? '',
      avdPath: json['avdPath'] as String? ?? '',
      config: EmulatorInstanceConfig.fromJson(
          json['config'] as Map<String, dynamic>? ?? {}),
      status: EmulatorInstanceStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => EmulatorInstanceStatus.stopped,
      ),
      consolePort: json['consolePort'] as int? ?? 5554,
      adbPort: json['adbPort'] as int? ?? 5555,
      pid: json['pid'] as int?,
      serial: json['serial'] as String? ?? '',
      snapshotId: json['snapshotId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      lastStartedAt: json['lastStartedAt'] != null
          ? DateTime.tryParse(json['lastStartedAt'] as String)
          : null,
      bootStage: json['bootStage'] as String? ?? '',
      bootProgress: json['bootProgress'] as int? ?? 0,
      bootMessage: json['bootMessage'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'imageId': imageId,
        'avdName': avdName,
        'avdPath': avdPath,
        'config': config.toJson(),
        'status': status.name,
        'consolePort': consolePort,
        'adbPort': adbPort,
        'pid': pid,
        'serial': serial,
        'snapshotId': snapshotId,
        'createdAt': createdAt.toIso8601String(),
        'lastStartedAt': lastStartedAt?.toIso8601String(),
        'bootStage': bootStage,
        'bootProgress': bootProgress,
        'bootMessage': bootMessage,
      };

  EmulatorInstance copyWith({
    String? id,
    String? imageId,
    String? avdName,
    String? avdPath,
    EmulatorInstanceConfig? config,
    EmulatorInstanceStatus? status,
    int? consolePort,
    int? adbPort,
    int? pid,
    String? serial,
    String? snapshotId,
    DateTime? createdAt,
    DateTime? lastStartedAt,
    String? bootStage,
    int? bootProgress,
    String? bootMessage,
  }) {
    return EmulatorInstance(
      id: id ?? this.id,
      imageId: imageId ?? this.imageId,
      avdName: avdName ?? this.avdName,
      avdPath: avdPath ?? this.avdPath,
      config: config ?? this.config,
      status: status ?? this.status,
      consolePort: consolePort ?? this.consolePort,
      adbPort: adbPort ?? this.adbPort,
      pid: pid ?? this.pid,
      serial: serial ?? this.serial,
      snapshotId: snapshotId ?? this.snapshotId,
      createdAt: createdAt ?? this.createdAt,
      lastStartedAt: lastStartedAt ?? this.lastStartedAt,
      bootStage: bootStage ?? this.bootStage,
      bootProgress: bootProgress ?? this.bootProgress,
      bootMessage: bootMessage ?? this.bootMessage,
    );
  }

  bool get isRunning => status == EmulatorInstanceStatus.running;
  bool get isStopped => status == EmulatorInstanceStatus.stopped;
  bool get isStarting => status == EmulatorInstanceStatus.starting;
}

enum EmulatorInstanceStatus {
  stopped,
  starting,
  running,
  error,
}

class EmulatorInstanceConfig {
  final int cores;
  final int memoryMb;
  final int width;
  final int height;
  final int density;
  final String? sdcardSize;
  final String gpuMode;

  const EmulatorInstanceConfig({
    this.cores = 4,
    this.memoryMb = 4096,
    this.width = 1080,
    this.height = 1920,
    this.density = 420,
    this.sdcardSize,
    this.gpuMode = 'auto',
  });

  factory EmulatorInstanceConfig.fromJson(Map<String, dynamic> json) {
    return EmulatorInstanceConfig(
      cores: json['cores'] as int? ?? 4,
      memoryMb: json['memoryMb'] as int? ?? 4096,
      width: json['width'] as int? ?? 1080,
      height: json['height'] as int? ?? 1920,
      density: json['density'] as int? ?? 420,
      sdcardSize: json['sdcardSize'] as String?,
      gpuMode: json['gpuMode'] as String? ?? 'auto',
    );
  }

  Map<String, dynamic> toJson() => {
        'cores': cores,
        'memoryMb': memoryMb,
        'width': width,
        'height': height,
        'density': density,
        'sdcardSize': sdcardSize,
        'gpuMode': gpuMode,
      };

  EmulatorInstanceConfig copyWith({
    int? cores,
    int? memoryMb,
    int? width,
    int? height,
    int? density,
    String? sdcardSize,
    String? gpuMode,
  }) {
    return EmulatorInstanceConfig(
      cores: cores ?? this.cores,
      memoryMb: memoryMb ?? this.memoryMb,
      width: width ?? this.width,
      height: height ?? this.height,
      density: density ?? this.density,
      sdcardSize: sdcardSize ?? this.sdcardSize,
      gpuMode: gpuMode ?? this.gpuMode,
    );
  }
}
