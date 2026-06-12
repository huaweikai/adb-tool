import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cross_file/cross_file.dart';

class MacDropDoneDetails {
  final List<XFile> files;
  MacDropDoneDetails(this.files);
}

class _MacDropTargetData {
  final VoidCallback? onDragEntered;
  final VoidCallback? onDragExited;
  final void Function(MacDropDoneDetails)? onDragDone;

  _MacDropTargetData({
    this.onDragEntered,
    this.onDragExited,
    this.onDragDone,
  });
}

class _MacDropChannel {
  static const _channel = MethodChannel('mac_drop');
  static final Map<String, _MacDropTargetData> _targets = {};
  static bool _handlerSet = false;

  static void _ensureHandler() {
    if (_handlerSet) return;
    _handlerSet = true;
    _channel.setMethodCallHandler(_handleCall);
  }

  static Future<dynamic> _handleCall(MethodCall call) async {
    final targets = Map<String, _MacDropTargetData>.from(_targets);
    switch (call.method) {
      case 'dragEntered':
        for (final t in targets.values) {
          t.onDragEntered?.call();
        }
      case 'dragExited':
        for (final t in targets.values) {
          t.onDragExited?.call();
        }
      case 'dragDone':
        final paths = List<String>.from(call.arguments as List);
        final files = paths.map((p) => XFile(p)).toList();
        for (final t in targets.values) {
          t.onDragDone?.call(MacDropDoneDetails(files));
        }
    }
  }

  static void register(String id, _MacDropTargetData data) {
    if (defaultTargetPlatform != TargetPlatform.macOS) return;
    _ensureHandler();
    _targets[id] = data;
    if (_targets.length == 1) {
      _channel.invokeMethod('setActive', true);
    }
  }

  static void unregister(String id) {
    _targets.remove(id);
    if (_targets.isEmpty) {
      _channel.invokeMethod('setActive', false);
    }
  }
}

class MacDropTarget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onDragEntered;
  final VoidCallback? onDragExited;
  final void Function(MacDropDoneDetails)? onDragDone;

  const MacDropTarget({
    super.key,
    required this.child,
    this.onDragEntered,
    this.onDragExited,
    this.onDragDone,
  });

  @override
  State<MacDropTarget> createState() => _MacDropTargetState();
}

class _MacDropTargetState extends State<MacDropTarget> {
  final String _id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      _MacDropChannel.register(_id, _MacDropTargetData(
        onDragEntered: widget.onDragEntered,
        onDragExited: widget.onDragExited,
        onDragDone: widget.onDragDone,
      ));
    }
  }

  @override
  void didUpdateWidget(MacDropTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      _MacDropChannel.register(_id, _MacDropTargetData(
        onDragEntered: widget.onDragEntered,
        onDragExited: widget.onDragExited,
        onDragDone: widget.onDragDone,
      ));
    }
  }

  @override
  void dispose() {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      _MacDropChannel.unregister(_id);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
