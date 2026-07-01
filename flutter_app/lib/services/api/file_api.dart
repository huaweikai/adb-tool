// Device file-system operations: list / read / pull / push / delete / rename / mkdir / touch / stat.
import 'dart:io';

import 'package:adb_tool/services/api_client.dart';
import 'package:adb_tool/models/app_package.dart';
import 'package:adb_tool/models/file_item.dart';
import 'package:dio/dio.dart';

mixin FileApi on ApiBase {
  Future<List<FileItem>> listFiles(String serial, String path) async {
    final resp = await dio.get(
      '/api/files',
      queryParameters: deviceQueryParameters(serial, {'path': path}),
    );
    throwIfNotOk(resp);
    final data = responseMap(resp);
    final list = data['files'] as List? ?? [];
    return list.map((e) => FileItem.fromJson(asMap(e))).toList();
  }

  Future<String> readFile(String serial, String path) async {
    final resp = await dio.get(
      '/api/file-content',
      queryParameters: deviceQueryParameters(serial, {'path': path}),
    );
    throwIfNotOk(resp);
    final data = responseMap(resp);
    return data['content'] ?? '';
  }

  Future<String> readFileContent(String serial, String path) async {
    final resp = await dio.get(
      '/api/file-content',
      queryParameters: deviceQueryParameters(serial, {'path': path}),
    );
    throwIfNotOk(resp);
    final data = responseMap(resp);
    return data['content'] ?? '';
  }

  Future<List<AppPackage>> getInstalledPackages(String serial) async {
    final resp = await dio.get(
      '/api/packages',
      queryParameters: deviceQueryParameters(serial),
    );
    throwIfNotOk(resp);
    final data = responseMap(resp);
    final list = data['packages'] as List? ?? [];
    return list.map((e) => AppPackage.fromJson(asMap(e))).toList();
  }

  Future<bool> deleteFile(
    String serial,
    String path, {
    required bool recursive,
  }) async {
    final resp = await dio.post(
      '/api/file-delete',
      queryParameters: deviceQueryParameters(serial, {
        'path': path,
        'recursive': recursive.toString(),
      }),
    );
    throwIfNotOk(resp);
    return true;
  }

  Future<bool> renameFile(String serial, String from, String to) async {
    final resp = await dio.post(
      '/api/file-rename',
      queryParameters: deviceQueryParameters(serial, {'from': from, 'to': to}),
    );
    throwIfNotOk(resp);
    return true;
  }

  Future<bool> createDirectory(String serial, String path) async {
    final resp = await dio.post(
      '/api/file-mkdir',
      queryParameters: deviceQueryParameters(serial, {'path': path}),
    );
    throwIfNotOk(resp);
    return true;
  }

  Future<bool> createFile(String serial, String path) async {
    final resp = await dio.post(
      '/api/file-touch',
      queryParameters: deviceQueryParameters(serial, {'path': path}),
    );
    throwIfNotOk(resp);
    return true;
  }

  Future<FileStat> statFile(String serial, String path) async {
    final resp = await dio.get(
      '/api/file-stat',
      queryParameters: deviceQueryParameters(serial, {'path': path}),
    );
    throwIfNotOk(resp);
    final data = responseMap(resp);
    return FileStat.fromJson(asMap(data['stat']));
  }

  Future<List<int>> pullFile(String serial, String path) async {
    final resp = await dio.get<List<int>>(
      '/api/pull-file',
      queryParameters: deviceQueryParameters(serial, {'path': path}),
      options: Options(responseType: ResponseType.bytes),
    );
    if (!isOk(resp)) {
      throw Exception('pull failed: ${resp.statusCode}');
    }
    return resp.data ?? [];
  }

  Future<void> downloadFileToPath(
    String serial,
    String remotePath,
    String localPath, {
    int totalBytes = 0,
    TransferProgressCallback? onProgress,
    TransferCancelToken? cancelToken,
  }) async {
    try {
      cancelToken?.throwIfCanceled();
      final response = await dio.download(
        '/api/pull-file',
        localPath,
        queryParameters: deviceQueryParameters(serial, {'path': remotePath}),
        cancelToken: cancelToken?.dioToken,
        onReceiveProgress: (received, total) {
          final expected = totalBytes > 0 ? totalBytes : total;
          onProgress?.call(TransferProgress(received, expected));
        },
      );
      cancelToken?.throwIfCanceled();
      if (!isOk(response)) {
        final file = File(localPath);
        if (await file.exists()) await file.delete();
        throw Exception('pull failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (isCancelError(e)) throw TransferCanceledException();
      rethrow;
    }
  }

  Future<bool> pushFile(String serial, String path, List<int> bytes) async {
    final resp = await dio.post(
      '/api/push-file',
      queryParameters: deviceQueryParameters(serial, {'path': path}),
      data: bytes,
      options: Options(contentType: 'application/octet-stream'),
    );
    throwIfNotOk(resp);
    return true;
  }

  Future<bool> pushLocalFile(
    String serial,
    String remotePath,
    String localPath, {
    TransferProgressCallback? onProgress,
    TransferCancelToken? cancelToken,
  }) async {
    await super.postLocalFile(
      '/api/push-file',
      localPath,
      queryParameters: deviceQueryParameters(serial, {'path': remotePath}),
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    return true;
  }
}
