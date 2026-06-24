// Emulator engine configuration card widget.
// Displays and manages the Android SDK import and configuration.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/emulator_engine_provider.dart';
import '../services/api_client.dart';

class EmulatorEngineCard extends StatefulWidget {
  const EmulatorEngineCard({super.key});

  @override
  State<EmulatorEngineCard> createState() => _EmulatorEngineCardState();
}

class _EmulatorEngineCardState extends State<EmulatorEngineCard> {
  bool _isImporting = false;

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
                  'Android SDK',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _buildStatusBadge(context, provider),
              ],
            ),
            const SizedBox(height: 16),
            _buildSDKStatus(context, provider),
            if (provider.serverStatus != null && provider.serverStatus!.isValid) ...[
              const SizedBox(height: 12),
              _buildVersionInfo(context, provider),
            ],
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
    final status = provider.serverStatus;
    final hasSDK = status?.androidHome?.isNotEmpty == true || status?.emulatorPath?.isNotEmpty == true;
    final toolchainReady = status?.toolchainReady == true;

    Color color;
    String label;
    IconData icon;

    if (_isImporting) {
      color = Colors.orange;
      label = '导入中...';
      icon = Icons.sync;
    } else if (toolchainReady) {
      color = Colors.green;
      label = '就绪';
      icon = Icons.check_circle;
    } else if (hasSDK) {
      color = Colors.orange;
      label = '部分就绪';
      icon = Icons.warning;
    } else {
      color = Colors.grey;
      label = '未导入';
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
          if (_isImporting)
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

  Widget _buildSDKStatus(BuildContext context, EmulatorEngineProvider provider) {
    final status = provider.serverStatus;
    final hasSDK = status?.androidHome?.isNotEmpty == true;

    if (!hasSDK) {
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
                Icon(Icons.cloud_download, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Text(
                  '导入 Android SDK 压缩包',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '上传 Android SDK 压缩包，系统会自动解压到 ~/.adb-tool/sdk/',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            _buildImportButton(context, provider),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoRow('SDK 路径', status?.androidHome ?? '未知'),
        if (status?.emulatorVersion != null) ...[
          const SizedBox(height: 4),
          _infoRow('emulator', status!.emulatorVersion!),
        ],
      ],
    );
  }

  Widget _buildImportButton(BuildContext context, EmulatorEngineProvider provider) {
    return ElevatedButton.icon(
      onPressed: _isImporting ? null : () => _pickAndImportSDK(context),
      icon: const Icon(Icons.upload_file, size: 18),
      label: Text(_isImporting ? '导入中...' : '选择 SDK 压缩包'),
    );
  }

  Future<void> _pickAndImportSDK(BuildContext context) async {
    // For now, show a dialog to input the zip file path
    // In production, this would use file_picker package
    final pathController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入 Android SDK'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '请提供 Android SDK 压缩包路径（zip 格式）',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pathController,
                decoration: const InputDecoration(
                  labelText: 'SDK 压缩包路径',
                  hintText: '/Users/xxx/Downloads/android-sdk.zip',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '支持从 Google 官网下载的 Android SDK Command Line Tools 压缩包',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
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
            onPressed: () => Navigator.pop(ctx, pathController.text),
            child: const Text('导入'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;
    if (!mounted) return;

    await _importSDK(context, result);
  }

  Future<void> _importSDK(BuildContext context, String zipPath) async {
    setState(() {
      _isImporting = true;
    });

    try {
      final api = context.read<ApiClient>();
      
      // Create multipart request
      final uri = Uri.parse('${api.baseUrl}/api/emulator/sdk/import');
      final request = http.MultipartRequest('POST', uri);
      
      // Read file and add to request
      final file = File(zipPath);
      if (!await file.exists()) {
        throw Exception('文件不存在: $zipPath');
      }
      
      request.files.add(await http.MultipartFile.fromPath('sdk', zipPath));

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('导入失败: ${response.body}');
      }

      // Refresh status
      if (mounted) {
        await context.read<EmulatorEngineProvider>().refreshStatus();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SDK 导入成功！')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
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

  Widget _buildVersionInfo(BuildContext context, EmulatorEngineProvider provider) {
    final status = provider.serverStatus!;

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
    // Extract short version
    String shortVersion = version;
    final lines = version.split('\n');
    if (lines.isNotEmpty) {
      final parts = lines[0].split(' ');
      if (parts.isNotEmpty) {
        shortVersion = parts.last;
      }
    }

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
    final status = provider.serverStatus;
    final hasSDK = status?.androidHome?.isNotEmpty == true;

    return Row(
      children: [
        FilledButton.icon(
          onPressed: () => _validate(context),
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('刷新状态'),
        ),
        if (hasSDK) ...[
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _confirmDeleteSDK(context, provider),
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('删除 SDK'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ],
    );
  }

  Future<void> _validate(BuildContext context) async {
    final provider = context.read<EmulatorEngineProvider>();
    await provider.refreshStatus();
  }

  Future<void> _confirmDeleteSDK(BuildContext context, EmulatorEngineProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除 SDK'),
        content: const Text('确定要删除已导入的 SDK 吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final api = context.read<ApiClient>();
      await api.dio.delete('/api/emulator/sdk/delete');
      
      if (mounted) {
        await provider.refreshStatus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SDK 已删除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
