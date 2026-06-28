// Device-offline guard widgets.
//
// Two pieces:
//
//   * [OfflineBanner] — a thin amber bar that shows at the top of a
//     screen when the active device is not connected. Pure informational;
//     does not block interaction. Use this when the screen already has
//     its own layout (e.g. toolbars that need to stay clickable) and you
//     only want to surface the offline state.
//
//   * [OfflineGuard] — wraps a screen body and adds the banner PLUS
//     disables interaction (IgnorePointer) and dims the body
//     (Opacity 0.5) while offline. Use this when nothing on the screen
//     can usefully do anything without a live device.
//
// Both read connection state from [DeviceProvider] via `context.select`
// so they only rebuild when the boolean flips, not on every device-list
// mutation.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n.dart';
import '../providers/device_provider.dart';

/// Thin banner shown when the active device is offline. SizedBox.shrink
/// otherwise — no empty gap when online. Standalone widget so screens
/// that own their layout can drop it anywhere they have room (toolbar
/// strip, body header, etc.).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.serial});

  final String serial;

  @override
  Widget build(BuildContext context) {
    // select: rebuild only when the boolean flips, not on every
    // refresh() that mutates the underlying device list.
    final isOnline = context
        .select<DeviceProvider, bool>((dp) => dp.isDeviceConnected(serial));
    if (isOnline) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.errorContainer,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off,
                size: 18,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('deviceOfflineBanner'),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps a child with [OfflineBanner] + offline-aware interaction
/// blocking. When the device is offline:
///
///   * The banner is shown at the top
///   * The child is wrapped in IgnorePointer (no taps / drags pass
///     through) and dimmed to ~50% opacity to visually communicate
///     "this is dead, just wait for the device to come back"
///
/// Intended for screens where the entire content is device-bound
/// (screen mirror, file browser, app manager, etc.). For screens with
/// mixed device-bound and global content (e.g. logcat screen with
/// device filter), drop [OfflineBanner] directly into the existing
/// layout instead of using [OfflineGuard].
class OfflineGuard extends StatelessWidget {
  const OfflineGuard({
    super.key,
    required this.serial,
    required this.child,
  });

  final String serial;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OfflineBanner(serial: serial),
        Expanded(
          child: _OfflineBlocker(serial: serial, child: child),
        ),
      ],
    );
  }
}

class _OfflineBlocker extends StatelessWidget {
  const _OfflineBlocker({required this.serial, required this.child});

  final String serial;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isOnline = context
        .select<DeviceProvider, bool>((dp) => dp.isDeviceConnected(serial));
    return IgnorePointer(
      ignoring: !isOnline,
      child: AnimatedOpacity(
        // Soft fade between states — instant flips would feel jarring
        // since DeviceProvider's offline detection can come in bursts
        // (a brief network blip flickers the device list for one tick).
        duration: const Duration(milliseconds: 180),
        opacity: isOnline ? 1.0 : 0.45,
        child: child,
      ),
    );
  }
}
