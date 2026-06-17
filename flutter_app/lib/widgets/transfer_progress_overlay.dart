import 'package:flutter/material.dart';

import '../i18n.dart';
import '../widgets/file_transfer.dart';

/// 文件传输进度全屏遮罩。
class TransferProgressOverlay extends StatelessWidget {
  final TransferState transfer;
  final String Function(String phaseKey) trPhase;
  final VoidCallback onCancel;

  const TransferProgressOverlay({
    super.key,
    required this.transfer,
    required this.trPhase,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUpload = transfer.mode == TransferMode.upload;
    final progress = transfer.progress;
    final percent = progress == null
        ? tr('processing')
        : '${(progress * 100).clamp(0, 100).toStringAsFixed(1)}%';

    return AbsorbPointer(
      absorbing: false,
      child: Container(
        color: theme.colorScheme.scrim.withAlpha(80),
        child: Center(
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(isUpload ? Icons.upload_file : Icons.download,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isUpload
                            ? tr('uploadingFile')
                            : tr('downloadingFile'),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(percent,
                        style: const TextStyle(
                            fontFamily: 'Menlo', fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  transfer.fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
                ),
                const SizedBox(height: 12),
                progress == null
                    ? const LinearProgressIndicator()
                    : LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0).toDouble()),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        trPhase(transfer.phaseKey),
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    Text(
                      '${formatBytes(transfer.sent)} / ${transfer.total > 0 ? formatBytes(transfer.total) : tr('unknownSize')}',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Menlo',
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  tr('transferWarning'),
                  style: TextStyle(
                      fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close, size: 16),
                    label: Text(tr('cancel')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
