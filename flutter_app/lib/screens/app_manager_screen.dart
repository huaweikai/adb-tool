import 'package:flutter/material.dart';
import '../services/drop_target.dart';
import '../models/app_package.dart';
import '../services/api_client.dart';
import '../i18n.dart';
import '../widgets/loading_view.dart';
import '../widgets/error_view.dart';
import '../widgets/file_transfer.dart';
import '../providers/locale_provider.dart';
import '../providers/device_provider.dart';
import 'package:provider/provider.dart';

class AppManagerScreen extends StatefulWidget {
  const AppManagerScreen({
    super.key,
  });

  @override
  State<AppManagerScreen> createState() => _AppManagerScreenState();
}

class _AppManagerScreenState extends State<AppManagerScreen> {
  String? get _selectedSerial => context.read<DeviceSerialScope>().serial;

  List<AppPackage> _allPackages = [];
  List<AppPackage> _filteredPackages = [];
  bool _loading = false;
  bool _dragOver = false;
  TransferState? _installState;
  TransferCancelToken? _installCancelToken;
  String? _error;

  bool get _installing => _installState != null;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    if (_installing) return;
    if (_selectedSerial == null) {
      setState(() {
        _allPackages = [];
        _filteredPackages = [];
        _error = tr('selectDevice');
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pkgs = await context
          .read<ApiClient>()
          .getInstalledPackages(_selectedSerial!);
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
            .where((p) =>
                p.packageName.toLowerCase().contains(q) ||
                p.shortName.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  Future<void> _clearAppData(AppPackage pkg) async {
    if (_installing) return;
    final serial = _selectedSerial;
    if (serial == null) return;
    final api = context.read<ApiClient>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(tr('clearData')),
        content: Text(tr('clearDataConfirm', {'pkg': pkg.packageName})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('clearData'))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final result = await api
          .executeAdbCommand(serial, ['shell', 'pm', 'clear', pkg.packageName]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result.ok
                ? tr('dataCleared', {'pkg': pkg.packageName})
                : '${tr('operationFailed')}: ${result.error}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('operationFailed')}: $e')),
      );
    }
  }

  Future<void> _forceStopApp(AppPackage pkg) async {
    if (_installing) return;
    final serial = _selectedSerial;
    if (serial == null) return;
    final api = context.read<ApiClient>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(tr('forceStop')),
        content: Text(tr('forceStopConfirm', {'pkg': pkg.packageName})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('forceStop'))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final result = await api.executeAdbCommand(
          serial, ['shell', 'am', 'force-stop', pkg.packageName]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result.ok
                ? tr('appForceStopped', {'pkg': pkg.packageName})
                : '${tr('operationFailed')}: ${result.error}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('operationFailed')}: $e')),
      );
    }
  }

  Future<void> _uninstallPackage(AppPackage pkg) async {
    if (_installing) return;
    final serial = _selectedSerial;
    if (serial == null) return;
    final api = context.read<ApiClient>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(tr('confirmUninstall')),
        content: Text(tr('uninstallConfirm', {'pkg': pkg.packageName})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('uninstall'))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final ok = await api.uninstallPackage(serial, pkg.packageName);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr('uninstallSuccess', {'pkg': pkg.packageName}))),
        );
        _loadPackages();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr('uninstallFailed', {'pkg': pkg.packageName}))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('uninstallFailedMsg')}: $e')),
      );
    }
  }

  Future<void> _onDropApk(DropDoneDetails details) async {
    if (_installing) return;
    final serial = _selectedSerial;
    if (serial == null) return;
    final api = context.read<ApiClient>();
    if (mounted) setState(() => _dragOver = false);
    for (final file in details.files) {
      if (!file.name.toLowerCase().endsWith('.apk')) continue;
      final totalBytes = await file.length();
      final cancelToken = TransferCancelToken();
      try {
        _installCancelToken = cancelToken;
        setState(() {
          _installState = TransferState(
            mode: TransferMode.upload,
            fileName: file.name,
            sent: 0,
            total: totalBytes,
            phaseKey: 'preparing',
          );
        });
        final result = await api.installLocalPackage(
          serial,
          file.path,
          cancelToken: cancelToken,
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _installState = TransferState(
                mode: TransferMode.upload,
                fileName: file.name,
                sent: progress.sent,
                total: progress.total,
                phaseKey: progress.total > 0 && progress.sent >= progress.total
                    ? 'deviceInstalling'
                    : 'uploading',
              );
            });
          },
        );
        if (!mounted) return;
        _installCancelToken = null;
        setState(() => _installState = null);
        final successMsg = result.contains('已卸载')
            ? result
            : tr('installSuccess', {'name': file.name});
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
            SnackBar(
                content: Text(tr('installCancelled', {'name': file.name}))),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Row(children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 24),
          const SizedBox(width: 8),
          Text(tr('installFailed')),
        ]),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fileName,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
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
              const SizedBox(height: 14),
              Text(tr('installHint'),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(tr('close'))),
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
    context.watch<LocaleProvider>();
    if (_selectedSerial == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.android, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(tr('selectDeviceSidebar'),
                style: const TextStyle(color: Colors.grey)),
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
                const Expanded(child: LoadingView())
              else if (_error != null)
                Expanded(
                  child: ErrorView(
                    message: _error!,
                    onRetry: _loadPackages,
                    retryLabel: tr('retry'),
                  ),
                )
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
                hintText: tr('searchHint'),
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 18),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(6))),
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.refresh, size: 16),
                const SizedBox(width: 4),
                Text(tr('refresh')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageList(BuildContext context) {
    if (_filteredPackages.isEmpty) {
      return Center(
          child:
              Text(tr('noApps'), style: const TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      itemCount: _filteredPackages.length,
      itemBuilder: (ctx, i) => _buildPackageRow(context, _filteredPackages[i]),
    );
  }

  Widget _buildPackageRow(BuildContext context, AppPackage pkg) {
    final theme = Theme.of(context);
    final initials =
        pkg.shortName.isNotEmpty ? pkg.shortName[0].toUpperCase() : '?';
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.deepOrange,
      Colors.indigo,
      Colors.pink,
    ];
    final color = colors[pkg.packageName.hashCode.abs() % colors.length];
    return InkWell(
      onTap: _installing ? null : () => _showPackageDetail(context, pkg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withAlpha(40),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(initials,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pkg.shortName,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pkg.packageName,
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFamily: 'Menlo'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              enabled: !_installing,
              onSelected: (v) {
                if (v == 'forceStop') _forceStopApp(pkg);
                if (v == 'clearData') _clearAppData(pkg);
                if (v == 'uninstall') _uninstallPackage(pkg);
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                    value: 'forceStop',
                    child: Row(
                      children: [
                        const Icon(Icons.stop_circle_outlined,
                            size: 18, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(tr('forceStop'),
                            style: const TextStyle(color: Colors.orange))
                      ],
                    )),
                PopupMenuItem(
                    value: 'clearData',
                    child: Row(
                      children: [
                        const Icon(Icons.cleaning_services_outlined,
                            size: 18, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(tr('clearData'),
                            style: const TextStyle(color: Colors.orange))
                      ],
                    )),
                PopupMenuItem(
                    value: 'uninstall',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline,
                            size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(tr('uninstall'),
                            style: const TextStyle(color: Colors.red))
                      ],
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
            _detailRow(tr('packageName'), pkg.packageName),
            _detailRow(tr('path'), pkg.sourceDir),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _forceStopApp(pkg);
                },
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: Text(tr('forceStop')),
                style: FilledButton.styleFrom(foregroundColor: Colors.orange),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _clearAppData(pkg);
                },
                icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                label: Text(tr('clearData')),
                style: FilledButton.styleFrom(foregroundColor: Colors.orange),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _uninstallPackage(pkg);
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(tr('uninstallApp')),
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
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 12, fontFamily: 'Menlo')),
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
        Text(tr('appCount', {'count': _filteredPackages.length.toString()}),
            style: const TextStyle(fontSize: 11)),
        if (_allPackages.length != _filteredPackages.length)
          Text(tr('totalCount', {'total': _allPackages.length.toString()}),
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
              Icon(Icons.file_upload,
                  size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(tr('dropHintApk'),
                  style: TextStyle(
                      fontSize: 16, color: theme.colorScheme.primary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstallingOverlay(TransferState state) {
    final theme = Theme.of(context);
    final progress = state.progress;
    final percent = progress == null
        ? tr('processing')
        : '${(progress * 100).clamp(0, 100).toStringAsFixed(1)}%';
    final phaseKeyCapitalized =
        'phase${state.phaseKey[0].toUpperCase()}${state.phaseKey.substring(1)}';
    final phaseText = tr(phaseKeyCapitalized);
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
                          tr('installingApk'),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(percent,
                          style: const TextStyle(
                              fontFamily: 'Menlo',
                              fontWeight: FontWeight.w600)),
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
                      : LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0).toDouble()),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          phaseText,
                          style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                      Text(
                        '${formatBytes(state.sent)} / ${state.total > 0 ? formatBytes(state.total) : tr('unknownSize')}',
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
                    tr('installingWarning'),
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: _cancelInstall,
                      icon: const Icon(Icons.close, size: 16),
                      label: Text(tr('cancel')),
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
}
