// Shared confirm dialogs for the screen-recording flow.
//
// The capture mixin pops these when it detects that scrcpy is busy
// (either mirroring on this device or recording somewhere else) and
// the user chose scrcpy mode. Keeping them in their own widget so
// both the file-browser and test-session hosts can call them via
// the same showScrcpyBusyConfirmDialog helper without duplicating
// the dialog markup.
import 'package:flutter/material.dart';

import '../i18n.dart';
import '../services/api_client.dart';

/// Pop a confirm dialog when the user tries to start a scrcpy
/// recording while scrcpy is busy. Returns true if the user agreed
/// to preempt (only meaningful when [busy.kind] == 'mirror' —
/// record-busy conflicts are not preemptable so the dialog is
/// dismiss-only).
Future<bool?> showScrcpyBusyConfirmDialog(
  BuildContext context, {
  required ScrcpyRecordBusyException busy,
}) {
  final isMirror = busy.isMirrorBusy;
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isMirror
          ? tr('recording.scrcpyBusyMirrorTitle')
          : tr('recording.scrcpyBusyRecordTitle')),
      content: Text(isMirror
          ? tr('recording.scrcpyBusyMirrorBody')
          : tr('recording.scrcpyBusyRecordBody')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(tr('recording.scrcpyBusyCancel')),
        ),
        if (isMirror)
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('recording.scrcpyBusyContinue')),
          ),
      ],
    ),
  );
}
