import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../design/design_tokens.dart';
import '../i18n.dart';

/// Global, app-wide hint text shown in the middle-right of the custom
/// title bar. Pages opt in by setting the value in initState and
/// clearing it (only if still theirs) in dispose.
class WindowChromeHint {
  WindowChromeHint._();

  static final ValueNotifier<String?> notifier = ValueNotifier<String?>(null);

  static void set(String? value) => notifier.value = value;

  /// Clear the hint only if it still equals [value] — avoids a
  /// disposing page erasing a hint that a newer page already set.
  static void clearIf(String? value) {
    if (notifier.value == value) notifier.value = null;
  }
}

/// Custom window title bar replacing the native chrome.
///
/// Layout follows design node 64:3 — 48px tall, brand label at the
/// left (16px inset), a drag area filling the middle, an optional hint
/// text and the custom minimize / maximize / close buttons at the right.
class WindowChrome extends StatefulWidget {
  const WindowChrome({super.key});

  static const double height = 48;

  @override
  State<WindowChrome> createState() => _WindowChromeState();
}

class _WindowChromeState extends State<WindowChrome> with WindowListener {
  bool _maximized = false;

  bool get _isDesktop => Platform.isMacOS || Platform.isWindows;

  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      windowManager.addListener(this);
      _syncMaximized();
    }
  }

  Future<void> _syncMaximized() async {
    final maximized = await windowManager.isMaximized();
    if (mounted && maximized != _maximized) {
      setState(() => _maximized = maximized);
    }
  }

  @override
  void dispose() {
    if (_isDesktop) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;

    return Container(
      height: WindowChrome.height,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          // Brand (design 64:4 — 16px inset).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              tr('appTitle'),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
          // Drag area (design 64:5 — spacer). Double-click toggles maximize.
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: _isDesktop ? _toggleMaximize : null,
              child: _isDesktop
                  ? const DragToMoveArea(child: SizedBox.expand())
                  : const SizedBox.expand(),
            ),
          ),
          // Hint (design 64:6 — right side, muted).
          ValueListenableBuilder<String?>(
            valueListenable: WindowChromeHint.notifier,
            builder: (context, hint, _) {
              if (hint == null || hint.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Text(
                  hint,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: onSurfaceVariant),
                ),
              );
            },
          ),
          if (_isDesktop) ...[
            _WindowButton(
              tooltip: tr('windowMinimize'),
              icon: _CaptionIcon.minimize,
              onPressed: () => windowManager.minimize(),
            ),
            _WindowButton(
              tooltip: _maximized ? tr('windowRestore') : tr('windowMaximize'),
              icon: _maximized
                  ? _CaptionIcon.restore
                  : _CaptionIcon.maximize,
              onPressed: _toggleMaximize,
            ),
            _WindowButton(
              tooltip: tr('windowClose'),
              icon: _CaptionIcon.close,
              isClose: true,
              onPressed: () => windowManager.close(),
            ),
          ],
        ],
      ),
    );
  }
}

enum _CaptionIcon { minimize, maximize, restore, close }

class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  final String tooltip;
  final _CaptionIcon icon;
  final VoidCallback onPressed;
  final bool isClose;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color background;
    final Color foreground;
    if (_hovered) {
      if (widget.isClose) {
        background = const Color(0xFFE81123);
        foreground = Colors.white;
      } else {
        background = theme.colorScheme.onSurface.withValues(alpha: 0.08);
        foreground = theme.colorScheme.onSurface;
      }
    } else {
      background = Colors.transparent;
      foreground = theme.colorScheme.onSurfaceVariant;
    }

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: AppDuration.fast,
            width: 44,
            height: WindowChrome.height,
            color: background,
            alignment: Alignment.center,
            child: CustomPaint(
              size: const Size(12, 12),
              painter: _CaptionIconPainter(widget.icon, foreground),
            ),
          ),
        ),
      ),
    );
  }
}

/// Crisp 1px-stroke caption glyphs (Windows-caption style) that scale
/// with the 12x12 canvas. Using CustomPaint instead of Material icons
/// keeps the glyphs pixel-aligned and visually lighter.
class _CaptionIconPainter extends CustomPainter {
  const _CaptionIconPainter(this.icon, this.color);

  final _CaptionIcon icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final w = size.width;
    final h = size.height;

    switch (icon) {
      case _CaptionIcon.minimize:
        final y = h / 2;
        canvas.drawLine(Offset(0, y), Offset(w, y), paint);
      case _CaptionIcon.maximize:
        canvas.drawRect(Rect.fromLTWH(0.6, 0.6, w - 1.2, h - 1.2), paint);
      case _CaptionIcon.restore:
        // Back square (offset up-right), clipped by front square.
        canvas.drawRect(Rect.fromLTWH(0.6, 2.6, w - 3.2, h - 3.2), paint);
        final path = Path()
          ..moveTo(2.6, 2.0)
          ..lineTo(2.6, 0.6)
          ..lineTo(w - 0.6, 0.6)
          ..lineTo(w - 0.6, h - 2.6)
          ..lineTo(w - 2.0, h - 2.6);
        canvas.drawPath(path, paint);
      case _CaptionIcon.close:
        canvas.drawLine(Offset(0.8, 0.8), Offset(w - 0.8, h - 0.8), paint);
        canvas.drawLine(Offset(w - 0.8, 0.8), Offset(0.8, h - 0.8), paint);
    }
  }

  @override
  bool shouldRepaint(_CaptionIconPainter oldDelegate) =>
      oldDelegate.icon != icon || oldDelegate.color != color;
}
