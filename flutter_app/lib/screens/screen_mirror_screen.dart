import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n.dart';
import '../providers/device_provider.dart';
import '../services/api_client.dart';

/// Screen-mirror (scrcpy) control panel.
///
/// The actual video stream runs in scrcpy's own SDL window outside this
/// Flutter app — we don't embed it. This screen is just a launcher plus
/// a row of shortcut buttons that fire `adb shell input keyevent` so
/// the user can do common things (home / back / recents / power / vol)
/// without having to reach for the device while scrcpy is focused.
class ScreenMirrorScreen extends StatefulWidget {
  const ScreenMirrorScreen({super.key});

  @override
  State<ScreenMirrorScreen> createState() => _ScreenMirrorScreenState();
}

class _ScreenMirrorScreenState extends State<ScreenMirrorScreen> {
  String? get _serial => context.read<DeviceSerialScope>().serial;

  // polled status — what the backend reports about the running subprocess.
  ScrcpyStatus _status = ScrcpyStatus.stopped;
  Timer? _pollTimer;
  bool _busy = false; // start/stop in flight, prevents double-clicks

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshStatus();
      _startPoll();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // 2s is enough to catch "user closed the scrcpy SDL window directly"
  // without hammering the backend. The user's main interaction is
  // pressing buttons here, not staring at the elapsed counter.
  void _startPoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) _refreshStatus();
    });
  }

  Future<void> _refreshStatus() async {
    final s = _serial;
    if (s == null) {
      setState(() => _status = ScrcpyStatus.stopped);
      return;
    }
    try {
      final next = await context.read<ApiClient>().scrcpyStatus(serial: s);
      if (mounted) setState(() => _status = next);
    } catch (_) {
      // network blip — keep last known status, don't flicker the UI
    }
  }

  Future<void> _onStart() async {
    final s = _serial;
    if (s == null || _busy) return;
    setState(() => _busy = true);
    try {
      await context.read<ApiClient>().startScrcpy(s);
      await _refreshStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('scrcpyWindowHint')),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('scrcpyStartFailed', {'error': e.toString()})),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onStop() async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('scrcpyConfirmStop')),
        content: Text(tr('scrcpyConfirmStopBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('scrcpyStop')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await context.read<ApiClient>().stopScrcpy();
      await _refreshStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('scrcpyStopFailed', {'error': e.toString()})),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onShortcut(String action) async {
    final s = _serial;
    if (s == null || _busy) return;
    // Shortcuts go straight through — they don't depend on scrcpy being
    // running, so we don't gate on _status.running. The user might be
    // using the buttons to drive the device while staring at scrcpy.
    try {
      await context.read<ApiClient>().scrcpyShortcut(s, action);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(tr('scrcpyShortcutFailed', {'error': e.toString()})),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final serial = _serial;
    final theme = Theme.of(context);

    if (serial == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            tr('scrcpyNoDevice'),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final isRunning = _status.running && _status.serial == serial;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status header — running / stopped + elapsed time
          _buildStatusCard(theme, serial, isRunning),
          const SizedBox(height: 16),

          // Main action button: Start / Stop / Restart
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : (isRunning ? _onStop : _onStart),
                  icon: Icon(isRunning ? Icons.stop : Icons.play_arrow),
                  label: Text(
                    isRunning ? tr('scrcpyStop') : tr('scrcpyStart'),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor:
                        isRunning ? theme.colorScheme.error : null,
                  ),
                ),
              ),
              if (isRunning) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _busy ? null : _onStart,
                  tooltip: tr('scrcpyRestart'),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // Hint about where the video window is — many users miss it
          // the first time because scrcpy opens outside the Flutter
          // app's window stack.
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('scrcpyWindowHint'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Shortcut button grid — independent of scrcpy running state.
          // Grouping: system (home/back/recents/power/menu) then media (vol).
          Text(
            tr('screenMirrorHint').split('—').first.trim(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          _buildShortcutGrid(theme, isRunning),
        ],
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme, String serial, bool isRunning) {
    final color =
        isRunning ? theme.colorScheme.primary : theme.colorScheme.outline;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRunning ? Colors.green : theme.colorScheme.outline,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('scrcpyTitle', {'serial': serial}),
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isRunning
                        ? tr('scrcpyElapsed',
                            {'seconds': _status.elapsedSeconds.toString()})
                        : tr('scrcpyStopped'),
                    style: theme.textTheme.bodySmall?.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutGrid(ThemeData theme, bool isRunning) {
    final shortcuts = <_ShortcutDef>[
      _ShortcutDef('home', Icons.home_outlined, tr('scrcpyShortcutHome')),
      _ShortcutDef('back', Icons.arrow_back, tr('scrcpyShortcutBack')),
      _ShortcutDef('recents', Icons.view_agenda_outlined,
          tr('scrcpyShortcutRecents')),
      _ShortcutDef('power', Icons.power_settings_new,
          tr('scrcpyShortcutPower')),
      _ShortcutDef('menu', Icons.menu, tr('scrcpyShortcutMenu')),
      _ShortcutDef('volume_up', Icons.volume_up, tr('scrcpyShortcutVolumeUp')),
      _ShortcutDef('volume_down', Icons.volume_down,
          tr('scrcpyShortcutVolumeDown')),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.0,
      children: shortcuts
          .map((s) => _ShortcutButton(
                def: s,
                enabled: !_busy,
                // Subtle visual cue that buttons work even when scrcpy
                // isn't running — but slightly muted when it's stopped
                // since "Home" doesn't do much on a sleeping device.
                active: isRunning,
                onTap: () => _onShortcut(s.action),
              ))
          .toList(),
    );
  }
}

class _ShortcutDef {
  final String action;
  final IconData icon;
  final String label;
  const _ShortcutDef(this.action, this.icon, this.label);
}

class _ShortcutButton extends StatelessWidget {
  final _ShortcutDef def;
  final bool enabled;
  final bool active;
  final VoidCallback onTap;

  const _ShortcutButton({
    required this.def,
    required this.enabled,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = active
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest.withAlpha(120);
    final fg = active
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(def.icon, size: 22, color: fg),
              const SizedBox(height: 4),
              Text(
                def.label,
                style: TextStyle(fontSize: 10, color: fg),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}