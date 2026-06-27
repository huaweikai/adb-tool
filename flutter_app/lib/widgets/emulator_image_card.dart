// Emulator image card widget.
// Displays a single system image with status and actions.
import 'package:flutter/material.dart';
import '../i18n.dart';
import '../models/emulator_image.dart';

class EmulatorImageCard extends StatelessWidget {
  final EmulatorImage image;
  final VoidCallback? onDelete;
  final VoidCallback? onCreateInstance;

  const EmulatorImageCard({
    super.key,
    required this.image,
    this.onDelete,
    this.onCreateInstance,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.storage,
                  size: 20,
                  color: _getStatusColor(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    image.displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _buildStatusChip(),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  image.fileSize > 0 ? image.fileSizeFormatted : tr('imageCard.unknownSize'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (image.localPath.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      image.localPath,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            if (image.isDownloading) ...[
              const SizedBox(height: 12),
              _buildDownloadProgress(),
            ],
            if (image.isReady) ...[
              const SizedBox(height: 12),
              _buildActions(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    final color = _getStatusColor();
    final label = _getStatusLabel();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (image.isDownloading)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            )
          else
            Icon(_getStatusIcon(), size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadProgress() {
    final progress = image.downloadProgress;
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
            Text('$percent%', style: const TextStyle(fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    final canCreate = image.status == EmulatorImageStatus.ready;
    return Row(
      children: [
        if (onCreateInstance != null)
          FilledButton.tonalIcon(
            onPressed: canCreate ? onCreateInstance : null,
            icon: const Icon(Icons.add, size: 16),
            label: Text(canCreate ? tr('emulatorSettings.createInstance') : tr('imageCard.notReady')),
          ),
        const SizedBox(width: 8),
        if (onDelete != null)
          OutlinedButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 16),
            label: Text(tr('imageCard.delete')),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (image.status) {
      case EmulatorImageStatus.ready:
        return Colors.green;
      case EmulatorImageStatus.downloading:
        return Colors.blue;
      case EmulatorImageStatus.error:
        return Colors.red;
      case EmulatorImageStatus.pending:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (image.status) {
      case EmulatorImageStatus.ready:
        return Icons.check_circle;
      case EmulatorImageStatus.downloading:
        return Icons.downloading;
      case EmulatorImageStatus.error:
        return Icons.error;
      case EmulatorImageStatus.pending:
        return Icons.hourglass_empty;
    }
  }

  String _getStatusLabel() {
    switch (image.status) {
      case EmulatorImageStatus.ready:
        return tr('engineCard.status.ready');
      case EmulatorImageStatus.downloading:
        return tr('imageCard.downloading');
      case EmulatorImageStatus.error:
        return tr('imageCard.error');
      case EmulatorImageStatus.pending:
        return tr('imageCard.pending');
    }
  }
}
