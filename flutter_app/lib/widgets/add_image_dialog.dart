// Add image dialog for adding system images via URL or local path.
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../services/api/emulator_image_api.dart';

class AddImageDialog extends StatefulWidget {
  final List<ImageSource> savedSources;
  final void Function(String url)? onRemoveSource;

  const AddImageDialog({
    super.key,
    this.savedSources = const [],
    this.onRemoveSource,
  });

  @override
  State<AddImageDialog> createState() => _AddImageDialogState();
}

class _AddImageDialogState extends State<AddImageDialog> {
  int _selectedSource = 0; // 0 = URL, 1 = Local Path
  int _localKind = 0; // 0 = Folder, 1 = Zip
  final _urlController = TextEditingController();
  final _pathController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加系统镜像'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Source selection
              const Text(
                '镜像来源',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('URL 下载')),
                  ButtonSegment(value: 1, label: Text('本地路径')),
                ],
                selected: {_selectedSource},
                onSelectionChanged: (selection) {
                  setState(() => _selectedSource = selection.first);
                },
              ),
              const SizedBox(height: 16),

              // URL input
              if (_selectedSource == 0) ...[
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: '镜像下载 URL',
                    hintText: 'https://dl.google.com/android/repository/...',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '提示: 下载完成后会自动解压到缓存目录，并解析镜像信息',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (widget.savedSources.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    '历史下载地址',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.savedSources.length,
                      itemBuilder: (context, index) {
                        final s = widget.savedSources[index];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.history, size: 18),
                          title: Text(
                            s.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: s.name.isNotEmpty
                              ? Text(
                                  s.url,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                )
                              : null,
                          trailing: widget.onRemoveSource != null
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  tooltip: '从历史中移除',
                                  onPressed: () =>
                                      widget.onRemoveSource!(s.url),
                                )
                              : null,
                          onTap: () {
                            setState(() => _urlController.text = s.url);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ],

              // Local path input
              if (_selectedSource == 1) ...[
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('选择文件夹')),
                    ButtonSegment(value: 1, label: Text('选择 Zip')),
                  ],
                  selected: {_localKind},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _localKind = selection.first;
                      _pathController.clear();
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pathController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: _localKind == 0 ? '镜像文件夹' : '镜像 Zip 文件',
                    hintText: _localKind == 0
                        ? '包含 system.img / config.ini 的目录'
                        : '系统镜像压缩包 (.zip)',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _localKind == 0
                            ? Icons.folder_open
                            : Icons.archive_outlined,
                      ),
                      onPressed: _localKind == 0 ? _pickFolder : _pickZip,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '提示: 镜像信息（API 级别、架构、变体）会从所选内容自动探测',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_selectedSource == 0 ? '开始下载' : '添加'),
        ),
      ],
    );
  }

  void _pickFolder() async {
    try {
      final dir = await getDirectoryPath();
      if (dir != null && dir.isNotEmpty) {
        setState(() => _pathController.text = dir);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择文件夹失败: $e')),
      );
    }
  }

  void _pickZip() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Zip', extensions: ['zip']),
        ],
      );
      if (file != null && file.path.isNotEmpty) {
        setState(() => _pathController.text = file.path);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择文件失败: $e')),
      );
    }
  }

  void _submit() {
    if (_selectedSource == 0) {
      // URL download
      if (_urlController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入下载 URL')),
        );
        return;
      }
      Navigator.pop(context, {
        'source': 'url',
        'url': _urlController.text.trim(),
      });
    } else {
      // Local path
      if (_pathController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_localKind == 0 ? '请选择镜像文件夹' : '请选择镜像 Zip 文件'),
          ),
        );
        return;
      }
      Navigator.pop(context, {
        'source': 'local',
        'path': _pathController.text,
        'isZip': _localKind == 1,
      });
    }
  }
}
