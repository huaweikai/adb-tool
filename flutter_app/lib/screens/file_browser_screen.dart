import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../services/drop_target.dart';
import '../models/file_item.dart';
import '../services/api_client.dart';
import '../i18n.dart';

enum _SortKey { name, date, size }

enum _TransferMode { upload, download }

class _TransferState {
  final _TransferMode mode;
  final String fileName;
  final int sent;
  final int total;
  final String phaseKey;

  const _TransferState({
    required this.mode,
    required this.fileName,
    required this.sent,
    required this.total,
    required this.phaseKey,
  });

  bool get waitingForAdb =>
      phaseKey == 'deviceReading' || phaseKey == 'deviceWriting';

  double? get progress => total > 0 && !waitingForAdb ? sent / total : null;
}

class FileBrowserScreen extends StatefulWidget {
  final ApiClient api;
  final String? selectedSerial;

  const FileBrowserScreen({
    super.key,
    required this.api,
    required this.selectedSerial,
  });

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  String trPhase(String phaseKey) =>
      tr('phase${phaseKey[0].toUpperCase()}${phaseKey.substring(1)}');

  List<FileItem> _files = [];
  String _currentPath = '/';
  bool _loading = false;
  String? _error;
  final List<String> _history = [];
  String? _fileContent;
  String _contentPath = '';

  bool _gridMode = false;
  bool _dragOver = false;
  _SortKey _sortKey = _SortKey.name;
  bool _sortAsc = true;

  bool _recording = false;
  bool _recordSaving = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  bool _screenshotting = false;
  _TransferState? _transfer;
  TransferCancelToken? _transferCancelToken;

  bool get _isTransferring => _transfer != null;

  static const _quickPaths = [
    ('/', 'root'),
    ('/sdcard', 'sd'),
    ('/storage/emulated/0', 'storage'),
    ('/data/local/tmp', 'tmp'),
  ];

  @override
  void didUpdateWidget(FileBrowserScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSerial != widget.selectedSerial) {
      _currentPath = '/';
      _history.clear();
      _fileContent = null;
      _contentPath = '';
      _loadFiles();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  String get _sortLabel {
    final base = _sortKey == _SortKey.name
        ? tr('name')
        : _sortKey == _SortKey.date
            ? tr('modified')
            : tr('size');
    return '$base${_sortAsc ? " ↑" : " ↓"}';
  }

  List<FileItem> _sorted(List<FileItem> files) {
    final sorted = List<FileItem>.from(files);
    sorted.sort((a, b) {
      int cmp;
      if (a.isDir && !b.isDir) return -1;
      if (!a.isDir && b.isDir) return 1;
      switch (_sortKey) {
        case _SortKey.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _SortKey.date:
          cmp = a.modified.compareTo(b.modified);
        case _SortKey.size:
          cmp = a.size.compareTo(b.size);
          if (cmp == 0) {
            cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }
      }
      return _sortAsc ? cmp : -cmp;
    });
    return sorted;
  }

  void _navigateTo(String path) {
    if (_isTransferring) return;
    setState(() {
      _history.add(_currentPath);
      _currentPath = path;
    });
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    if (_isTransferring) return;
    if (widget.selectedSerial == null) {
      setState(() {
        _files = [];
        _error = tr('selectDevice');
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _fileContent = null;
      _contentPath = '';
    });
    try {
      final files =
          await widget.api.listFiles(widget.selectedSerial!, _currentPath);
      if (!mounted) return;
      setState(() {
        _files = _sorted(files);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _enterDir(FileItem dir) async {
    if (_isTransferring) return;
    if (widget.selectedSerial == null) return;
    setState(() {
      _history.add(_currentPath);
      _currentPath = dir.path;
      _loading = true;
      _error = null;
    });
    try {
      final files =
          await widget.api.listFiles(widget.selectedSerial!, _currentPath);
      if (!mounted) return;
      setState(() {
        _files = _sorted(files);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currentPath = _history.removeLast();
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('accessDenied', {'name': dir.name})),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _goUp() {
    if (_isTransferring) return;
    if (_history.isEmpty) return;
    setState(() {
      _currentPath = _history.removeLast();
    });
    _loadFiles();
  }

  void _goHome() {
    if (_isTransferring) return;
    setState(() {
      _history.clear();
      _currentPath = '/';
    });
    _loadFiles();
  }

  Future<void> _viewFile(FileItem file) async {
    if (_isTransferring) return;
    if (widget.selectedSerial == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final content =
          await widget.api.readFile(widget.selectedSerial!, file.path);
      if (!mounted) return;
      setState(() {
        _fileContent = content;
        _contentPath = file.path;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _downloadFile(FileItem file) async {
    if (_isTransferring) return;
    if (widget.selectedSerial == null) return;
    TransferCancelToken? cancelToken;
    String? localPath;
    try {
      final location = await getSaveLocation(
        suggestedName: file.name,
        confirmButtonText: tr('save'),
      );
      if (location == null) return;
      localPath = location.path;
      cancelToken = TransferCancelToken();
      _transferCancelToken = cancelToken;
      setState(() {
        _transfer = _TransferState(
          mode: _TransferMode.download,
          fileName: file.name,
          sent: 0,
          total: 0,
          phaseKey: 'deviceReading',
        );
      });
      await widget.api.downloadFileToPath(
        widget.selectedSerial!,
        file.path,
        location.path,
        totalBytes: file.size,
        cancelToken: cancelToken,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _transfer = _TransferState(
              mode: _TransferMode.download,
              fileName: file.name,
              sent: progress.sent,
              total: progress.total,
              phaseKey: progress.total > 0 && progress.sent >= progress.total
                  ? 'writingFile'
                  : 'downloading',
            );
          });
        },
      );
      if (!mounted) return;
      _transferCancelToken = null;
      setState(() => _transfer = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr('savedTo', {'path': location.path})),
            behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      if (e is TransferCanceledException || cancelToken?.canceled == true) {
        try {
          if (localPath != null) {
            final partial = File(localPath);
            if (await partial.exists()) await partial.delete();
          }
        } catch (_) {}
        if (!mounted) return;
        _transferCancelToken = null;
        setState(() => _transfer = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr('downloadCancelled')),
              behavior: SnackBarBehavior.floating),
        );
        return;
      }
      _transferCancelToken = null;
      setState(() => _transfer = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${tr('downloadFailed')}: $e'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _uploadFile() async {
    if (_isTransferring) return;
    if (widget.selectedSerial == null) return;
    final result = await openFile(confirmButtonText: tr('upload'));
    if (result == null) return;
    final remotePath = _currentPath.endsWith('/')
        ? '$_currentPath${result.name}'
        : '$_currentPath/${result.name}';
    final totalBytes = await result.length();
    final cancelToken = TransferCancelToken();
    try {
      _transferCancelToken = cancelToken;
      setState(() {
        _transfer = _TransferState(
          mode: _TransferMode.upload,
          fileName: result.name,
          sent: 0,
          total: totalBytes,
          phaseKey: 'preparing',
        );
      });
      await widget.api.pushLocalFile(
        widget.selectedSerial!,
        remotePath,
        result.path,
        cancelToken: cancelToken,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _transfer = _TransferState(
              mode: _TransferMode.upload,
              fileName: result.name,
              sent: progress.sent,
              total: progress.total,
              phaseKey: progress.total > 0 && progress.sent >= progress.total
                  ? 'deviceWriting'
                  : 'uploading',
            );
          });
        },
      );
      if (!mounted) return;
      _transferCancelToken = null;
      setState(() => _transfer = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr('uploadedTo', {'path': remotePath})),
            behavior: SnackBarBehavior.floating),
      );
      _loadFiles();
    } catch (e) {
      if (!mounted) return;
      if (e is TransferCanceledException || cancelToken.canceled) {
        if (!mounted) return;
        _transferCancelToken = null;
        setState(() => _transfer = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr('uploadCancelled')),
              behavior: SnackBarBehavior.floating),
        );
        return;
      }
      _transferCancelToken = null;
      setState(() => _transfer = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${tr('uploadFailed')}: $e'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _cancelTransfer() {
    _transferCancelToken?.cancel();
  }

  Future<void> _startRecording() async {
    if (widget.selectedSerial == null) return;
    if (_recordSaving || _recording) return;
    try {
      await widget.api.screenRecordAction(widget.selectedSerial!, 'start');
      if (!mounted) return;
      setState(() {
        _recording = true;
        _recordSaving = false;
        _recordSeconds = 0;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSeconds++);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr('recordingStarted')),
            behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${tr('recordingFailed')}: $e'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _stopRecording() async {
    if (widget.selectedSerial == null) return;
    if (_recordSaving || !_recording) return;
    _recordTimer?.cancel();
    setState(() => _recordSaving = true);
    try {
      await widget.api.screenRecordAction(widget.selectedSerial!, 'stop');
      if (!mounted) return;
      final location = await getSaveLocation(
        suggestedName:
            'screen-record-${DateTime.now().millisecondsSinceEpoch}.mp4',
        confirmButtonText: tr('saveRecording'),
      );
      if (location == null) {
        setState(() {
          _recording = false;
          _recordSaving = false;
          _recordSeconds = 0;
        });
        return;
      }
      final bytes = await widget.api.pullRecordedVideo(widget.selectedSerial!);
      await File(location.path).writeAsBytes(bytes);
      if (!mounted) return;
      setState(() {
        _recording = false;
        _recordSaving = false;
        _recordSeconds = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr('recordingSaved', {'path': location.path})),
            behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _recording = false;
        _recordSaving = false;
        _recordSeconds = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${tr('recordingStopFailed')}: $e'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _takeScreenshot() async {
    if (widget.selectedSerial == null || _screenshotting) return;
    setState(() => _screenshotting = true);
    try {
      final b64 = await widget.api.takeScreenshot(widget.selectedSerial!);
      if (b64 == null) {
        if (!mounted) return;
        setState(() => _screenshotting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr('screenshotFailed')),
              behavior: SnackBarBehavior.floating),
        );
        return;
      }
      if (!mounted) return;
      final location = await getSaveLocation(
        suggestedName:
            'screenshot-${DateTime.now().millisecondsSinceEpoch}.png',
        confirmButtonText: tr('saveScreenshot'),
      );
      if (location == null) {
        setState(() => _screenshotting = false);
        return;
      }
      final bytes = base64Decode(b64);
      await File(location.path).writeAsBytes(bytes);
      if (!mounted) return;
      setState(() => _screenshotting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr('screenshotSaved', {'path': location.path})),
            behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _screenshotting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${tr('screenshotFailed')}: $e'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  String _formatSeconds(int total) {
    final m = total ~/ 60;
    final s = total % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    if (unit == 0) return '$bytes ${units[unit]}';
    return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unit]}';
  }

  Future<void> _onDropFile(DropDoneDetails details) async {
    if (_isTransferring) return;
    if (widget.selectedSerial == null) return;
    if (mounted) setState(() => _dragOver = false);
    for (final file in details.files) {
      final remotePath = _currentPath.endsWith('/')
          ? '$_currentPath${file.name}'
          : '$_currentPath/${file.name}';
      final totalBytes = await file.length();
      final cancelToken = TransferCancelToken();
      try {
        _transferCancelToken = cancelToken;
        setState(() {
          _transfer = _TransferState(
            mode: _TransferMode.upload,
            fileName: file.name,
            sent: 0,
            total: totalBytes,
            phaseKey: 'preparing',
          );
        });
        await widget.api.pushLocalFile(
          widget.selectedSerial!,
          remotePath,
          file.path,
          cancelToken: cancelToken,
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _transfer = _TransferState(
                mode: _TransferMode.upload,
                fileName: file.name,
                sent: progress.sent,
                total: progress.total,
                phaseKey: progress.total > 0 && progress.sent >= progress.total
                    ? 'deviceWriting'
                    : 'uploading',
              );
            });
          },
        );
        if (!mounted) return;
        if (!mounted) return;
        _transferCancelToken = null;
        setState(() => _transfer = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('uploadedTo', {'path': remotePath})),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        if (e is TransferCanceledException || cancelToken.canceled) {
          _transferCancelToken = null;
          setState(() => _transfer = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('uploadCancelled')),
              behavior: SnackBarBehavior.floating,
            ),
          );
          break;
        }
        if (!mounted) return;
        _transferCancelToken = null;
        setState(() => _transfer = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('uploadFailed')}: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    _loadFiles();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedSerial == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(tr('selectDeviceSidebar'),
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_fileContent != null) {
      return _buildFileViewer();
    }

    return DropTarget(
      onDragEntered: () {
        if (_isTransferring) return;
        setState(() => _dragOver = true);
      },
      onDragExited: () {
        if (_isTransferring) return;
        setState(() => _dragOver = false);
      },
      onDragDone: _onDropFile,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPathBar(),
              if (_loading)
                const Expanded(
                    child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                Expanded(
                    child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 8),
                      Text(_error!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12)),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                          onPressed: _loadFiles, child: Text(tr('retry'))),
                    ],
                  ),
                ))
              else
                Expanded(
                    child: _gridMode ? _buildGridView() : _buildFileList()),
            ],
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_dragOver,
              child: AnimatedOpacity(
                opacity: _dragOver ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: _buildDragOverlay(),
              ),
            ),
          ),
          if (_transfer != null)
            Positioned.fill(
              child: _buildTransferOverlay(_transfer!),
            ),
        ],
      ),
    );
  }

  Widget _buildDragOverlay() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.primary, width: 3),
      ),
      child: Container(
        color: theme.colorScheme.primary.withAlpha(30),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_upload,
                  size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(tr('dropHintFile', {'path': _currentPath}),
                  style: TextStyle(
                      fontSize: 16, color: theme.colorScheme.primary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransferOverlay(_TransferState transfer) {
    final theme = Theme.of(context);
    final isUpload = transfer.mode == _TransferMode.upload;
    final progress = transfer.progress;
    final percent = progress == null
        ? tr('processing')
        : '${(progress * 100).clamp(0, 100).toStringAsFixed(1)}%';
    return AbsorbPointer(
      absorbing: false,
      child: Container(
        color: theme.colorScheme.scrim.withAlpha(80),
        child: Center(
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(isUpload ? Icons.upload_file : Icons.download,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isUpload ? tr('uploadingFile') : tr('downloadingFile'),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(percent,
                        style: const TextStyle(
                            fontFamily: 'Menlo', fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  transfer.fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
                ),
                const SizedBox(height: 12),
                progress == null
                    ? const LinearProgressIndicator()
                    : LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0).toDouble()),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        trPhase(transfer.phaseKey),
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    Text(
                      '${_formatBytes(transfer.sent)} / ${transfer.total > 0 ? _formatBytes(transfer.total) : tr('unknownSize')}',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Menlo',
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  tr('transferWarning'),
                  style: TextStyle(
                      fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: _cancelTransfer,
                    icon: const Icon(Icons.close, size: 16),
                    label: Text(tr('cancel')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPathBar() {
    final theme = Theme.of(context);
    final parts = _currentPath.split('/').where((p) => p.isNotEmpty).toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.home, size: 20),
            onPressed: _isTransferring ? null : _goHome,
            tooltip: tr('rootDir'),
          ),
          const SizedBox(width: 4),
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.arrow_upward, size: 20),
              onPressed: _isTransferring ? null : _goUp,
              tooltip: tr('parentDir'),
            ),
          const SizedBox(width: 4),
          for (final qp in _quickPaths) _quickBtn(qp.$1, tr(qp.$2)),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < parts.length; i++) ...[
                    if (i > 0)
                      const Icon(Icons.chevron_right,
                          size: 14, color: Colors.grey),
                    GestureDetector(
                      onTap: !_isTransferring && i < parts.length - 1
                          ? () {
                              final path =
                                  '/${parts.sublist(0, i + 1).join('/')}';
                              _navigateTo(path);
                            }
                          : null,
                      child: Text(
                        parts[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Menlo',
                          fontWeight: i == parts.length - 1
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: i == parts.length - 1
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          !_gridMode ? _sortBtn() : const SizedBox.shrink(),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(_gridMode ? Icons.list : Icons.grid_view, size: 20),
            onPressed: _isTransferring
                ? null
                : () => setState(() => _gridMode = !_gridMode),
            tooltip: _gridMode ? tr('listMode') : tr('gridMode'),
          ),
          const SizedBox(width: 4),
          _recordSaving
              ? FilledButton.tonal(
                  onPressed: null,
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 6),
                      Text(tr('saving')),
                    ],
                  ),
                )
              : _recording
                  ? _buildRecordingBtn()
                  : FilledButton.tonal(
                      onPressed: _isTransferring ? null : _startRecording,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12),
                        backgroundColor: Colors.red.shade100,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.fiber_manual_record,
                              size: 16, color: Colors.red),
                          const SizedBox(width: 4),
                          Text(tr('record'),
                              style: const TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
          const SizedBox(width: 4),
          FilledButton.tonal(
            onPressed:
                _screenshotting || _isTransferring ? null : _takeScreenshot,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: _screenshotting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt, size: 16),
                      const SizedBox(width: 4),
                      Text(tr('screenshot')),
                    ],
                  ),
          ),
          const SizedBox(width: 4),
          FilledButton.tonal(
            onPressed: _isTransferring ? null : _uploadFile,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.upload_file, size: 16),
                const SizedBox(width: 4),
                Text(tr('upload')),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _isTransferring ? null : _loadFiles,
            tooltip: tr('refresh'),
          ),
        ],
      ),
    );
  }

  Widget _quickBtn(String path, String label) {
    final isActive = _currentPath == path;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: isActive ? Theme.of(context).colorScheme.primaryContainer : null,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: isActive || _isTransferring ? null : () => _navigateTo(path),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(label,
                style: const TextStyle(fontSize: 11, fontFamily: 'Menlo')),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _transferCancelToken?.cancel();
    super.dispose();
  }

  Widget _buildRecordingBtn() {
    return FilledButton.tonal(
      onPressed: _recordSaving ? null : _stopRecording,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 12),
        backgroundColor: Colors.red.shade400,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stop, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(_formatSeconds(_recordSeconds),
              style: const TextStyle(color: Colors.white, fontFamily: 'Menlo')),
        ],
      ),
    );
  }

  Widget _sortBtn() {
    return PopupMenuButton<_SortKey>(
      onSelected: (key) {
        setState(() {
          if (_sortKey == key) {
            _sortAsc = !_sortAsc;
          } else {
            _sortKey = key;
            _sortAsc = true;
          }
          _files = _sorted(_files);
        });
      },
      tooltip: tr('sortLabel', {'label': _sortLabel}),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14),
            const SizedBox(width: 4),
            Text(_sortLabel, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
      itemBuilder: (ctx) => _SortKey.values.map((key) {
        final isCurrent = _sortKey == key;
        final labels = [tr('name'), tr('modified'), tr('size')];
        return PopupMenuItem(
          value: key,
          child: Row(
            children: [
              if (isCurrent)
                Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 16)
              else
                const SizedBox(width: 16),
              const SizedBox(width: 4),
              Text(labels[key.index],
                  style: TextStyle(
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFileList() {
    if (_files.isEmpty) {
      return Center(
          child:
              Text(tr('emptyDir'), style: const TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (ctx, i) => _buildFileRow(context, _files[i]),
    );
  }

  Widget _buildFileRow(BuildContext context, FileItem file) {
    final theme = Theme.of(context);
    final isText = _isTextFile(file.name);

    return InkWell(
      onTap: _isTransferring
          ? null
          : () {
              if (file.isDir) {
                _enterDir(file);
              } else if (isText) {
                _viewFile(file);
              }
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            Icon(
              file.isDir
                  ? Icons.folder
                  : (isText ? Icons.description : Icons.insert_drive_file),
              size: 18,
              color: file.isDir
                  ? Colors.amber.shade400
                  : theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                file.name,
                style: const TextStyle(fontSize: 12, fontFamily: 'Menlo'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 100,
              child: Text(
                file.modified,
                style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'Menlo',
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            if (file.sizeFormatted.isNotEmpty)
              SizedBox(
                width: 70,
                child: Text(
                  file.sizeFormatted,
                  style: TextStyle(
                      fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.end,
                ),
              ),
            if (!file.isDir) ...[
              const SizedBox(width: 4),
              _iconBtn(Icons.download, tr('downloadTooltip'),
                  _isTransferring ? null : () => _downloadFile(file)),
            ],
            if (file.isDir) ...[
              const SizedBox(width: 4),
              _iconBtn(Icons.upload, tr('uploadToDir'),
                  _isTransferring ? null : _uploadFile),
            ],
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback? onTap) {
    return IconButton(
      icon: Icon(icon, size: 16),
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      tooltip: tooltip,
    );
  }

  Widget _buildGridView() {
    if (_files.isEmpty) {
      return Center(
          child:
              Text(tr('emptyDir'), style: const TextStyle(color: Colors.grey)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 0.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _files.length,
      itemBuilder: (ctx, i) => _buildFileGridItem(context, _files[i]),
    );
  }

  Widget _buildFileGridItem(BuildContext context, FileItem file) {
    final theme = Theme.of(context);
    final isText = _isTextFile(file.name);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _isTransferring
            ? null
            : () {
                if (file.isDir) {
                  _enterDir(file);
                } else if (isText) {
                  _viewFile(file);
                }
              },
        onLongPress:
            _isTransferring ? null : () => _showFileMenu(context, file),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                file.isDir
                    ? Icons.folder
                    : (isText ? Icons.description : Icons.insert_drive_file),
                size: 28,
                color: file.isDir
                    ? Colors.amber.shade400
                    : theme.colorScheme.primary,
              ),
              const SizedBox(height: 6),
              Text(
                file.name,
                style: const TextStyle(fontSize: 10, fontFamily: 'Menlo'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              if (file.sizeFormatted.isNotEmpty)
                Text(
                  file.sizeFormatted,
                  style: TextStyle(
                      fontSize: 9, color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFileMenu(BuildContext context, FileItem file) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(file.name,
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            if (!file.isDir)
              ListTile(
                leading: const Icon(Icons.download),
                title: Text(tr('downloadTooltip')),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadFile(file);
                },
              ),
            if (file.isDir)
              ListTile(
                leading: const Icon(Icons.upload),
                title: Text(tr('uploadToDir')),
                onTap: () {
                  Navigator.pop(ctx);
                  _uploadFile();
                },
              ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(tr('details')),
              onTap: () {
                Navigator.pop(ctx);
                _showFileInfo(context, file);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showFileInfo(BuildContext context, FileItem file) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(file.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(tr('type'), file.isDir ? tr('directory') : tr('file')),
            _infoRow(tr('path'), file.path),
            if (!file.isDir) _infoRow(tr('size'), file.sizeFormatted),
            _infoRow(tr('permissions'), file.permissions),
            _infoRow(tr('modified'), file.modified),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(tr('close'))),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 80,
              child: Text('$label:',
                  style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 12, fontFamily: 'Menlo'))),
        ],
      ),
    );
  }

  bool _isTextFile(String name) {
    final ext = name.split('.').last.toLowerCase();
    return [
      'txt',
      'xml',
      'json',
      'html',
      'css',
      'js',
      'kt',
      'java',
      'py',
      'log',
      'cfg',
      'conf',
      'prop',
      'ini',
      'md',
      'csv',
      'yaml',
      'yml',
      'sh',
      'bat',
      'gradle',
      'pro'
    ].contains(ext);
  }

  Widget _buildFileViewer() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 18),
                onPressed: () => setState(() {
                  _fileContent = null;
                  _contentPath = '';
                }),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _contentPath,
                  style: const TextStyle(fontSize: 12, fontFamily: 'Menlo'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              _fileContent!,
              style: const TextStyle(
                  fontFamily: 'Menlo', fontSize: 11, height: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
