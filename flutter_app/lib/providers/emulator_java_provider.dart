// Emulator Java runtime provider.
// Manages Java runtime detection, validation, and download.
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../db/database.dart';
import '../services/api_client.dart';

enum JavaStatus {
  unknown,
  checking,
  found,
  notFound,
  downloading,
  error,
}

class EmulatorJavaProvider extends ChangeNotifier {
  final ApiClient _api;
  final AppDatabase? _db;

  JavaRuntimeStatus? _status;
  JavaStatus _javaStatus = JavaStatus.unknown;
  String? _errorMessage;
  Timer? _progressPoller;
  String? _currentDownloadId;

  StreamSubscription? _statusPoller;

  EmulatorJavaProvider({required ApiClient api, AppDatabase? db})
      : _api = api,
        _db = db;

  JavaRuntimeStatus? get status => _status;
  JavaStatus get javaStatus => _javaStatus;
  String? get errorMessage => _errorMessage;
  String? get currentDownloadId => _currentDownloadId;

  bool get hasJava => _status?.hasJava == true;
  bool get isDownloading => _currentDownloadId != null;

  List<JavaRuntimeInfo> get runtimes => _status?.runtimes ?? const [];
  String? get selectedPath => _status?.selectedPath;
  bool get selectedInvalid => _status?.selectedInvalid ?? false;

  double get downloadProgress {
    if (_currentDownloadId == null) return 0.0;
    final download = _status?.downloads
        .where((d) => d.id == _currentDownloadId)
        .firstOrNull;
    return download?.progress ?? 0.0;
  }

  /// Start polling Java status periodically
  void startPolling({Duration interval = const Duration(seconds: 5)}) {
    _statusPoller?.cancel();
    _statusPoller = Stream.periodic(interval).listen((_) => refreshStatus());
  }

  void stopPolling() {
    _statusPoller?.cancel();
    _statusPoller = null;
  }

  /// Refresh Java runtime status from backend
  Future<void> refreshStatus() async {
    try {
      final status = await _api.getJavaStatus();
      _status = status;

      if (status.isFound) {
        _javaStatus = JavaStatus.found;
      } else if (status.systemJava != null) {
        _javaStatus = JavaStatus.found;
      } else {
        _javaStatus = JavaStatus.notFound;
      }

      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      debugPrint('[EmulatorJavaProvider] refreshStatus error: $e');
      _javaStatus = JavaStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Validate a specific Java path
  Future<bool> validate(String javaPath) async {
    _javaStatus = JavaStatus.checking;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _api.validateJava(javaPath);
      if (result.valid) {
        _javaStatus = JavaStatus.found;
        await refreshStatus();
        return true;
      } else {
        _javaStatus = JavaStatus.notFound;
        _errorMessage = result.error ?? 'Java validation failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('[EmulatorJavaProvider] validate error: $e');
      _javaStatus = JavaStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Select a Java runtime to use (persisted on the backend and locally in DB)
  Future<bool> select(String javaPath) async {
    _javaStatus = JavaStatus.checking;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _api.selectJava(javaPath);
      if (result.selected) {
        // Persist to local DB
        await _db?.appStatesDao.updateAppState(selectedJavaPath: javaPath);
        await refreshStatus();
        return true;
      } else {
        _errorMessage = result.error ?? 'Java selection failed';
        await refreshStatus();
        return false;
      }
    } catch (e) {
      debugPrint('[EmulatorJavaProvider] select error: $e');
      _javaStatus = JavaStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Restore the previously selected Java path from local DB.
  /// Call this on app startup after backend is ready.
  Future<bool> restoreFromDB() async {
    if (_db == null) return false;

    final savedPath = await _db!.appStatesDao.getSelectedJavaPath();
    if (savedPath == null || savedPath.isEmpty) return false;

    debugPrint('[EmulatorJavaProvider] Restoring Java path from DB: $savedPath');
    return await select(savedPath);
  }

  /// Start downloading a Java runtime. Pass either an explicit [url], or
  /// leave it null and set [version] to let the backend pick a default
  /// Adoptium Temurin build.
  Future<bool> download({
    required String id,
    String? url,
    String? version,
    String? sha256,
    String? name,
  }) async {
    try {
      final result = await _api.downloadJava(
        id: id,
        url: url,
        version: version,
        sha256: sha256,
        name: name,
      );

      if (result.error != null) {
        _errorMessage = result.error;
        _javaStatus = JavaStatus.error;
        notifyListeners();
        return false;
      }

      _currentDownloadId = result.id;
      _javaStatus = JavaStatus.downloading;
      notifyListeners();

      // Start polling progress
      _startProgressPolling(result.id);

      return true;
    } catch (e) {
      debugPrint('[EmulatorJavaProvider] download error: $e');
      _javaStatus = JavaStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Import a Java runtime from a local `.zip` archive. The backend
  /// streams the file, extracts it into the managed runtime dir and
  /// validates that the resulting `bin/java` actually runs.
  Future<bool> importJava({
    required String id,
    required String localPath,
  }) async {
    _javaStatus = JavaStatus.checking;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _api.importJava(id: id, localPath: localPath);
      if (!result.success) {
        _javaStatus = JavaStatus.error;
        _errorMessage = result.error ?? 'Java import failed';
        notifyListeners();
        return false;
      }
      await refreshStatus();
      return true;
    } catch (e) {
      debugPrint('[EmulatorJavaProvider] importJava error: $e');
      _javaStatus = JavaStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete a managed Java runtime by id. No-op for system / detected
  /// runtimes — the backend only ever touches its own java-runtime dir.
  Future<bool> deleteJava(String id) async {
    try {
      await _api.deleteJava(id);
      // If the deleted runtime was the active selection, clear it locally
      // so the next status poll doesn't keep the stale path around.
      if (_status?.selectedPath != null && _status!.selectedPath!.contains(id)) {
        await _db?.appStatesDao.updateAppState(clearJavaPath: true);
      }
      await refreshStatus();
      return true;
    } catch (e) {
      debugPrint('[EmulatorJavaProvider] deleteJava error: $e');
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Cancel ongoing download
  Future<void> cancelDownload() async {
    if (_currentDownloadId == null) return;

    try {
      await _api.cancelDownload(_currentDownloadId!);
      _stopProgressPolling();
      _currentDownloadId = null;
      _javaStatus = JavaStatus.notFound;
      notifyListeners();
    } catch (e) {
      debugPrint('[EmulatorJavaProvider] cancelDownload error: $e');
    }
  }

  void _startProgressPolling(String id) {
    _progressPoller?.cancel();
    _progressPoller = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _pollProgress(id),
    );
  }

  void _stopProgressPolling() {
    _progressPoller?.cancel();
    _progressPoller = null;
  }

  Future<void> _pollProgress(String id) async {
    try {
      final progress = await _api.getDownloadProgress(id);

      // Update status
      await refreshStatus();

      if (progress.isComplete) {
        _stopProgressPolling();
        _currentDownloadId = null;
        _javaStatus = JavaStatus.found;
        notifyListeners();
      } else if (progress.hasError) {
        _stopProgressPolling();
        _currentDownloadId = null;
        _javaStatus = JavaStatus.error;
        _errorMessage = progress.error;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[EmulatorJavaProvider] pollProgress error: $e');
    }
  }

  @override
  void dispose() {
    stopPolling();
    _stopProgressPolling();
    super.dispose();
  }
}
