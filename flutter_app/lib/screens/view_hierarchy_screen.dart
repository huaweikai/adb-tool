import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/design_tokens.dart';
import '../i18n.dart';
import '../mixins/device_reconnect_mixin.dart';
import '../models/view_node.dart';
import '../providers/device_provider.dart';
import '../providers/locale_provider.dart';
import '../services/api_client.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import '../widgets/offline_guard.dart';

class ViewHierarchyScreen extends StatefulWidget {
  const ViewHierarchyScreen({super.key});

  @override
  State<ViewHierarchyScreen> createState() => _ViewHierarchyScreenState();
}

class _ViewHierarchyScreenState extends State<ViewHierarchyScreen>
    with DeviceReconnectMixin<ViewHierarchyScreen> {
  // Snapshot of currently visible rows; invalidated whenever _expanded or
  // _root changes so ListView.builder never re-flattens mid-build.
  List<_FlatRow>? _rowsCache;
  String? get _selectedSerial => context.read<DeviceSerialScope>().serial;

  ViewNode? _root;
  int _rotation = 0; // 0/1/2/3 — applied to the screenshot before overlaying bounds.
  int _effectiveRotation = 0; // actual rotation applied to the displayed image.
  String? _error;
  bool _loading = false;

  ViewNode? _selectedNode;

  // Screenshot — loaded lazily only when a node is selected.
  // `_screenshotPhysicalSize` is the raw PNG size (pre-rotation).
  // `_screenshotDumpSize` is the size after rotation, matching the dump
  // coordinate space.
  Uint8List? _screenshotBytes;
  ui.Size? _screenshotPhysicalSize;
  Size? _screenshotDumpSize;
  bool _screenshotLoading = false;

  final Set<ViewNode> _expanded = {};

  @override
  void initState() {
    super.initState();
    _dump();
  }

  @override
  String? get reconnectSerial => _selectedSerial;

  @override
  void onDeviceReconnected() {
    _dump();
  }

  Future<void> _dump() async {
    final serial = _selectedSerial;
    if (serial == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _root = null;
      _rotation = 0;
      _effectiveRotation = 0;
      _selectedNode = null;
      _screenshotBytes = null;
      _screenshotPhysicalSize = null;
      _screenshotDumpSize = null;
      _screenshotLoading = false;
      _expanded.clear();
    });
    try {
      final api = context.read<ApiClient>();
      final dump = await api.dumpViewHierarchy(serial);
      if (!mounted) return;
      if (dump == null) {
        setState(() { _loading = false; _error = 'dump failed'; });
        return;
      }
      // If the device rotated since the last screenshot, the old bytes are
      // stale relative to the new dump coordinates — drop them.
      if (_rotation != dump.rotation) {
        _screenshotBytes = null;
        _screenshotPhysicalSize = null;
        _screenshotDumpSize = null;
        _effectiveRotation = 0;
      }
      setState(() {
        _loading = false;
        _root = dump.root;
        _rotation = dump.rotation;
        _expanded.add(dump.root);
        _invalidateRowsCache();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _loadScreenshot({bool force = false}) async {
    if (!force && (_screenshotBytes != null || _screenshotLoading)) return;
    final serial = _selectedSerial;
    if (serial == null) return;
    setState(() => _screenshotLoading = true);
    try {
      final api = context.read<ApiClient>();
      final b64 = await api.takeScreenshot(serial);
      if (!mounted) return;
      if (b64 == null || b64.isEmpty) {
        setState(() => _screenshotLoading = false);
        return;
      }
      final bytes = base64Decode(b64);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      final physW = frame.image.width.toDouble();
      final physH = frame.image.height.toDouble();
      // Decide whether the PNG needs to be rotated to match the dump
      // coordinate space. Modern Android returns screenshots already in the
      // current display orientation, so normally no rotation is applied; but
      // some devices/ROMs return the physical framebuffer orientation only,
      // in which case the dump `rotation` attribute tells us how to correct.
      // We detect by comparing the screenshot's aspect to the dump root's
      // aspect — if they're swapped, apply the rotation from the dump.
      final rootBounds = _root?.bounds;
      int effectiveRotation = 0;
      if (rootBounds != null && rootBounds.width > 0 && rootBounds.height > 0) {
        final same =
            (physW - rootBounds.width).abs() < 16 && (physH - rootBounds.height).abs() < 16;
        final swapped =
            (physW - rootBounds.height).abs() < 16 && (physH - rootBounds.width).abs() < 16;
        if (swapped && !same) {
          effectiveRotation = _rotation.isOdd ? _rotation : (_rotation == 0 ? 1 : 3);
        }
      } else if (_rotation.isOdd) {
        effectiveRotation = _rotation;
      }
      final dumpW = effectiveRotation.isOdd ? physH : physW;
      final dumpH = effectiveRotation.isOdd ? physW : physH;
      setState(() {
        _screenshotLoading = false;
        _screenshotBytes = bytes;
        _screenshotPhysicalSize = ui.Size(physW, physH);
        _screenshotDumpSize = Size(dumpW, dumpH);
        _effectiveRotation = effectiveRotation;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _screenshotLoading = false);
    }
  }

  void _toggleExpand(ViewNode node) {
    setState(() {
      if (_expanded.contains(node)) {
        _expanded.remove(node);
      } else {
        _expanded.add(node);
      }
      _invalidateRowsCache();
    });
  }

  void _selectNode(ViewNode node) {
    setState(() => _selectedNode = _selectedNode == node ? null : node);
    _loadScreenshot();
  }

  Future<void> _refreshScreenshot() => _loadScreenshot(force: true);

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
    context.watch<DeviceSerialScope>();
    final serial = _selectedSerial;
    if (serial == null) {
      return Center(child: Text(tr('selectDevice')));
    }

    final isOnline = context.select<DeviceProvider, bool>(
      (p) => p.isDeviceConnected(serial),
    );

    return Column(
      children: [
        OfflineBanner(serial: serial),
        _buildToolbar(serial, isOnline),
        Expanded(
          child: _loading
              ? const LoadingView()
              : _error != null
                  ? ErrorView(message: _error!, onRetry: _dump)
                  : _root == null
                      ? const EmptyState(icon: Icons.account_tree, title: 'No data')
                      : _buildContent(),
        ),
      ],
    );
  }

  Widget _buildToolbar(String serial, bool isOnline) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          FilledButton.tonalIcon(
            onPressed: isOnline ? _dump : null,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(tr('viewHierarchy.dump')),
          ),
          if (_root != null) ...[
            const SizedBox(width: AppSpacing.md),
            Text(
              tr('viewHierarchy.nodes', {'count': '$_totalNodeCount'}),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            IconButton(
              tooltip: tr('viewHierarchy.refreshScreenshot'),
              onPressed: isOnline ? _refreshScreenshot : null,
              icon: const Icon(Icons.image_search, size: 18),
            ),
            if (_rotation != 0)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Text(
                  '${_rotation * 90}°',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  int? _cachedNodeCount;

  int _countNodes(ViewNode node) {
    int c = 1;
    for (final child in node.children) {
      c += _countNodes(child);
    }
    return c;
  }

  int get _totalNodeCount {
    final cached = _cachedNodeCount;
    if (cached != null) return cached;
    final root = _root;
    if (root == null) return 0;
    _cachedNodeCount = _countNodes(root);
    return _cachedNodeCount!;
  }

  // Flatten the currently-visible (expanded) subtree into a list of
  // (node, depth). Lets ListView lazily build only on-screen rows instead of
  // eagerly constructing the whole tree as nested Columns.
  List<_FlatRow> _flattenVisible() {
    final root = _root;
    if (root == null) return const [];
    final out = <_FlatRow>[];
    void walk(ViewNode node, int depth) {
      out.add(_FlatRow(node, depth));
      if (_expanded.contains(node)) {
        for (final c in node.children) {
          walk(c, depth + 1);
        }
      }
    }
    walk(root, 0);
    return out;
  }

  Widget _buildContent() {
    return Row(
      children: [
        SizedBox(
          width: 360,
          child: Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: _buildTreePanel(),
          ),
        ),
        Expanded(child: _buildScreenshotPanel()),
      ],
    );
  }

  Widget _buildTreePanel() {
    final rows = _visibleRows;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final r = rows[i];
        return _buildNodeTile(r.node, r.depth, i);
      },
    );
  }

  List<_FlatRow> get _visibleRows {
    final cached = _rowsCache;
    if (cached != null) return cached;
    _rowsCache = _flattenVisible();
    return _rowsCache!;
  }

  void _invalidateRowsCache() => _rowsCache = null;

  Widget _buildNodeTile(ViewNode node, int depth, int index) {
    final hasChildren = node.children.isNotEmpty;
    final isExpanded = _expanded.contains(node);
    final isSelected = _selectedNode == node;

    // Depth accent color: cycle 8 hues.
    const depthColors = [
      Colors.blue, Colors.teal, Colors.orange, Colors.purple,
      Colors.pink, Colors.indigo, Colors.green, Colors.deepOrange,
    ];
    final accent = depthColors[depth % depthColors.length];

    return InkWell(
      key: ValueKey('${node.index}:${node.className}:$index'),
      onTap: () => _selectNode(node),
      child: Container(
        padding: EdgeInsets.only(
          left: 8.0 + depth * 16.0,
          right: 8, top: 4, bottom: 4,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4)
              : null,
          border: isSelected
              ? Border(
                  left: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            if (hasChildren)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _toggleExpand(node),
                child: Icon(
                  isExpanded ? Icons.expand_more : Icons.chevron_right,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              const SizedBox(width: 18),
            const SizedBox(width: 4),
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                node.displayName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : null,
                      color: node.clickable
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              node.shortClass,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenshotPanel() {
    if (_selectedNode == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app, size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: AppSpacing.sm),
            Text(tr('viewHierarchy.selectNode')),
          ],
        ),
      );
    }

    if (_screenshotLoading) {
      return const LoadingView();
    }

    final root = _root;
    final rootBounds = root?.bounds;
    final dumpSize = _screenshotDumpSize;
    if (_screenshotBytes == null || dumpSize == null || rootBounds == null) {
      return const SizedBox();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // The dump root bounds ARE the screen surface in dump coordinates.
        // Scale so the canvas fits the available panel; InteractiveViewer
        // lets the user pan/zoom if the highlighted node is off-screen
        // (e.g. NestedScrollView items with negative top coords).
        final scale = (constraints.maxWidth / rootBounds.width)
            .clamp(0.0, constraints.maxHeight / rootBounds.height);
        final canvasW = rootBounds.width * scale;
        final canvasH = rootBounds.height * scale;

        return ClipRect(
          child: InteractiveViewer(
            constrained: false,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            minScale: 0.25,
            maxScale: 6.0,
            child: SizedBox(
              width: canvasW,
              height: canvasH,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Screenshot rotated to match the dump orientation.
                  Positioned.fill(
                    child: RotatedBox(
                      quarterTurns: _effectiveRotation,
                      child: Image.memory(
                        _screenshotBytes!,
                        width: _screenshotPhysicalSize!.width,
                        height: _screenshotPhysicalSize!.height,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                  ..._buildSelectedOverlay(scale),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Highlight the currently selected node directly in dump coordinate space.
  // Stack clipBehavior is Clip.none so bounds outside the root (scrolled-off
  // items in NestedScrollView) remain visible when the user pans.
  List<Widget> _buildSelectedOverlay(double scale) {
    final node = _selectedNode;
    if (node == null) return const [];
    final b = node.bounds;
    if (b == null) return const [];
    return [
      Positioned(
        left: b.left * scale,
        top: b.top * scale,
        width: b.width * scale,
        height: b.height * scale,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red.withValues(alpha: 0.85), width: 2),
              color: Colors.red.withValues(alpha: 0.18),
            ),
          ),
        ),
      ),
    ];
  }
}

class _FlatRow {
  final ViewNode node;
  final int depth;
  const _FlatRow(this.node, this.depth);
}
