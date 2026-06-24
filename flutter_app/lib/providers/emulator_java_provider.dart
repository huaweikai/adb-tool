// Emulator Java runtime provider.
// Manages Java runtime detection, validation, and download.
import 'dart:async';
import 'package:flutter/foundation.dart';
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

  JavaRuntimeStatus? _status;
  JavaStatus _javaStatus = JavaStatus.unknown;
  String? _errorMessage;
  Timer? _progressPoller;
  String? _currentDownloadId;

  StreamSubscription? _statusPoller;

  EmulatorJavaProvider({required ApiClient api}) : _api = api;

  JavaRuntimeStatus? get status => _status;
  JavaStatus get javaStatus => _javaStatus;
  String? get errorMessage => _errorMessage;
  String? get currentDownloadId => _currentDownloadId;

  bool get hasJava => _status?.hasJava == true;
  bool get isDownloading => _currentDownloadId != null;

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

  /// Start downloading a Java runtime
  Future<bool> download({
    required String url,
    required String id,
    String? sha256,
    String? name,
  }) async {
    try {
      final result = await _api.downloadJava(
        url: url,
        id: id,
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
