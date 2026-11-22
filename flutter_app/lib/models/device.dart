enum DeviceCapability {
  deviceStatus,
  deviceInfo,
  liveLogs,
  files,
  apps,
  clipboard,
  viewHierarchy,
  adbCommands,
  testSession,
  screenMirror,
  screenshot,
  crashReports,
  iosLiveLogs,
  iosPcap,
  networkProxy;

  // Default for older backends and Android rows saved while offline.
  static const androidDefaults = {
    deviceStatus,
    deviceInfo,
    liveLogs,
    files,
    apps,
    clipboard,
    viewHierarchy,
    adbCommands,
    testSession,
    screenMirror,
    screenshot,
    networkProxy,
  };
}

/// One row from `GET /api/devices`. Carries two distinct identifiers
/// because adb identifies devices by transient address (ip:port for
/// wireless, transport-id for USB) while the rest of the app —
/// `saved_devices` PK, `test_sessions.deviceSerial` FK, the sidebar
/// list — needs a stable identity that survives reconnects.
///
///   - [serial]          — adb-level address. Used directly in
///                         `?serial=...` adb-command URLs. Empty for
///                         offline / non-state="device" entries.
///   - [hardwareSerial]  — ro.serialno. The stable identity. Used
///                         to match against `saved_devices.serial`
///                         so a wireless reconnect on a different
///                         port doesn't create a new device row.
///                         May be empty when the backend can't read
///                         props (e.g. unauthorized devices); the
///                         reconcile logic treats that as "no match
///                         by hardware" and falls back to adb-serial.
/// iOS uses the same namespaced UDID for both identifiers and reports the
/// current connection separately in [transport].
class Device {
  static bool isIosIdentity(String serial) => serial.startsWith('ios:');

  final String serial;
  final String hardwareSerial;
  final String state;
  final String model;
  final String brand;
  final String sdk;
  final String platform;
  final String? transport;
  final Set<DeviceCapability> capabilities;

  const Device({
    required this.serial,
    this.hardwareSerial = '',
    required this.state,
    this.model = '',
    this.brand = '',
    this.sdk = '',
    this.platform = 'android',
    this.transport,
    Set<DeviceCapability>? capabilities,
  }) : capabilities = capabilities ??
            (platform == 'android'
                ? DeviceCapability.androidDefaults
                : const {});

  factory Device.fromJson(Map<String, dynamic> json) {
    final platform = json['platform'] as String? ?? 'android';
    final advertised = json['capabilities'];
    return Device(
      serial: json['serial'] ?? '',
      hardwareSerial: json['hardwareSerial'] ?? '',
      state: json['state'] ?? '',
      model: json['model'] ?? '',
      brand: json['brand'] ?? '',
      sdk: json['sdk'] ?? '',
      platform: platform,
      transport: json['transport'] as String?,
      capabilities: advertised is List
          ? Set.unmodifiable(DeviceCapability.values
              .where((capability) => advertised.contains(capability.name)))
          : null,
    );
  }

  String get displayName {
    if (model.isNotEmpty) return model;
    if (brand.isNotEmpty) return brand;
    return serial;
  }

  bool get isOnline => state == 'device';

  /// True iff [stableSerial] (typically the DeviceSerialScope value, =
  /// ro.serialno) matches either the adb-level [serial] (ip:port for
  /// wireless, equal to ro.serialno for USB) or the [hardwareSerial]
  /// (ro.serialno for wireless). UI code that needs to look up a
  /// Device from a scope must use this — the old `d.serial ==
  /// scopeSerial` check no longer works after the v8→v9 identity
  /// split because the two fields now carry different identifiers.
  bool matchesIdentity(String? stableSerial) {
    if (stableSerial == null || stableSerial.isEmpty) return false;
    return serial == stableSerial || hardwareSerial == stableSerial;
  }
}

class LogFilter {
  String _tag;
  String _keyword;

  // Pre-lowercased snapshots of [tag] and [keyword]. matchesFilter is
  // called once per incoming LogEntry — with a 12.5 Hz stream flush
  // pushing 5000-entry evictions, that's a lot of `.toLowerCase()` work
  // on raw 200-char strings. Caching the lowercase form on the writer
  // side (setter) keeps the hot path allocation-free as long as the
  // filter text doesn't change.
  String _tagLower;
  String _keywordLower;

  static const _priorities = 'VDIWEF';
  String _priority;
  int _minimumLevel;
  String packageName;
  String _packagePid;
  Set<String> _pids;

  LogFilter({
    String tag = '',
    String priority = 'W',
    String keyword = '',
    this.packageName = '',
    String packagePid = '',
  })  : _tag = tag,
        _keyword = keyword,
        _tagLower = tag.toLowerCase(),
        _keywordLower = keyword.toLowerCase(),
        _priority = priority,
        _minimumLevel = _priorities.indexOf(priority),
        _packagePid = packagePid,
        _pids = _parsePids(packagePid);

  String get tag => _tag;
  String get keyword => _keyword;
  String get priority => _priority;
  String get packagePid => _packagePid;

  set priority(String value) {
    _priority = value;
    _minimumLevel = _priorities.indexOf(value);
  }

  set packagePid(String value) {
    _packagePid = value;
    _pids = _parsePids(value);
  }

  static Set<String> _parsePids(String value) => value.trim().isEmpty
      ? const {}
      : value.trim().split(RegExp(r'\s+')).toSet();

  LogFilter copy() => LogFilter(
        tag: tag,
        keyword: keyword,
        priority: priority,
        packageName: packageName,
        packagePid: packagePid,
      );

  set tag(String v) {
    if (_tag == v) return;
    _tag = v;
    _tagLower = v.toLowerCase();
  }

  set keyword(String v) {
    if (_keyword == v) return;
    _keyword = v;
    _keywordLower = v.toLowerCase();
  }

  Map<String, dynamic> toJson() => {
        'tag': _tag,
        'priority': priority,
        'keyword': _keyword,
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
  // App/process name that emitted the log, e.g. "com.example.app" or
  // "system_process". Empty for now because `adb logcat -v threadtime`
  // doesn't include this field — Android Studio looks it up separately
  // by PID. The display layer still reserves a fixed-width column for
  // it so the layout matches Android Studio's logcat row format.
  // TODO: populate by caching `adb shell ps` lookups keyed by PID.
  final String process;
  final String message;
  final bool isContinuation;

  LogEntry({
    required this.raw,
    this.time = '',
    this.pid = '',
    this.tid = '',
    this.priority = '',
    this.tag = '',
    this.process = '',
    this.message = '',
    this.isContinuation = false,
  });

  static final _threadtimePattern = RegExp(
    r'^((?:\d{4}-)?\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d+)\s+(\d+)\s+(\d+)\s+([VDIWEF])\s+(.+?):\s?(.*)$',
  );

  factory LogEntry.parse(String line) {
    final m = _threadtimePattern.firstMatch(line);
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
    if (filter._pids.isNotEmpty && !filter._pids.contains(pid)) return false;
    if (priority.isNotEmpty &&
        LogFilter._priorities.indexOf(priority) < filter._minimumLevel) {
      return false;
    }
    if (filter._tagLower.isNotEmpty &&
        tag.isNotEmpty &&
        !tag.toLowerCase().contains(filter._tagLower)) {
      return false;
    }
    return filter._keywordLower.isEmpty ||
        raw.toLowerCase().contains(filter._keywordLower);
  }
}
