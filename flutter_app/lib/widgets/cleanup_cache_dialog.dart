// One-shot "clean all adb-tool caches" dialog.
//
// Two-stage confirmation:
//   1. User clicks "Clean all caches" → first AlertDialog lists what
//      will be wiped (read from a static allowlist) and asks the user
//      to confirm. Default keeps the Android SDK.
//   2. After the user clicks "Clean" the first dialog calls the
//      backend, then this dialog shows a second screen summarising
//      what was actually wiped (size, count, skipped).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n.dart';
import '../services/api/cleanup_api.dart';
import '../services/api_client.dart';

/// Show the cache cleanup flow. Returns the result if the user
/// completed the flow (regardless of success); null if they backed
/// out.
Future<CacheCleanupResult?> showCleanupCacheDialog(BuildContext context) {
  return showDialog<CacheCleanupResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _CleanupCacheDialog(),
  );
}

class _CleanupCacheDialog extends StatefulWidget {
  const _CleanupCacheDialog();

  @override
  State<_CleanupCacheDialog> createState() => _CleanupCacheDialogState();
}

class _CleanupCacheDialogState extends State<_CleanupCacheDialog> {
  bool _keepSDK = true;
  bool _busy = false;
  String? _error;
  CacheCleanupResult? _result;

  // Static preview of what gets wiped. Kept in sync with
  // backend/internal/server/handlers_cache.go's
  // cacheCleanupCandidates(); the backend is the source of truth
  // for size/count, this list is purely for the confirmation screen.
  static const _wipeTargets = <_TargetPreview>[
    _TargetPreview(
      title: 'ADB / scrcpy binary cache',
      detail: '系统 TempDir 下的 adb-tool-cache(避免每次启动重新解压)',
    ),
    _TargetPreview(
      title: '录屏、剪贴板、push/pull 临时文件',
      detail: 'adb-recording-*.mp4 / clipboard-helper.apk / adb-tool-*-*',
    ),
    _TargetPreview(
      title: '模拟器实例日志',
      detail: '~/.adb-tool/emulator/instances/<id>/logs/*.log (AVD 文件保留)',
    ),
    _TargetPreview(
      title: '后端日志',
      detail: '~/Library/Application Support/ADBTool 或 %APPDATA%\\ADBTool',
    ),
    _TargetPreview(
      title: 'Flutter 端数据库 + 会话附件',
      detail: '%APPDATA%\\com.example.ADB Tool\\ 等',
    ),
    _TargetPreview(
      title: 'Flutter 引擎缓存 (ADBToolData)',
      detail: '~/ADBToolData 或 flutter_app/ADBToolData (best-effort)',
    ),
  ];

  // Always kept, regardless of keepSDK checkbox. Mirrors the
  // backend's "never add to wipe list" contract.
  static const _keptTargets = <_TargetPreview>[
    _TargetPreview(
      title: 'Android SDK',
      detail: '~/.adb-tool/sdk/  (默认保留 — 重装几 GB 慢)',
    ),
    _TargetPreview(
      title: 'Java runtime',
      detail: '~/.adb-tool/emulator/java-runtime/',
    ),
    _TargetPreview(
      title: 'System images',
      detail: '~/.adb-tool/emulator/system-images/',
    ),
    _TargetPreview(
      title: 'AVD 配置和磁盘',
      detail: '~/.adb-tool/emulator/instances/<id>/{config.ini,*.avd,*.img}',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return _buildResultDialog(context, _result!);
    }
    return _buildConfirmDialog(context);
  }

  Widget _buildConfirmDialog(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.delete_sweep_outlined, size: 20),
          const SizedBox(width: 8),
          Text(tr('cleanupCache.title')),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '将清理以下位置(白名单内):',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              ..._wipeTargets.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.fiber_manual_record, size: 8, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.title,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              t.detail,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 4),
              Text(
                '始终保留:',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              ..._keptTargets.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.fiber_manual_record, size: 8, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${t.title} — ${t.detail}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _keepSDK,
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _keepSDK = v ?? true),
                title: Text(tr('cleanupCache.keepSDK')),
                subtitle: Text(
                  tr('cleanupCache.keepSDKHint'),
                  style: const TextStyle(fontSize: 11),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(20),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(tr('cancel')),
        ),
        FilledButton.tonal(
          onPressed: _busy ? null : _runCleanup,
          style: FilledButton.styleFrom(
            foregroundColor: Colors.red,
          ),
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(tr('cleanupCache.confirm')),
        ),
      ],
    );
  }

  Widget _buildResultDialog(BuildContext context, CacheCleanupResult r) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Text(tr('cleanupCache.done')),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.storage, color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${tr('cleanupCache.freed', {'size': r.totalFormatted})}'
                        '${tr('cleanupCache.freedCount', {'count': '${r.cleanedCount}'})}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (r.skipped.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  tr('cleanupCache.skippedHeader', {'count': '${r.skippedCount}'}),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                ...r.skipped.take(5).map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${e.path}\n  ${e.error ?? "unknown reason"}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                if (r.skipped.length > 5)
                  Text(
                    tr('cleanupCache.skippedMore', {'count': '${r.skipped.length - 5}'}),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
              if (r.cleaned.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  tr('cleanupCache.cleanupDetail'),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                ...r.cleaned.take(8).map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '• ${e.description.isNotEmpty ? e.description : e.path}',
                            style: const TextStyle(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          e.existed ? e.sizeFormatted : tr('cleanupCache.notExists'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (r.cleaned.length > 8)
                  Text(
                    tr('cleanupCache.skippedMore', {'count': '${r.cleaned.length - 8}'}),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
              if (r.keptSDK) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.check, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(tr('cleanupCache.sdkKept'), style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, r),
          child: Text(tr('cleanupCache.close')),
        ),
      ],
    );
  }

  Future<void> _runCleanup() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      final result = await api.cleanupCache(
        keepSDK: _keepSDK,
        confirmed: true,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }
}

class _TargetPreview {
  final String title;
  final String detail;
  const _TargetPreview({required this.title, required this.detail});
}
