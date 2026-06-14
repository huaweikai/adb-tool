class DeviceStatus {
  final String collectedAt;
  final String batteryLevel;
  final String batteryStatus;
  final String batteryTemperature;
  final String cpuUsage;
  final String cpuLoad;
  final String memoryTotal;
  final String memoryAvailable;
  final String memoryUsedPercent;
  final String storageTotal;
  final String storageUsed;
  final String storageAvailable;
  final String storageUsedPercent;
  final String resolution;
  final String density;
  final String refreshRate;
  final String frameStats;
  final String networkType;
  final String wifiSsid;
  final String wifiRssi;
  final String mobileSignal;
  final String ipAddress;
  final String uptime;
  final String thermalStatus;
  final List<ProcessStatus> topProcesses;

  const DeviceStatus({
    required this.collectedAt,
    required this.batteryLevel,
    required this.batteryStatus,
    required this.batteryTemperature,
    required this.cpuUsage,
    required this.cpuLoad,
    required this.memoryTotal,
    required this.memoryAvailable,
    required this.memoryUsedPercent,
    required this.storageTotal,
    required this.storageUsed,
    required this.storageAvailable,
    required this.storageUsedPercent,
    required this.resolution,
    required this.density,
    required this.refreshRate,
    required this.frameStats,
    required this.networkType,
    required this.wifiSsid,
    required this.wifiRssi,
    required this.mobileSignal,
    required this.ipAddress,
    required this.uptime,
    required this.thermalStatus,
    required this.topProcesses,
  });

  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    final processes = json['topProcesses'] as List? ?? [];
    return DeviceStatus(
      collectedAt: _str(json['collectedAt']),
      batteryLevel: _str(json['batteryLevel']),
      batteryStatus: _str(json['batteryStatus']),
      batteryTemperature: _str(json['batteryTemperature']),
      cpuUsage: _str(json['cpuUsage']),
      cpuLoad: _str(json['cpuLoad']),
      memoryTotal: _str(json['memoryTotal']),
      memoryAvailable: _str(json['memoryAvailable']),
      memoryUsedPercent: _str(json['memoryUsedPercent']),
      storageTotal: _str(json['storageTotal']),
      storageUsed: _str(json['storageUsed']),
      storageAvailable: _str(json['storageAvailable']),
      storageUsedPercent: _str(json['storageUsedPercent']),
      resolution: _str(json['resolution']),
      density: _str(json['density']),
      refreshRate: _str(json['refreshRate']),
      frameStats: _str(json['frameStats']),
      networkType: _str(json['networkType']),
      wifiSsid: _str(json['wifiSsid']),
      wifiRssi: _str(json['wifiRssi']),
      mobileSignal: _str(json['mobileSignal']),
      ipAddress: _str(json['ipAddress']),
      uptime: _str(json['uptime']),
      thermalStatus: _str(json['thermalStatus']),
      topProcesses: processes
          .whereType<Map>()
          .map((e) => ProcessStatus.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  static String _str(dynamic value) => value?.toString() ?? '';
}

class ProcessStatus {
  final String pid;
  final String user;
  final String cpu;
  final String memory;
  final String name;
  final String command;

  const ProcessStatus({
    required this.pid,
    required this.user,
    required this.cpu,
    required this.memory,
    required this.name,
    required this.command,
  });

  factory ProcessStatus.fromJson(Map<String, dynamic> json) {
    return ProcessStatus(
      pid: json['pid']?.toString() ?? '',
      user: json['user']?.toString() ?? '',
      cpu: json['cpu']?.toString() ?? '',
      memory: json['memory']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      command: json['command']?.toString() ?? '',
    );
  }
}
