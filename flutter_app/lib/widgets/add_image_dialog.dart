// Add image dialog for adding system images via URL or local path.
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../i18n.dart';
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
  // 0 = URL 下载, 1 = SDK 下载, 2 = 本地路径
  int _selectedSource = 0;
  int _localKind = 0; // 0 = Folder, 1 = Zip
  final _urlController = TextEditingController();
  final _pathController = TextEditingController();

  // "SDK 下载" 用的镜像配置：选 API level + variant + arch 后，构造
  // system-images;android-XX;variant;arch 包名交给 SDKInstaller。
  int _sdkApiLevel = 33;
  String _sdkArch = 'arm64-v8a';
  String _sdkVariant = 'google_apis_playstore';

  @override
  void dispose() {
    _urlController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('addImage.title')),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Source selection
              Text(
                tr('addImage.source'),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 0, label: Text(tr('addImage.tabURL'))),
                  ButtonSegment(value: 1, label: Text(tr('addImage.tabSDK'))),
                  ButtonSegment(value: 2, label: Text(tr('addImage.tabLocal'))),
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
                  decoration: InputDecoration(
                    labelText: tr('addImage.urlLabel'),
                    hintText: 'https://dl.google.com/android/repository/...',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr('addImage.urlHint'),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (widget.savedSources.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    tr('addImage.historyTitle'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: ListView.builder(
                      shrinkWrap: true,
                      // Nested inside the dialog's outer scroll — disable
                      // its own scrolling so the two viewports don't fight
                      // over the gesture (and the a11y bridge doesn't warn).
                      physics: const NeverScrollableScrollPhysics(),
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
                                  tooltip: tr('addImage.removeFromHistory'),
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

              // SDK 下载：通过 sdkmanager / avdmanager 下载选定的镜像配置
              if (_selectedSource == 1) ...[
                Text(
                  tr('addImage.config'),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _sdkApiLevel,
                  decoration:
                      InputDecoration(labelText: tr('addImage.apiLevel')),
                  items: const [
                    DropdownMenuItem(
                        value: 30, child: Text('Android 11 (API 30)')),
                    DropdownMenuItem(
                        value: 31, child: Text('Android 12 (API 31)')),
                    DropdownMenuItem(
                        value: 32, child: Text('Android 12L (API 32)')),
                    DropdownMenuItem(
                        value: 33, child: Text('Android 13 (API 33)')),
                    DropdownMenuItem(
                        value: 34, child: Text('Android 14 (API 34)')),
                    DropdownMenuItem(
                        value: 35, child: Text('Android 15 (API 35)')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _sdkApiLevel = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _sdkArch,
                  decoration: InputDecoration(labelText: tr('addImage.arch')),
                  items: const [
                    DropdownMenuItem(
                      value: 'arm64-v8a',
                      child: Text('arm64-v8a (Apple Silicon)'),
                    ),
                    DropdownMenuItem(
                      value: 'x86_64',
                      child: Text('x86_64 (Intel Mac)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _sdkArch = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _sdkVariant,
                  decoration:
                      InputDecoration(labelText: tr('addImage.variant')),
                  items: [
                    DropdownMenuItem(
                      value: 'google_apis_playstore',
                      child: Text(tr('addImage.variantGooglePlay')),
                    ),
                    DropdownMenuItem(
                      value: 'google_apis',
                      child: const Text('Google APIs'),
                    ),
                    DropdownMenuItem(
                      value: 'default',
                      child: Text(tr('addImage.variantDefault')),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _sdkVariant = v);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  tr('addImage.sdkHint'),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],

              // Local path input
              if (_selectedSource == 2) ...[
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(
                        value: 0, label: Text(tr('addImage.pickFolder'))),
                    ButtonSegment(
                        value: 1, label: Text(tr('addImage.pickZip'))),
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
                    labelText: _localKind == 0
                        ? tr('addImage.folderLabel')
                        : tr('addImage.zipLabel'),
                    hintText: _localKind == 0
                        ? tr('addImage.folderHint')
                        : tr('addImage.zipFileHint'),
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
                Text(
                  tr('addImage.localHint'),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_selectedSource == 0
              ? tr('engineCard.startDownload')
              : tr('addImage.confirm')),
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
        SnackBar(
            content: Text(tr('addImage.folderPickFailed', {'error': '$e'}))),
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
        SnackBar(content: Text(tr('addImage.filePickFailed', {'error': '$e'}))),
      );
    }
  }

  void _submit() {
    if (_selectedSource == 0) {
      // URL download
      if (_urlController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('engineCard.downloadLog.needURL'))),
        );
        return;
      }
      Navigator.pop(context, {
        'source': 'url',
        'url': _urlController.text.trim(),
      });
    } else if (_selectedSource == 1) {
      // SDK 下载 — 选好配置后让 SDKInstaller 跑 sdkmanager
      Navigator.pop(context, {
        'source': 'sdk',
        'apiLevel': _sdkApiLevel,
        'arch': _sdkArch,
        'variant': _sdkVariant,
      });
    } else {
      // Local path
      if (_pathController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_localKind == 0
                ? tr('addImage.validator.folder')
                : tr('addImage.validator.zip')),
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
