import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/design_tokens.dart';
import '../i18n.dart';
import '../models/device.dart';
import '../providers/device_provider.dart';
import '../services/api_client.dart';
import '../services/device_stream.dart';
import '../widgets/window_chrome.dart';
import '../widgets/wireless_adb_dialog.dart';

/// Launch page — device selection (design node 64:2 "启动 — 设备选择").
///
/// Shown right after the backend is ready, before entering the main
/// app. The user picks a connected device and hits "打开", which
/// pre-selects the device in [DeviceProvider] and calls [onOpen] so
/// the parent can swap in the HomeScreen. A "连接新设备" section offers
/// USB instructions plus the wireless/QR pairing dialog.
class LaunchPage extends StatefulWidget {
  const LaunchPage({super.key, required this.onOpen});

  /// Called after a device has been selected in [DeviceProvider].
  final VoidCallback onOpen;

  @override
  State<LaunchPage> createState() => _LaunchPageState();
}

class _LaunchPageState extends State<LaunchPage> {
  // Design 64:2 uses green for the selected option + open button.
  static const Color _accent = Color(0xFF2EA043);
  static const Color _accentBorder = Color(0xFF3FB950);

  final DeviceStreamService _deviceStream = DeviceStreamService();
  String? _selectedSerial;
  String? _hint;

  @override
  void initState() {
    super.initState();
    _hint = tr('launchHint');
    WindowChromeHint.set(_hint);
    final dp = context.read<DeviceProvider>();
    final api = context.read<ApiClient>();
    dp.connectDeviceStream(_deviceStream, api);
    _deviceStream.connect();
  }

  @override
  void dispose() {
    WindowChromeHint.clearIf(_hint);
    // Do NOT call dp.disconnectDeviceStream() here: when HomeScreen
    // replaces this page its initState re-connects the provider to its
    // own stream BEFORE this dispose runs; cancelling here would kill
    // the new subscription. We only tear down our own WebSocket.
    _deviceStream.dispose();
    super.dispose();
  }

  void _open() {
    final serial = _selectedSerial;
    if (serial == null) return;
    context.read<DeviceProvider>().select(serial);
    widget.onOpen();
  }

  Future<void> _showWirelessDialog() async {
    final api = context.read<ApiClient>();
    final dp = context.read<DeviceProvider>();
    await showDialog<void>(
      context: context,
      builder: (_) => WirelessAdbDialog(api: api, deviceProvider: dp),
    );
  }

  void _showUsbTip() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('launchUsbTipTitle')),
        content: Text(tr('launchUsbTipBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('close')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dp = context.watch<DeviceProvider>();
    final devices = dp.devices;

    // Drop a selection whose device disappeared or went offline.
    if (_selectedSerial != null) {
      final match = devices.where(
        (d) => d.serial == _selectedSerial && d.isOnline,
      );
      if (match.isEmpty) _selectedSerial = null;
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: ConstrainedBox(
          // Design 64:7 — picker card is 440 wide.
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xxl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Title + subtitle (64:8 / 64:9) ──
                Text(
                  tr('launchPickDevice'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  tr('launchPickDeviceSubtitle'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Device options (64:10 / 64:19) ──
                if (devices.isEmpty)
                  _EmptyDevices(theme: theme)
                else
                  ...devices.map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _DeviceOption(
                        device: d,
                        selected: d.serial == _selectedSerial,
                        accent: _accent,
                        accentBorder: _accentBorder,
                        onTap: d.isOnline
                            ? () =>
                                setState(() => _selectedSerial = d.serial)
                            : null,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.xs),

                // ── Connect new device (64:28) ──
                Text(
                  tr('launchConnectNew'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _ConnectMethodButton(
                        icon: Icons.usb,
                        label: tr('launchUsbConnect'),
                        onTap: _showUsbTip,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _ConnectMethodButton(
                        icon: Icons.wifi,
                        label: tr('launchWifiConnect'),
                        onTap: _showWirelessDialog,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _ConnectMethodButton(
                        icon: Icons.qr_code_scanner,
                        label: tr('launchQrConnect'),
                        onTap: _showWirelessDialog,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Open button (64:33 — 44 tall, green) ──
                SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: _selectedSerial != null ? _open : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          theme.colorScheme.onSurface.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: Text(
                      tr('launchOpen'),
                      style: const TextStyle(
                        fontSize: AppFontSize.title,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One selectable device row — 64px tall, radio at the left, green
/// border when selected (design 64:10 / 64:19).
class _DeviceOption extends StatelessWidget {
  const _DeviceOption({
    required this.device,
    required this.selected,
    required this.accent,
    required this.accentBorder,
    required this.onTap,
  });

  final Device device;
  final bool selected;
  final Color accent;
  final Color accentBorder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = onTap == null;
    final borderColor = selected
        ? accentBorder
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.6);

    return AnimatedContainer(
      duration: AppDuration.fast,
      height: 64,
      decoration: BoxDecoration(
        color: selected
            ? accent.withValues(alpha: 0.08)
            : theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                // Radio (64:18 / 64:27).
                _RadioDot(selected: selected, accent: accentBorder),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: disabled
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        device.serial,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: AppFontSize.md,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _StatusPill(online: device.isOnline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected, required this.accent});

  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: AppDuration.fast,
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? accent : theme.colorScheme.outline,
          width: selected ? 5 : 1.5,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = online ? const Color(0xFF3FB950) : theme.colorScheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            tr(online ? 'online' : 'offline'),
            style: TextStyle(
              fontSize: AppFontSize.sm,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Connect-method button — 40 tall (design 66:3 / 66:5 / 66:7).
class _ConnectMethodButton extends StatelessWidget {
  const _ConnectMethodButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 40,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: AppFontSize.body,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}

class _EmptyDevices extends StatelessWidget {
  const _EmptyDevices({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.phonelink_erase,
            size: 32,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            tr('launchNoDevices'),
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            tr('launchNoDevicesSubtitle'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
