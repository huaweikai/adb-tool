// Emulator instance card widget.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
        ] else if (instance.status == EmulatorInstanceStatus.starting)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.play_arrow, color: Colors.green),
            tooltip: 'Start',
            onPressed: () => _startInstance(context, provider),
          ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) => _handleMenuAction(context, value, provider),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete'),
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

  Future<void> _restartInstance(BuildContext context, EmulatorInstanceProvider provider) async {
    await provider.stopInstance(instance.id);
    // Wait a moment for cleanup
    await Future.delayed(const Duration(seconds: 1));
    await provider.startInstance(instance.id);
  }

  Future<void> _handleMenuAction(BuildContext context, String action, EmulatorInstanceProvider provider) async {
    switch (action) {
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Instance'),
            content: Text('Are you sure you want to delete "${instance.avdName}"? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await provider.deleteInstance(instance.id);
        }
        break;
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
