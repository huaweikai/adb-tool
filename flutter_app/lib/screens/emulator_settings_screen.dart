// Emulator settings screen.
// Main screen for managing Android emulator configuration.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/emulator_image_provider.dart';
import '../providers/emulator_instance_provider.dart';
import '../providers/emulator_engine_provider.dart';
import '../providers/emulator_java_provider.dart';
import '../widgets/emulator_engine_card.dart';
import '../widgets/emulator_java_card.dart';
import '../widgets/emulator_image_card.dart';
import '../widgets/add_image_dialog.dart';
import '../widgets/emulator_instance_card.dart';
import '../widgets/create_instance_dialog.dart';

class EmulatorSettingsScreen extends StatefulWidget {
  const EmulatorSettingsScreen({super.key});

  @override
  State<EmulatorSettingsScreen> createState() => _EmulatorSettingsScreenState();
}

class _EmulatorSettingsScreenState extends State<EmulatorSettingsScreen> {
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
        const SizedBox(height: 12),
        _buildImageList(context, provider),
      ],
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
