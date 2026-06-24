// Emulator engine configuration model.
// Stores the user's configured paths for Android SDK emulator tools.
class EmulatorEngineConfig {
  final String id;
  final String? androidHome;
  final String emulatorPath;
  final String? avdmanagerPath;
  final String? sdkmanagerPath;
  final String? javaPath;
  final String? javaVersion;
  final String? emulatorVersion;
  final bool isValid;
  final bool toolchainReady;
  final DateTime? lastVerified;

  const EmulatorEngineConfig({
    required this.id,
    this.androidHome,
    this.emulatorPath = '',
    this.avdmanagerPath,
    this.sdkmanagerPath,
    this.javaPath,
    this.javaVersion,
    this.emulatorVersion,
    this.isValid = false,
    this.toolchainReady = false,
    this.lastVerified,
  });

  factory EmulatorEngineConfig.empty() => const EmulatorEngineConfig(
        id: 'default',
        emulatorPath: '',
      );

  factory EmulatorEngineConfig.fromJson(Map<String, dynamic> json) {
    return EmulatorEngineConfig(
      id: json['id'] as String? ?? 'default',
      androidHome: json['androidHome'] as String?,
      emulatorPath: json['emulatorPath'] as String? ?? '',
      avdmanagerPath: json['avdmanagerPath'] as String?,
      sdkmanagerPath: json['sdkmanagerPath'] as String?,
      javaPath: json['javaPath'] as String?,
      javaVersion: json['javaVersion'] as String?,
      emulatorVersion: json['emulatorVersion'] as String?,
      isValid: json['isValid'] as bool? ?? false,
      toolchainReady: json['toolchainReady'] as bool? ?? false,
      lastVerified: json['lastVerified'] != null
          ? DateTime.tryParse(json['lastVerified'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'androidHome': androidHome,
        'emulatorPath': emulatorPath,
        'avdmanagerPath': avdmanagerPath,
        'sdkmanagerPath': sdkmanagerPath,
        'javaPath': javaPath,
        'javaVersion': javaVersion,
        'emulatorVersion': emulatorVersion,
        'isValid': isValid,
        'toolchainReady': toolchainReady,
        'lastVerified': lastVerified?.toIso8601String(),
      };

  EmulatorEngineConfig copyWith({
    String? id,
    String? androidHome,
    String? emulatorPath,
    String? avdmanagerPath,
    String? sdkmanagerPath,
    String? javaPath,
    String? javaVersion,
    String? emulatorVersion,
    bool? isValid,
    bool? toolchainReady,
    DateTime? lastVerified,
  }) {
    return EmulatorEngineConfig(
      id: id ?? this.id,
      androidHome: androidHome ?? this.androidHome,
      emulatorPath: emulatorPath ?? this.emulatorPath,
      avdmanagerPath: avdmanagerPath ?? this.avdmanagerPath,
      sdkmanagerPath: sdkmanagerPath ?? this.sdkmanagerPath,
      javaPath: javaPath ?? this.javaPath,
      javaVersion: javaVersion ?? this.javaVersion,
      emulatorVersion: emulatorVersion ?? this.emulatorVersion,
      isValid: isValid ?? this.isValid,
      toolchainReady: toolchainReady ?? this.toolchainReady,
      lastVerified: lastVerified ?? this.lastVerified,
    );
  }
}
