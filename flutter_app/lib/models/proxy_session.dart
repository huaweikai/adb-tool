class ProxySession {
  final String id;
  final int timestamp;
  final String method;
  final String url;
  final String host;
  final String path;
  final String scheme;
  final int statusCode;
  final String statusText;
  final int durationMs;
  final Map<String, String> reqHeaders;
  final String reqBody;
  final int reqSize;
  final Map<String, String> respHeaders;
  final String respBody;
  final int respSize;
  final bool isMocked;
  final String? matchedRule;
  final String clientIP;

  const ProxySession({
    required this.id,
    required this.timestamp,
    required this.method,
    required this.url,
    required this.host,
    required this.path,
    required this.scheme,
    required this.statusCode,
    required this.statusText,
    required this.durationMs,
    required this.reqHeaders,
    required this.reqBody,
    required this.reqSize,
    required this.respHeaders,
    required this.respBody,
    required this.respSize,
    required this.isMocked,
    this.matchedRule,
    required this.clientIP,
  });

  factory ProxySession.fromJson(Map<String, dynamic> json) {
    Map<String, String> reqHeaders = {};
    if (json['reqHeaders'] is Map) {
      (json['reqHeaders'] as Map).forEach((k, v) {
        reqHeaders[k.toString()] = v.toString();
      });
    }

    Map<String, String> respHeaders = {};
    if (json['respHeaders'] is Map) {
      (json['respHeaders'] as Map).forEach((k, v) {
        respHeaders[k.toString()] = v.toString();
      });
    }

    return ProxySession(
      id: json['id'] as String? ?? '',
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      method: (json['method'] as String? ?? 'GET').toUpperCase(),
      url: json['url'] as String? ?? '',
      host: json['host'] as String? ?? '',
      path: json['path'] as String? ?? '',
      scheme: json['scheme'] as String? ?? 'https',
      statusCode: (json['statusCode'] as num?)?.toInt() ?? 0,
      statusText: json['statusText'] as String? ?? '',
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      reqHeaders: reqHeaders,
      reqBody: json['reqBody'] as String? ?? '',
      reqSize: (json['reqSize'] as num?)?.toInt() ?? 0,
      respHeaders: respHeaders,
      respBody: json['respBody'] as String? ?? '',
      respSize: (json['respSize'] as num?)?.toInt() ?? 0,
      isMocked: json['isMocked'] as bool? ?? false,
      matchedRule: json['matchedRule'] as String?,
      clientIP: json['clientIP'] as String? ?? '',
    );
  }

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
  bool get isRedirect => statusCode >= 300 && statusCode < 400;
  bool get isClientError => statusCode >= 400 && statusCode < 500;
  bool get isServerError => statusCode >= 500;

  Map<String, String> get requestHeaders => reqHeaders;
  String get requestBody => reqBody;
  int get requestSize => reqSize;
  Map<String, String> get responseHeaders => respHeaders;
  String get responseBody => respBody;
  int get responseSize => respSize;
  int get startTime => timestamp;
  String get clientIp => clientIP;
}
