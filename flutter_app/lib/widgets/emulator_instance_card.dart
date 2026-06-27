// Emulator instance card widget.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adb_tool/i18n.dart';
import 'package:adb_tool/models/emulator_instance.dart';
import 'package:adb_tool/providers/emulator_instance_provider.dart';

class EmulatorInstanceCard extends StatelessWidget {
  final EmulatorInstance instance;
  final VoidCallback? onTap;

  const EmulatorInstanceCard({
    super.key,
    required this.instance,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  _StatusIndicator(status: instance.status),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          instance.avdName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _getStatusText(instance.status),
                          style: TextStyle(
                            color: _getStatusColor(instance.status),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ActionButtons(instance: instance),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Info grid
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.memory,
                    label: '${instance.config.cores} cores',
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.storage,
                    label: '${instance.config.memoryMb} MB',
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.smartphone,
                    label: '${instance.config.width}×${instance.config.height}',
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Port info
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.link,
                    label: 'Serial: ${instance.serial}',
                  ),
                  const SizedBox(width: 8),
                  if (instance.isRunning)
                    _InfoChip(
                      icon: Icons.dns,
                      label: 'PID: ${instance.pid ?? "?"}',
                    ),
                ],
              ),

              // Live boot progress, shown only while the instance is
              // actually starting. A real bar with a stage label beats
              // a spinning dot in the corner: the user can see what's
              // happening, and they can cancel the boot.
              if (instance.status == EmulatorInstanceStatus.starting) ...[
                const SizedBox(height: 12),
                _BootProgressPanel(instance: instance),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final EmulatorInstanceStatus status;

  const _StatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _getStatusColor(status),
      ),
    );
  }

  Color _getStatusColor(EmulatorInstanceStatus status) {
    switch (status) {
      case EmulatorInstanceStatus.running:
        return Colors.green;
      case EmulatorInstanceStatus.starting:
        return Colors.orange;
      case EmulatorInstanceStatus.stopped:
        return Colors.grey;
      case EmulatorInstanceStatus.error:
        return Colors.red;
    }
  }
}

/// Boot progress strip: shows the live stage label, a percentage, and
/// a LinearProgressIndicator that fills in 0..100 as the backend
/// reports progress. Visible only when the instance is in
/// StatusStarting.
class _BootProgressPanel extends StatelessWidget {
  final EmulatorInstance instance;

  const _BootProgressPanel({required this.instance});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Backend reports 0..100. Clamp defensively so a stray value
    // outside that range doesn't blow up the progress bar.
    final raw = instance.bootProgress;
    final value = raw <= 0
        ? null
        : (raw >= 100 ? 1.0 : raw / 100.0);

    final stage = _stageLabel(instance.bootStage);
    final message = instance.bootMessage.isNotEmpty
        ? instance.bootMessage
        : '正在准备 emulator…';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
              Text(
                raw > 0 ? '$raw%' : '…',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.orange.shade800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: Colors.orange.withAlpha(40),
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _stageLabel(String raw) {
    switch (raw) {
      case 'launching':
        return '正在启动 emulator…';
      case 'booting_kernel':
        return '正在启动内核…';
      case 'booting_android':
        return 'Android 正在启动…';
      case 'adb_connecting':
        return '正在连接 ADB…';
      case 'ready':
        return '启动完成';
      default:
        return '正在启动…';
    }
  }
}

class _ActionButtons extends StatelessWidget {
  final EmulatorInstance instance;

  const _ActionButtons({required this.instance});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<EmulatorInstanceProvider>();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (instance.isRunning) ...[
          IconButton(
            icon: const Icon(Icons.stop, color: Colors.red),
            tooltip: 'Stop',
            onPressed: () => _stopInstance(context, provider),
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Restart',
            onPressed: () => _restartInstance(context, provider),
          ),
        ] else if (instance.status == EmulatorInstanceStatus.starting) ...[
          // Cancel a boot that the user no longer wants to wait for.
          // Uses the same Stop endpoint — the backend treats
          // StatusStarting as a valid target for stop.
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            tooltip: '取消启动',
            onPressed: () => _stopInstance(context, provider),
          ),
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: '查看启动日志',
            onPressed: () => _showInstanceLog(context, provider),
          ),
        ] else
          IconButton(
            icon: const Icon(Icons.play_arrow, color: Colors.green),
            tooltip: 'Start',
            onPressed: () => _startInstance(context, provider),
          ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) => _handleMenuAction(context, value, provider),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'reveal',
              child: Row(
                children: [
                  const Icon(Icons.folder_open),
                  const SizedBox(width: 8),
                  Text(tr('instanceCard.openInExplorer')),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(tr('delete')),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _startInstance(BuildContext context, EmulatorInstanceProvider provider) async {
    await provider.startInstance(instance.id);
  }

  Future<void> _stopInstance(BuildContext context, EmulatorInstanceProvider provider) async {
    await provider.stopInstance(instance.id);
  }

  /// Open a dialog showing the last ~80 lines of the instance's
  /// emulator.log. Useful when a boot is hung and the user wants to
  /// see what the emulator said before it stalled. Fetches on demand
  /// rather than streaming so we don't need a second WebSocket.
  Future<void> _showInstanceLog(
      BuildContext context, EmulatorInstanceProvider provider) async {
    final lines = await provider.fetchInstanceLog(instance.id, tail: 80);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.description_outlined, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${instance.avdName} · emulator.log',
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        content: SizedBox(
          width: 640,
          height: 420,
          child: lines == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(tr('instanceCard.logLoadFailed')),
                  ),
                )
              : lines.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(tr('instanceCard.logEmpty')),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Scrollbar(
                        child: ListView.builder(
                          itemCount: lines.length,
                          itemBuilder: (_, i) => Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 1),
                            child: Text(
                              lines[i],
                              style: const TextStyle(
                                fontFamily: 'Menlo',
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('instanceCard.close')),
          ),
        ],
      ),
    );
  }

  Future<void> _restartInstance(BuildContext context, EmulatorInstanceProvider provider) async {
    await provider.stopInstance(instance.id);
    // Wait a moment for cleanup
    await Future.delayed(const Duration(seconds: 1));
    await provider.startInstance(instance.id);
  }

  Future<void> _handleMenuAction(BuildContext context, String action, EmulatorInstanceProvider provider) async {
    switch (action) {
      case 'reveal':
        await _revealInExplorer(context);
        break;
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(tr('delete') + ' Instance'),
            content: Text('Are you sure you want to delete "${instance.avdName}"? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(tr('cancel')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(tr('delete')),
              ),
            ],
          ),
        );
if (confirmed == true) {
          final ok = await provider.deleteInstance(instance.id);
          if (!context.mounted) break;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ok
                  ? tr('instanceCard.deleted')
                  : '${tr('delete')} failed: ${provider.error ?? tr("emulatorSettings.common.unknownError")}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        break;
      }
    }

  Future<void> _revealInExplorer(BuildContext context) async {
    final path = instance.avdPath;
    if (path.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('instanceCard.noLocalPath'))),
        );
      }
      return;
    }

    if (!FileSystemEntity.isDirectorySync(path) &&
        !File(path).existsSync() &&
        !Directory(path).existsSync()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('instanceCard.pathMissing', {'path': path}))),
        );
      }
      return;
    }

    try {
      if (Platform.isWindows) {
        final isDir = FileSystemEntity.isDirectorySync(path);
        if (isDir) {
          await Process.run('explorer', [path]);
        } else {
          await Process.run('explorer', ['/select,', path]);
        }
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', path]);
      } else if (Platform.isLinux) {
        final dir = FileSystemEntity.isDirectorySync(path)
            ? path
            : File(path).parent.path;
        await Process.run('xdg-open', [dir]);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('instanceCard.openFailed', {'error': '$e'}))),
        );
      }
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

String _getStatusText(EmulatorInstanceStatus status) {
  switch (status) {
    case EmulatorInstanceStatus.running:
      return 'Running';
    case EmulatorInstanceStatus.starting:
      return 'Starting...';
    case EmulatorInstanceStatus.stopped:
      return 'Stopped';
    case EmulatorInstanceStatus.error:
      return 'Error';
  }
}

Color _getStatusColor(EmulatorInstanceStatus status) {
  switch (status) {
    case EmulatorInstanceStatus.running:
      return Colors.green;
    case EmulatorInstanceStatus.starting:
      return Colors.orange;
    case EmulatorInstanceStatus.stopped:
      return Colors.grey;
    case EmulatorInstanceStatus.error:
      return Colors.red;
  }
}
