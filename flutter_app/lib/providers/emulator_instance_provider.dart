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

  /// Fetch all instances from backend. Also (re)connects the status
  /// WebSocket so subsequent state changes — boot progress, starting →
  /// running, stop — arrive as live pushes instead of never showing up.
  /// Previously the WS connection was opt-in (the screen had to call
  /// `connectStatusUpdates` after fetch), and nothing called it, so the
  /// status column was stuck on whatever fetch returned. Now fetch is
  /// the canonical "subscribe to status updates" entry point.
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
      // Re-subscribe so newly-created or newly-started instances are
      // watched too. connectStatusUpdates closes any existing socket
      // before opening a new one, so this is safe to call repeatedly.
      unawaited(connectStatusUpdates());
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
      // The new instance needs a WS subscription too; otherwise its
      // boot progress / running state would never reach the UI. The
      // re-subscribe closes the existing socket and opens a new one
      // carrying the fresh id list.
      unawaited(connectStatusUpdates());
      return instance;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Start an instance. The backend's start endpoint only returns the
  /// mutable fields (status, pid, ports, boot progress, lastError,
  /// logPath) — not the immutable identity (avdName, imageId, config,
  /// createdAt, avdPath, ...). Previously we replaced the whole local
  /// instance with the start payload, which silently zeroed out the
  /// name and config and made the card show an empty title. Now we
  /// patch only the fields the backend actually sent, keeping the
  /// identity intact.
  Future<void> startInstance(String id) async {
    _error = null;

    try {
      final response = await _api.dio.post(
        '/api/emulator/instance/start',
        queryParameters: {'id': id},
      );
      final data = _api.responseMap(response);
      final patch = EmulatorInstance.fromJson(data);
      final index = _instances.indexWhere((i) => i.id == id);
      if (index >= 0) {
        _instances[index] = _instances[index].copyWith(
          status: patch.status,
          pid: patch.pid,
          serial: patch.serial,
          consolePort: patch.consolePort,
          adbPort: patch.adbPort,
          bootStage: patch.bootStage,
          bootProgress: patch.bootProgress,
          bootMessage: patch.bootMessage,
        );
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
        queryParameters: {'id': id, 'confirm': 'true'},
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

  /// Connect to WebSocket for real-time status updates. Always (re-)
  /// subscribes — including when the instance list is empty — so the
  /// socket is up before the user creates or starts an instance.
  /// Without this, instance boot progress / starting → running pushes
  /// silently go nowhere.
  Future<void> connectStatusUpdates() async {
    final ids = _instances.map((i) => i.id).toList();
    _ws?.close();

    try {
      final newWs = await WebSocket.connect(_getStatusWebSocketUrl(ids));
      _ws = newWs;
      newWs.listen(
        (data) {
          final update = jsonDecode(data as String) as Map<String, dynamic>;
          _handleStatusUpdate(update);
        },
        // ponytail: root-cause fix for the M9 reconnect race. When
        // connectStatusUpdates is called twice in quick succession (e.g.
        // fetch → close old → open new → add() → close new → open newer),
        // the OLD socket's onDone/onError would fire on a socket we
        // already abandoned, see `_ws == null`, and queue another
        // connect that stomps on the latest one. Gate callbacks on
        // "am I still the active socket?" — if a newer connect already
        // took over, drop the event silently.
        onError: (e) {
          debugPrint('WebSocket error: $e');
          if (_ws != newWs) return;
          Future.delayed(const Duration(seconds: 5), connectStatusUpdates);
        },
        onDone: () {
          if (_ws != newWs) return;
          Future.delayed(const Duration(seconds: 5), connectStatusUpdates);
        },
      );
    } catch (e) {
      debugPrint('Failed to connect WebSocket: $e');
    }
  }

  String _getStatusWebSocketUrl(List<String> instanceIds) {
    final ids = instanceIds.join(',');
    // _api.baseUrl is an http(s) URL like "http://127.0.0.1:9876" — we
    // can't just prepend "ws://", that yields "ws://http://..." and
    // the hostname becomes the literal string "http". Swap the scheme
    // instead so the host:port survive intact. Handles both http and
    // https → ws / wss.
    final wsBase = _api.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    return '$wsBase/ws/emulator/status?id=$ids';
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

    // The backend's 5s pollStatus loop sends pid/serial/lastStart
    // inside a nested `data` object (see status_monitor.go
    // checkAndBroadcastStatus). Pull them out so we don't overwrite
    // a known pid with null just because this particular push
    // didn't include one at the top level.
    final data = update['data'] as Map<String, dynamic>?;
    final pid = (update['pid'] as int?) ?? (data?['pid'] as int?);

    _instances[index] = _instances[index].copyWith(
      status: status,
      pid: pid,
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
