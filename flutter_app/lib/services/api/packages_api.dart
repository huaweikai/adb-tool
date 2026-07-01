// APK install / uninstall.
import 'package:adb_tool/services/api_client.dart';
import 'package:dio/dio.dart';

mixin PackagesApi on ApiBase {
  Future<String> installPackage(String serial, List<int> apkBytes) async {
    final resp = await dio.post(
      '/api/install-package',
      queryParameters: deviceQueryParameters(serial),
      data: apkBytes,
      options: Options(contentType: 'application/octet-stream'),
    );
    if (!isOk(resp)) {
      throw Exception(errorMessage(resp));
    }
    final data = responseMap(resp);
    return data['status'] ?? 'ok';
  }

  Future<String> installLocalPackage(
    String serial,
    String apkPath, {
    TransferProgressCallback? onProgress,
    TransferCancelToken? cancelToken,
  }) async {
    final data = await super.postLocalFile(
      '/api/install-package',
      apkPath,
      queryParameters: deviceQueryParameters(serial),
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    return data['status'] ?? 'ok';
  }

  Future<bool> uninstallPackage(String serial, String packageName) async {
    final resp = await dio.post(
      '/api/uninstall-package',
      queryParameters: deviceQueryParameters(serial, {'package': packageName}),
    );
    throwIfNotOk(resp);
    return true;
  }
}
