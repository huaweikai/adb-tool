// Add image dialog for adding system images via URL or local path.
import 'package:flutter/material.dart';

class AddImageDialog extends StatefulWidget {
  const AddImageDialog({super.key});

  @override
  State<AddImageDialog> createState() => _AddImageDialogState();
}

class _AddImageDialogState extends State<AddImageDialog> {
  int _selectedSource = 0; // 0 = URL, 1 = Local Path
  final _urlController = TextEditingController();
  final _pathController = TextEditingController();
  final _nameController = TextEditingController();
  int _selectedApiLevel = 34;
  String _selectedArch = 'arm64-v8a';
  String _selectedVariant = 'google_apis';

  @override
  void dispose() {
    _urlController.dispose();
    _pathController.dispose();
    _nameController.dispose();
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
                  '提示: 可以从 Google 官方或内部镜像服务器下载',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],

              // Local path input
              if (_selectedSource == 1) ...[
                TextField(
                  controller: _pathController,
                  decoration: InputDecoration(
                    labelText: '本地路径',
                    hintText: '/Users/xxx/Library/Android/sdk/system-images/android-34/...',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.folder_open),
                      onPressed: _pickFolder,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Image info
              const Text(
                '镜像信息',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '名称',
                  hintText: 'Android 14 (API 34) - google_apis - arm64-v8a',
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedApiLevel,
                      decoration: const InputDecoration(
                        labelText: 'API 级别',
                      ),
                      items: _apiLevelOptions,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedApiLevel = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedArch,
                      decoration: const InputDecoration(
                        labelText: '架构',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'arm64-v8a',
                          child: Text('arm64-v8a (Apple Silicon)'),
                        ),
                        DropdownMenuItem(
                          value: 'x86_64',
                          child: Text('x86_64 (Intel)'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedArch = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _selectedVariant,
                decoration: const InputDecoration(
                  labelText: '变体',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'google_apis',
                    child: Text('Google APIs (推荐)'),
                  ),
                  DropdownMenuItem(
                    value: 'google_apis_playstore',
                    child: Text('Google Play'),
                  ),
                  DropdownMenuItem(
                    value: 'default',
                    child: Text('Default (无 Google 服务)'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedVariant = value);
                  }
                },
              ),
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

  List<DropdownMenuItem<int>> get _apiLevelOptions {
    final levels = <int, String>{
      33: 'Android 13 (API 33)',
      34: 'Android 14 (API 34)',
      35: 'Android 15 (API 35)',
    };
    return levels.entries
        .map((e) => DropdownMenuItem(
              value: e.key,
              child: Text(e.value),
            ))
        .toList();
  }

  void _pickFolder() {
    // TODO: Implement folder picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('文件夹选择功能即将推出'),
        duration: Duration(seconds: 2),
      ),
    );
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
        'url': _urlController.text,
        'name': _nameController.text.isNotEmpty
            ? _nameController.text
            : 'Android $_selectedApiLevel ($_selectedVariant, $_selectedArch)',
        'apiLevel': _selectedApiLevel,
        'arch': _selectedArch,
        'variant': _selectedVariant,
      });
    } else {
      // Local path
      if (_pathController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入本地路径')),
        );
        return;
      }
      Navigator.pop(context, {
        'source': 'local',
        'path': _pathController.text,
        'name': _nameController.text,
      });
    }
  }
}
