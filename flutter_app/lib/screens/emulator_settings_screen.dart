// Emulator settings screen.
// Main screen for managing Android emulator configuration.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/emulator_image_provider.dart';
import '../widgets/emulator_engine_card.dart';
import '../widgets/emulator_java_card.dart';
import '../widgets/emulator_image_card.dart';
import '../widgets/add_image_dialog.dart';

class EmulatorSettingsScreen extends StatelessWidget {
  const EmulatorSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final imageProvider = context.watch<EmulatorImageProvider>();

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
            _buildImageSection(context, imageProvider),
          ],
        ),
      ),
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
            onCreateInstance: image.isReady ? () => _createInstance(context, image.id) : null,
          ),
        );
      }).toList(),
    );
  }

  Future<void> _showAddImageDialog(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const AddImageDialog(),
    );

    if (result != null && context.mounted) {
      final provider = context.read<EmulatorImageProvider>();

      if (result['source'] == 'url') {
        await provider.addImage(
          url: result['url'],
          name: result['name'],
          apiLevel: result['apiLevel'],
          arch: result['arch'],
          variant: result['variant'],
        );
      } else {
        // TODO: Handle local path
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('本地路径功能即将推出')),
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

  void _createInstance(BuildContext context, String imageId) {
    // TODO: Implement create instance dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('创建实例功能即将推出')),
    );
  }
}
