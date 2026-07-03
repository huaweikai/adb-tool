// Scrcpy keyboard shortcut reference card.
//
// Renders a side-by-side Windows / macOS comparison of scrcpy 4.0's
// built-in shortcuts. The user reads this card and presses the
// shortcut while the scrcpy SDL window is focused — the shortcut
// then acts on the running scrcpy session (quit, fullscreen, etc.).
//
// Why display rather than dispatch? scrcpy 4.0 has NO external
// control API (no CLI flag, no socket, no stdin, no signal — see
// app/src/control_msg.h + app/src/controller.c). Shortcuts can only
// be triggered from scrcpy's own SDL event loop. Our ADB Tool
// process is a separate window/process and cannot inject into
// scrcpy's event queue. Showing the keys lets the user press them
// directly, which is honest about the constraint.
//
// Modifier key display notes:
//   scrcpy 4.0 defaults to --shortcut-mod=lalt,lsuper, which on
//   Windows means "Alt or ⊞ Win" and on macOS means "⌥ Option or
//   ⌘ Command". We display the platform's primary modifier (Alt on
//   Win, ⌘ on Mac) and add a hint that the user can change this in
//   the settings panel via the `shortcut_mod` option.
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../i18n.dart';

class ScrcpyShortcutReference extends StatelessWidget {
  const ScrcpyShortcutReference({super.key});

  // 18 most-used shortcuts from scrcpy 4.0 doc/shortcuts.md. Order
  // roughly by how often a mirroring user reaches for them. We list
  // the modifier-explicit form so the user can see exactly what
  // scrcpy expects, including Shift-combos.
  static const List<_Shortcut> _shortcuts = [
    _Shortcut('scrcpyRefActionQuit', 'q', shift: false),
    _Shortcut('scrcpyRefActionFullscreen', 'F', shift: false),
    _Shortcut('scrcpyRefActionHome', 'H', shift: false),
    _Shortcut('scrcpyRefActionBack', 'B', shift: false),
    _Shortcut('scrcpyRefActionRecents', 'S', shift: false),
    _Shortcut('scrcpyRefActionMenu', 'M', shift: false),
    _Shortcut('scrcpyRefActionPower', 'P', shift: false),
    _Shortcut('scrcpyRefActionVolumeUp', '↑', shift: false),
    _Shortcut('scrcpyRefActionVolumeDown', '↓', shift: false),
    _Shortcut('scrcpyRefActionScreenOff', 'O', shift: false),
    _Shortcut('scrcpyRefActionScreenOn', 'O', shift: true),
    _Shortcut('scrcpyRefActionRotateDevice', 'R', shift: false),
    _Shortcut('scrcpyRefActionExpandNotif', 'N', shift: false),
    _Shortcut('scrcpyRefActionCollapsePanels', 'N', shift: true),
    _Shortcut('scrcpyRefActionCopy', 'C', shift: false),
    _Shortcut('scrcpyRefActionCut', 'X', shift: false),
    _Shortcut('scrcpyRefActionPaste', 'V', shift: false),
    _Shortcut('scrcpyRefActionPause', 'Z', shift: false),
    _Shortcut('scrcpyRefActionUnpause', 'Z', shift: true),
    _Shortcut('scrcpyRefActionResetVideo', 'R', shift: true),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMac = Platform.isMacOS;
    final isWin = Platform.isWindows;
    final osCard = isMac
        ? _OsCard(
            osLabel: tr('scrcpyRefPlatformMac'),
            mod: '⌘',
            modSymbol: '⌘ Command',
            shortcuts: _shortcuts,
          )
        : isWin
            ? _OsCard(
                osLabel: tr('scrcpyRefPlatformWin'),
                mod: 'Alt',
                modSymbol: 'Alt',
                shortcuts: _shortcuts,
              )
            : _OsCard(
                osLabel: tr('scrcpyRefPlatformOther'),
                mod: 'Ctrl',
                modSymbol: 'Ctrl',
                shortcuts: _shortcuts,
              );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight.isFinite) {
          // Bounded height (wide layout — inside Expanded). Column +
          // Expanded(_OsCard) so the _OsCard gets a tight height and
          // its internal ListView scrolls properly inside the card.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('scrcpyRefTitle'),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                tr('scrcpyRefHint'),
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Expanded(child: osCard),
            ],
          );
        }
        // Unbounded height (narrow layout — outer ListView scrolls).
        // A Column + Expanded would throw, and a plain Column would
        // overflow because _OsCard shrinkWraps to its full content
        // height. Instead use a shrinkWrap ListView so all items are
        // laid out sequentially and the outer ListView scrolls them.
        return ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            Text(
              tr('scrcpyRefTitle'),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              tr('scrcpyRefHint'),
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            osCard,
          ],
        );
      },
    );
  }
}

class _Shortcut {
  final String actionKey;
  final String keyLabel;
  final bool shift;

  const _Shortcut(this.actionKey, this.keyLabel, {required this.shift});
}

class _OsCard extends StatelessWidget {
  final String osLabel;
  final String mod;
  final String modSymbol;
  final List<_Shortcut> shortcuts;

  const _OsCard({
    required this.osLabel,
    required this.mod,
    required this.modSymbol,
    required this.shortcuts,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(8),
      ),
      // LayoutBuilder peeks at the *incoming* height constraint on this
      // _OsCard. Two cases:
      //   1. bounded (wide layout — _RightPane gave us a definite
      //      remaining height via Expanded). We give the title a
      //      Flexible-like fixed slot and pack the row ListView into an
      //      Expanded so it gets a TIGHT height and scrolls properly.
      //   2. unbounded (narrow layout — _OsCard sits inside an outer
      //      ListView). Expanded would throw, so we use a shrinkWrap
      //      ListView that lays out all rows and doesn't scroll; the
      //      outer ListView scrolls the whole card.
      child: LayoutBuilder(builder: (context, constraints) {
        final title = Text(
          osLabel,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        );
        Widget buildRow(_Shortcut s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tr(s.actionKey),
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _Kbd(mod: modSymbol, keyLabel: s.keyLabel, shift: s.shift),
                ],
              ),
            );
        final isBounded = constraints.maxHeight.isFinite;
        final listView = ListView.builder(
          // 如果有边界，不需要 shrinkWrap（性能更好）；没边界时才开启 shrinkWrap 撑开高度
          shrinkWrap: !isBounded,
          // 如果有边界，允许滚动（使用默认物理效果）；没边界时禁用滚动，由外层滚动
          physics: isBounded
              ? const AlwaysScrollableScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          itemCount: shortcuts.length,
          itemBuilder: (ctx, i) => buildRow(shortcuts[i]),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            const SizedBox(height: 6),
            // 3. 如果有边界，必须用 Expanded 包裹 ListView，否则 Column 会报错；
            //    如果没有边界，直接返回 ListView
            isBounded ? Expanded(child: listView) : listView,
          ],
        );
      }),
    );
  }
}

/// A keyboard hint "chip" — renders the modifier + optional Shift +
/// key in a tight monospace-ish style. e.g. `Alt + Q`, `⌘ + ⇧ + N`.
class _Kbd extends StatelessWidget {
  final String mod;
  final String keyLabel;
  final bool shift;

  const _Kbd({required this.mod, required this.keyLabel, required this.shift});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.colorScheme.surface;
    final fg = theme.colorScheme.onSurface;
    Widget chip(String s) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            s,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontFamily: 'monospace',
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        chip(mod),
        Text('+', style: theme.textTheme.labelSmall),
        if (shift) ...[
          chip('⇧ Shift'),
          Text('+', style: theme.textTheme.labelSmall),
        ],
        chip(keyLabel),
      ],
    );
  }
}
