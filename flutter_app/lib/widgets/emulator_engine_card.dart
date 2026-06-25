// Emulator engine configuration card widget.
// Displays and manages the Android SDK import and configuration.
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/emulator_engine_provider.dart';
import '../services/api_client.dart';

class _LogEntry {
  final DateTime time;
  final String operation;
  final String message;
  final bool isError;

  _LogEntry({
    required this.time,
    required this.operation,
    required this.message,
    this.isError = false,
  });
}

class EmulatorEngineCard extends StatefulWidget {
  const EmulatorEngineCard({super.key});

  @override
  State<EmulatorEngineCard> createState() => _EmulatorEngineCardState();
}

class _EmulatorEngineCardState extends State<EmulatorEngineCard> {
  bool _isImporting = false;
  bool _isDetecting = false;
  Timer? _downloadPoller;

  // 当前选中的 Tab
  int _selectedTab = 0; // 0=扫描检测, 1=选择路径, 2=下载 SDK, 3=导入压缩包
  bool _debugExpanded = false;

  // 调试日志
  final List<_LogEntry> _logs = [];
  final ScrollController _logScrollController = ScrollController();

  void _addLog(String operation, String message, {bool isError = false}) {
    final entry = _LogEntry(
      time: DateTime.now(),
      operation: operation,
      message: message,
      isError: isError,
    );
    setState(() {
      _logs.insert(0, entry);
      if (_logs.length > 100) {
        _logs.removeLast();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // 下载相关
  final _downloadUrlController = TextEditingController();
  bool _isDownloading = false;
  double _downloadProgress = 0;

  // 导入相关
  final _importPathController = TextEditingController();

  // 选择路径相关
  final _customPathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 默认选中扫描检测
    _selectedTab = 0;
  }

  @override
  void dispose() {
    _downloadUrlController.dispose();
    _importPathController.dispose();
    _customPathController.dispose();
    _downloadPoller?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmulatorEngineProvider>();
    final theme = Theme.of(context);

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

            // Tab 切换栏
            _buildTabBar(),

            const SizedBox(height: 16),

            // Tab 内容容器
            _buildTabContent(provider),

            if (provider.errorMessage != null) ...[
              const SizedBox(height: 12),
              _buildErrorMessage(provider),
            ],

            const Divider(height: 24),

            // 调试日志区域
            _buildDebugSection(),
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

  Widget _buildTabBar() {
    return Row(
      children: [
        _buildTabButton(
          index: 0,
          icon: Icons.search,
          label: '扫描检测',
          isLoading: _isDetecting,
        ),
        const SizedBox(width: 8),
        _buildTabButton(
          index: 1,
          icon: Icons.folder_open,
          label: '选择路径',
        ),
        const SizedBox(width: 8),
        _buildTabButton(
          index: 2,
          icon: Icons.cloud_download,
          label: '下载 SDK',
        ),
        const SizedBox(width: 8),
        _buildTabButton(
          index: 3,
          icon: Icons.upload_file,
          label: '导入压缩包',
        ),
      ],
    );
  }

  Widget _buildTabButton({
    required int index,
    required IconData icon,
    required String label,
    bool isLoading = false,
  }) {
    final isSelected = _selectedTab == index;

    return Expanded(
      child: OutlinedButton.icon(
        onPressed: () => setState(() => _selectedTab = index),
        icon: Icon(isLoading ? Icons.sync : icon, size: 16),
        label: Text(isLoading ? '处理中...' : label),
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? Colors.blue.withAlpha(10) : null,
          foregroundColor: isSelected ? Colors.blue.shade700 : null,
          side: isSelected ? BorderSide(color: Colors.blue.shade300) : null,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildTabContent(EmulatorEngineProvider provider) {
    switch (_selectedTab) {
      case 0:
        return _buildScanContent(provider);
      case 1:
        return _buildSelectPathContent(provider);
      case 2:
        return _buildDownloadContent();
      case 3:
        return _buildImportContent();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildScanContent(EmulatorEngineProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 说明信息
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withAlpha(10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withAlpha(30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    '扫描说明',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '将扫描以下位置查找 Android SDK：',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 4),
              _buildScanPathHint('~/Library/Android/sdk', 'Android Studio 默认路径'),
              _buildScanPathHint('/Volumes/xxx/Android/sdk', '外置硬盘（如有）'),
              _buildScanPathHint('~/.adb-tool/sdk', '我们管理的 SDK（如有）'),
              _buildScanPathHint('ANDROID_HOME', '环境变量路径'),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _isDetecting ? null : () => _detectSDKs(context),
                    icon: Icon(_isDetecting ? Icons.sync : Icons.search, size: 16),
                    label: Text(_isDetecting ? '扫描中...' : '开始扫描'),
                  ),
                  const SizedBox(width: 8),
                  if (provider.detectedSDKs.isNotEmpty)
                    TextButton.icon(
                      onPressed: _isDetecting ? null : () => _detectSDKs(context),
                      icon: Icon(Icons.refresh, size: 14, color: Colors.grey),
                      label: Text('重新扫描', style: TextStyle(color: Colors.grey.shade600)),
                    ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 扫描结果
        if (provider.detectedSDKs.isEmpty && !_isDetecting)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                '点击上方按钮扫描系统中的 SDK',
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
        else ...[
          Row(
            children: [
              const Icon(Icons.check_circle, size: 16, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                '扫描结果（${provider.detectedSDKs.length} 个）',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...provider.detectedSDKs.map((sdk) => _buildSDKItem(context, sdk, provider)),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildScanPathHint(String path, String description) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(Icons.arrow_right, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text(
            path,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
          const SizedBox(width: 8),
          Text(
            '- $description',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildSDKItem(BuildContext context, SDKDetectResult sdk, EmulatorEngineProvider provider) {
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
                    // Java 环境不在这里显示，应该在单独的 Java 检查区域
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

  // ========== Tab 内容 ==========

  Widget _buildSelectPathContent(EmulatorEngineProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha(10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.folder_open, color: Colors.blue, size: 18),
              SizedBox(width: 8),
              Text(
                '手动输入 SDK 路径',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customPathController,
                  decoration: InputDecoration(
                    hintText: '/Users/xxx/Library/Android/sdk',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () => _customPathController.clear(),
                    ),
                  ),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      _useSDK(context, value.trim());
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _selectFolder(),
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text('浏览'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '输入 Android SDK 根目录路径',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    final path = _customPathController.text.trim();
                    if (path.isNotEmpty) {
                      _useSDK(context, path);
                    }
                  },
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('使用此路径'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  // 打开官方下载页面
                  final url = Uri.parse('https://developer.android.com/studio#command-line-tools-only');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
                icon: const Icon(Icons.help_outline, size: 16),
                label: const Text('不知道在哪？'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadContent() {
    return Container(
      padding: const EdgeInsets.all(16),
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
                '下载 Android SDK',
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
          TextField(
            controller: _downloadUrlController,
            decoration: InputDecoration(
              hintText: '输入 SDK 下载 URL',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: const OutlineInputBorder(),
            ),
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

  Widget _buildImportContent() {
    return Container(
      padding: const EdgeInsets.all(16),
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
          TextField(
            controller: _importPathController,
            decoration: InputDecoration(
              hintText: '输入 SDK 压缩包路径 (.zip)',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: const OutlineInputBorder(),
            ),
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

  Widget _buildDebugSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏
        InkWell(
          onTap: () => setState(() => _debugExpanded = !_debugExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  _debugExpanded ? Icons.terminal : Icons.terminal_outlined,
                  size: 16,
                  color: Colors.blueGrey,
                ),
                const SizedBox(width: 8),
                const Text(
                  '调试日志',
                  style: TextStyle(fontWeight: FontWeight.w500, color: Colors.blueGrey),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _logs.isEmpty ? Colors.grey.withAlpha(20) : Colors.blue.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_logs.length}',
                    style: TextStyle(
                      fontSize: 10,
                      color: _logs.isEmpty ? Colors.grey : Colors.blue,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  _debugExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),

        // 日志内容
        if (_debugExpanded) ...[
          const SizedBox(height: 8),
          // 操作按钮
          Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _logs.clear()),
                icon: const Icon(Icons.delete_outline, size: 14),
                label: const Text('清空'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  // 模拟一些测试日志
                  _addLog('TEST', '这是一条测试日志 - ${DateTime.now()}');
                  _addLog('API', 'GET /api/emulator/sdk/detect');
                  _addLog('SDK', '检测到路径: ~/Library/Android/sdk');
                },
                icon: const Icon(Icons.play_arrow, size: 14),
                label: const Text('测试日志'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 日志列表
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(8),
            ),
            child: _logs.isEmpty
                ? const Center(
                    child: Text(
                      '暂无日志',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: _logScrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: _logs.length,
                    itemBuilder: (ctx, index) {
                      final log = _logs[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              height: 1.4,
                            ),
                            children: [
                              TextSpan(
                                text: '[${_formatTime(log.time)}] ',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                              TextSpan(
                                text: '${log.operation}: ',
                                style: TextStyle(
                                  color: log.isError ? Colors.red.shade300 : Colors.cyan.shade300,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              TextSpan(
                                text: log.message,
                                style: TextStyle(
                                  color: log.isError ? Colors.red.shade200 : Colors.grey.shade300,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }

  /// 打开文件夹选择对话框，选择 SDK 目录
  Future<void> _selectFolder() async {
    try {
      final String? selectedDirectory = await getDirectoryPath();
      if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
        setState(() {
          _customPathController.text = selectedDirectory;
        });
      }
    } catch (e) {
      debugPrint('Failed to open folder picker: $e');
    }
  }

  Future<void> _detectSDKs(BuildContext context) async {
    _addLog('SDK', '开始扫描...');

    setState(() {
      _isDetecting = true;
    });

    try {
      final provider = context.read<EmulatorEngineProvider>();
      final sdks = await provider.detectSDKs();
      _addLog('SDK', '检测到 ${sdks.length} 个 SDK');
    } catch (e) {
      _addLog('ERROR', '扫描失败: $e', isError: true);
    }

    setState(() => _isDetecting = false);
  }

  Future<void> _useSDK(BuildContext context, String path) async {
    _addLog('USE', '========== 切换 SDK ==========');
    _addLog('USE', '目标路径: $path');

    try {
      final api = context.read<ApiClient>();
      _addLog('USE', '发送 POST /api/emulator/sdk/use');
      _addLog('USE', '请求体: {"sdkPath": "$path"}');

      final response = await api.dio.post('/api/emulator/sdk/use', data: {
        'sdkPath': path,
      });

      _addLog('USE', '收到响应: 状态码=${response.statusCode}');
      _addLog('USE', '响应体: ${response.data}');

      if (response.data['ok'] == true) {
        _addLog('USE', '✅ 后端确认成功!');
        _addLog('USE', '调用 provider.refreshStatus()...');

        final provider = context.read<EmulatorEngineProvider>();
        await provider.refreshStatus();

        _addLog('USE', '✅ refreshStatus 完成');
        _addLog('USE', '当前 engine 状态:');
        _addLog('  ', 'androidHome: ${provider.serverStatus?.androidHome}');
        _addLog('  ', 'emulatorVersion: ${provider.serverStatus?.emulatorVersion}');
        _addLog('  ', 'isValid: ${provider.serverStatus?.isValid}');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已切换到: $path'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        _addLog('USE', '❌ 后端返回失败: ${response.data['error']}', isError: true);
      }

      _addLog('USE', '========== 切换 SDK 完成 ==========');
    } catch (e, stack) {
      _addLog('USE', '❌ 异常: $e', isError: true);
      _addLog('USE', '堆栈: $stack', isError: true);
    }
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
