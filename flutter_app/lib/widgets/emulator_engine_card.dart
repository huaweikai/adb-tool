// Emulator engine configuration card widget.
// Displays and manages the Android SDK import and configuration.
import 'dart:async';
import 'dart:io';
import 'package:adb_tool/providers/locale_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../i18n.dart';
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

  // sdkmanager-driven install (e.g. emulator + system-images). Distinct from
  // the SDK-zip download (handled by _downloadPoller above).
  SDKInstallJob? _installJob;
  Timer? _installPoller;

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
    _installPoller?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
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
      final invalidPath = status?.selectedSDKInvalid == true
          ? status?.selectedSDKPath
          : null;
      if (invalidPath != null && invalidPath.isNotEmpty) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withAlpha(60)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('engineCard.selectedSDKInvalid'),
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                invalidPath,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        );
      }
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Text(
              tr('engineCard.noSDKConfigured'),
              style: const TextStyle(color: Colors.grey),
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
                    SnackBar(content: Text(tr('engineCard.pathCopied')), duration: const Duration(seconds: 1)),
                  );
                },
                tooltip: tr('engineCard.copyPath'),
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
              _infoChip(
                Icons.apps,
                status.emulatorVersion != null && status.emulatorVersion!.isNotEmpty
                    ? tr('engineCard.emulatorInstalled', {'version': status.emulatorVersion!})
                    : tr('engineCard.emulatorMissing'),
                isReady: status.emulatorVersion != null && status.emulatorVersion!.isNotEmpty,
              ),
              _infoChip(
                Icons.settings,
                'AVD Manager',
                isReady: status.avdmanagerPath != null && status.avdmanagerPath!.isNotEmpty,
              ),
              _infoChip(
                Icons.inventory,
                'SDK Manager',
                isReady: status.sdkmanagerPath != null && status.sdkmanagerPath!.isNotEmpty,
              ),
            ],
          ),
          // Emulator 还没装时，显示下载入口和实时进度
          _buildInstallEmulatorSection(context, status),
        ],
      ),
    );
  }

  /// "下载 emulator" 按钮 + 实时进度条。仅在 toolchain 已就绪、emulator
  /// 二进制还没装、sdkmanager 可用时显示。一旦安装完成，下一次刷新就会让
  /// Emulator chip 变成绿色 ✓，"创建实例"按钮也会解锁。
  Widget _buildInstallEmulatorSection(BuildContext context, EmulatorEngineStatus status) {
    final emulatorReady = status.emulatorVersion != null && status.emulatorVersion!.isNotEmpty;
    final sdkmanagerReady = status.sdkmanagerPath != null && status.sdkmanagerPath!.isNotEmpty;

    if (emulatorReady) return const SizedBox.shrink();

    final job = _installJob;
    final running = job != null && job.isRunning;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (running) ...[
            // 正在下载：进度条 + 当前 activity
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.message.isNotEmpty ? job.message : tr('emulatorSettings.install.downloadPreparing'),
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: job.progress > 0 ? job.progress : null,
                          minHeight: 6,
                          backgroundColor: Colors.grey.withAlpha(40),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(job.progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ] else if (job != null && job.status == 'error') ...[
            // 上一次下载失败
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    job.error ?? tr('engineCard.installFailed'),
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: sdkmanagerReady ? () => _installEmulator(context) : null,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(tr('engineCard.retry')),
                ),
              ],
            ),
          ] else if (job != null && job.status == 'completed') ...[
            // 已安装但 chip 还没刷新（极端情况下）
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 6),
                Text(tr('engineCard.installCompleted'),
                    style: const TextStyle(color: Colors.green, fontSize: 12)),
              ],
            ),
          ] else ...[
            // 初始状态：CTA 按钮
            Row(
              children: [
                Expanded(
                  child: Text(
                    sdkmanagerReady
                        ? tr('engineCard.installEmulatorViaSdkmanager')
                        : tr('engineCard.installEmulatorNeedsCmdline'),
                    style: TextStyle(
                      fontSize: 12,
                      color: sdkmanagerReady ? Colors.grey.shade700 : Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: sdkmanagerReady ? () => _installEmulator(context) : null,
                  icon: const Icon(Icons.download, size: 16),
                  label: Text(tr('engineCard.installEmulator')),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

Widget _infoChip(IconData icon, String label, {required bool isReady}) {
    final color = isReady ? Colors.green : Colors.red;
    final suffix = isReady ? ' ✓' : ' ✗';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$label$suffix',
            style: TextStyle(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(EmulatorEngineProvider provider) {
    final status = provider.serverStatus;
    final toolchainReady = status?.toolchainReady == true;
    final hasSDK = status?.androidHome?.isNotEmpty == true;
    // emulatorReady requires both the version string (proves validateEmulatorBinary
    // ran successfully) and an actual EmulatorPath. toolchainReady alone only
    // means sdkmanager + avdmanager + java are present — emulator itself can
    // still be missing, in which case the SDK is "partially ready".
    final emulatorReady = status != null &&
        status.emulatorPath != null &&
        status.emulatorPath!.isNotEmpty &&
        status.emulatorVersion != null &&
        status.emulatorVersion!.isNotEmpty;

    // Full readiness requires emulator binary to actually be installed and
    // runnable. toolchain-only SDKs (avdmanager + java, no emulator) are
    // "partially ready" — usable for picking a path and downloading, but
    // not for creating/starting instances.
    final fullyReady = toolchainReady && emulatorReady;

    Color color;
    String label;
    IconData icon;

    if (_isImporting || provider.isDetecting || _isDownloading) {
      color = Colors.orange;
      label = tr('engineCard.status.processing');
      icon = Icons.hourglass_top;
    } else if (fullyReady) {
      color = Colors.green;
      label = tr('engineCard.status.ready');
      icon = Icons.check_circle;
    } else if (hasSDK) {
      color = Colors.orange;
      label = tr('engineCard.status.partialReady');
      icon = Icons.warning_amber_rounded;
    } else {
      color = Colors.grey;
      label = tr('engineCard.status.notConfigured');
      icon = Icons.info_outline;
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
            Icon(icon, size: 14, color: color),
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
          label: tr('engineCard.action.scan'),
          isLoading: _isDetecting,
        ),
        const SizedBox(width: 8),
        _buildTabButton(
          index: 1,
          icon: Icons.folder_open,
          label: tr('engineCard.action.pickPath'),
        ),
        const SizedBox(width: 8),
        _buildTabButton(
          index: 2,
          icon: Icons.cloud_download,
          label: tr('engineCard.action.downloadSDK'),
        ),
        const SizedBox(width: 8),
        _buildTabButton(
          index: 3,
          icon: Icons.upload_file,
          label: tr('engineCard.action.importZip'),
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
        label: Text(isLoading ? tr('engineCard.status.processingDots') : label),
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
                    tr('engineCard.scanTitle'),
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tr('engineCard.scanIntro'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 4),
              _buildScanPathHint('~/Library/Android/sdk', tr('engineCard.scanLoc1')),
              _buildScanPathHint('/Volumes/xxx/Android/sdk', tr('engineCard.scanLoc2')),
              _buildScanPathHint('~/.adb-tool/sdk', tr('engineCard.scanLoc3')),
              _buildScanPathHint('ANDROID_HOME', tr('engineCard.scanLoc4')),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _isDetecting ? null : () => _detectSDKs(context),
                    icon: Icon(_isDetecting ? Icons.sync : Icons.search, size: 16),
                    label: Text(_isDetecting ? tr('engineCard.scanning') : tr('engineCard.startScan')),
                  ),
                  const SizedBox(width: 8),
                  if (provider.detectedSDKs.isNotEmpty)
                    TextButton.icon(
                      onPressed: _isDetecting ? null : () => _detectSDKs(context),
                      icon: Icon(Icons.refresh, size: 14, color: Colors.grey),
                      label: Text(tr('engineCard.rescan'), style: TextStyle(color: Colors.grey.shade600)),
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
            child: Center(
              child: Text(
                tr('engineCard.scanHint'),
                style: const TextStyle(color: Colors.grey),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(tr('engineCard.scanningDots')),
              ],
            ),
          )
        else ...[
          Row(
            children: [
              const Icon(Icons.check_circle, size: 16, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                tr('engineCard.scanResultCount', {'count': '${provider.detectedSDKs.length}'}),
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
              child: Text(
                tr('engineCard.inUse'),
                style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
              ),
            )
          else if (sdk.hasEmulator)
            FilledButton(
              onPressed: () => _useSDK(context, sdk.path),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(tr('engineCard.useThisSDK')),
            )
          else if (sdk.hasAvdmanager)
            // No emulator binary yet, but the toolchain (sdkmanager + avdmanager)
            // is there — let the user select the SDK and we'll guide them to
            // install emulator + system-image via sdkmanager.
            FilledButton.tonal(
              onPressed: () => _useSDK(context, sdk.path),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(tr('engineCard.useThisSDKNoEmulator')),
            )
          else
            // Neither emulator nor avdmanager — this path isn't a usable SDK.
            Tooltip(
              message: tr('engineCard.invalidSDKDir'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(20),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(tr('engineCard.unavailable'), style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
          Row(
            children: [
              const Icon(Icons.folder_open, color: Colors.blue, size: 18),
              const SizedBox(width: 8),
              Text(
                tr('engineCard.manualPickTitle'),
                style: const TextStyle(fontWeight: FontWeight.w500),
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
                label: Text(tr('engineCard.browse')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tr('engineCard.pathHint'),
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
                  label: Text(tr('engineCard.useThisPath')),
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
                label: Text(tr('engineCard.whereIsIt')),
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
              Text(
                tr('engineCard.downloadSDKTitle'),
                style: const TextStyle(fontWeight: FontWeight.w500),
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
                label: Text(tr('engineCard.officialPage')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _downloadUrlController,
            decoration: InputDecoration(
              hintText: tr('engineCard.urlHint'),
              hintStyle: TextStyle(color: Colors.grey.shade400),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('engineCard.urlHelp'),
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
                  child: Text(tr('emulatorSettings.delete.cancel')),
                ),
              ],
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: () => _startDownload(context),
              icon: const Icon(Icons.download, size: 16),
              label: Text(tr('engineCard.startDownload')),
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
          Row(
            children: [
              const Icon(Icons.upload_file, color: Colors.purple, size: 18),
              const SizedBox(width: 8),
              Text(
                tr('engineCard.action.importZip'),
                style: const TextStyle(fontWeight: FontWeight.w500),
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
                    hintText: tr('engineCard.zipHint'),
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () async {
                  final file = await openFile(
                    acceptedTypeGroups: [
                      XTypeGroup(
                        label: 'ZIP',
                        extensions: ['zip'],
                      ),
                    ],
                  );
                  if (file != null) {
                    _importPathController.text = file.path;
                  }
                },
                icon: const Icon(Icons.folder_open, size: 20),
                tooltip: tr('engineCard.browseZip'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tr('engineCard.zipHelp'),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isImporting ? null : () => _importSDK(context),
            icon: Icon(_isImporting ? Icons.sync : Icons.upload_file, size: 16),
            label: Text(_isImporting ? tr('engineCard.importingDots') : tr('engineCard.startImport')),
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
                Text(
                  tr('engineCard.debugLogTitle'),
                  style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.blueGrey),
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
                label: Text(tr('engineCard.clearLog')),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  // 模拟一些测试日志
                  _addLog('TEST', tr('engineCard.testLogEntry', {'time': DateTime.now().toString()}));
                  _addLog('API', 'GET /api/emulator/sdk/detect');
                  _addLog('SDK', tr('engineCard.detectedPathEntry'));
                },
                icon: const Icon(Icons.play_arrow, size: 14),
                label: Text(tr('engineCard.testLog')),
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
                ? Center(
                    child: Text(
                      tr('engineCard.noLog'),
                      style: const TextStyle(color: Colors.grey),
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
    _addLog('SDK', tr('engineCard.scanLog.start'));

    setState(() {
      _isDetecting = true;
    });

    try {
      final provider = context.read<EmulatorEngineProvider>();
      final sdks = await provider.detectSDKs();
      _addLog('SDK', tr('engineCard.scanLog.found', {'count': '${sdks.length}'}));
    } catch (e) {
      _addLog('ERROR', tr('engineCard.scanLog.failed', {'error': '$e'}), isError: true);
    }

    setState(() => _isDetecting = false);
  }

  Future<void> _useSDK(BuildContext context, String path) async {
    _addLog('USE', tr('engineCard.useSDKLog.header'));
    _addLog('USE', tr('engineCard.useSDKLog.target', {'path': path}));

    try {
      final api = context.read<ApiClient>();
      _addLog('USE', tr('engineCard.useSDKLog.request'));
      _addLog('USE', '请求体: {"sdkPath": "$path"}');

      final response = await api.dio.post('/api/emulator/sdk/use', data: {
        'sdkPath': path,
      });

      _addLog('USE', tr('engineCard.useSDKLog.response', {'code': '${response.statusCode}'}));
      _addLog('USE', tr('engineCard.useSDKLog.responseBody', {'body': '${response.data}'}));

      if (response.data['ok'] == true) {
        _addLog('USE', tr('engineCard.useSDKLog.backendOk'));
        _addLog('USE', tr('engineCard.useSDKLog.refresh'));

        final provider = context.read<EmulatorEngineProvider>();
        await provider.refreshStatus();

        _addLog('USE', tr('engineCard.useSDKLog.refreshDone'));
        _addLog('USE', tr('engineCard.useSDKLog.stateNow'));
        _addLog('  ', 'androidHome: ${provider.serverStatus?.androidHome}');
        _addLog('  ', 'emulatorVersion: ${provider.serverStatus?.emulatorVersion}');
        _addLog('  ', 'isValid: ${provider.serverStatus?.isValid}');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('engineCard.useSDKLog.switched', {'path': path})),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        _addLog('USE', tr('engineCard.useSDKLog.backendFailed', {'error': '${response.data['error']}'}), isError: true);
      }

      _addLog('USE', tr('engineCard.useSDKLog.done'));
    } catch (e, stack) {
      _addLog('USE', tr('engineCard.useSDKLog.exception', {'error': '$e'}), isError: true);
      _addLog('USE', tr('engineCard.useSDKLog.stack', {'stack': '$stack'}), isError: true);
    }
  }

  /// Kick off an sdkmanager-driven emulator install. Backend runs the
  /// sdkmanager child process; we poll for progress every 800ms until the
  /// job finishes, then refresh engine status so the chip + button flip
  /// to "ready".
  Future<void> _installEmulator(BuildContext context) async {
    final api = context.read<ApiClient>();
    final provider = context.read<EmulatorEngineProvider>();

    _addLog('INSTALL', tr('engineCard.installLog.header'));
    _addLog('INSTALL', '发送 POST /api/emulator/sdk/install packages=["emulator"]');

    try {
      final job = await api.installPackages(['emulator']);
      _addLog('INSTALL', tr('engineCard.installLog.started', {'id': job.id}));
      if (!mounted) return;

      setState(() => _installJob = job);

      _installPoller?.cancel();
      _installPoller = Timer.periodic(const Duration(milliseconds: 800), (timer) async {
        final current = _installJob;
        if (current == null) {
          timer.cancel();
          return;
        }
        if (!current.isRunning) {
          timer.cancel();
          return;
        }
        try {
          final updated = await api.getInstallStatus(current.id);
          if (!mounted) return;
          setState(() => _installJob = updated);
          if (updated.isDone) {
            timer.cancel();
            if (updated.status == 'completed') {
              _addLog('INSTALL', tr('engineCard.installLog.completed'));
              await provider.refreshStatus();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(tr('engineCard.installLog.done')),
                      duration: const Duration(seconds: 2)),
                );
              }
            } else {
              _addLog('INSTALL', tr('engineCard.installLog.failed', {'error': '${updated.error}'}), isError: true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr('emulatorSettings.install.failed', {
                    'error': updated.error ??
                        tr('emulatorSettings.common.unknownError'),
                  }))),
                );
              }
            }
          }
        } catch (e) {
          _addLog('INSTALL', tr('engineCard.installLog.pollException', {'error': '$e'}), isError: true);
        }
      });
    } catch (e, stack) {
      _addLog('INSTALL', tr('engineCard.installLog.startFailed', {'error': '$e'}), isError: true);
      _addLog('INSTALL', tr('engineCard.useSDKLog.stack', {'stack': '$stack'}), isError: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('engineCard.installLog.kickoffFailed', {'error': '$e'}))),
        );
      }
    }
  }

  Future<void> _startDownload(BuildContext context) async {
    final url = _downloadUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('engineCard.downloadLog.needURL'))),
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
          SnackBar(content: Text(tr('engineCard.cancelFailed', {'error': '$e'}))),
        );
      }
    }
  }

  Future<void> _importSDK(BuildContext context) async {
    final path = _importPathController.text.trim();
    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('engineCard.importLog.needZip'))),
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
        throw Exception(tr('engineCard.importLog.fileMissing', {'path': path}));
      }

      request.files.add(await http.MultipartFile.fromPath('sdk', path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception(tr('engineCard.importLog.failedBody', {'body': response.body}));
      }

      if (mounted) {
        await context.read<EmulatorEngineProvider>().refreshStatus();
        _importPathController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('engineCard.importLog.success'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr('engineCard.importLog.failed', {'error': '$e'})),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }
}
