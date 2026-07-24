import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/design_tokens.dart';
import '../i18n.dart';
import '../providers/device_provider.dart';
import '../services/api_client.dart';
import '../services/device_stream.dart';
import '../widgets/window_chrome.dart';
import '../widgets/wireless_adb_dialog.dart';

/// App startup / device-selection page (design node 64:2 "启动 — 设备选择").
///
/// This is one screen inside the [AdbToolApp] shell — it does NOT own the
/// Go-backend lifecycle (that lives in the shell) nor the app-level page
/// switch. It renders the device list + the "启动后端" status banner and
/// reports the user's choices back through callbacks:
///  * [onOpen]        — a device was picked; the shell swaps in HomeScreen.
///  * [onOpenSettings]— open the settings dialog (backend port, etc.).
///  * [onStartBackend]— manually launch the backend when auto-start is off
///                     (null while the backend is booting / running).
///  * [backendUp] / [notStarted] — drive the status banner.
class LaunchPage extends StatefulWidget {
  const LaunchPage({
    super.key,
    required this.backendUp,
    required this.notStarted,
    required this.onOpen,
    this.onOpenSettings,
    this.onStartBackend,
  });

  /// Whether the Go backend is currently reachable. When false the status
  /// banner is shown.
  final bool backendUp;

  /// True when auto-start is off (or a boot failed). Drives the banner's
  /// red "启动后端" treatment with a manual-start button.
  final bool notStarted;

  /// Called after a device has been selected in [DeviceProvider].
  final VoidCallback onOpen;

  /// Opens the settings dialog. Null when settings are not reachable.
  final VoidCallback? onOpenSettings;

  /// When non-null, the backend is not running and the user must start it
  /// manually. The page shows a banner with a "启动后端" button bound to
  /// this callback.
  final Future<void> Function()? onStartBackend;

  @override
  State<LaunchPage> createState() => _LaunchPageState();
}

class _LaunchPageState extends State<LaunchPage> {
  // Design 64:2 uses green for the selected option + open button.
  static const Color _accent = Color(0xFF2EA043);
  static const Color _accentBorder = Color(0xFF3FB950);

  // Selection is a ValueNotifier, not raw state, so picking a row only
  // notifies the rows that actually change (the newly-selected one and
  // the previously-selected one) — not the whole page. The device-event
  // stream otherwise rebuilds the page on every push, and a full Stateful
  // setState here would pile that on top of the selection animation.
  final ValueNotifier<String?> _selectedSerial = ValueNotifier<String?>(null);
  String? _hint;
  // De-bounces the after-frame selection-clear so we don't stack
  // post-frame callbacks while an invalid selection persists.
  bool _selectionClearScheduled = false;

  @override
  void initState() {
    super.initState();
    _hint = tr('launchHint');
    WindowChromeHint.set(_hint);
  }

  @override
  void dispose() {
    _selectedSerial.dispose();
    WindowChromeHint.clearIf(_hint);
    super.dispose();
  }

  // The device is pre-selected on tap (see the list onTap), so opening
  // just hands control to the shell.
  void _open() => widget.onOpen();

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
    // The selection page reads from the local saved-devices table
    // (drift DB), not the live-only online list. Known devices stay
    // visible when offline, each tagged with its connection state.
    // Only a genuinely empty DB shows the "no device" empty state.
    final saved = dp.savedDevices;

    // Drop a selection whose device is gone from the DB or went offline.
    // Done on the next frame (not mid-build) to avoid mutating the
    // notifier while the widget tree is being built.
    final sel = _selectedSerial.value;
    if (sel != null &&
        !saved.any((d) => d.serial == sel && d.isConnected) &&
        !_selectionClearScheduled) {
      _selectionClearScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _selectionClearScheduled = false;
        if (_selectedSerial.value == sel) _selectedSerial.value = null;
      });
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
                // Keeps the device-event stream alive only while the
                // selection surface is visible; unmounts (closing its
                // WebSocket) once the shell swaps in HomeScreen, which
                // opens its own stream.
                const _LaunchDeviceStream(),
                // ── Settings gear (top-right) ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, size: 20),
                      tooltip: tr('settings.title'),
                      color: theme.colorScheme.onSurfaceVariant,
                      onPressed: widget.onOpenSettings,
                      splashRadius: 18,
                    ),
                  ],
                ),
                // ── Backend status banner ──
                // Driven by the shell: [widget.backendUp] toggles the whole
                // banner; [widget.notStarted] switches it between a red
                // "manual start" treatment (with a button) and a neutral
                // "connecting…" hint with a spinner while auto-start boots.
                if (!widget.backendUp) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: widget.notStarted
                          ? theme.colorScheme.errorContainer
                              .withValues(alpha: 0.18)
                          : theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: widget.notStarted
                            ? theme.colorScheme.error.withValues(alpha: 0.4)
                            : theme.colorScheme.outline.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (widget.notStarted)
                          Icon(Icons.power_settings_new,
                              color: theme.colorScheme.error, size: 20)
                        else
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.notStarted
                                    ? tr('launchBackendOffTitle')
                                    : tr('launchBackendConnecting'),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.notStarted
                                    ? tr('launchBackendOffDesc')
                                    : tr('launchBackendConnectingDesc'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.notStarted) ...[
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 36,
                            child: FilledButton.icon(
                              onPressed: widget.onStartBackend,
                              icon: const Icon(Icons.play_arrow, size: 18),
                              label: Text(tr('launchStartBackend')),
                              style: FilledButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
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
                // Source of truth = saved_devices table. Each known
                // device is shown with its connection state; offline
                // ones are listed but not selectable. Only a truly
                // empty DB renders the "no device" empty state.
                if (saved.isEmpty)
                  _EmptyDevices(theme: theme)
                else
                  ...saved.map(
                    (d) {
                      final name = dp.displayNameFor(d.serial) ?? d.serial;
                      final secondary =
                          (d.address != null && d.address!.isNotEmpty)
                              ? d.address!
                              : d.serial;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _DeviceOption(
                          displayName: name,
                          secondary: secondary,
                          stableSerial: d.serial,
                          online: d.isConnected,
                          selectedNotifier: _selectedSerial,
                          accent: _accent,
                          accentBorder: _accentBorder,
                          onTap: d.isConnected
                              ? () {
                                  dp.select(d.serial);
                                  _selectedSerial.value = d.serial;
                                }
                              : null,
                        ),
                      );
                    },
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
                // Listens only to the selection notifier, so it enables /
                // disables without rebuilding the whole page on every
                // device-stream push.
                ValueListenableBuilder<String?>(
                  valueListenable: _selectedSerial,
                  builder: (ctx, sel, _) => SizedBox(
                    height: 44,
                    child: FilledButton(
                      onPressed: sel != null ? _open : null,
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
    required this.displayName,
    required this.secondary,
    required this.stableSerial,
    required this.online,
    required this.selectedNotifier,
    required this.accent,
    required this.accentBorder,
    required this.onTap,
  });

  final String displayName;
  final String secondary;
  final String stableSerial;
  final bool online;
  final ValueNotifier<String?> selectedNotifier;
  final Color accent;
  final Color accentBorder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = onTap == null;
    // Only rebuild this row when its own selection state flips — picking
    // a different row animates just that row + the previously selected one,
    // never the page.
    return ValueListenableBuilder<String?>(
      valueListenable: selectedNotifier,
      builder: (context, selectedSerial, _) {
        final selected = selectedSerial == stableSerial;
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
            border:
                Border.all(color: borderColor, width: selected ? 1.5 : 1),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
                            displayName,
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
                            secondary,
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
                    _StatusPill(online: online),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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

/// Connects the device-event stream only while the selection surface is
/// visible (mounted). Once a device is picked and [HomeScreen] takes
/// over, this widget unmounts and its WebSocket closes — [HomeScreen]
/// opens its own stream, so we never run two sockets at once.
class _LaunchDeviceStream extends StatefulWidget {
  const _LaunchDeviceStream();

  @override
  State<_LaunchDeviceStream> createState() => _LaunchDeviceStreamState();
}

class _LaunchDeviceStreamState extends State<_LaunchDeviceStream> {
  final DeviceStreamService _stream = DeviceStreamService();

  @override
  void initState() {
    super.initState();
    final dp = context.read<DeviceProvider>();
    final api = context.read<ApiClient>();
    dp.connectDeviceStream(_stream, api);
    _stream.connect();
  }

  @override
  void dispose() {
    _stream.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
