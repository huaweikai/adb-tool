// Shown when a device disconnects while a test session is running.
// Presents two options: wait for the device to come back, or end the
// session now. If the device has an in-flight recording, it is
// automatically stopped before the dialog appears.
import 'package:flutter/material.dart';
import '../i18n.dart';

enum DeviceOfflineResult { wait, endSession }

/// Show the device-offline dialog. Returns [DeviceOfflineResult.wait] if
/// the user wants to keep waiting, or [DeviceOfflineResult.endSession]
/// if they want to abandon the session.
Future<DeviceOfflineResult?> showDeviceOfflineDialog({
  required BuildContext context,
  required String deviceName,
}) {
  return showDialog<DeviceOfflineResult>(
    context: context,
    barrierDismissible: false, // device offline is critical — must choose
    builder: (ctx) => AlertDialog(
      icon: Icon(
        Icons.usb_off,
        size: 40,
        color: Theme.of(ctx).colorScheme.error,
      ),
      title: Text(tr('deviceDisconnected')),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('deviceDisconnectedBody', {'device': deviceName})),
            const SizedBox(height: 12),
            Text(
              tr('deviceDisconnectedHint'),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(ctx).pop(DeviceOfflineResult.endSession),
          child: Text(tr('endSessionNow')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(DeviceOfflineResult.wait),
          child: Text(tr('waitForReconnect')),
        ),
      ],
    ),
  );
}
