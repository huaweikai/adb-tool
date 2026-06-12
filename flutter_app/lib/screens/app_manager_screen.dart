import 'package:flutter/material.dart';
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

    return Column(
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
    return InkWell(
      onTap: () => _showPackageDetail(context, pkg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.android, size: 18, color: theme.colorScheme.primary),
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
}
