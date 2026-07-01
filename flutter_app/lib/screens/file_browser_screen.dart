import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:provider/provider.dart';

import '../db/database.dart';
import '../db/dao/saved_devices_dao.dart';
import '../services/drop_target.dart';
import '../models/file_item.dart';
import '../services/api_client.dart';
import '../i18n.dart';
import '../widgets/loading_view.dart';
import '../widgets/error_view.dart';
import '../widgets/file_transfer.dart';
import '../widgets/safe_dialog.dart';
import '../widgets/transfer_progress_overlay.dart';
import '../widgets/file_sheet_actions.dart';
import '../widgets/info_row.dart';
import '../widgets/offline_guard.dart';
import '../mixins/file_browser_capture_mixin.dart';
import '../providers/test_session_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/device_provider.dart';
import '../providers/test_config_provider.dart';

enum _SortKey { name, date, size }

enum _FileAction {
  open,
  download,
  uploadToDir,
  copyPath,
  rename,
  delete,
  newFile,
  newFolder,
  details,
}

class FileBrowserScreen extends StatefulWidget {
  const FileBrowserScreen({
    super.key,
  });

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen>
    with FileBrowserCaptureMixin<FileBrowserScreen> {
  /// Stable device identity (ro.serialno). Survives reconnects —
  /// handed to `ApiClient` directly; the API boundary resolves
  /// it to the current adb address on demand.
  String? get _selectedSerial => context.read<DeviceSerialScope>().serial;

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

  static const _quickPaths = [
    ('/', 'root'),
    ('/storage/emulated/0', 'storage'),
    ('/sdcard/Android/data', 'sandbox'),
    ('/data/local/tmp', 'tmp'),
  ];

  @override
  void initState() {
    super.initState();
    screenshotting = false;
    initScreenRecordState();
    _loadFiles();
  }

  // ── FileBrowserCaptureMixin 实现 ─────────────────────────────
  @override
  ApiClient get apiClient => context.read<ApiClient>();
  @override
  TestSessionProvider get sessionProvider =>
      context.read<TestSessionProvider>();
  @override
  SavedDevicesDao get savedDevicesDao =>
      context.read<AppDatabase>().savedDevicesDao;
  @override
  String? get serial => _selectedSerial;

  @override
  Future<void> onScreenshotSaved(Uint8List bytes, String? localPath) async {
    // The mixin has already shown the save dialog and written the file
    // (when localPath != null). Only confirm with a snackbar here —
    // showing another getSaveLocation would pop the dialog a second
    // time. If the user cancelled in the mixin's dialog, localPath is
    // null and there is nothing to confirm.
    if (localPath == null) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('savedTo', {'path': localPath})),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Future<void> onVideoSaved(Uint8List bytes) async {
    // The in-app preview is disabled (see lib/widgets/video_preview.dart).
    // Hand the bytes straight to the user: pop a save-location picker
    // and write the file. If the user cancels, the bytes are dropped
    // (the backend's recording is already saved on-device under its
    // own folder).
    if (bytes.isEmpty) return;
    if (!mounted) return;
    final location = await getSaveLocation(
      suggestedName: 'screen-record-${DateTime.now().millisecondsSinceEpoch}.mp4',
      confirmButtonText: tr('saveRecording'),
    );
    if (location == null) return;
    await File(location.path).writeAsBytes(bytes);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('recordingSaved', {'path': location.path})),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 传输中状态（mixin 需要通过它判断是否可以开始录屏/截图）
  TransferState? _transfer;
  TransferCancelToken? _transferCancelToken;

  // ── mixin 字段 ────────────────────────────────────────────────
  // No local screen-record fields. All of recording / recordSaving /
  // recordSeconds / recordTimer are derived from recordState.stateOf
  // inside the mixin, so navigating away and back does not reset the
  // in-flight recording.
  @override
  late bool screenshotting;

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
    if (isTransferring) return;
    setState(() {
      _history.add(_currentPath);
      _currentPath = path;
    });
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    if (isTransferring) return;
    if (_selectedSerial == null) {
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
      final files = await context
          .read<ApiClient>()
          .listFiles(_selectedSerial ?? '', _currentPath);
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
    if (isTransferring) return;
    if (_selectedSerial == null) return;
    setState(() {
      _history.add(_currentPath);
      _currentPath = dir.path;
      _loading = true;
      _error = null;
    });
    try {
      final files = await context
          .read<ApiClient>()
          .listFiles(_selectedSerial ?? '', _currentPath);
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
    if (isTransferring) return;
    if (_history.isEmpty) return;
    setState(() {
      _currentPath = _history.removeLast();
    });
    _loadFiles();
  }

  void _goHome() {
    if (isTransferring) return;
    setState(() {
      _history.clear();
      _currentPath = '/';
    });
    _loadFiles();
  }

  Future<void> _viewFile(FileItem file) async {
    if (isTransferring) return;
    if (_selectedSerial == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final content =
          await context.read<ApiClient>().readFile(_selectedSerial ?? '', file.path);
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
    if (isTransferring) return;
    final deviceSerial = _selectedSerial;
    if (deviceSerial == null) return;
    final api = context.read<ApiClient>();
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
        _transfer = TransferState(
          mode: TransferMode.download,
          fileName: file.name,
          sent: 0,
          total: 0,
          phaseKey: 'deviceReading',
        );
        isTransferring = true;
      });
      await api.downloadFileToPath(
        deviceSerial,
        file.path,
        location.path,
        totalBytes: file.size,
        cancelToken: cancelToken,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _transfer = TransferState(
              mode: TransferMode.download,
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
      setState(() {
        _transfer = null;
        isTransferring = false;
      });
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
        setState(() {
          _transfer = null;
          isTransferring = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr('downloadCancelled')),
              behavior: SnackBarBehavior.floating),
        );
        return;
      }
      _transferCancelToken = null;
      setState(() {
        _transfer = null;
        isTransferring = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${tr('downloadFailed')}: $e'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _uploadFile({String? targetDir}) async {
    if (isTransferring) return;
    final deviceSerial = _selectedSerial;
    if (deviceSerial == null) return;
    final api = context.read<ApiClient>();
    final result = await openFile(confirmButtonText: tr('upload'));
    if (result == null) return;
    final remotePath = _joinRemotePath(targetDir ?? _currentPath, result.name);
    final totalBytes = await result.length();
    final cancelToken = TransferCancelToken();
    try {
      _transferCancelToken = cancelToken;
      setState(() {
        _transfer = TransferState(
          mode: TransferMode.upload,
          fileName: result.name,
          sent: 0,
          total: totalBytes,
          phaseKey: 'preparing',
        );
        isTransferring = true;
      });
      await api.pushLocalFile(
        deviceSerial,
        remotePath,
        result.path,
        cancelToken: cancelToken,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _transfer = TransferState(
              mode: TransferMode.upload,
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
      setState(() {
        _transfer = null;
        isTransferring = false;
      });
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
        setState(() {
          _transfer = null;
          isTransferring = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr('uploadCancelled')),
              behavior: SnackBarBehavior.floating),
        );
        return;
      }
      _transferCancelToken = null;
      setState(() {
        _transfer = null;
        isTransferring = false;
      });
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

  String _joinRemotePath(String basePath, String name) {
    final trimmedName = name.trim();
    if (basePath == '/') return '/$trimmedName';
    return '${basePath.replaceAll(RegExp(r'/+$'), '')}/$trimmedName';
  }

  Future<String?> _askName({
    required String title,
    required String label,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => SafeDialog(
        controllers: [controller],
        builder: (_) => AlertDialog(
          scrollable: true,
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: label),
            onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(tr('confirm')),
            ),
          ],
        ),
      ),
    );
    final trimmed = result?.trim();
    if (trimmed == null ||
        trimmed.isEmpty ||
        trimmed == '.' ||
        trimmed == '..' ||
        trimmed.contains('/') ||
        trimmed.contains('\\')) {
      return null;
    }
    return trimmed;
  }

  Future<bool> _confirm(
      {required String title, required String message}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('confirm')),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _copyPath(FileItem file) async {
    await Clipboard.setData(ClipboardData(text: file.path));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('pathCopied', {'path': file.path})),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _renameFile(FileItem file) async {
    if (isTransferring) return;
    final deviceSerial = _selectedSerial;
    if (deviceSerial == null) return;
    final api = context.read<ApiClient>();
    final newName = await _askName(
      title: tr('rename'),
      label: tr('newName'),
      initialValue: file.name,
    );
    if (newName == null || newName == file.name) return;
    final targetPath = _joinRemotePath(_currentPath, newName);
    try {
      await api.renameFile(deviceSerial, file.path, targetPath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('renamedTo', {'name': newName})),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadFiles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr('renameFailed')}: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteFile(FileItem file) async {
    if (isTransferring) return;
    final deviceSerial = _selectedSerial;
    if (deviceSerial == null) return;
    final api = context.read<ApiClient>();
    final ok = await _confirm(
      title: tr('delete'),
      message: tr(
        file.isDir ? 'deleteDirConfirm' : 'deleteFileConfirm',
        {'name': file.name},
      ),
    );
    if (!ok) return;
    try {
      await api.deleteFile(
        deviceSerial,
        file.path,
        recursive: file.isDir,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('deleted', {'name': file.name})),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadFiles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr('deleteFailed')}: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _createFileOrFolder({
    required bool directory,
    String? targetDir,
  }) async {
    if (isTransferring) return;
    final deviceSerial = _selectedSerial;
    if (deviceSerial == null) return;
    final api = context.read<ApiClient>();
    final name = await _askName(
      title: directory ? tr('newFolder') : tr('newFile'),
      label: tr('name'),
    );
    if (name == null) return;
    final path = _joinRemotePath(targetDir ?? _currentPath, name);
    try {
      if (directory) {
        await api.createDirectory(deviceSerial, path);
      } else {
        await api.createFile(deviceSerial, path);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(directory ? 'folderCreated' : 'fileCreated', {
            'name': name,
          })),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadFiles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${tr(directory ? 'createFolderFailed' : 'createFileFailed')}: $e',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showFileInfoWithStat(FileItem file) async {
    if (_selectedSerial == null) {
      _showFileInfo(context, file);
      return;
    }
    try {
      final stat =
          await context.read<ApiClient>().statFile(_selectedSerial ?? '', file.path);
      if (!mounted) return;
      _showFileInfo(context, file, stat: stat);
    } catch (_) {
      if (!mounted) return;
      _showFileInfo(context, file);
    }
  }

  Future<void> _onDropFile(DropDoneDetails details) async {
    if (isTransferring) return;
    final deviceSerial = _selectedSerial;
    if (deviceSerial == null) return;
    final api = context.read<ApiClient>();
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
          _transfer = TransferState(
            mode: TransferMode.upload,
            fileName: file.name,
            sent: 0,
            total: totalBytes,
            phaseKey: 'preparing',
          );
          isTransferring = true;
        });
        await api.pushLocalFile(
          deviceSerial,
          remotePath,
          file.path,
          cancelToken: cancelToken,
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _transfer = TransferState(
                mode: TransferMode.upload,
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
        _transferCancelToken = null;
        setState(() {
          _transfer = null;
          isTransferring = false;
        });
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
          setState(() {
            _transfer = null;
            isTransferring = false;
          });
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
        setState(() {
          _transfer = null;
          isTransferring = false;
        });
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
    context.watch<LocaleProvider>();
    context.watch<TestConfigProvider>();
    // The mixin's initScreenRecordState() opened a stream subscription
    // on this device's SavedDevices row. The mixin calls setState() on
    // every row update, so this widget naturally rebuilds whenever
    // the row changes. The first stream event is also a row update,
    // so a fresh build runs right after the widget is mounted.
    if (_selectedSerial == null) {
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
        if (isTransferring) return;
        setState(() => _dragOver = true);
      },
      onDragExited: () {
        if (isTransferring) return;
        setState(() => _dragOver = false);
      },
      onDragDone: _onDropFile,
      child: OfflineGuard(
        serial: _selectedSerial!,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPathBar(),
                if (_loading)
                  const Expanded(child: LoadingView())
                else if (_error != null)
                  Expanded(
                    child: ErrorView(
                      message: _error!,
                      onRetry: _loadFiles,
                      retryLabel: tr('retry'),
                    ),
                  )
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
                child: TransferProgressOverlay(
                  transfer: _transfer!,
                  trPhase: trPhase,
                  onCancel: _cancelTransfer,
                ),
              ),
          ],
        ),
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
            onPressed: isTransferring ? null : _goHome,
            tooltip: tr('rootDir'),
          ),
          const SizedBox(width: 4),
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.arrow_upward, size: 20),
              onPressed: isTransferring ? null : _goUp,
              tooltip: tr('parentDir'),
            ),
          const SizedBox(width: 4),
          for (final qp in _quickPaths) _quickBtn(qp.$1, tr(qp.$2)),
          ...() {
            final configPaths =
                context.read<TestConfigProvider>().currentApp?.filePaths ?? [];
            return [
              for (final fp in configPaths) _quickBtn(fp.path, fp.name),
            ];
          }(),
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
                      onTap: !isTransferring && i < parts.length - 1
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
            onPressed: isTransferring
                ? null
                : () => setState(() => _gridMode = !_gridMode),
            tooltip: _gridMode ? tr('listMode') : tr('gridMode'),
          ),
          const SizedBox(width: 4),
          isTransferring ? const SizedBox(width: 80) : buildRecordingButton(),
          const SizedBox(width: 4),
          FilledButton.tonal(
            onPressed: screenshotting || isTransferring ? null : takeScreenshot,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: screenshotting
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
            onPressed: isTransferring ? null : _uploadFile,
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
            onPressed: isTransferring ? null : _loadFiles,
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
          onTap: isActive || isTransferring ? null : () => _navigateTo(path),
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
    disposeScreenRecordState();
    _transferCancelToken?.cancel();
    super.dispose();
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
    final isText = isTextFile(file.name);

    return GestureDetector(
      onSecondaryTapDown: isTransferring
          ? null
          : (details) => _showFileContextMenu(details.globalPosition, file),
      child: InkWell(
        onTap: isTransferring
            ? null
            : () {
                if (file.isDir) {
                  _enterDir(file);
                } else if (isText) {
                  _viewFile(file);
                }
              },
        onLongPress: isTransferring ? null : () => _showFileMenu(context, file),
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
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (file.sizeFormatted.isNotEmpty)
                SizedBox(
                  width: 70,
                  child: Text(
                    file.sizeFormatted,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              if (!file.isDir) ...[
                const SizedBox(width: 4),
                _iconBtn(
                  Icons.download,
                  tr('downloadTooltip'),
                  isTransferring ? null : () => _downloadFile(file),
                ),
              ],
              if (file.isDir) ...[
                const SizedBox(width: 4),
                _iconBtn(
                  Icons.upload,
                  tr('uploadToDir'),
                  isTransferring
                      ? null
                      : () => _uploadFile(targetDir: file.path),
                ),
              ],
            ],
          ),
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
    // 7 columns + slightly-tall tiles. Compromise between density
    // (more items per screen) and legibility (folder icons and names
    // remain readable on a 1920px-wide window without becoming
    // postage-stamp sized). aspectRatio 0.9 leaves headroom for the
    // 2-line filename + size line without cropping.
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.9,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: _files.length,
      itemBuilder: (ctx, i) => _buildFileGridItem(context, _files[i]),
    );
  }

  Widget _buildFileGridItem(BuildContext context, FileItem file) {
    final theme = Theme.of(context);
    final isText = isTextFile(file.name);

    return GestureDetector(
      onSecondaryTapDown: isTransferring
          ? null
          : (details) => _showFileContextMenu(details.globalPosition, file),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainer,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: isTransferring
              ? null
              : () {
                  if (file.isDir) {
                    _enterDir(file);
                  } else if (isText) {
                    _viewFile(file);
                  }
                },
          onLongPress:
              isTransferring ? null : () => _showFileMenu(context, file),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  file.isDir
                      ? Icons.folder
                      : (isText ? Icons.description : Icons.insert_drive_file),
                  size: 30,
                  color: file.isDir
                      ? Colors.amber.shade400
                      : theme.colorScheme.primary,
                ),
                const SizedBox(height: 4),
                Text(
                  file.name,
                  style: const TextStyle(fontSize: 11, fontFamily: 'Menlo'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                if (file.sizeFormatted.isNotEmpty)
                  Text(
                    file.sizeFormatted,
                    style: TextStyle(
                      fontSize: 9,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showFileContextMenu(Offset position, FileItem file) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final action = await showMenu<_FileAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: _filePopupMenuItems(file),
    );
    if (action == null) return;
    await _handleFileAction(action, file);
  }

  List<PopupMenuEntry<_FileAction>> _filePopupMenuItems(FileItem file) {
    return [
      if (file.isDir)
        PopupMenuItem(
          value: _FileAction.open,
          child: _menuRow(Icons.folder_open, tr('open')),
        ),
      if (!file.isDir)
        PopupMenuItem(
          value: _FileAction.download,
          child: _menuRow(Icons.download, tr('downloadTooltip')),
        ),
      if (file.isDir)
        PopupMenuItem(
          value: _FileAction.uploadToDir,
          child: _menuRow(Icons.upload, tr('uploadToDir')),
        ),
      PopupMenuItem(
        value: _FileAction.copyPath,
        child: _menuRow(Icons.copy, tr('copyPath')),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: _FileAction.rename,
        child: _menuRow(Icons.drive_file_rename_outline, tr('rename')),
      ),
      PopupMenuItem(
        value: _FileAction.delete,
        child: _menuRow(Icons.delete_outline, tr('delete')),
      ),
      if (file.isDir) ...[
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _FileAction.newFile,
          child: _menuRow(Icons.note_add_outlined, tr('newFile')),
        ),
        PopupMenuItem(
          value: _FileAction.newFolder,
          child: _menuRow(Icons.create_new_folder_outlined, tr('newFolder')),
        ),
      ],
      const PopupMenuDivider(),
      PopupMenuItem(
        value: _FileAction.details,
        child: _menuRow(Icons.info_outline, tr('details')),
      ),
    ];
  }

  Widget _menuRow(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Text(label),
      ],
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
              child: Text(
                file.name,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            FileSheetActions(
              sheetContext: ctx,
              file: file,
              tr: tr,
              onOpen: file.isDir ? () => _enterDir(file) : null,
              onDownload: !file.isDir ? () => _downloadFile(file) : null,
              onUploadToDir:
                  file.isDir ? () => _uploadFile(targetDir: file.path) : null,
              onCopyPath: () => _copyPath(file),
              onRename: () => _renameFile(file),
              onDelete: () => _deleteFile(file),
              onNewFile: file.isDir
                  ? () => _createFileOrFolder(
                      directory: false, targetDir: file.path)
                  : null,
              onNewFolder: file.isDir
                  ? () =>
                      _createFileOrFolder(directory: true, targetDir: file.path)
                  : null,
              onDetails: () => _showFileInfoWithStat(file),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _handleFileAction(_FileAction action, FileItem file) async {
    switch (action) {
      case _FileAction.open:
        _enterDir(file);
      case _FileAction.download:
        await _downloadFile(file);
      case _FileAction.uploadToDir:
        await _uploadFile(targetDir: file.path);
      case _FileAction.copyPath:
        await _copyPath(file);
      case _FileAction.rename:
        await _renameFile(file);
      case _FileAction.delete:
        await _deleteFile(file);
      case _FileAction.newFile:
        await _createFileOrFolder(directory: false, targetDir: file.path);
      case _FileAction.newFolder:
        await _createFileOrFolder(directory: true, targetDir: file.path);
      case _FileAction.details:
        await _showFileInfoWithStat(file);
    }
  }

  void _showFileInfo(BuildContext context, FileItem file, {FileStat? stat}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(file.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoRow(tr('type'),
                (stat?.isDir ?? file.isDir) ? tr('directory') : tr('file')),
            InfoRow(tr('path'), stat?.path ?? file.path),
            if (!(stat?.isDir ?? file.isDir))
              InfoRow(tr('size'), stat?.sizeFormatted ?? file.sizeFormatted),
            InfoRow(tr('permissions'), stat?.permissions ?? file.permissions),
            InfoRow(tr('modified'), stat?.modified ?? file.modified),
            if (stat != null && stat.raw.isNotEmpty)
              InfoRow(tr('rawInfo'), stat.raw),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(tr('close'))),
        ],
      ),
    );
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
