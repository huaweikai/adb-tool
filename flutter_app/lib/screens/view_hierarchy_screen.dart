import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/view_node_inspector_panel.dart';

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

  // Search/filter state. When non-empty, `_visibleRows` ignores user
  // expand state and instead shows matched rows plus their ancestor chain.
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  int _matchCount = 0;

  // For scrolling a row into view when the selection changes via tapping
  // the screenshot panel (reverse select).
  final ScrollController _treeScroll = ScrollController();
  GlobalKey? _selectedRowKey;

  // InteractiveViewer transform controller — used by reverse-select to
  // invert the user's pan/zoom back into dump coordinate space.
  final TransformationController _xformController = TransformationController();

  @override
  void initState() {
    super.initState();
    _dump();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _treeScroll.dispose();
    _xformController.dispose();
    super.dispose();
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

  /// Selecting a node and make sure its ancestor chain is expanded and the
  /// row is scrolled into view. Used by reverse-select (tap screenshot).
  void _selectAndReveal(ViewNode node) {
    final root = _root;
    if (root == null) return;
    final ancestors = ViewNode.ancestorChain(root, node);
    setState(() {
      _selectedNode = node;
      if (ancestors != null) {
        for (final a in ancestors) {
          _expanded.add(a);
        }
      }
      _invalidateRowsCache();
      _selectedRowKey = GlobalKey();
    });
    _loadScreenshot();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _selectedRowKey;
      final ctx = key?.currentContext;
      if (ctx != null && _treeScroll.hasClients) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.4,
          duration: const Duration(milliseconds: 150),
        );
      }
    });
  }

  void _onQueryChanged(String q) {
    setState(() {
      _query = q.trim();
      _invalidateRowsCache();
    });
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
              _query.isEmpty
                  ? tr('viewHierarchy.nodes', {'count': '$_totalNodeCount'})
                  : tr('viewHierarchy.matchCount', {
                      'count': '$_totalNodeCount',
                      'matches': '$_matchCount',
                    }),
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
  //
  // When `_query` is non-empty, expands the matched rows' ancestor chains
  // regardless of `_expanded`. Each row carries an `matches` flag so the tile
  // can dim non-matched rows and highlight matched ones.
  List<_FlatRow> _flattenVisible() {
    final root = _root;
    if (root == null) return const [];
    final out = <_FlatRow>[];
    if (_query.isEmpty) {
      void walk(ViewNode node, int depth) {
        out.add(_FlatRow(node, depth, false));
        if (_expanded.contains(node)) {
          for (final c in node.children) {
            walk(c, depth + 1);
          }
        }
      }
      walk(root, 0);
      _matchCount = 0;
      return out;
    }
    // Compute the set of nodes that should be shown: each matched node plus
    // the chain of ancestors from root down to the matched node.
    final shown = <ViewNode>{};
    int matches = 0;
    void collect(ViewNode n) {
      if (n.matchesQuery(_query)) {
        matches++;
        final chain = ViewNode.ancestorChain(root, n);
        if (chain != null) {
          shown.addAll(chain);
        } else {
          shown.add(n);
        }
      }
      for (final c in n.children) {
        collect(c);
      }
    }
    collect(root);
    _matchCount = matches;
    void walk(ViewNode n, int depth) {
      if (!shown.contains(n)) return;
      out.add(_FlatRow(n, depth, n.matchesQuery(_query)));
      for (final c in n.children) {
        walk(c, depth + 1);
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
            child: Column(
              children: [
                _buildSearchBox(),
                Expanded(child: _buildTreePanel()),
              ],
            ),
          ),
        ),
        Expanded(child: _buildScreenshotPanel()),
        if (_selectedNode != null)
          SizedBox(
            width: 280,
            child: ViewNodeInspectorPanel(node: _selectedNode!),
          ),
      ],
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      child: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        onChanged: _onQueryChanged,
        style: Theme.of(context).textTheme.bodySmall,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          prefixIcon: const Icon(Icons.search, size: 18),
          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          hintText: tr('viewHierarchy.searchHint'),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide(color: Theme.of(context).dividerColor),
          ),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    _searchCtrl.clear();
                    _onQueryChanged('');
                    _searchFocus.unfocus();
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildTreePanel() {
    final rows = _visibleRows;
    return Scrollbar(
      controller: _treeScroll,
      child: ListView.builder(
        controller: _treeScroll,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        itemCount: rows.length,
        itemBuilder: (context, i) {
          final r = rows[i];
          return _buildNodeTile(r.node, r.depth, i, r.matches);
        },
      ),
    );
  }

  List<_FlatRow> get _visibleRows {
    final cached = _rowsCache;
    if (cached != null) return cached;
    _rowsCache = _flattenVisible();
    return _rowsCache!;
  }

  void _invalidateRowsCache() => _rowsCache = null;

  Widget _buildNodeTile(ViewNode node, int depth, int index, bool matches) {
    final hasChildren = node.children.isNotEmpty;
    final isExpanded = _expanded.contains(node);
    final isSelected = _selectedNode == node;
    final dim = _query.isNotEmpty && !matches;

    // Depth accent color: cycle 8 hues.
    const depthColors = [
      Colors.blue, Colors.teal, Colors.orange, Colors.purple,
      Colors.pink, Colors.indigo, Colors.green, Colors.deepOrange,
    ];
    final accent = depthColors[depth % depthColors.length];

    return InkWell(
      key: isSelected ? _selectedRowKey : ValueKey('${node.index}:${node.className}:$index'),
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
        child: Opacity(
          opacity: dim ? 0.35 : 1.0,
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
        // The screenshot PNG, after applying `_effectiveRotation`, occupies
        // exactly `_screenshotDumpSize` in dump coordinate space. We size the
        // canvas by the rotated screenshot size (NOT by `rootBounds`) so the
        // image isn't letterboxed/stretched when the dump root covers only a
        // sub-rect of the screen (status bar, notch, non-fullscreen apps).
        // Node bounds are absolute dump coordinates, so they sit on the same
        // canvas space regardless of where `rootBounds` is anchored.
        final scale = (constraints.maxWidth / dumpSize.width)
            .clamp(0.0, constraints.maxHeight / dumpSize.height);
        final canvasW = dumpSize.width * scale;
        final canvasH = dumpSize.height * scale;

        return ClipRect(
          child: Stack(
            children: [
              InteractiveViewer(
                constrained: false,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                minScale: 0.25,
                maxScale: 6.0,
                transformationController: _xformController,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (d) => _reverseSelect(d.localPosition, scale),
                  child: SizedBox(
                    width: canvasW,
                    height: canvasH,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Screenshot rotated to match the dump orientation.
                        // BoxFit.fill is safe here because `Positioned.fill`
                        // forces the image box to `canvasW × canvasH`, which
                        // is already the image's rotated aspect (so no
                        // distortion — same bytes-to-canvas ratio).
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
              ),
              if (_selectedNode != null)
                Positioned(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  bottom: AppSpacing.lg,
                  child: _buildNodeActionToolbar(),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Convert a tap position on the screenshot panel back into dump coordinate
  /// space and pick the deepest node whose bounds contains that point.
  ///
  /// The `GestureDetector` is placed INSIDE the `InteractiveViewer`, so
  /// Flutter's hit-test already inverts the user's pan/zoom before dispatching
  /// `onTapUp` — `localPosition` is the tap point in the child widget's own
  /// coordinate system (i.e. canvas space = dumpSize × scale). We just divide
  /// by `scale` to recover dump coordinates. Calling `toScene()` here would
  /// double-invert the transform and place the hit point in the wrong node.
  void _reverseSelect(Offset localPosition, double scale) {
    final root = _root;
    if (root == null || scale <= 0) return;
    final dumpX = localPosition.dx / scale;
    final dumpY = localPosition.dy / scale;
    final hit = ViewNode.hitTest(root, Offset(dumpX, dumpY));
    if (hit != null) {
      _selectAndReveal(hit);
    }
  }

  Widget _buildNodeActionToolbar() {
    final node = _selectedNode;
    if (node == null) return const SizedBox();
    final b = node.bounds;
    final canTap = b != null && b.width > 0 && b.height > 0;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _actionButton(Icons.touch_app, tr('viewHierarchy.tap'),
                  enabled: canTap, onTap: _tapSelected),
              _actionButton(Icons.back_hand, tr('viewHierarchy.longPress'),
                  enabled: canTap, onTap: _longPressSelected),
              _actionButton(Icons.keyboard, tr('viewHierarchy.inputText'),
                  enabled: true, onTap: _inputTextSelected),
              _actionButton(Icons.copy, tr('viewHierarchy.copyResourceId'),
                  enabled: node.resourceId.isNotEmpty,
                  onTap: () => _copyResourceId(node)),
              _copyAsMenu(node),
              _actionButton(Icons.visibility, tr('viewHierarchy.scrollToVisible'),
                  enabled: b != null && b.width > 0 && b.height > 0,
                  onTap: _scrollToSelected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, String tooltip,
      {required bool enabled, required Future<void> Function() onTap}) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 20),
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        onPressed: enabled
            ? () {
                onTap();
              }
            : null,
      ),
    );
  }

  Future<void> _tapSelected() async {
    final node = _selectedNode;
    final b = node?.bounds;
    if (node == null || b == null || b.width <= 0 || b.height <= 0) return;
    final cx = (b.left + b.right) ~/ 2;
    final cy = (b.top + b.bottom) ~/ 2;
    await _runAdbAndRefresh(['shell', 'input', 'tap', '$cx', '$cy']);
  }

  Future<void> _longPressSelected() async {
    final node = _selectedNode;
    final b = node?.bounds;
    if (node == null || b == null || b.width <= 0 || b.height <= 0) return;
    final cx = (b.left + b.right) ~/ 2;
    final cy = (b.top + b.bottom) ~/ 2;
    await _runAdbAndRefresh(
        ['shell', 'input', 'swipe', '$cx', '$cy', '$cx', '$cy', '1000']);
  }

  Future<void> _inputTextSelected() async {
    final node = _selectedNode;
    if (node == null) return;
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(tr('viewHierarchy.inputText')),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: tr('viewHierarchy.textHint'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
            minLines: 1,
            maxLines: 3,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    if (result == null) return;
    // `adb shell input text` parses %s as a literal space; raw spaces in
    // other tools get split by the device shell, so use %s for safety.
    final escaped = result.replaceAll(' ', '%s');
    if (escaped.isEmpty) return;
    await _runAdbAndRefresh(['shell', 'input', 'text', escaped]);
  }

  /// Scrolls the device UI until the selected node's bounds is fully within
  /// its scrollable ancestor's visible viewport, or gives up after 6 tries.
  /// Walks ancestor chain for the nearest `scrollable == true` node and uses
  /// `adb shell input swipe` against that ancestor's bounds center to drive
  /// the scroll in the right direction (up if target above viewport, down if
  /// below).
  Future<void> _scrollToSelected() async {
    final root = _root;
    final node = _selectedNode;
    if (root == null || node == null) return;
    final target = node.bounds;
    if (target == null || target.width <= 0 || target.height <= 0) return;

    // Find the nearest scrollable ancestor. ancestorChain returns null if
    // the node is no longer in the tree (e.g. user re-dumped since).
    final chain = ViewNode.ancestorChain(root, node);
    if (chain == null) return;
    ViewNode? scrollAncestor;
    for (var i = chain.length - 2; i >= 0; i--) {
      if (chain[i].scrollable && chain[i].bounds != null) {
        scrollAncestor = chain[i];
        break;
      }
    }
    if (scrollAncestor == null) {
      // Nothing scrollable in the path — node is either visible already or
      // not in any scroll container. Nothing for us to do.
      return;
    }
    final viewport = scrollAncestor.bounds!;

    const maxAttempts = 6;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final current = _selectedNode?.bounds;
      if (current == null) break;
      // Visible when fully inside the viewport.
      if (current.top >= viewport.top &&
          current.bottom <= viewport.bottom) {
        return; // success
      }
      // Decide swipe direction.
      // Target above viewport → swipe down (so content moves UP into view).
      // Target below viewport → swipe up (so content moves DOWN into view).
      final viewportCx = (viewport.left + viewport.right) ~/ 2;
      final y1 = (viewport.top + viewport.bottom) ~/ 2;
      const swipeDistance = 600; // device pixels
      late int y2;
      if (current.top < viewport.top) {
        // target is above viewport — swipe down (start low, end high)
        y2 = y1 - swipeDistance;
      } else {
        // target is below viewport — swipe up (start high, end low)
        y2 = y1 + swipeDistance;
      }
      await _runAdb([
        'shell',
        'input',
        'swipe',
        '$viewportCx',
        '$y1',
        '$viewportCx',
        '$y2',
        '400',
      ]);
      if (!mounted) return;
      // Wait for device to redraw, then re-dump+re-screenshot so the next
      // iteration can re-evaluate the target's new bounds. Reuse the same
      // 400ms rhythm as the other refresh actions.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      await _dump();
      // After re-dump we get a new tree. Re-find the node we were scrolling
      // toward — by resource-id+bounds (or just by resourceId, less robust)
      // since the ViewNode instance we hold is now stale. If we can't find
      // a match, stop scrolling.
      final newRoot = _root;
      if (newRoot == null) return;
      final relocated = _findNodeByIdentity(newRoot, node);
      if (relocated == null) {
        // The view got recycled / removed during scroll; nothing more to do.
        return;
      }
      // Keep _selectedNode in sync with the new tree so subsequent taps land
      // at the relocated position.
      _selectAndReveal(relocated);
    }
    // Exhausted attempts.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('viewHierarchy.scrollToVisibleFailed',
          {'n': '$maxAttempts'}))),
    );
  }

  /// Best-effort identity match between old and new dump trees so
  /// `_scrollToSelected` can follow a node across re-dumps. Matches by
  /// resource-id first; if resource-id is empty, matches by className +
  /// same parent path depth. Returns null when no clear match exists.
  ViewNode? _findNodeByIdentity(ViewNode root, ViewNode old) {
    // Strongest match: unique resource-id, present at most once in the tree.
    if (old.resourceId.isNotEmpty) {
      final matches = <ViewNode>[];
      void scan(ViewNode n) {
        if (n.resourceId == old.resourceId) matches.add(n);
        for (final c in n.children) {
          scan(c);
        }
      }
      scan(root);
      if (matches.length == 1) return matches.first;
      // length>1 means the id isn't unique enough — try bounds+class match
    }
    // Weaker match: same class + same boundsStr. Useful when resource-id is
    // empty (e.g. anonymous TextView whose position changed mid-scroll).
    final bstr = old.boundsStr;
    if (bstr.isNotEmpty) {
      ViewNode? found;
      void scan(ViewNode n) {
        if (found == null && n.className == old.className && n.boundsStr == bstr) {
          found = n;
        }
        for (final c in n.children) {
          scan(c);
        }
      }
      scan(root);
      return found;
    }
    return null;
  }

  Future<void> _copyResourceId(ViewNode node) async {
    if (node.resourceId.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: node.resourceId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('viewHierarchy.copiedResourceId'))),
    );
  }

  Future<void> _copyXPath(ViewNode node) async {
    await Clipboard.setData(ClipboardData(text: node.toXPath()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('viewHierarchy.copiedXPath'))),
    );
  }

  Future<void> _copyUiAutomator(ViewNode node) async {
    await Clipboard.setData(ClipboardData(text: node.toUiAutomator()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('viewHierarchy.copiedUiAutomator'))),
    );
  }

  Future<void> _copyEspresso(ViewNode node) async {
    await Clipboard.setData(ClipboardData(text: node.toEspresso()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('viewHierarchy.copiedEspresso'))),
    );
  }

  /// Popup menu for "Copy as" — emits XPath, UiAutomator By.* or Espresso
  /// onView(...) strings a tester pastes into instrumentation/host-side
  /// test code. Keeps the toolbar compact (1 icon slot instead of 3) and
  /// leaves room for the future "scroll to visible" action.
  Widget _copyAsMenu(ViewNode node) {
    return PopupMenuButton<_CopyAsKind>(
      tooltip: tr('viewHierarchy.copyAs'),
      icon: const Icon(Icons.code, size: 20),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onSelected: (kind) {
        switch (kind) {
          case _CopyAsKind.xpath:
            _copyXPath(node);
            break;
          case _CopyAsKind.uiautomator:
            _copyUiAutomator(node);
            break;
          case _CopyAsKind.espresso:
            _copyEspresso(node);
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _CopyAsKind.xpath,
          child: Text(tr('viewHierarchy.copyAsXPath')),
        ),
        PopupMenuItem(
          value: _CopyAsKind.uiautomator,
          child: Text(tr('viewHierarchy.copyAsUiAutomator')),
        ),
        PopupMenuItem(
          value: _CopyAsKind.espresso,
          child: Text(tr('viewHierarchy.copyAsEspresso')),
        ),
      ],
    );
  }

  Future<void> _runAdb(List<String> args) async {
    final serial = _selectedSerial;
    if (serial == null) return;
    try {
      final api = context.read<ApiClient>();
      await api.executeAdbCommand(serial, args);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('viewHierarchy.actionFailed', {'error': '$e'}))),
      );
    }
  }

  /// Run an adb shell command that mutates the device UI (tap / long press /
  /// text input), then automatically re-dump the view hierarchy and refresh
  /// the screenshot so the red bounds box and screenshot stay in sync with
  /// the new on-screen state.
  ///
  /// The 400ms wait lets the target app start its reaction animation /
  /// navigation transition before we capture, otherwise the dump would still
  /// show the pre-tap state. If the UI has a longer transition the user can
  /// tap "Dump" toolbar button / "Re-shoot" screenshot button to capture a
  /// later snapshot.
  Future<void> _runAdbAndRefresh(List<String> args) async {
    await _runAdb(args);
    if (!mounted) return;
    // Give the device a beat to react (open dialog / navigate / show toast)
    // before we re-dump. Cheap and matches the user's intuition that "after
    // tapping, the tool updates the screenshot".
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    await _dump();
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
  final bool matches;
  const _FlatRow(this.node, this.depth, this.matches);
}

/// Choice kinds emitted by the "Copy as" popup on the node-action toolbar.
enum _CopyAsKind { xpath, uiautomator, espresso }
