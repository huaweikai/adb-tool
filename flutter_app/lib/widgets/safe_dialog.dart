import 'package:flutter/material.dart';

/// Dialog 专用：自动 dispose 传入的 TextEditingController，避免内存泄漏。
class SafeDialog extends StatefulWidget {
  final List<TextEditingController> controllers;
  final Widget Function(List<TextEditingController> ctrls) builder;

  const SafeDialog({
    super.key,
    required this.controllers,
    required this.builder,
  });

  @override
  State<SafeDialog> createState() => SafeDialogState();
}

class SafeDialogState extends State<SafeDialog> {
  @override
  void dispose() {
    for (final c in widget.controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(widget.controllers);
}
