class MockRule {
  final String id;
  final String name;
  final bool enabled;
  final String method;
  final String urlPattern;
  final bool isRegex;
  final String action; // 'mock' or 'rewrite'
  final int mockStatus;
  final Map<String, String> mockHeaders;
  final String mockBody;
  final String findText;
  final String replaceText;
  final int newStatus;
  final int createdAt;
  final int updatedAt;

  const MockRule({
    this.id = '',
    required this.name,
    this.enabled = true,
    this.method = '',
    required this.urlPattern,
    this.isRegex = false,
    this.action = 'mock',
    this.mockStatus = 200,
    this.mockHeaders = const {'Content-Type': 'application/json'},
    this.mockBody = '',
    this.findText = '',
    this.replaceText = '',
    this.newStatus = 0,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  factory MockRule.fromJson(Map<String, dynamic> json) {
    Map<String, String> headers = {};
    if (json['mockHeaders'] is Map) {
      (json['mockHeaders'] as Map).forEach((k, v) {
        headers[k.toString()] = v.toString();
      });
    }

    return MockRule(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      method: json['method'] as String? ?? '',
      urlPattern: json['urlPattern'] as String? ?? '',
      isRegex: json['isRegex'] as bool? ?? false,
      action: json['action'] as String? ?? 'mock',
      mockStatus: (json['mockStatus'] as num?)?.toInt() ?? 200,
      mockHeaders: headers,
      mockBody: json['mockBody'] as String? ?? '',
      findText: json['findText'] as String? ?? '',
      replaceText: json['replaceText'] as String? ?? '',
      newStatus: (json['newStatus'] as num?)?.toInt() ?? 0,
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      'enabled': enabled,
      'method': method,
      'urlPattern': urlPattern,
      'isRegex': isRegex,
      'action': action,
      'mockStatus': mockStatus,
      'mockHeaders': mockHeaders,
      'mockBody': mockBody,
      'findText': findText,
      'replaceText': replaceText,
      'newStatus': newStatus,
    };
  }

  MockRule copyWith({
    String? id,
    String? name,
    bool? enabled,
    String? method,
    String? urlPattern,
    bool? isRegex,
    String? action,
    int? mockStatus,
    Map<String, String>? mockHeaders,
    String? mockBody,
    String? findText,
    String? replaceText,
    int? newStatus,
  }) {
    return MockRule(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      method: method ?? this.method,
      urlPattern: urlPattern ?? this.urlPattern,
      isRegex: isRegex ?? this.isRegex,
      action: action ?? this.action,
      mockStatus: mockStatus ?? this.mockStatus,
      mockHeaders: mockHeaders ?? this.mockHeaders,
      mockBody: mockBody ?? this.mockBody,
      findText: findText ?? this.findText,
      replaceText: replaceText ?? this.replaceText,
      newStatus: newStatus ?? this.newStatus,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
