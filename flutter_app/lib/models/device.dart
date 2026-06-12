class Device {
  final String serial;
  final String state;
  final String model;
  final String brand;
  final String sdk;

  Device({
    required this.serial,
    required this.state,
    this.model = '',
    this.brand = '',
    this.sdk = '',
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      serial: json['serial'] ?? '',
      state: json['state'] ?? '',
      model: json['model'] ?? '',
      brand: json['brand'] ?? '',
      sdk: json['sdk'] ?? '',
    );
  }

  String get displayName {
    if (model.isNotEmpty) return model;
    if (brand.isNotEmpty) return brand;
    return serial;
  }

  bool get isOnline => state == 'device';
}

class LogFilter {
  String tag;
  String priority;
  String keyword;
  String packageName;
  String packagePid;

  LogFilter({
    this.tag = '',
    this.priority = 'W',
    this.keyword = '',
    this.packageName = '',
    this.packagePid = '',
  });

  Map<String, dynamic> toJson() => {
    'tag': tag,
    'priority': priority,
    'keyword': keyword,
    'packageName': packageName,
    'packagePid': packagePid,
  };
}

class LogEntry {
  final String raw;
  final String time;
  final String pid;
  final String tid;
  final String priority;
  final String tag;
  final String message;
  final bool isContinuation;

  LogEntry({
    required this.raw,
    this.time = '',
    this.pid = '',
    this.tid = '',
    this.priority = '',
    this.tag = '',
    this.message = '',
    this.isContinuation = false,
  });

  factory LogEntry.parse(String line) {
    final re = RegExp(
      r'^(\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d+)\s+(\d+)\s+(\d+)\s+([VDIWEF])\s+(.+?):\s?(.*)$',
    );
    final m = re.firstMatch(line);
    if (m != null) {
      return LogEntry(
        raw: line,
        time: m.group(1)!,
        pid: m.group(2)!,
        tid: m.group(3)!,
        priority: m.group(4)!,
        tag: m.group(5)!,
        message: m.group(6)!,
      );
    }

    final trimmed = line.trim();
    if (trimmed.isNotEmpty &&
        (trimmed.startsWith('at ') ||
         trimmed.startsWith('Caused by:') ||
         trimmed.startsWith('... ') ||
         line.startsWith('\t'))) {
      return LogEntry(raw: line, message: line, isContinuation: true);
    }

    return LogEntry(raw: line, message: line);
  }

  bool matchesFilter(LogFilter filter) {
    if (filter.keyword.isNotEmpty &&
        !raw.toLowerCase().contains(filter.keyword.toLowerCase())) {
      return false;
    }
    if (filter.tag.isNotEmpty) {
      if (tag.isEmpty) return true;
      if (!tag.toLowerCase().contains(filter.tag.toLowerCase())) {
        return false;
      }
    }
    return true;
  }
}
