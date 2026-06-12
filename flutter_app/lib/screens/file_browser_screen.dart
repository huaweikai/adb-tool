import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../models/file_item.dart';
import '../services/api_client.dart';

enum _SortKey { name, date, size }

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
    ('/', '根'),
    ('/sdcard', 'SD'),
    ('/storage/emulated/0', '存储'),
    ('/data/local/tmp', '临时'),
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
    final base = _sortKey == _SortKey.name ? '名称' : _sortKey == _SortKey.date ? '时间' : '大小';
    return base + (_sortAsc ? ' ↑' : ' ↓');
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
          if (cmp == 0) cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return _sortAsc ? cmp : -cmp;
    });
    return sorted;
  }

  void _navigateTo(String path) {
    setState(() {
      _history.add(_currentPath);
      _currentPath = path;
    });
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    if (widget.selectedSerial == null) {
      setState(() {
        _files = [];
        _error = '请先选择设备';
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
      final files = await widget.api.listFiles(widget.selectedSerial!, _currentPath);
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
    if (widget.selectedSerial == null) return;
    final prevPath = _currentPath;
    setState(() {
      _history.add(_currentPath);
      _currentPath = dir.path;
      _loading = true;
      _error = null;
    });
    try {
      final files = await widget.api.listFiles(widget.selectedSerial!, _currentPath);
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
          content: Text('无法访问 ${dir.name}：无权限或目录不存在'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _goUp() {
    if (_history.isEmpty) return;
    setState(() {
      _currentPath = _history.removeLast();
    });
    _loadFiles();
  }

  void _goHome() {
    setState(() {
      _history.clear();
      _currentPath = '/';
    });
    _loadFiles();
  }

  Future<void> _viewFile(FileItem file) async {
    if (widget.selectedSerial == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final content = await widget.api.readFile(widget.selectedSerial!, file.path);
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
    if (widget.selectedSerial == null) return;
    try {
      final location = await getSaveLocation(
        suggestedName: file.name,
        confirmButtonText: '保存',
      );
      if (location == null) return;
      final bytes = await widget.api.pullFile(widget.selectedSerial!, file.path);
      await File(location.path).writeAsBytes(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已保存到 ${location.path}'), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('下载失败: $e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _uploadFile() async {
    if (widget.selectedSerial == null) return;
    final result = await openFile(confirmButtonText: '上传');
    if (result == null) return;
    final bytes = await result.readAsBytes();
    final remotePath = _currentPath.endsWith('/')
        ? '$_currentPath${result.name}'
        : '$_currentPath/${result.name}';
    try {
      await widget.api.pushFile(widget.selectedSerial!, remotePath, bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已上传到 $remotePath'), behavior: SnackBarBehavior.floating),
      );
      _loadFiles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('上传失败: $e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _onDropFile(DropDoneDetails details) async {
    if (widget.selectedSerial == null) return;
    for (final file in details.files) {
      final bytes = await file.readAsBytes();
      final remotePath = _currentPath.endsWith('/')
          ? '$_currentPath${file.name}'
          : '$_currentPath/${file.name}';
      try {
        await widget.api.pushFile(widget.selectedSerial!, remotePath, bytes);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已上传 ${file.name} 到 $remotePath'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('上传 ${file.name} 失败: $e'),
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
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('请先在侧边栏选择设备', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_fileContent != null) {
      return _buildFileViewer();
    }

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragOver = true),
      onDragExited: (_) => setState(() => _dragOver = false),
      onDragDone: _onDropFile,
      child: Stack(
        children: [
          Container(
            decoration: _dragOver
                ? BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPathBar(),
                if (_loading)
                  const Expanded(child: Center(child: CircularProgressIndicator()))
                else if (_error != null)
                  Expanded(child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 8),
                        Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                        const SizedBox(height: 12),
                        FilledButton.tonal(onPressed: _loadFiles, child: const Text('重试')),
                      ],
                    ),
                  ))
                else
                  Expanded(child: _gridMode ? _buildGridView() : _buildFileList()),
              ],
            ),
          ),
          if (_dragOver)
            _buildDragOverlay(),
        ],
      ),
    );
  }

  Widget _buildDragOverlay() {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: Container(
        color: theme.colorScheme.primary.withAlpha(30),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_upload, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text('释放文件以上传到 ${_currentPath}',
                  style: TextStyle(fontSize: 16, color: theme.colorScheme.primary)),
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
            onPressed: _goHome,
            tooltip: '根目录',
          ),
          const SizedBox(width: 4),
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.arrow_upward, size: 20),
              onPressed: _goUp,
              tooltip: '上级目录',
            ),
          const SizedBox(width: 4),
          for (final qp in _quickPaths)
            _quickBtn(qp.$1, qp.$2),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < parts.length; i++) ...[
                    if (i > 0) const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
                    GestureDetector(
                      onTap: i < parts.length - 1 ? () {
                        final path = '/' + parts.sublist(0, i + 1).join('/');
                        _navigateTo(path);
                      } : null,
                      child: Text(
                        parts[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Menlo',
                          fontWeight: i == parts.length - 1 ? FontWeight.w600 : FontWeight.normal,
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
            onPressed: () => setState(() => _gridMode = !_gridMode),
            tooltip: _gridMode ? '列表模式' : '网格模式',
          ),
          const SizedBox(width: 4),
          FilledButton.tonal(
            onPressed: _uploadFile,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.upload_file, size: 16),
                SizedBox(width: 4),
                Text('上传'),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadFiles,
            tooltip: '刷新',
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
          onTap: isActive ? null : () => _navigateTo(path),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(label, style: const TextStyle(fontSize: 11, fontFamily: 'Menlo')),
          ),
        ),
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
      tooltip: '排序: $_sortLabel',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward, size: 14),
            const SizedBox(width: 4),
            Text(_sortLabel, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
      itemBuilder: (ctx) => _SortKey.values.map((key) {
        final isCurrent = _sortKey == key;
        final labels = ['名称', '修改时间', '大小'];
        return PopupMenuItem(
          value: key,
          child: Row(
            children: [
              if (isCurrent) Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward, size: 16)
              else const SizedBox(width: 16),
              const SizedBox(width: 4),
              Text(labels[key.index], style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFileList() {
    if (_files.isEmpty) {
      return const Center(child: Text('空目录', style: TextStyle(color: Colors.grey)));
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
      onTap: () {
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
              file.isDir ? Icons.folder : (isText ? Icons.description : Icons.insert_drive_file),
              size: 18,
              color: file.isDir ? Colors.amber.shade400 : theme.colorScheme.primary,
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
                style: TextStyle(fontSize: 10, fontFamily: 'Menlo', color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            if (file.sizeFormatted.isNotEmpty)
              SizedBox(
                width: 70,
                child: Text(
                  file.sizeFormatted,
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.end,
                ),
              ),
            if (!file.isDir) ...[
              const SizedBox(width: 4),
              _iconBtn(Icons.download, '下载到 Mac', () => _downloadFile(file)),
            ],
            if (file.isDir) ...[
              const SizedBox(width: 4),
              _iconBtn(Icons.upload, '上传到此目录', _uploadFile),
            ],
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback onTap) {
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
      return const Center(child: Text('空目录', style: TextStyle(color: Colors.grey)));
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
        onTap: () {
          if (file.isDir) {
            _enterDir(file);
          } else if (isText) {
            _viewFile(file);
          }
        },
        onLongPress: () => _showFileMenu(context, file),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                file.isDir ? Icons.folder : (isText ? Icons.description : Icons.insert_drive_file),
                size: 28,
                color: file.isDir ? Colors.amber.shade400 : theme.colorScheme.primary,
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
                  style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurfaceVariant),
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
              child: Text(file.name, style: Theme.of(context).textTheme.titleSmall),
            ),
            if (!file.isDir)
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('下载到 Mac'),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadFile(file);
                },
              ),
            if (file.isDir)
              ListTile(
                leading: const Icon(Icons.upload),
                title: const Text('上传文件到此目录'),
                onTap: () {
                  Navigator.pop(ctx);
                  _uploadFile();
                },
              ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('详情'),
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
            _infoRow('类型', file.isDir ? '目录' : '文件'),
            _infoRow('路径', file.path),
            if (!file.isDir) _infoRow('大小', file.sizeFormatted),
            _infoRow('权限', file.permissions),
            _infoRow('修改时间', file.modified),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
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
          SizedBox(width: 60, child: Text('$label:', style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontFamily: 'Menlo'))),
        ],
      ),
    );
  }

  bool _isTextFile(String name) {
    final ext = name.split('.').last.toLowerCase();
    return ['txt', 'xml', 'json', 'html', 'css', 'js', 'kt', 'java', 'py',
            'log', 'cfg', 'conf', 'prop', 'ini', 'md', 'csv', 'yaml', 'yml',
            'sh', 'bat', 'gradle', 'pro'].contains(ext);
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
              style: const TextStyle(fontFamily: 'Menlo', fontSize: 11, height: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
