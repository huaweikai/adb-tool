// Emulator Java runtime status card widget.
// Displays and manages Java runtime configuration.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/emulator_java_provider.dart';

class EmulatorJavaCard extends StatelessWidget {
  const EmulatorJavaCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmulatorJavaProvider>();
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.coffee, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Java 运行环境',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _buildStatusBadge(context, provider),
              ],
            ),
            const SizedBox(height: 16),
            _buildJavaInfo(context, provider),
            if (provider.errorMessage != null) ...[
              const SizedBox(height: 12),
              _buildErrorMessage(context, provider),
            ],
            if (provider.isDownloading) ...[
              const SizedBox(height: 12),
              _buildDownloadProgress(context, provider),
            ],
            const SizedBox(height: 16),
            _buildActions(context, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, EmulatorJavaProvider provider) {
    Color color;
    String label;
    IconData icon;

    switch (provider.javaStatus) {
      case JavaStatus.found:
        color = Colors.green;
        label = '就绪';
        icon = Icons.check_circle;
      case JavaStatus.notFound:
        color = Colors.orange;
        label = '未找到';
        icon = Icons.warning;
      case JavaStatus.downloading:
        color = Colors.blue;
        label = '下载中';
        icon = Icons.downloading;
      case JavaStatus.checking:
        color = Colors.blue;
        label = '检测中...';
        icon = Icons.sync;
      case JavaStatus.error:
        color = Colors.red;
        label = '错误';
        icon = Icons.error;
      case JavaStatus.unknown:
        color = Colors.grey;
        label = '未知';
        icon = Icons.help_outline;
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

  Widget _buildJavaInfo(BuildContext context, EmulatorJavaProvider provider) {
    final status = provider.status;
    final systemJava = status?.systemJava;

    if (systemJava != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow('路径', systemJava.path),
          const SizedBox(height: 8),
          _infoRow('版本', systemJava.version ?? '未知'),
          if (systemJava.vendor != null) ...[
            const SizedBox(height: 8),
            _infoRow('厂商', systemJava.vendor!),
          ],
        ],
      );
    }

    return Text(
      '未检测到 Java 运行环境',
      style: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(BuildContext context, EmulatorJavaProvider provider) {
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

  Widget _buildDownloadProgress(BuildContext context, EmulatorJavaProvider provider) {
    final progress = provider.downloadProgress;
    final percent = (progress * 100).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(value: progress),
            ),
            const SizedBox(width: 8),
            Text('$percent%', style: const TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton(
              onPressed: () => provider.cancelDownload(),
              child: const Text('取消下载'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, EmulatorJavaProvider provider) {
    final isDownloading = provider.isDownloading;

    return Row(
      children: [
        FilledButton.icon(
          onPressed: isDownloading ? null : () => provider.refreshStatus(),
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('重新检测'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: isDownloading ? null : () => _showDownloadDialog(context),
          icon: const Icon(Icons.download, size: 18),
          label: const Text('下载 Java'),
        ),
      ],
    );
  }

  Future<void> _showDownloadDialog(BuildContext context) async {
    final urlController = TextEditingController();
    String selectedVersion = '17';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('下载 Java 运行环境'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '下载 JetBrains Runtime (JBR) - 推荐用于 Android 开发',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedVersion,
                  decoration: const InputDecoration(
                    labelText: 'Java 版本',
                  ),
                  items: const [
                    DropdownMenuItem(value: '17', child: Text('Java 17 (推荐)')),
                    DropdownMenuItem(value: '21', child: Text('Java 21')),
                    DropdownMenuItem(value: '11', child: Text('Java 11')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedVersion = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: '自定义 URL (可选)',
                    hintText: '留空使用默认下载地址',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '注意: 手动下载地址需要提供完整 URL 和 SHA-256 校验和',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
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
              onPressed: () async {
                Navigator.pop(ctx);
                // TODO: Implement download with proper URL
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('下载功能即将推出'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('开始下载'),
            ),
          ],
        ),
      ),
    );
  }
}
