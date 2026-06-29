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
class Device {
  final String serial;
  final String hardwareSerial;
  final String state;
  final String model;
  final String brand;
  final String sdk;

  const Device({
    required this.serial,
    this.hardwareSerial = '',
    required this.state,
    this.model = '',
    this.brand = '',
    this.sdk = '',
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      serial: json['serial'] ?? '',
      hardwareSerial: json['hardwareSerial'] ?? '',
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

  String priority;
  String packageName;
  String packagePid;

  LogFilter({
    String tag = '',
    this.priority = 'W',
    String keyword = '',
    this.packageName = '',
    this.packagePid = '',
  })  : _tag = tag,
        _keyword = keyword,
        _tagLower = tag.toLowerCase(),
        _keywordLower = keyword.toLowerCase();

  String get tag => _tag;
  String get keyword => _keyword;

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
    // Filter tag / keyword come pre-lowercased by LogFilter setters.
    // raw and tag are per-entry, but matched against the cached lower
    // form, so each call only allocates 1-2 lowercase strings instead
    // of 3.
    if (filter.keyword.isNotEmpty &&
        !raw.toLowerCase().contains(filter._keywordLower)) {
      return false;
    }
    if (filter.tag.isNotEmpty) {
      if (tag.isEmpty) return true;
      if (!tag.toLowerCase().contains(filter._tagLower)) {
        return false;
      }
    }
    // Package filter: when a PID is resolved (state.packagePid / filter
    // .packagePid), drop any entry that doesn't match it. Without this,
    // changing the package filter on a stopped/slow stream would leave
    // the old non-matching entries visible in the buffer — the backend
    // stops sending new non-matching lines but never re-prunes the
    // already-buffered ones.
    if (filter.packagePid.isNotEmpty && pid != filter.packagePid) {
      return false;
    }
    return true;
  }
}
