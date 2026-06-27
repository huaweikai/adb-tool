// Emulator settings screen.
// Main screen for managing Android emulator configuration.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/emulator_image_provider.dart';
import '../providers/emulator_instance_provider.dart';
import '../providers/emulator_engine_provider.dart';
import '../providers/emulator_java_provider.dart';
import '../services/api_client.dart';
import '../widgets/emulator_engine_card.dart';
import '../widgets/emulator_java_card.dart';
import '../widgets/emulator_image_card.dart';
import '../widgets/add_image_dialog.dart';
import '../widgets/emulator_instance_card.dart';
import '../widgets/create_instance_dialog.dart';
import '../widgets/cleanup_cache_dialog.dart';

class EmulatorSettingsScreen extends StatefulWidget {
  const EmulatorSettingsScreen({super.key});

  @override
  State<EmulatorSettingsScreen> createState() => _EmulatorSettingsScreenState();
}

class _EmulatorSettingsScreenState extends State<EmulatorSettingsScreen> {
  // SDK-driven system image install — shows progress in the image section
  // until the job finishes, then we refresh the image list so the new
  // entry shows up. Separate from engine_card's emulator install, which
  // tracks `emulator` specifically.
  SDKInstallJob? _systemImageInstallJob;
  Timer? _systemImageInstallPoller;

  @override
  void dispose() {
    _systemImageInstallPoller?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Pull persisted state from backend on load so SDK / Java selections and
    // imported images are restored without requiring a manual scan.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<EmulatorEngineProvider>().refreshStatus();
      context.read<EmulatorJavaProvider>().refreshStatus();
      context.read<EmulatorImageProvider>().loadImages();
      context.read<EmulatorInstanceProvider>().fetchInstances();
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageProvider = context.watch<EmulatorImageProvider>();
    final instanceProvider = context.watch<EmulatorInstanceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Android 模拟器'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: '清理所有 adb-tool 缓存(SDK 保留)',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => showCleanupCacheDialog(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EmulatorEngineCard(),
            const SizedBox(height: 16),
            const EmulatorJavaCard(),
            const SizedBox(height: 24),
            _buildInstanceSection(context, instanceProvider),
            const SizedBox(height: 24),
            _buildImageSection(context, imageProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildInstanceSection(BuildContext context, EmulatorInstanceProvider provider) {
    final theme = Theme.of(context);
    // Block "create instance" when the engine isn't fully ready — we need
    // a working emulator binary + AVD manager to actually launch one.
    final engineProvider = context.watch<EmulatorEngineProvider>();
    final engineStatus = engineProvider.serverStatus;
    final emulatorReady = engineStatus != null &&
        engineStatus.emulatorPath != null &&
        engineStatus.emulatorPath!.isNotEmpty &&
        engineStatus.emulatorVersion != null &&
        engineStatus.emulatorVersion!.isNotEmpty;
    final canCreate = emulatorReady;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.smartphone, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              '模拟器实例',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Tooltip(
              message: canCreate ? '' : '请先在上方 SDK 引擎卡片中安装 emulator + system-image',
              child: FilledButton.icon(
                onPressed: canCreate ? () => _showCreateInstanceDialog(context) : null,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('创建实例'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildInstanceList(context, provider),
      ],
    );
  }

  Widget _buildInstanceList(BuildContext context, EmulatorInstanceProvider provider) {
    final instances = provider.instances;

    if (provider.isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (instances.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.phone_android,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(100),
                ),
                const SizedBox(height: 12),
                Text(
                  '暂无模拟器实例',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '创建实例以开始使用模拟器',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(150),
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: instances.map((instance) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: EmulatorInstanceCard(instance: instance),
        );
      }).toList(),
    );
  }

  Widget _buildImageSection(BuildContext context, EmulatorImageProvider provider) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.storage, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              '系统镜像',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => _showAddImageDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加镜像'),
            ),
          ],
        ),
        if (_systemImageInstallJob != null) ...[
          const SizedBox(height: 12),
          _buildSystemImageInstallProgress(context),
        ],
        const SizedBox(height: 12),
        _buildImageList(context, provider),
      ],
    );
  }

  /// Live progress card for the in-flight SDK system-image install. Shown
  /// between the section header and the image list whenever there's an
  /// active job — disappears once the job is done and we've shown the
  /// final status for a few seconds.
  Widget _buildSystemImageInstallProgress(BuildContext context) {
    final job = _systemImageInstallJob!;
    final running = job.isRunning;
    final isError = job.status == 'error';
    final isDone = job.status == 'completed';
    final pkg = job.packages.isNotEmpty ? job.packages.first : 'system image';

    Color barColor;
    IconData icon;
    if (isError) {
      barColor = Colors.red;
      icon = Icons.error_outline;
    } else if (isDone) {
      barColor = Colors.green;
      icon = Icons.check_circle;
    } else {
      barColor = Colors.blue;
      icon = Icons.downloading;
    }

    return Card(
      color: barColor.withAlpha(15),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: barColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isError
                        ? '下载失败: ${job.error ?? pkg}'
                        : isDone
                            ? '$pkg 下载完成'
                            : (job.message.isNotEmpty ? job.message : '正在准备...'),
                    style: TextStyle(fontSize: 13, color: barColor, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(job.progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, color: barColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: running && job.progress > 0 ? job.progress : (running ? null : 1.0),
                minHeight: 6,
                backgroundColor: barColor.withAlpha(40),
                color: barColor,
              ),
            ),
            if (pkg.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                pkg,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageList(BuildContext context, EmulatorImageProvider provider) {
    final images = provider.images;

    if (images.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.cloud_download,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(100),
                ),
                const SizedBox(height: 12),
                Text(
                  '暂无系统镜像',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '点击上方按钮添加镜像',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(150),
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: images.map((image) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: EmulatorImageCard(
            image: image,
            onDelete: () => _confirmDelete(context, image.id),
            onCreateInstance: image.isReady ? () => _showCreateInstanceDialog(context) : null,
          ),
        );
      }).toList(),
    );
  }

  Future<void> _showAddImageDialog(BuildContext context) async {
    final provider = context.read<EmulatorImageProvider>();
    await provider.loadSources();
    if (!context.mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AddImageDialog(
        savedSources: provider.sources,
        onRemoveSource: (url) async {
          await provider.removeSource(url);
          if (context.mounted) {
            Navigator.of(context).pop();
            _showAddImageDialog(context);
          }
        },
      ),
    );

    if (result != null && context.mounted) {
      if (result['source'] == 'url') {
        await provider.addImage(url: result['url']);
      } else if (result['source'] == 'sdk') {
        // 通过 sdkmanager 下载 — 调 SDKInstaller 异步装包
        final apiLevel = result['apiLevel'] as int;
        final arch = result['arch'] as String;
        final variant = result['variant'] as String;
        final package = 'system-images;android-$apiLevel;$variant;$arch';
        await _installSystemImageViaSdk(context, package);
      } else {
        final path = result['path'] as String;
        final isZip = result['isZip'] == true;
        final ok = isZip
            ? await provider.importFromZip(path)
            : await provider.importFromPath(path);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? '镜像导入成功'
                  : '镜像导入失败: ${provider.errorMessage ?? '未知错误'}',
            ),
          ),
        );
      }
    }
  }

  /// Start an sdkmanager-driven system image install. We kick off the job
  /// and poll its progress every 800ms — both to drive the progress bar
  /// in the image section and so the user can see when it finishes. On
  /// completion we refresh the image list so the new entry shows up.
  Future<void> _installSystemImageViaSdk(
    BuildContext context,
    String package,
  ) async {
    final api = context.read<ApiClient>();
    final imageProvider = context.read<EmulatorImageProvider>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('开始下载: $package'),
        duration: const Duration(seconds: 2),
      ),
    );

    SDKInstallJob job;
    try {
      job = await api.installPackages([package]);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('启动下载失败: $e')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _systemImageInstallJob = job);

    _systemImageInstallPoller?.cancel();
    _systemImageInstallPoller = Timer.periodic(const Duration(milliseconds: 800), (timer) async {
      final current = _systemImageInstallJob;
      if (current == null || !current.isRunning) {
        timer.cancel();
        return;
      }
      try {
        final updated = await api.getInstallStatus(current.id);
        if (!mounted) return;
        setState(() => _systemImageInstallJob = updated);
        if (updated.isDone) {
          timer.cancel();
          if (updated.status == 'completed') {
            await imageProvider.refreshImages();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('镜像安装完成: $package')),
              );
            }
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('镜像下载失败: ${updated.error ?? "未知错误"}')),
            );
          }
          // Drop the job after a short delay so the user can see the final
          // status; then clear.
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) setState(() => _systemImageInstallJob = null);
          });
        }
      } catch (e) {
        // network blip — keep polling
      }
    });
  }

  Future<void> _confirmDelete(BuildContext context, String imageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除镜像'),
        content: const Text('确定要删除此镜像吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<EmulatorImageProvider>().deleteImage(imageId);
    }
  }

  Future<void> _showCreateInstanceDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => const CreateInstanceDialog(),
    );
  }
}
