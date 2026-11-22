import 'package:adb_tool/models/mock_rule.dart';
import 'package:adb_tool/models/proxy_session.dart';
import 'package:adb_tool/services/api_client.dart';
import 'package:dio/dio.dart';

typedef ProxyStatus = ProxyServerStatus;

class ProxyServerStatus {
  final bool running;
  final int port;
  final List<String> lanIps;
  final int sessionCount;
  final int ruleCount;

  const ProxyServerStatus({
    required this.running,
    required this.port,
    required this.lanIps,
    required this.sessionCount,
    required this.ruleCount,
  });

  List<String> get ips => lanIps;

  factory ProxyServerStatus.fromJson(Map<String, dynamic> json) {
    List<String> ips = [];
    if (json['lanIps'] is List) {
      ips = (json['lanIps'] as List).map((e) => e.toString()).toList();
    }
    return ProxyServerStatus(
      running: json['running'] == true,
      port: (json['port'] as num?)?.toInt() ?? 8899,
      lanIps: ips,
      sessionCount: (json['sessionCount'] as num?)?.toInt() ?? 0,
      ruleCount: (json['ruleCount'] as num?)?.toInt() ?? 0,
    );
  }
}

mixin NetworkProxyApi on ApiBase {
  Future<ProxyServerStatus> getProxyStatus() async {
    final response = await dio.get('/api/proxy/status');
    throwIfNotOk(response);
    final data = responseMap(response);
    return ProxyServerStatus.fromJson(data);
  }

  Future<bool> startProxy({int? port}) async {
    final response = await dio.post(
      '/api/proxy/start',
      data: port != null && port > 0 ? {'port': port} : {},
    );
    throwIfNotOk(response);
    final data = responseMap(response);
    return data['running'] == true || isOk(response);
  }

  Future<bool> stopProxy() async {
    final response = await dio.post('/api/proxy/stop');
    throwIfNotOk(response);
    final data = responseMap(response);
    return data['running'] == false || isOk(response);
  }

  Future<List<ProxySession>> getProxySessions({
    String? filter,
    int limit = 200,
  }) async {
    final response = await dio.get(
      '/api/proxy/sessions',
      queryParameters: {
        if (filter != null && filter.isNotEmpty) 'filter': filter,
        'limit': limit,
      },
    );
    throwIfNotOk(response);
    final raw = responseData(response);
    if (raw is List) {
      return raw
          .map((e) => ProxySession.fromJson(asMap(e)))
          .toList();
    }
    return [];
  }

  Future<ProxySession?> getProxySessionDetail(String id) async {
    final response = await dio.get(
      '/api/proxy/session/detail',
      queryParameters: {'id': id},
    );
    throwIfNotOk(response);
    final data = responseMap(response);
    if (data.isNotEmpty) {
      return ProxySession.fromJson(data);
    }
    return null;
  }

  Future<bool> clearProxySessions() async {
    final response = await dio.post('/api/proxy/sessions/clear');
    throwIfNotOk(response);
    return isOk(response);
  }

  Future<List<MockRule>> getMockRules() async {
    final response = await dio.get('/api/proxy/rules');
    throwIfNotOk(response);
    final raw = responseData(response);
    if (raw is List) {
      return raw
          .map((e) => MockRule.fromJson(asMap(e)))
          .toList();
    }
    return [];
  }

  Future<MockRule> saveMockRule(MockRule rule) async {
    final response = await dio.post(
      '/api/proxy/rules',
      data: rule.toJson(),
    );
    throwIfNotOk(response);
    final data = responseMap(response);
    return MockRule.fromJson(data);
  }

  Future<bool> deleteMockRule(String id) async {
    final response = await dio.delete(
      '/api/proxy/rules',
      queryParameters: {'id': id},
    );
    throwIfNotOk(response);
    return isOk(response);
  }

  Future<bool> setAdbProxy(String serial, String host, int port) async {
    final response = await dio.post(
      '/api/proxy/adb/set',
      data: {
        'serial': serial,
        'host': host,
        'port': port,
      },
    );
    throwIfNotOk(response);
    return isOk(response);
  }

  Future<bool> clearAdbProxy(String serial) async {
    final response = await dio.post(
      '/api/proxy/adb/clear',
      data: {'serial': serial},
    );
    throwIfNotOk(response);
    return isOk(response);
  }

  Future<String> getAdbProxyStatus(String serial) async {
    final response = await dio.get(
      '/api/proxy/adb/status',
      queryParameters: {'serial': serial},
    );
    throwIfNotOk(response);
    final data = responseMap(response);
    return data['proxy']?.toString() ?? '';
  }

  Future<String> getProxyCaCert() async {
    final response = await dio.get(
      '/api/proxy/ca.crt',
      options: Options(responseType: ResponseType.plain),
    );
    return response.data?.toString() ?? '';
  }

  String getProxyCaDownloadUrl() {
    return '$baseUrl/api/proxy/ca.crt';
  }
}
