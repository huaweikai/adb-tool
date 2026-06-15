enum TestSessionStatus { running, finished }

enum TestSessionEventType {
  sessionCreated,
  noteAdded,
  logcatStarted,
  logcatSaved,
  screenshotTaken,
  screenRecordStarted,
  screenRecordStopped,
  issueMarked,
  sessionFinished,
}

enum TestSessionArtifactKind { screenshot, video, log, report }

enum TestSessionIssueType {
  crash,
  anr,
  performance,
  ui,
  api,
  functional,
  compatibility,
  other,
}

enum TestSessionIssueSeverity {
  blocker,
  major,
  normal,
  minor,
}

class TestSessionEvent {
  final String id;
  final TestSessionEventType type;
  final DateTime time;
  final String title;
  final String detail;
  final String? filePath;

  const TestSessionEvent({
    required this.id,
    required this.type,
    required this.time,
    required this.title,
    this.detail = '',
    this.filePath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'time': time.toIso8601String(),
        'title': title,
        'detail': detail,
        'filePath': filePath,
      };

  factory TestSessionEvent.fromJson(Map<String, dynamic> json) {
    return TestSessionEvent(
      id: json['id']?.toString() ?? '',
      type: TestSessionEventType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => TestSessionEventType.noteAdded,
      ),
      time: DateTime.tryParse(json['time']?.toString() ?? '') ?? DateTime.now(),
      title: json['title']?.toString() ?? '',
      detail: json['detail']?.toString() ?? '',
      filePath: json['filePath']?.toString(),
    );
  }
}

class TestSessionArtifact {
  final String id;
  final TestSessionArtifactKind kind;
  final String name;
  final String path;
  final DateTime createdAt;
  final int size;

  const TestSessionArtifact({
    required this.id,
    required this.kind,
    required this.name,
    required this.path,
    required this.createdAt,
    this.size = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'name': name,
        'path': path,
        'createdAt': createdAt.toIso8601String(),
        'size': size,
      };

  factory TestSessionArtifact.fromJson(Map<String, dynamic> json) {
    return TestSessionArtifact(
      id: json['id']?.toString() ?? '',
      kind: TestSessionArtifactKind.values.firstWhere(
        (kind) => kind.name == json['kind'],
        orElse: () => TestSessionArtifactKind.log,
      ),
      name: json['name']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      size: int.tryParse(json['size']?.toString() ?? '') ?? 0,
    );
  }
}

class TestSessionNote {
  final String id;
  final DateTime createdAt;
  final String content;

  const TestSessionNote({
    required this.id,
    required this.createdAt,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'content': content,
      };

  factory TestSessionNote.fromJson(Map<String, dynamic> json) {
    return TestSessionNote(
      id: json['id']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      content: json['content']?.toString() ?? '',
    );
  }
}

class TestSessionIssue {
  final String id;
  final DateTime createdAt;
  final String title;
  final TestSessionIssueType type;
  final TestSessionIssueSeverity severity;
  final String steps;
  final String expected;
  final String actual;
  final String note;
  final List<String> relatedArtifactIds;

  const TestSessionIssue({
    required this.id,
    required this.createdAt,
    required this.title,
    this.type = TestSessionIssueType.other,
    this.severity = TestSessionIssueSeverity.normal,
    this.steps = '',
    this.expected = '',
    this.actual = '',
    this.note = '',
    this.relatedArtifactIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'title': title,
        'type': type.name,
        'severity': severity.name,
        'steps': steps,
        'expected': expected,
        'actual': actual,
        'note': note,
        'relatedArtifactIds': relatedArtifactIds,
      };

  factory TestSessionIssue.fromJson(Map<String, dynamic> json) {
    return TestSessionIssue(
      id: json['id']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      title: json['title']?.toString() ?? '',
      type: _issueTypeFrom(json['type']?.toString()),
      severity: _severityFrom(json['severity']?.toString()),
      steps: json['steps']?.toString() ?? '',
      expected: json['expected']?.toString() ?? '',
      actual: json['actual']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      relatedArtifactIds: (json['relatedArtifactIds'] as List? ?? [])
          .map((id) => id.toString())
          .toList(),
    );
  }
}

TestSessionIssueType _issueTypeFrom(String? name) {
  return TestSessionIssueType.values.firstWhere(
    (t) => t.name == name,
    orElse: () => TestSessionIssueType.other,
  );
}

TestSessionIssueSeverity _severityFrom(String? name) {
  return TestSessionIssueSeverity.values.firstWhere(
    (s) => s.name == name,
    orElse: () => TestSessionIssueSeverity.normal,
  );
}

class TestSession {
  final String id;
  final String name;
  final String type;
  final TestSessionStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String directoryPath;
  final String deviceSerial;
  final String deviceModel;
  final String deviceBrand;
  final String deviceSdk;
  final String packageName;
  final String note;
  final List<TestSessionEvent> events;
  final List<TestSessionArtifact> artifacts;
  final List<TestSessionNote> notes;
  final List<TestSessionIssue> issues;

  const TestSession({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.startedAt,
    required this.directoryPath,
    required this.deviceSerial,
    this.endedAt,
    this.deviceModel = '',
    this.deviceBrand = '',
    this.deviceSdk = '',
    this.packageName = '',
    this.note = '',
    this.events = const [],
    this.artifacts = const [],
    this.notes = const [],
    this.issues = const [],
  });

  TestSession copyWith({
    TestSessionStatus? status,
    DateTime? endedAt,
    List<TestSessionEvent>? events,
    List<TestSessionArtifact>? artifacts,
    List<TestSessionNote>? notes,
    List<TestSessionIssue>? issues,
  }) {
    return TestSession(
      id: id,
      name: name,
      type: type,
      status: status ?? this.status,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      directoryPath: directoryPath,
      deviceSerial: deviceSerial,
      deviceModel: deviceModel,
      deviceBrand: deviceBrand,
      deviceSdk: deviceSdk,
      packageName: packageName,
      note: note,
      events: events ?? this.events,
      artifacts: artifacts ?? this.artifacts,
      notes: notes ?? this.notes,
      issues: issues ?? this.issues,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'status': status.name,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'directoryPath': directoryPath,
        'deviceSerial': deviceSerial,
        'deviceModel': deviceModel,
        'deviceBrand': deviceBrand,
        'deviceSdk': deviceSdk,
        'packageName': packageName,
        'note': note,
        'events': events.map((event) => event.toJson()).toList(),
        'artifacts': artifacts.map((artifact) => artifact.toJson()).toList(),
        'notes': notes.map((note) => note.toJson()).toList(),
        'issues': issues.map((issue) => issue.toJson()).toList(),
      };

  factory TestSession.fromJson(Map<String, dynamic> json) {
    return TestSession(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      status: TestSessionStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => TestSessionStatus.finished,
      ),
      startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? '') ??
          DateTime.now(),
      endedAt: DateTime.tryParse(json['endedAt']?.toString() ?? ''),
      directoryPath: json['directoryPath']?.toString() ?? '',
      deviceSerial: json['deviceSerial']?.toString() ?? '',
      deviceModel: json['deviceModel']?.toString() ?? '',
      deviceBrand: json['deviceBrand']?.toString() ?? '',
      deviceSdk: json['deviceSdk']?.toString() ?? '',
      packageName: json['packageName']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      events: (json['events'] as List? ?? [])
          .whereType<Map>()
          .map((event) => TestSessionEvent.fromJson(
              event.map((key, value) => MapEntry(key.toString(), value))))
          .toList(),
      artifacts: (json['artifacts'] as List? ?? [])
          .whereType<Map>()
          .map((artifact) => TestSessionArtifact.fromJson(
              artifact.map((key, value) => MapEntry(key.toString(), value))))
          .toList(),
      notes: (json['notes'] as List? ?? [])
          .whereType<Map>()
          .map((note) => TestSessionNote.fromJson(
              note.map((key, value) => MapEntry(key.toString(), value))))
          .toList(),
      issues: (json['issues'] as List? ?? [])
          .whereType<Map>()
          .map((issue) => TestSessionIssue.fromJson(
              issue.map((key, value) => MapEntry(key.toString(), value))))
          .toList(),
    );
  }
}
