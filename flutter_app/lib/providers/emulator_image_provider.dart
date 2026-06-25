// Emulator image provider.
// Manages system image listing, download, and status.
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/emulator_image.dart';
import '../services/api_client.dart';
import '../services/api/emulator_image_api.dart';

enum ImageLoadingState {
  initial,
  loading,
  loaded,
  error,
}

class EmulatorImageProvider extends ChangeNotifier {
  final ApiClient _api;

  List<EmulatorImage> _images = [];
  List<ImageSource> _sources = [];
  ImageLoadingState _state = ImageLoadingState.initial;
  String? _errorMessage;
  Timer? _progressPoller;
  final Set<String> _activeDownloadIds = {};

  StreamSubscription? _refreshTimer;

  EmulatorImageProvider({required ApiClient api}) : _api = api;

  List<EmulatorImage> get images => _images;
  List<ImageSource> get sources => _sources;
  ImageLoadingState get state => _state;
  String? get errorMessage => _errorMessage;

  List<EmulatorImage> get readyImages =>
      _images.where((img) => img.status == EmulatorImageStatus.ready).toList();

  List<EmulatorImage> get downloadingImages =>
      _images.where((img) => img.status == EmulatorImageStatus.downloading).toList();

  /// Start polling images periodically
  void startPolling({Duration interval = const Duration(seconds: 10)}) {
    _refreshTimer?.cancel();
    _refreshTimer = Stream.periodic(interval).listen((_) => refreshImages());
  }

  void stopPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Refresh images from backend
  Future<void> refreshImages() async {
    try {
      debugPrint('[EmulatorImageProvider] refreshImages: fetching from backend...');
      final backendImages = await _api.getImages();
      debugPrint('[EmulatorImageProvider] refreshImages: got ${backendImages.length} image(s) from backend');
      for (final img in backendImages) {
        debugPrint('[EmulatorImageProvider]   - id=${img.id} status=${img.status} '
            'api=${img.apiLevel} arch=${img.arch} variant=${img.variant} path=${img.localPath}');
      }

      // Update images list, preserving download progress
      _images = backendImages.map((img) {
        // Find existing image to preserve UI state
        final existing = _images.where((e) => e.id == img.id).firstOrNull;
        if (existing != null && existing.isDownloading) {
          // Keep downloading state with progress
          return existing.copyWith(
            localPath: img.localPath,
            files: img.files,
            fileSize: img.fileSize,
            status: _mapStatus(img.status),
          );
        }
        return EmulatorImage(
          id: img.id,
          name: img.name,
          apiLevel: img.apiLevel,
          arch: img.arch,
          variant: img.variant,
          localPath: img.localPath,
          files: img.files,
          fileSize: img.fileSize,
          status: _mapStatus(img.status),
          downloadProgress: img.progress,
          createdAt: existing?.createdAt ?? DateTime.now(),
        );
      }).toList();

      // Check for completed downloads
      _checkCompletedDownloads();

      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      debugPrint('[EmulatorImageProvider] refreshImages error: $e');
      _state = ImageLoadingState.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Load images (initial load)
  Future<void> loadImages() async {
    debugPrint('[EmulatorImageProvider] loadImages: state=$_state');
    if (_state == ImageLoadingState.loading) return;

    _state = ImageLoadingState.loading;
    notifyListeners();

    await refreshImages();
    await loadSources();

    _state = _images.isNotEmpty
        ? ImageLoadingState.loaded
        : ImageLoadingState.initial;
    debugPrint('[EmulatorImageProvider] loadImages: done, '
        '${_images.length} image(s), ${_sources.length} source(s), state=$_state');
    notifyListeners();
  }

  /// Load the persisted image-source address book.
  Future<void> loadSources() async {
    try {
      _sources = await _api.getImageSources();
      notifyListeners();
    } catch (e) {
      debugPrint('[EmulatorImageProvider] loadSources error: $e');
    }
  }

  /// Add an image-source URL to the address book (dedup by URL on backend).
  Future<bool> addSource({
    required String url,
    String? name,
    int? apiLevel,
    String? arch,
    String? variant,
    String? sha256,
  }) async {
    try {
      _sources = await _api.addImageSource(
        url: url,
        name: name,
        apiLevel: apiLevel,
        arch: arch,
        variant: variant,
        sha256: sha256,
      );
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[EmulatorImageProvider] addSource error: $e');
      _errorMessage = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  /// Remove an image-source URL from the address book.
  Future<void> removeSource(String url) async {
    try {
      _sources = await _api.removeImageSource(url);
      notifyListeners();
    } catch (e) {
      debugPrint('[EmulatorImageProvider] removeSource error: $e');
    }
  }

  /// Add a new image for download.
  ///
  /// Only the URL is required: the downloaded archive is extracted into the
  /// cache directory and the backend scans it to determine the real API level,
  /// arch and variant, so those no longer need to be supplied by the UI.
  Future<bool> addImage({
    required String url,
    String? name,
    String? sha256,
  }) async {
    try {
      final displayName = (name != null && name.isNotEmpty)
          ? name
          : _nameFromUrl(url);
      final result = await _api.addImage(
        url: url,
        id: displayName,
        name: displayName,
        sha256: sha256,
      );

      if (result.error != null) {
        _errorMessage = result.error;
        notifyListeners();
        return false;
      }

      // Add to local list with downloading state
      final newImage = EmulatorImage(
        id: result.id,
        name: displayName,
        apiLevel: 0,
        arch: '',
        variant: '',
        sourceUrl: url,
        status: EmulatorImageStatus.downloading,
        downloadProgress: 0.0,
        createdAt: DateTime.now(),
      );

      _images.add(newImage);
      _activeDownloadIds.add(result.id);
      notifyListeners();

      // The backend persisted this URL in the address book; refresh our copy.
      await loadSources();

      // Start polling progress
      _startProgressPolling(result.id);

      return true;
    } catch (e) {
      debugPrint('[EmulatorImageProvider] addImage error: $e');
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Derives a human-friendly fallback name from a download URL (its last path
  /// segment, without extension).
  String _nameFromUrl(String url) {
    var name = url;
    final slash = name.lastIndexOf('/');
    if (slash >= 0 && slash < name.length - 1) {
      name = name.substring(slash + 1);
    }
    final dot = name.lastIndexOf('.');
    if (dot > 0) {
      name = name.substring(0, dot);
    }
    return name.isEmpty ? url : name;
  }

  /// Cancel download
  Future<void> cancelDownload(String id) async {
    try {
      await _api.cancelDownload(id);
      _activeDownloadIds.remove(id);

      // Update status
      final index = _images.indexWhere((img) => img.id == id);
      if (index >= 0) {
        _images[index] = _images[index].copyWith(
          status: EmulatorImageStatus.error,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[EmulatorImageProvider] cancelDownload error: $e');
    }
  }

  /// Import an image from a server-side local path (extracted directory or
  /// `.zip` archive). The backend scans the path, registers every image it
  /// finds, and returns the freshly registered entries; we just refresh
  /// the list afterwards so the UI sees the new entries.
  Future<bool> importFromPath(String path) async {
    try {
      debugPrint('[EmulatorImageProvider] importFromPath: path=$path');
      final imgs = await _api.importImageFromPath(path);
      debugPrint('[EmulatorImageProvider] importFromPath: backend returned ${imgs.length} image(s)');
      for (final img in imgs) {
        debugPrint('[EmulatorImageProvider]   - id=${img.id} api=${img.apiLevel} '
            'arch=${img.arch} variant=${img.variant} path=${img.localPath}');
      }
      await refreshImages();
      return true;
    } catch (e) {
      debugPrint('[EmulatorImageProvider] importFromPath error: $e');
      _errorMessage = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  /// Import an image from a local `.zip` file on the user's machine.
  Future<bool> importFromZip(String localPath) async {
    try {
      final imgs = await _api.importImageFromZip(localPath);
      debugPrint('[EmulatorImageProvider] importFromZip: backend returned ${imgs.length} image(s)');
      await refreshImages();
      return true;
    } catch (e) {
      debugPrint('[EmulatorImageProvider] importFromZip error: $e');
      _errorMessage = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  /// Extracts a human-friendly message from an API error, preferring the
  /// backend-provided `error` field (e.g. "image already exists at ...").
  String _extractError(Object e) {
    if (e is DioException) {
      final resp = e.response;
      if (resp != null) {
        final data = resp.data;
        if (data is Map && data['error'] != null) {
          return data['error'].toString();
        }
        try {
          final decoded = data is String ? jsonDecode(data) : data;
          if (decoded is Map && decoded['error'] != null) {
            return decoded['error'].toString();
          }
        } catch (_) {}
      }
      return e.message ?? e.toString();
    }
    return e.toString();
  }

  /// Delete an image
  Future<void> deleteImage(String id) async {
    // TODO: Implement backend API for deleting images
    _images.removeWhere((img) => img.id == id);
    notifyListeners();
  }

  void _checkCompletedDownloads() {
    for (final id in _activeDownloadIds.toList()) {
      final img = _images.where((e) => e.id == id).firstOrNull;
      if (img != null && img.status == EmulatorImageStatus.ready) {
        _activeDownloadIds.remove(id);
      }
    }
  }

  void _startProgressPolling(String id) {
    _progressPoller?.cancel();
    _progressPoller = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollProgress(id),
    );
  }

  Future<void> _pollProgress(String id) async {
    try {
      final progress = await _api.getDownloadProgress(id);

      // Update image progress
      final index = _images.indexWhere((img) => img.id == id);
      if (index >= 0) {
        final status = _mapDownloadStatus(progress.status);
        _images[index] = _images[index].copyWith(
          status: status,
          downloadProgress: progress.progress,
        );
        notifyListeners();

        if (progress.isComplete || progress.hasError) {
          _stopProgressPolling();
          if (progress.isComplete) {
            _activeDownloadIds.remove(id);
            // Refresh to get updated image info
            await refreshImages();
          }
        }
      }
    } catch (e) {
      debugPrint('[EmulatorImageProvider] pollProgress error: $e');
    }
  }

  void _stopProgressPolling() {
    _progressPoller?.cancel();
    _progressPoller = null;
  }

  EmulatorImageStatus _mapStatus(SystemImageStatus status) {
    switch (status) {
      case SystemImageStatus.ready:
        return EmulatorImageStatus.ready;
      case SystemImageStatus.downloading:
        return EmulatorImageStatus.downloading;
      case SystemImageStatus.error:
        return EmulatorImageStatus.error;
      case SystemImageStatus.pending:
        return EmulatorImageStatus.pending;
    }
  }

  EmulatorImageStatus _mapDownloadStatus(String status) {
    switch (status) {
      case 'completed':
        return EmulatorImageStatus.ready;
      case 'downloading':
        return EmulatorImageStatus.downloading;
      case 'error':
        return EmulatorImageStatus.error;
      default:
        return EmulatorImageStatus.pending;
    }
  }

  @override
  void dispose() {
    stopPolling();
    _stopProgressPolling();
    super.dispose();
  }
}
