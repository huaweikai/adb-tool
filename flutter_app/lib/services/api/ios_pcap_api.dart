import 'package:adb_tool/services/api_client.dart';
import 'package:dio/dio.dart';

class IosPcapStatus {
  final String status;
  final bool active;
  final String filePath;
  final int packets;
  final int bytes;
  final double duration;
  final String startTime;
  final String? process;
  final String? interface;
  final String? error;

  const IosPcapStatus({
    required this.status,
    required this.active,
    required this.filePath,
    required this.packets,
    required this.bytes,
    required this.duration,
    required this.startTime,
    this.process,
    this.interface,
    this.error,
  });

  factory IosPcapStatus.fromJson(Map<String, dynamic> json) {
    return IosPcapStatus(
      status: json['status']?.toString() ?? 'idle',
      active: json['active'] == true,
      filePath: json['filePath']?.toString() ?? '',
      packets: (json['packets'] as num?)?.toInt() ?? 0,
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      startTime: json['startTime']?.toString() ?? '',
      process: json['process']?.toString(),
      interface: json['interface']?.toString(),
      error: json['error']?.toString(),
    );
  }

  bool get isCapturing => status == 'capturing' || active;
}

mixin IosPcapApi on ApiBase {
  Future<IosPcapStatus> startIosPcap(
    String serial, {
    String? process,
    String? interface,
  }) async {
    final query = deviceQueryParameters(serial);
    if (process != null && process.trim().isNotEmpty) {
      query['process'] = process.trim();
    }
    if (interface != null && interface.trim().isNotEmpty) {
      query['interface'] = interface.trim();
    }
    final resp = await dio.post('/api/ios/pcap/start', queryParameters: query);
    throwIfNotOk(resp);
    return IosPcapStatus.fromJson(responseMap(resp));
  }

  Future<IosPcapStatus> stopIosPcap(String serial) async {
    final resp = await dio.post('/api/ios/pcap/stop',
        queryParameters: deviceQueryParameters(serial));
    throwIfNotOk(resp);
    return IosPcapStatus.fromJson(responseMap(resp));
  }

  Future<IosPcapStatus> getIosPcapStatus(String serial) async {
    final resp = await dio.get('/api/ios/pcap/status',
        queryParameters: deviceQueryParameters(serial));
    throwIfNotOk(resp);
    return IosPcapStatus.fromJson(responseMap(resp));
  }

  Future<List<int>> downloadIosPcap(String serial, {String? path}) async {
    final query = deviceQueryParameters(serial);
    if (path != null && path.isNotEmpty) {
      query['path'] = path;
    }
    final resp = await dio.get<List<int>>(
      '/api/ios/pcap/download',
      queryParameters: query,
      options: Options(responseType: ResponseType.bytes),
    );
    throwIfNotOk(resp);
    return resp.data ?? <int>[];
  }

  Future<Map<String, dynamic>> openIosPcapInWireshark(
    String serial, {
    String? path,
  }) async {
    final query = deviceQueryParameters(serial);
    if (path != null && path.isNotEmpty) {
      query['path'] = path;
    }
    final resp =
        await dio.post('/api/ios/pcap/wireshark', queryParameters: query);
    throwIfNotOk(resp);
    return responseMap(resp);
  }
}
