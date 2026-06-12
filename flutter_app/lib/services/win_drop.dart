import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cross_file/cross_file.dart';

class WinDropDoneDetails {
  final List<XFile> files;
  WinDropDoneDetails(this.files);
}

class _WinDropTargetData {
  final VoidCallback? onDragEntered;
  final VoidCallback? onDragExited;
  final void Function(WinDropDoneDetails)? onDragDone;

  _WinDropTargetData({
    this.onDragEntered,
    this.onDragExited,
    this.onDragDone,
  });
}

class _WinDropChannel {
  static const _channel = MethodChannel('win_drop');
  static final Map<String, _WinDropTargetData> _targets = {};
  static bool _handlerSet = false;

  static void _ensureHandler() {
    if (_handlerSet) return;
    _handlerSet = true;
    _channel.setMethodCallHandler(_handleCall);
  }

  static Future<dynamic> _handleCall(MethodCall call) async {
    final targets = Map<String, _WinDropTargetData>.from(_targets);
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
          t.onDragDone?.call(WinDropDoneDetails(files));
        }
    }
  }

  static void register(String id, _WinDropTargetData data) {
    if (defaultTargetPlatform != TargetPlatform.windows) return;
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

class WinDropTarget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onDragEntered;
  final VoidCallback? onDragExited;
  final void Function(WinDropDoneDetails)? onDragDone;

  const WinDropTarget({
    super.key,
    required this.child,
    this.onDragEntered,
    this.onDragExited,
    this.onDragDone,
  });

  @override
  State<WinDropTarget> createState() => _WinDropTargetState();
}

class _WinDropTargetState extends State<WinDropTarget> {
  final String _id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.windows) {
      _WinDropChannel.register(_id, _WinDropTargetData(
        onDragEntered: widget.onDragEntered,
        onDragExited: widget.onDragExited,
        onDragDone: widget.onDragDone,
      ));
    }
  }

  @override
  void didUpdateWidget(WinDropTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (defaultTargetPlatform == TargetPlatform.windows) {
      _WinDropChannel.register(_id, _WinDropTargetData(
        onDragEntered: widget.onDragEntered,
        onDragExited: widget.onDragExited,
        onDragDone: widget.onDragDone,
      ));
    }
  }

  @override
  void dispose() {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      _WinDropChannel.unregister(_id);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
