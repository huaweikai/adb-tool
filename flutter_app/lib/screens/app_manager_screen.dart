import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../models/app_package.dart';
import '../services/api_client.dart';

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
  bool _installing = false;
  String? _error;
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
    if (widget.selectedSerial == null) return;
    for (final file in details.files) {
      if (!file.name.toLowerCase().endsWith('.apk')) continue;
      setState(() => _installing = true);
      try {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        final result = await widget.api.installPackage(widget.selectedSerial!, bytes);
        if (!mounted) return;
        final successMsg = result.contains('已卸载') ? result : '${file.name} 安装成功';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMsg)),
        );
        _loadPackages();
      } catch (e) {
        if (!mounted) return;
        _showInstallError(file.name, e.toString());
      } finally {
        if (mounted) setState(() => _installing = false);
      }
    }
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
      onDragEntered: (_) => setState(() => _dragOver = true),
      onDragExited: (_) => setState(() => _dragOver = false),
      onDragDone: _onDropApk,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildToolbar(context),
              if (_loading || _installing)
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
          if (_dragOver) _buildDragOverlay(),
          if (_installing) _buildInstallingOverlay(),
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
            onPressed: _loadPackages,
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
      onTap: () => _showPackageDetail(context, pkg),
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
    return Positioned.fill(
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

  Widget _buildInstallingOverlay() {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: Container(
        color: Colors.black26,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('正在安装 APK...',
                      style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
