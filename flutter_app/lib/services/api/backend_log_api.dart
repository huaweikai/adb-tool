// Backend (Go) in-memory ring buffer log snapshot.
import 'package:adb_tool/services/api_client.dart';

mixin BackendLogApi on ApiBase {
  Future<List<Map<String, dynamic>>> getBackendLogs() async {
    final resp =
        await dio.get('/api/backend-logs').timeout(const Duration(seconds: 3));
    if (!isOk(resp)) return [];
    final data = responseMap(resp);
    final list = data['logs'] as List? ?? [];
    return list.map((e) => asMap(e)).toList();
  }
}
