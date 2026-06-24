// Emulator engine configuration card widget.
// Displays and manages the Android SDK emulator configuration.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/emulator_engine_provider.dart';

class EmulatorEngineCard extends StatelessWidget {
  const EmulatorEngineCard({super.key});

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
            Row(
              children: [
                Icon(Icons.smart_toy, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '模拟器引擎',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _buildStatusBadge(context, provider),
              ],
            ),
            const SizedBox(height: 16),
            _buildPathInfo(context, provider),
            const SizedBox(height: 12),
            _buildVersionInfo(context, provider),
            if (provider.errorMessage != null) ...[
              const SizedBox(height: 12),
              _buildErrorMessage(context, provider),
            ],
            const SizedBox(height: 16),
            _buildActions(context, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, EmulatorEngineProvider provider) {
    final isValid = provider.isValid;
    final isValidating = provider.validationState == EngineValidationState.validating;

    Color color;
    String label;
    IconData icon;

    if (isValidating) {
      color = Colors.orange;
      label = '检测中...';
      icon = Icons.sync;
    } else if (isValid) {
      color = Colors.green;
      label = '就绪';
      icon = Icons.check_circle;
    } else {
      color = Colors.grey;
      label = '未配置';
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
          if (isValidating)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
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

  Widget _buildPathInfo(BuildContext context, EmulatorEngineProvider provider) {
    final config = provider.config;
    final status = provider.serverStatus;

    final androidHome = config.androidHome ?? status?.androidHome ?? '未设置';
    final emulatorPath = config.emulatorPath.isNotEmpty
        ? config.emulatorPath
        : status?.emulatorPath ?? '未设置';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoRow('ANDROID_HOME', androidHome),
        const SizedBox(height: 8),
        _infoRow('emulator', emulatorPath),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: value == '未设置' ? Colors.grey : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVersionInfo(BuildContext context, EmulatorEngineProvider provider) {
    final status = provider.serverStatus;

    if (status == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Row(
          children: [
            if (status.emulatorVersion != null) ...[
              _versionChip('emulator', status.emulatorVersion!),
              const SizedBox(width: 8),
            ],
            if (status.javaVersion != null)
              _versionChip('Java', status.javaVersion!),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _toolChip('avdmanager', status.avdmanagerPath != null),
            const SizedBox(width: 8),
            _toolChip('sdkmanager', status.sdkmanagerPath != null),
          ],
        ),
      ],
    );
  }

  Widget _versionChip(String label, String version) {
    // Extract short version (e.g., "35.2.9" from full output)
    final shortVersion = version.split('\n').first.split(' ').last;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          Text(
            shortVersion,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _toolChip(String label, bool available) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: available ? Colors.green.withAlpha(20) : Colors.grey.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            available ? Icons.check : Icons.close,
            size: 12,
            color: available ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: available ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(BuildContext context, EmulatorEngineProvider provider) {
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

  Widget _buildActions(BuildContext context, EmulatorEngineProvider provider) {
    final isValidating = provider.validationState == EngineValidationState.validating;

    return Row(
      children: [
        FilledButton.icon(
          onPressed: isValidating ? null : () => _validate(context),
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('重新检测'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => _showConfigDialog(context),
          icon: const Icon(Icons.settings, size: 18),
          label: const Text('配置路径'),
        ),
      ],
    );
  }

  Future<void> _validate(BuildContext context) async {
    final provider = context.read<EmulatorEngineProvider>();
    await provider.refreshStatus();
  }

  Future<void> _showConfigDialog(BuildContext context) async {
    final provider = context.read<EmulatorEngineProvider>();
    final status = provider.serverStatus;

    final androidHomeController = TextEditingController(
      text: status?.androidHome ?? '',
    );
    final emulatorPathController = TextEditingController(
      text: status?.emulatorPath ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('配置模拟器路径'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: androidHomeController,
                decoration: const InputDecoration(
                  labelText: 'ANDROID_HOME',
                  hintText: '/Users/xxx/Library/Android/sdk',
                  helperText: '留空将自动检测',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emulatorPathController,
                decoration: const InputDecoration(
                  labelText: 'emulator 路径',
                  hintText: '/Users/xxx/Library/Android/sdk/emulator/emulator',
                  helperText: '留空将从 ANDROID_HOME 推导',
                ),
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
              await provider.updateConfig(
                androidHome: androidHomeController.text.isNotEmpty
                    ? androidHomeController.text
                    : null,
                emulatorPath: emulatorPathController.text.isNotEmpty
                    ? emulatorPathController.text
                    : null,
              );
            },
            child: const Text('保存并验证'),
          ),
        ],
      ),
    );
  }
}
