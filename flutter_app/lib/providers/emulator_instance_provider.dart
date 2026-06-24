// Emulator instance provider - manages instance state and operations.
import 'dart:async';
import 'dart:convert';
import 'dart:io' show WebSocket;
import 'package:flutter/foundation.dart';
import 'package:adb_tool/models/emulator_instance.dart';
import 'package:adb_tool/services/api_client.dart';

class EmulatorInstanceProvider extends ChangeNotifier {
  final ApiClient _api;
  List<EmulatorInstance> _instances = [];
  bool _isLoading = false;
  String? _error;
  WebSocket? _ws;

  EmulatorInstanceProvider({required ApiClient api}) : _api = api;

  List<EmulatorInstance> get instances => _instances;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch all instances from backend.
  Future<void> fetchInstances() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.dio.get('/api/emulator/instances');
      final data = _api.responseMap(response);
      _instances = (data['instances'] as List?)
              ?.map((e) => EmulatorInstance.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new instance.
  Future<EmulatorInstance?> createNewInstance({
    required String name,
    required String imageId,
    int cores = 4,
    int memoryMb = 4096,
    int width = 1080,
    int height = 1920,
    int density = 420,
    String? sdcardSize,
    String gpuMode = 'auto',
  }) async {
    _error = null;

    try {
      final response = await _api.dio.post(
        '/api/emulator/instance/create',
        data: {
          'name': name,
          'imageId': imageId,
          'cores': cores,
          'memoryMb': memoryMb,
          'width': width,
          'height': height,
          'density': density,
          if (sdcardSize != null) 'sdcardSize': sdcardSize,
          'gpuMode': gpuMode,
        },
      );
      final data = _api.responseMap(response);
      final instance = EmulatorInstance.fromJson(data);
      _instances.add(instance);
      notifyListeners();
      return instance;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Start an instance.
  Future<void> startInstance(String id) async {
    _error = null;

    try {
      final response = await _api.dio.post(
        '/api/emulator/instance/start',
        queryParameters: {'id': id},
      );
      final data = _api.responseMap(response);
      final instance = EmulatorInstance.fromJson(data);
      final index = _instances.indexWhere((i) => i.id == id);
      if (index >= 0) {
        _instances[index] = instance;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Stop an instance.
  Future<void> stopInstance(String id) async {
    _error = null;

    try {
      await _api.dio.post(
        '/api/emulator/instance/stop',
        queryParameters: {'id': id},
      );
      final index = _instances.indexWhere((i) => i.id == id);
      if (index >= 0) {
        _instances[index] = _instances[index].copyWith(
          status: EmulatorInstanceStatus.stopped,
          pid: null,
        );
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Delete an instance.
  Future<void> deleteInstance(String id) async {
    _error = null;

    try {
      await _api.dio.delete(
        '/api/emulator/instance/delete',
        queryParameters: {'id': id},
      );
      _instances.removeWhere((i) => i.id == id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Connect to WebSocket for real-time status updates.
  Future<void> connectStatusUpdates() async {
    if (_instances.isEmpty) return;

    final ids = _instances.map((i) => i.id).toList();
    _ws?.close();

    try {
      _ws = await WebSocket.connect(_getStatusWebSocketUrl(ids));
      _ws!.listen(
        (data) {
          final update = jsonDecode(data as String) as Map<String, dynamic>;
          _handleStatusUpdate(update);
        },
        onError: (e) {
          debugPrint('WebSocket error: $e');
          // Reconnect after delay
          Future.delayed(const Duration(seconds: 5), connectStatusUpdates);
        },
        onDone: () {
          // Reconnect after delay
          Future.delayed(const Duration(seconds: 5), connectStatusUpdates);
        },
      );
    } catch (e) {
      debugPrint('Failed to connect WebSocket: $e');
    }
  }

  String _getStatusWebSocketUrl(List<String> instanceIds) {
    final ids = instanceIds.join(',');
    return 'ws://${_api.baseUrl}/ws/emulator/status?id=$ids';
  }

  void _handleStatusUpdate(Map<String, dynamic> update) {
    final instanceId = update['instanceId'] as String?;
    if (instanceId == null) return;

    final index = _instances.indexWhere((i) => i.id == instanceId);
    if (index < 0) return;

    final statusStr = update['status'] as String?;
    final status = EmulatorInstanceStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => EmulatorInstanceStatus.stopped,
    );

    _instances[index] = _instances[index].copyWith(
      status: status,
      pid: update['pid'] as int?,
    );
    notifyListeners();
  }

  /// Disconnect from WebSocket.
  void disconnect() {
    _ws?.close();
    _ws = null;
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
