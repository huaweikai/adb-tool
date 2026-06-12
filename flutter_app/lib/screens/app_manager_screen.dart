import 'package:flutter/material.dart';
import '../services/drop_target.dart';
import '../models/app_package.dart';
import '../services/api_client.dart';

class _InstallState {
  final String fileName;
  final int sent;
  final int total;
  final String phase;

  const _InstallState({
    required this.fileName,
    required this.sent,
    required this.total,
    required this.phase,
  });

  bool get waitingForAdb => phase.startsWith('设备');

  double? get progress => total > 0 && !waitingForAdb ? sent / total : null;
}

class AppManagerScreen extends StatefulWidget {
  final ApiClient api;
  final String? selectedSerial;

  const AppManagerScreen({
    super.key,
    required this.api,
    required this.selectedSerial,
  });

  @override
  State<AppManagerScreen> createState() => _AppManagerScreenState();
}

class _AppManagerScreenState extends State<AppManagerScreen> {
  List<AppPackage> _allPackages = [];
  List<AppPackage> _filteredPackages = [];
  bool _loading = false;
  bool _dragOver = false;
  _InstallState? _installState;
  TransferCancelToken? _installCancelToken;
  String? _error;

  bool get _installing => _installState != null;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void didUpdateWidget(AppManagerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSerial != widget.selectedSerial) {
      _loadPackages();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    if (_installing) return;
    if (widget.selectedSerial == null) {
      setState(() {
        _allPackages = [];
        _filteredPackages = [];
        _error = '请先选择设备';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pkgs = await widget.api.getInstalledPackages(widget.selectedSerial!);
      if (!mounted) return;
      setState(() {
        _allPackages = pkgs;
        _filteredPackages = pkgs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onSearch(String query) {
    if (_installing) return;
    setState(() {
      if (query.isEmpty) {
        _filteredPackages = List.from(_allPackages);
      } else {
        final q = query.toLowerCase();
        _filteredPackages = _allPackages
            .where((p) => p.packageName.toLowerCase().contains(q) || p.shortName.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  Future<void> _uninstallPackage(AppPackage pkg) async {
    if (_installing) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认卸载'),
        content: Text('确定要卸载 ${pkg.packageName} 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('卸载')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final ok = await widget.api.uninstallPackage(widget.selectedSerial!, pkg.packageName);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('卸载 ${pkg.packageName} 成功')),
        );
        _loadPackages();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('卸载 ${pkg.packageName} 失败')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('卸载失败: $e')),
      );
    }
  }

  Future<void> _onDropApk(DropDoneDetails details) async {
    if (_installing) return;
    if (widget.selectedSerial == null) return;
    if (mounted) setState(() => _dragOver = false);
    for (final file in details.files) {
      if (!file.name.toLowerCase().endsWith('.apk')) continue;
      final totalBytes = await file.length();
      final cancelToken = TransferCancelToken();
      try {
        _installCancelToken = cancelToken;
        setState(() {
          _installState = _InstallState(
            fileName: file.name,
            sent: 0,
            total: totalBytes,
            phase: '准备上传 APK...',
          );
        });
        final result = await widget.api.installLocalPackage(
          widget.selectedSerial!,
          file.path,
          cancelToken: cancelToken,
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _installState = _InstallState(
                fileName: file.name,
                sent: progress.sent,
                total: progress.total,
                phase: progress.total > 0 && progress.sent >= progress.total ? '设备安装中...' : '正在上传 APK...',
              );
            });
          },
        );
        if (!mounted) return;
        _installCancelToken = null;
        setState(() => _installState = null);
        final successMsg = result.contains('已卸载') ? result : '${file.name} 安装成功';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMsg)),
        );
        _loadPackages();
      } catch (e) {
        if (!mounted) return;
        if (e is TransferCanceledException || cancelToken.canceled) {
          _installCancelToken = null;
          setState(() => _installState = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${file.name} 安装已取消')),
          );
          break;
        }
        _installCancelToken = null;
        setState(() => _installState = null);
        _showInstallError(file.name, e.toString());
      }
    }
  }

  void _cancelInstall() {
    _installCancelToken?.cancel();
  }

  void _showInstallError(String fileName, String error) {
    final needsUninstall = error.contains('INSTALL_FAILED') || error.contains('卸载');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 24),
          const SizedBox(width: 8),
          const Text('安装失败'),
        ]),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fileName, style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SelectableText(error,
                    style: const TextStyle(fontSize: 12, fontFamily: 'Menlo')),
              ),
              if (needsUninstall) ...[
                const SizedBox(height: 14),
                const Text('提示：版本降级或签名不一致导致的失败已自动尝试卸载重装；'
                    '如果仍然失败，请手动卸载后重试。',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _installCancelToken?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedSerial == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.android, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('请先在侧边栏选择设备', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return DropTarget(
      onDragEntered: () {
        if (_installing) return;
        setState(() => _dragOver = true);
      },
      onDragExited: () {
        if (_installing) return;
        setState(() => _dragOver = false);
      },
      onDragDone: _onDropApk,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildToolbar(context),
              if (_loading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                Expanded(child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      const SizedBox(height: 12),
                      FilledButton.tonal(onPressed: _loadPackages, child: const Text('重试')),
                    ],
                  ),
                ))
              else
                Expanded(child: _buildPackageList(context)),
            _buildStatusBar(context),
          ],
        ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_dragOver,
            child: AnimatedOpacity(
              opacity: _dragOver ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: _buildDragOverlay(),
            ),
          ),
        ),
        if (_installState != null) _buildInstallingOverlay(_installState!),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 300,
            child: TextField(
              controller: _searchCtrl,
              enabled: !_installing,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: '搜索应用包名...',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6))),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonal(
            onPressed: _installing ? null : _loadPackages,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, size: 16),
                SizedBox(width: 4),
                Text('刷新'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageList(BuildContext context) {
    if (_filteredPackages.isEmpty) {
      return const Center(child: Text('没有找到应用', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      itemCount: _filteredPackages.length,
      itemBuilder: (ctx, i) => _buildPackageRow(context, _filteredPackages[i]),
    );
  }

  Widget _buildPackageRow(BuildContext context, AppPackage pkg) {
    final theme = Theme.of(context);
    final initials = pkg.shortName.isNotEmpty ? pkg.shortName[0].toUpperCase() : '?';
    final colors = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple,
      Colors.teal, Colors.deepOrange, Colors.indigo, Colors.pink,
    ];
    final color = colors[pkg.packageName.hashCode.abs() % colors.length];
    return InkWell(
      onTap: _installing ? null : () => _showPackageDetail(context, pkg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withAlpha(40),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(initials,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pkg.shortName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pkg.packageName,
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant, fontFamily: 'Menlo'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              enabled: !_installing,
              onSelected: (v) {
                if (v == 'uninstall') _uninstallPackage(pkg);
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'uninstall', child: Row(
                  children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('卸载', style: TextStyle(color: Colors.red))],
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPackageDetail(BuildContext context, AppPackage pkg) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pkg.shortName, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            _detailRow('包名', pkg.packageName),
            _detailRow('路径', pkg.sourceDir),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _uninstallPackage(pkg);
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('卸载此应用'),
                style: FilledButton.styleFrom(foregroundColor: Colors.red),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontFamily: 'Menlo')),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(children: [
        Text('应用数: ${_filteredPackages.length}', style: const TextStyle(fontSize: 11)),
        if (_allPackages.length != _filteredPackages.length)
          Text(' (共 ${_allPackages.length})', style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
    );
  }

  Widget _buildDragOverlay() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.primary, width: 3),
      ),
      child: Container(
        color: theme.colorScheme.primary.withAlpha(30),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.file_upload, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text('释放 APK 文件以安装',
                  style: TextStyle(fontSize: 16, color: theme.colorScheme.primary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstallingOverlay(_InstallState state) {
    final theme = Theme.of(context);
    final progress = state.progress;
    final percent = progress == null ? '处理中' : '${(progress * 100).clamp(0, 100).toStringAsFixed(1)}%';
    return Positioned.fill(
      child: AbsorbPointer(
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
                      Icon(Icons.android, color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '正在安装 APK',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(percent, style: const TextStyle(fontFamily: 'Menlo', fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    state.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  progress == null
                      ? const LinearProgressIndicator()
                      : LinearProgressIndicator(value: progress.clamp(0.0, 1.0).toDouble()),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          state.phase,
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                      Text(
                        '${_formatBytes(state.sent)} / ${state.total > 0 ? _formatBytes(state.total) : '未知大小'}',
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
                    'APK 安装中，请等待完成后再进行应用管理操作。',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: _cancelInstall,
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('取消'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    if (unit == 0) return '$bytes ${units[unit]}';
    return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unit]}';
  }
}
