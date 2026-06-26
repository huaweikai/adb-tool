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

  /// Stop an instance. Also used as "cancel" while the instance is
  /// still booting — the backend's Stop endpoint accepts both
  /// StatusRunning and StatusStarting.
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
          // Wipe boot progress optimistically so the card collapses
          // back to the "Stopped" state immediately, without waiting
          // for the next WebSocket ping.
          bootStage: '',
          bootProgress: 0,
          bootMessage: '',
        );
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Fetch the last [tail] lines of the instance's emulator.log so the
  /// UI can pop a "view log" dialog without re-implementing file IO.
  /// Returns null if the request failed or no log is available yet.
  Future<List<String>?> fetchInstanceLog(String id, {int tail = 80}) async {
    try {
      final response = await _api.dio.get(
        '/api/emulator/instance/log',
        queryParameters: {'id': id, 'tail': tail},
      );
      final data = _api.responseMap(response);
      final lines = data['lines'];
      if (lines is List) {
        return lines.map((e) => e?.toString() ?? '').toList();
      }
      return const [];
    } catch (e) {
      debugPrint('fetchInstanceLog failed: $e');
      return null;
    }
  }

  /// Delete an instance. Returns true on success, false if the backend
/// rejected the request (caller should surface an error to the user).
  Future<bool> deleteInstance(String id) async {
    _error = null;
    notifyListeners();

    try {
      await _api.dio.delete(
        '/api/emulator/instance/delete',
        queryParameters: {'id': id},
      );
      _instances.removeWhere((i) => i.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
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

    // Boot fields are sent on every status push while the instance is
    // in flight. When the instance leaves StatusStarting / StatusRunning
    // the backend sends empty values, so we just write them through.
    // copyWith with null-mapped params would also accept them as
    // "don't change", but the WS payload always carries explicit
    // values (including empty strings), so a plain merge is correct.
    final bootStage = update['bootStage'] as String?;
    final bootProgress = update['bootProgress'] as int?;
    final bootMessage = update['bootMessage'] as String?;

    _instances[index] = _instances[index].copyWith(
      status: status,
      pid: update['pid'] as int?,
      bootStage: bootStage ?? '',
      bootProgress: bootProgress ?? 0,
      bootMessage: bootMessage ?? '',
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
