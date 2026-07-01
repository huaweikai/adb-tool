// Mirror configuration card widget.
// Allows users to configure a mirror URL for sdkmanager downloads.
import 'dart:async';
import 'package:adb_tool/providers/locale_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n.dart';
import '../services/api_client.dart';

class MirrorConfigCard extends StatefulWidget {
  const MirrorConfigCard({super.key});

  @override
  State<MirrorConfigCard> createState() => _MirrorConfigCardState();
}

class _MirrorConfigCardState extends State<MirrorConfigCard> {
  final _urlController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String _currentMirror = '';

  @override
  void initState() {
    super.initState();
    _loadMirror();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadMirror() async {
    try {
      final api = context.read<ApiClient>();
      final url = await api.getMirrorURL();
      if (mounted) {
        setState(() {
          _currentMirror = url;
          _urlController.text = url;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _saving = true);
    try {
      final api = context.read<ApiClient>();
      await api.setMirrorURL(url);
      if (mounted) {
        setState(() {
          _currentMirror = url;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('mirror.saved'))),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _clear() async {
    setState(() => _saving = true);
    try {
      final api = context.read<ApiClient>();
      await api.setMirrorURL('');
      if (mounted) {
        setState(() {
          _currentMirror = '';
          _urlController.clear();
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('mirror.cleared'))),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _applyPreset(String url) {
    _urlController.text = url;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  tr('mirror.title'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              tr('mirror.subtitle'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (_currentMirror.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${tr('mirror.current')}: $_currentMirror',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              tr('mirror.label'),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: tr('mirror.hint'),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(tr('mirror.save')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  tr('mirror.quickSelect'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  label: Text(tr('mirror.tencent')),
                  onPressed: () => _applyPreset(
                      'https://mirrors.cloud.tencent.com/AndroidSDK/'),
                  avatar: const Icon(Icons.cloud, size: 16),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  label: Text(tr('mirror.huawei')),
                  onPressed: () => _applyPreset(
                      'https://mirrors.huaweicloud.com/android/'),
                  avatar: const Icon(Icons.cloud, size: 16),
                ),
                if (_currentMirror.isNotEmpty) ...[
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _saving ? null : _clear,
                    icon: const Icon(Icons.clear, size: 16),
                    label: Text(tr('mirror.clear')),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tr('mirror.proxyHint'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
