// Emulator engine configuration card widget.
// Displays and manages the Android SDK import and configuration.
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/emulator_engine_provider.dart';
import '../services/api_client.dart';

class EmulatorEngineCard extends StatefulWidget {
  const EmulatorEngineCard({super.key});

  @override
  State<EmulatorEngineCard> createState() => _EmulatorEngineCardState();
}

class _EmulatorEngineCardState extends State<EmulatorEngineCard> {
  bool _isImporting = false;
  bool _isDetecting = false;
  Timer? _downloadPoller;

  // 展开/折叠状态
  bool _scanExpanded = false;
  bool _downloadExpanded = false;
  bool _importExpanded = false;

  // 下载相关
  final _downloadUrlController = TextEditingController();
  bool _isDownloading = false;
  double _downloadProgress = 0;

  // 导入相关
  final _importPathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 默认展开扫描检测
    _scanExpanded = true;
  }

  @override
  void dispose() {
    _downloadUrlController.dispose();
    _importPathController.dispose();
    _downloadPoller?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmulatorEngineProvider>();
    final theme = Theme.of(context);
    final status = provider.serverStatus;
    final hasSDK = status?.androidHome?.isNotEmpty == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Row(
              children: [
                Icon(Icons.smart_toy, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Android SDK',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _buildStatusBadge(provider),
              ],
            ),

            const SizedBox(height: 12),

            // 当前 SDK 信息
            _buildCurrentSDKInfo(provider),

            const SizedBox(height: 12),

            // 操作按钮栏
            _buildActionBar(provider),

            const Divider(height: 24),

            // 扫描检测区域
            _buildScanSection(provider),

            // 下载 SDK 区域
            _buildDownloadSection(provider),

            // 导入压缩包区域
            _buildImportSection(provider),

            if (provider.errorMessage != null) ...[
              const SizedBox(height: 12),
              _buildErrorMessage(provider),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentSDKInfo(EmulatorEngineProvider provider) {
    final status = provider.serverStatus;
    final hasSDK = status?.androidHome?.isNotEmpty == true;

    if (!hasSDK) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Text(
              '尚未配置 SDK',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha(10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder, color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status!.androidHome!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: status.androidHome!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('路径已复制'), duration: Duration(seconds: 1)),
                  );
                },
                tooltip: '复制路径',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (status.emulatorVersion != null)
                _infoChip(Icons.apps, 'Emulator ${status.emulatorVersion}'),
              if (status.javaVersion != null)
                _infoChip(Icons.coffee, status.javaVersion!.split('\n').first.trim()),
              if (status.avdmanagerPath != null)
                _infoChip(Icons.settings, 'AVD Manager ✓'),
              if (status.sdkmanagerPath != null)
                _infoChip(Icons.inventory, 'SDK Manager ✓'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.green),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.green),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(EmulatorEngineProvider provider) {
    final status = provider.serverStatus;
    final toolchainReady = status?.toolchainReady == true;
    final hasSDK = status?.androidHome?.isNotEmpty == true;

    Color color;
    String label;

    if (_isImporting || provider.isDetecting || _isDownloading) {
      color = Colors.orange;
      label = '处理中';
    } else if (toolchainReady) {
      color = Colors.green;
      label = '就绪';
    } else if (hasSDK) {
      color = Colors.orange;
      label = '部分就绪';
    } else {
      color = Colors.grey;
      label = '未配置';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isImporting || provider.isDetecting || _isDownloading)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(
              toolchainReady ? Icons.check_circle : (hasSDK ? Icons.warning : Icons.info_outline),
              size: 14,
              color: color,
            ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(EmulatorEngineProvider provider) {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: () => _detectSDKs(context),
          icon: Icon(_isDetecting ? Icons.sync : Icons.search, size: 16),
          label: Text(_isDetecting ? '扫描中...' : '扫描检测'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => _showSelectPathDialog(context, provider),
          icon: const Icon(Icons.folder_open, size: 16),
          label: const Text('选择路径'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            _downloadExpanded = !_downloadExpanded;
            _scanExpanded = false;
            _importExpanded = false;
          }),
          icon: Icon(_downloadExpanded ? Icons.cloud_download : Icons.cloud_download_outlined, size: 16),
          label: const Text('下载 SDK'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            _importExpanded = !_importExpanded;
            _scanExpanded = false;
            _downloadExpanded = false;
          }),
          icon: Icon(_importExpanded ? Icons.upload_file : Icons.upload_outlined, size: 16),
          label: const Text('导入压缩包'),
        ),
      ],
    );
  }

  Widget _buildScanSection(EmulatorEngineProvider provider) {
    if (!_scanExpanded) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.search, size: 16),
            const SizedBox(width: 8),
            const Text(
              '扫描结果',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _detectSDKs(context),
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('重新扫描'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (provider.detectedSDKs.isEmpty && !_isDetecting)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                '点击「扫描检测」查找系统中的 SDK',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else if (_isDetecting)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('正在扫描...'),
              ],
            ),
          )
        else
          ...provider.detectedSDKs.map((sdk) => _buildSDKItem(context, sdk, provider)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSDKItem(BuildContext context, DetectedSDK sdk, EmulatorEngineProvider provider) {
    final currentPath = provider.serverStatus?.androidHome ?? '';
    final isActive = sdk.path == currentPath;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withAlpha(10) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? Colors.green : Colors.grey.withAlpha(50),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.folder,
            color: isActive ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sdk.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isActive ? Colors.green.shade700 : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sdk.path,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _miniChip(Icons.apps, 'Emulator', sdk.hasEmulator),
                    const SizedBox(width: 6),
                    _miniChip(Icons.settings, 'AVD', sdk.hasAvdmanager),
                    const SizedBox(width: 6),
                    _miniChip(Icons.coffee, 'Java', sdk.hasJava),
                  ],
                ),
              ],
            ),
          ),
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '使用中',
                style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
              ),
            )
          else if (sdk.hasEmulator)
            FilledButton(
              onPressed: () => _useSDK(context, sdk.path),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('使用此 SDK'),
            )
          else
            Tooltip(
              message: '此目录不包含 emulator',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(20),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('不可用', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniChip(IconData icon, String label, bool available) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: available ? Colors.green.withAlpha(20) : Colors.grey.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: available ? Colors.green : Colors.grey),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: available ? Colors.green : Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadSection(EmulatorEngineProvider provider) {
    if (!_downloadExpanded) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha(10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_download, color: Colors.green, size: 18),
              const SizedBox(width: 8),
              const Text(
                '下载 SDK',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final url = Uri.parse('https://developer.android.com/studio#command-line-tools-only');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('官方下载页面'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _downloadUrlController,
                  decoration: InputDecoration(
                    hintText: '输入 SDK 下载 URL',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '从 Android 开发者官网下载 Command Line Tools 后粘贴下载链接',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          if (_isDownloading) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: _downloadProgress,
                        backgroundColor: Colors.grey.withAlpha(50),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => _cancelDownload(context),
                  child: const Text('取消'),
                ),
              ],
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: () => _startDownload(context),
              icon: const Icon(Icons.download, size: 16),
              label: const Text('开始下载'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImportSection(EmulatorEngineProvider provider) {
    if (!_importExpanded) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withAlpha(10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.upload_file, color: Colors.purple, size: 18),
              SizedBox(width: 8),
              Text(
                '导入压缩包',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _importPathController,
                  decoration: InputDecoration(
                    hintText: '输入 SDK 压缩包路径 (.zip)',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '解压到 ~/.adb-tool/sdk/',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isImporting ? null : () => _importSDK(context),
            icon: Icon(_isImporting ? Icons.sync : Icons.upload_file, size: 16),
            label: Text(_isImporting ? '导入中...' : '开始导入'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(EmulatorEngineProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withAlpha(50)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              provider.errorMessage!,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _detectSDKs(BuildContext context) async {
    setState(() {
      _isDetecting = true;
      _scanExpanded = true;
    });
    final provider = context.read<EmulatorEngineProvider>();
    await provider.detectSDKs();
    setState(() => _isDetecting = false);
  }

  Future<void> _useSDK(BuildContext context, String path) async {
    final provider = context.read<EmulatorEngineProvider>();
    await provider.useSDK(path);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已切换到: $path'), duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<void> _showSelectPathDialog(BuildContext context, EmulatorEngineProvider provider) async {
    final pathController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择 SDK 路径'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: pathController,
                decoration: const InputDecoration(
                  labelText: 'SDK 路径',
                  hintText: '/Users/xxx/Library/Android/sdk',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '输入 Android SDK 根目录路径',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, pathController.text),
            child: const Text('使用此路径'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;
    if (!mounted) return;

    await _useSDK(context, result);
  }

  Future<void> _startDownload(BuildContext context) async {
    final url = _downloadUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入下载 URL')),
      );
      return;
    }

    // 从 URL 提取文件名作为 ID
    final uri = Uri.tryParse(url);
    final filename = uri?.pathSegments.last.replaceAll('.zip', '').replaceAll('.tar.gz', '') ?? 'sdk';
    final id = filename.split('-').last;

    final provider = context.read<EmulatorEngineProvider>();

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    await provider.downloadSDK(
      url: url,
      id: id,
      name: filename,
    );

    // Start polling
    _downloadPoller?.cancel();
    _downloadPoller = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!_isDownloading) {
        _downloadPoller?.cancel();
        return;
      }

      await provider.checkDownloadProgress(id);
      final download = provider.currentDownload;

      setState(() {
        _downloadProgress = download?.progress ?? 0;
        if (download?.status != 'downloading') {
          _isDownloading = false;
          _downloadPoller?.cancel();

          if (download?.status == 'completed') {
            _downloadUrlController.clear();
          }
        }
      });
    });
  }

  Future<void> _cancelDownload(BuildContext context) async {
    final provider = context.read<EmulatorEngineProvider>();
    final id = provider.currentDownload?.id;
    if (id == null) return;

    try {
      final api = context.read<ApiClient>();
      await api.dio.post('/api/emulator/download/cancel', queryParameters: {'id': id});
      setState(() => _isDownloading = false);
      _downloadPoller?.cancel();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('取消失败: $e')),
        );
      }
    }
  }

  Future<void> _importSDK(BuildContext context) async {
    final path = _importPathController.text.trim();
    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入压缩包路径')),
      );
      return;
    }

    setState(() => _isImporting = true);

    try {
      final api = context.read<ApiClient>();

      final uri = Uri.parse('${api.baseUrl}/api/emulator/sdk/import');
      final request = http.MultipartRequest('POST', uri);

      final file = File(path);
      if (!await file.exists()) {
        throw Exception('文件不存在: $path');
      }

      request.files.add(await http.MultipartFile.fromPath('sdk', path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('导入失败: ${response.body}');
      }

      if (mounted) {
        await context.read<EmulatorEngineProvider>().refreshStatus();
        _importPathController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SDK 导入成功！')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }
}
