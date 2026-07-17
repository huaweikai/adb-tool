import 'package:adb_tool/models/view_node.dart';
import 'package:adb_tool/services/api_client.dart';

mixin ViewHierarchyApi on ApiBase {
  Future<HierarchyDump?> dumpViewHierarchy(String serial) async {
    final resp = await dio.post(
      '/api/view-hierarchy',
      queryParameters: deviceQueryParameters(serial),
    );
    if (!isOk(resp)) return null;
    final data = responseMap(resp);
    final hierarchy = data['hierarchy'];
    if (hierarchy == null) return null;
    final root = ViewNode.fromJson(hierarchy as Map<String, dynamic>);
    final rotation = (data['rotation'] as num?)?.toInt() ?? 0;
    return HierarchyDump(root, rotation);
  }
}
