import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/design_tokens.dart';

/// A searchable item in the command palette.
class PaletteItem {
  const PaletteItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onSelect,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onSelect;
}

/// Quick-launch command palette (Cmd/Ctrl+K).
///
/// Displays a dialog with a search input and a filtered list of
/// [items]. Supports keyboard navigation: ↑↓ to select, ↵ to
/// confirm, Esc to close.
class CommandPalette extends StatefulWidget {
  const CommandPalette({super.key, required this.items});

  final List<PaletteItem> items;

  /// Show the command palette as a dialog.
  static Future<void> show(BuildContext context,
      {required List<PaletteItem> items}) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => CommandPalette(items: items),
    );
  }

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  late final TextEditingController _ctrl;
  late final FocusNode _focusNode;
  final ScrollController _scrollCtrl = ScrollController();
  int _selectedIndex = 0;
  List<PaletteItem> _filtered = [];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _focusNode = FocusNode();
    _filtered = widget.items;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _filter(String query) {
    final lower = query.toLowerCase();
    setState(() {
      _filtered = widget.items.where((item) {
        return item.title.toLowerCase().contains(lower) ||
            item.subtitle.toLowerCase().contains(lower);
      }).toList();
      _selectedIndex = 0;
    });
  }

  void _select(int index) {
    if (index < 0 || index >= _filtered.length) return;
    Navigator.of(context).pop();
    _filtered[index].onSelect();
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % _filtered.length;
      });
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex =
            (_selectedIndex - 1 + _filtered.length) % _filtered.length;
      });
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      _select(_selectedIndex);
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        _handleKey(event);
        return KeyEventResult.handled;
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 460),
          child: Material(
            elevation: AppElevation.dialog,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            color: theme.colorScheme.surfaceContainerHigh,
            surfaceTintColor: theme.colorScheme.surfaceTint,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search input
                  Container(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focusNode,
                      onChanged: _filter,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _ctrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _ctrl.clear();
                                  _filter('');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Results list
                  Expanded(
                    child: _filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Text(
                                'No results',
                                style: TextStyle(
                                  fontSize: AppFontSize.body,
                                  color:
                                      theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) {
                              final item = _filtered[index];
                              final selected =
                                  index == _selectedIndex;
                              return Material(
                                color: selected
                                    ? theme.colorScheme.primaryContainer
                                    : Colors.transparent,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm),
                                child: InkWell(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                  onTap: () => _select(index),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md,
                                      vertical: AppSpacing.sm,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(item.icon,
                                            size: 16,
                                            color: theme
                                                .colorScheme.primary),
                                        const SizedBox(
                                            width: AppSpacing.md),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.title,
                                                style: TextStyle(
                                                  fontSize:
                                                      AppFontSize.subtitle,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                item.subtitle,
                                                style: TextStyle(
                                                  fontSize:
                                                      AppFontSize.sm,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  // Footer hint
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(AppRadius.lg),
                        bottomRight: Radius.circular(AppRadius.lg),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _badge(theme, '↑↓', 'Navigate'),
                        const SizedBox(width: AppSpacing.md),
                        _badge(theme, '↵', 'Select'),
                        const SizedBox(width: AppSpacing.md),
                        _badge(theme, 'Esc', 'Close'),
                      ],
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

  Widget _badge(ThemeData theme, String key, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Text(
            key,
            style: TextStyle(
              fontSize: AppFontSize.xs,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: AppFontSize.xs,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
