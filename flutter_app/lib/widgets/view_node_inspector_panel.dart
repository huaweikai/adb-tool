// Right-hand inspector panel for the view-hierarchy screen.
//
// Renders every attribute of a single selected ViewNode in a compact
// scrollable list with a per-row copy affordance. Split out of
// view_hierarchy_screen.dart because the AGENTS.md "fat files" rule
// fires when a widget-scope responsibility (list every attribute of a
// node) lands in the same State as the panel-switching / dump-refresh
// flow — and the file had already hit 816 lines from the previous
// reverse-select + actions + search commits.
//
// The widget is intentionally stateless — copy feedback is shown by the
// caller via ScaffoldMessenger so the panel doesn't need a Navigator or
// an Overlay. Stays agnostic to which serialization the caller prefers
// (xpath / espresso / uiautomator), the caller asks the ViewNode for
// those strings itself.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/design_tokens.dart';
import '../i18n.dart';
import '../models/view_node.dart';

class ViewNodeInspectorPanel extends StatelessWidget {
  final ViewNode node;

  const ViewNodeInspectorPanel({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    final rows = _buildRows();
    return Container(
      decoration: BoxDecoration(
        border: Border(
            left: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          Divider(
            height: 1,
            thickness: 1,
            color: Theme.of(context).dividerColor,
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.xs),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final r = rows[i];
                return _InspectorRow(row: r);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              node.displayName,
              style: Theme.of(context).textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          if (node.clickable)
            _Badge(
              text: tr('viewHierarchy.clickable'),
              color: Theme.of(context).colorScheme.primary,
            ),
        ],
      ),
    );
  }

  /// Build the attribute rows in display order. Keeping this list inline
  /// rather than via reflection keeps the row set visible at the
  /// implementation site (which is what a tester wants when triaging).
  List<_InspectorRowData> _buildRows() {
    return [
      _InspectorRowData(label: 'class', value: node.className, copyable: true),
      _InspectorRowData(
          label: 'package', value: node.package, copyable: true),
      _InspectorRowData(
          label: 'resource-id', value: node.resourceId, copyable: true),
      _InspectorRowData(label: 'text', value: node.text, copyable: true),
      _InspectorRowData(
          label: 'content-desc', value: node.contentDesc, copyable: true),
      _InspectorRowData(
          label: 'bounds', value: node.boundsStr, copyable: true),
      _InspectorRowData(
          label: 'index', value: '${node.index}', copyable: false),
      _InspectorRowData(
          label: 'instance', value: '${node.instance}', copyable: false),
      _InspectorRowData(
          label: 'clickable', value: _bool(node.clickable), copyable: false),
      _InspectorRowData(
          label: 'long-clickable',
          value: _bool(node.longClickable),
          copyable: false),
      _InspectorRowData(
          label: 'checkable', value: _bool(node.checkable), copyable: false),
      _InspectorRowData(
          label: 'checked', value: _bool(node.checked), copyable: false),
      _InspectorRowData(
          label: 'enabled', value: _bool(node.enabled), copyable: false),
      _InspectorRowData(
          label: 'focusable', value: _bool(node.focusable), copyable: false),
      _InspectorRowData(
          label: 'focused', value: _bool(node.focused), copyable: false),
      _InspectorRowData(
          label: 'scrollable', value: _bool(node.scrollable), copyable: false),
      _InspectorRowData(
          label: 'selected', value: _bool(node.selected), copyable: false),
      _InspectorRowData(
          label: 'password', value: _bool(node.password), copyable: false),
    ];
  }

  static String _bool(bool v) => v ? 'true' : 'false';
}

class _InspectorRowData {
  final String label;
  final String value;
  final bool copyable;
  const _InspectorRowData({
    required this.label,
    required this.value,
    required this.copyable,
  });
}

class _InspectorRow extends StatelessWidget {
  final _InspectorRowData row;
  const _InspectorRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final muted = row.value.isEmpty;
    final theme = Theme.of(context);
    return InkWell(
      onTap: row.copyable && row.value.isNotEmpty
          ? () async {
              await Clipboard.setData(ClipboardData(text: row.value));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('viewHierarchy.copied'))),
              );
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs + 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Text(
                row.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Text(
                row.value.isEmpty ? '—' : row.value,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: muted ? theme.colorScheme.onSurfaceVariant : null,
                  fontFamily: row.label == 'bounds' ||
                          row.label == 'resource-id' ||
                          row.label == 'class'
                      ? 'monospace'
                      : null,
                ),
              ),
            ),
            if (row.copyable && row.value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: Icon(
                  Icons.copy,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.xs)),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}