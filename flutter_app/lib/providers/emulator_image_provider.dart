// Emulator image provider.
// Manages system image listing, download, and status.
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/emulator_image.dart';
import '../services/api_client.dart';

enum ImageLoadingState {
  initial,
  loading,
  loaded,
  error,
}

class EmulatorImageProvider extends ChangeNotifier {
  final ApiClient _api;

  List<EmulatorImage> _images = [];
  ImageLoadingState _state = ImageLoadingState.initial;
  String? _errorMessage;
  Timer? _progressPoller;
  final Set<String> _activeDownloadIds = {};

  StreamSubscription? _refreshTimer;

  EmulatorImageProvider({required ApiClient api}) : _api = api;

  List<EmulatorImage> get images => _images;
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
      final backendImages = await _api.getImages();

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
    if (_state == ImageLoadingState.loading) return;

    _state = ImageLoadingState.loading;
    notifyListeners();

    await refreshImages();

    _state = _images.isNotEmpty
        ? ImageLoadingState.loaded
        : ImageLoadingState.initial;
    notifyListeners();
  }

  /// Add a new image for download
  Future<bool> addImage({
    required String url,
    required String name,
    required int apiLevel,
    required String arch,
    String variant = 'google_apis',
    String? sha256,
  }) async {
    try {
      final result = await _api.addImage(
        url: url,
        id: '$apiLevel',
        name: name,
        sha256: sha256,
        apiLevel: apiLevel,
        arch: arch,
        variant: variant,
      );

      if (result.error != null) {
        _errorMessage = result.error;
        notifyListeners();
        return false;
      }

      // Add to local list with downloading state
      final newImage = EmulatorImage(
        id: result.id,
        name: name,
        apiLevel: apiLevel,
        arch: arch,
        variant: variant,
        sourceUrl: url,
        status: EmulatorImageStatus.downloading,
        downloadProgress: 0.0,
        createdAt: DateTime.now(),
      );

      _images.add(newImage);
      _activeDownloadIds.add(result.id);
      notifyListeners();

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
