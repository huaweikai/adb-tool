import 'package:flutter/cupertino.dart';
import 'package:cross_file/cross_file.dart';

import 'mac_drop.dart';
import 'win_drop.dart';

class DropDoneDetails {
  final List<XFile> files;
  DropDoneDetails(this.files);
}

class DropTarget extends StatelessWidget {
  final Widget child;
  final VoidCallback? onDragEntered;
  final VoidCallback? onDragExited;
  final void Function(DropDoneDetails)? onDragDone;

  const DropTarget({
    super.key,
    required this.child,
    this.onDragEntered,
    this.onDragExited,
    this.onDragDone,
  });

  @override
  Widget build(BuildContext context) {
    return MacDropTarget(
      onDragEntered: onDragEntered,
      onDragExited: onDragExited,
      onDragDone: onDragDone != null
          ? (details) => onDragDone!(DropDoneDetails(details.files))
          : null,
      child: WinDropTarget(
        onDragEntered: onDragEntered,
        onDragExited: onDragExited,
        onDragDone: onDragDone != null
            ? (details) => onDragDone!(DropDoneDetails(details.files))
            : null,
        child: child,
      ),
    );
  }
}
