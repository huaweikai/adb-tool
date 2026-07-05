import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n.dart';
import '../providers/device_provider.dart';
import '../providers/mirror_state_provider.dart';
import '../providers/scrcpy_record_state_provider.dart';
import '../providers/scrcpy_settings_provider.dart';
import '../services/api_client.dart';
import '../widgets/offline_guard.dart';
import '../widgets/scrcpy_settings_panel.dart';
import '../widgets/scrcpy_shortcut_reference.dart';

/// Screen-mirror (scrcpy) control panel.
///
/// The actual video stream runs in scrcpy's own SDL window outside this
/// Flutter app — we don't embed it. This screen is just a launcher
/// plus a row of shortcut buttons that fire `adb shell input keyevent`
/// so the user can do common things (home / back / recents / power /
/// vol) without having to reach for the device while scrcpy is focused.
///
/// Layout (split horizontal, collapses to single column on narrow
/// windows — scrcpy's own window is detached so the right side has
/// plenty of space on a typical desktop):
///
///   ┌──────────────────┬──────────────────┐
///   │  Settings panel  │  Status + Start  │
///   │  (per-device     │  + Shortcut grid │
///   │   persisted)     │                  │
///   └──────────────────┴──────────────────┘
class ScreenMirrorScreen extends StatefulWidget {
  const ScreenMirrorScreen({super.key});

  @override
  State<ScreenMirrorScreen> createState() => _ScreenMirrorScreenState();
}

class _ScreenMirrorScreenState extends State<ScreenMirrorScreen> {
  /// Stable device identity (ro.serialno). Each _CachedScreen provides
  /// its own DeviceSerialScope so this returns the device THIS screen
  /// instance belongs to.
  String? get _selectedSerial => context.read<DeviceSerialScope>().serial;

  /// 2s poll timer — catches "user closed the scrcpy SDL window".
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final mirror = context.read<MirrorStateProvider>();
      final stable = _selectedSerial;
      if (stable != null) {
        mirror.refresh(stable);
      }
      _startPoll();
      context.read<ScrcpySettingsProvider>().setActiveSerial(_selectedSerial);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = _selectedSerial;
    if (s != _lastSeenSerial) {
      _lastSeenSerial = s;
      final settings = context.read<ScrcpySettingsProvider>();
      settings.setActiveSerial(s);
      if (s != null) {
        context.read<MirrorStateProvider>().refresh(s);
      }
    }
  }

  String? _lastSeenSerial;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      if (!context.read<DeviceScreenActiveScope>().active) return;
      final stable = _selectedSerial;
      if (stable == null) return;
      context.read<MirrorStateProvider>().refresh(stable);
      context.read<ScrcpyRecordStateProvider>().refresh(serial: stable);
    });
  }

  Future<void> _onStart() async {
    final s = _selectedSerial;
    if (s == null) return;
    final mirror = context.read<MirrorStateProvider>();
    if (mirror.isBusy(s)) return;
    // Refresh from backend so recording-block check sees current state.
    await mirror.refresh(s);
    final recordProvider = context.read<ScrcpyRecordStateProvider>();
    await recordProvider.refresh(serial: s);
    final recording = recordProvider.statusFor(s);
    if (recording.running && recording.serial == s) {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('scrcpy.recordingBusyTitle')),
          content: Text(tr('scrcpy.recordingBusyBody')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('recording.scrcpyBusyCancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('scrcpy.recordingBusyContinue')),
            ),
          ],
        ),
      );
      if (ok != true) return;
      try {
        await recordProvider.stop(s);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('recording.stopFailed', {'error': e.toString()})),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
    }
    if (!mounted) return;
    final opts = context.read<ScrcpySettingsProvider>().current;
    if (opts == null) {
      return;
    }
    final recordPath = opts.record;
    if (opts.recordEnabled && (recordPath ?? '').isNotEmpty) {
      final exists = await Directory(recordPath!).exists();
      if (!exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('scrcpyRecordFolderNotFound')),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }
    }
    try {
      await mirror.start(s, opts);
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
    }
  }

  Future<void> _onStop() async {
    final s = _selectedSerial;
    if (s == null) return;
    final mirror = context.read<MirrorStateProvider>();
    if (mirror.isBusy(s)) return;
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

    try {
      await mirror.stop(s);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('scrcpyStopFailed', {'error': e.toString()})),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<DeviceSerialScope>();
    final stable = _selectedSerial;
    if (stable == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            tr('scrcpyNoDevice'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    // Per-device status — each screen instance queries only the status
    // for its own device serial.
    final status = context.select<MirrorStateProvider, ScrcpyStatus>(
        (p) => p.statusFor(stable));
    final busy = context.select<MirrorStateProvider, bool>(
        (p) => p.isBusy(stable));
    final recording = context.select<ScrcpyRecordStateProvider, ScrcpyRecordStatus>(
        (p) => p.statusFor(stable));
    final isRunning = status.running;
    final elapsed = context.select<MirrorStateProvider, int>(
        (p) => p.elapsedFor(stable));
    final recordingBlocksMirror =
        recording.running && recording.serial == stable;

    return OfflineGuard(
      serial: stable,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const breakpoint = 720.0;
          final rightPane = _RightPane(
            serial: stable,
            isRunning: isRunning,
            elapsed: elapsed,
            busy: busy,
            recording: recording,
            recordingBlocksMirror: recordingBlocksMirror,
            onStart: _onStart,
            onStop: _onStop,
          );
          if (constraints.maxWidth >= breakpoint) {
            return Column(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Expanded(
                        flex: 4,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(12, 12, 6, 12),
                          child: Card(
                            margin: EdgeInsets.zero,
                            child: ScrcpySettingsPanel(),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(6, 12, 12, 12),
                          child: rightPane,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const Card(
                margin: EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  height: 360,
                  child: ScrcpySettingsPanel(),
                ),
              ),
              rightPane,
            ],
          );
        },
      ),
    );
  }
}

class _RightPane extends StatelessWidget {
  final String serial;
  final bool isRunning;
  final int elapsed;
  final bool busy;
  final ScrcpyRecordStatus recording;
  final bool recordingBlocksMirror;
  final VoidCallback onStart;
  final VoidCallback onStop;
  const _RightPane({
    required this.serial,
    required this.isRunning,
    required this.elapsed,
    required this.busy,
    required this.recording,
    required this.recordingBlocksMirror,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(6, 12, 12, 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(builder: (context, constraints) {
          final statusCard = _buildStatusCard(theme, serial, isRunning, elapsed,
              recording, recordingBlocksMirror);
          final startButton = Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: recordingBlocksMirror
                      ? tr('scrcpy.recordingCantStartMirror')
                      : '',
                  child: FilledButton.icon(
                    onPressed: busy || recordingBlocksMirror
                        ? null
                        : (isRunning ? onStop : onStart),
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
              ),
              if (isRunning) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: busy || recordingBlocksMirror ? null : onStart,
                  tooltip: tr('scrcpyRestart'),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ],
          );
          final windowHint = Container(
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
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          );
          if (constraints.hasBoundedHeight) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                statusCard,
                const SizedBox(height: 16),
                startButton,
                const SizedBox(height: 12),
                windowHint,
                const SizedBox(height: 12),
                const Expanded(child: ScrcpyShortcutReference()),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              statusCard,
              const SizedBox(height: 16),
              startButton,
              const SizedBox(height: 12),
              windowHint,
              const SizedBox(height: 12),
              const ScrcpyShortcutReference(),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildStatusCard(
    ThemeData theme,
    String serial,
    bool isRunning,
    int elapsed,
    ScrcpyRecordStatus recording,
    bool recordingBlocksMirror,
  ) {
    final color =
        isRunning ? theme.colorScheme.primary : theme.colorScheme.outline;
    return Container(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                          ? tr('scrcpyElapsed', {'seconds': elapsed.toString()})
                          : tr('scrcpyStopped'),
                      style: theme.textTheme.bodySmall?.copyWith(color: color),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (recording.running) ...[
            const SizedBox(height: 8),
            _buildRecordingBanner(theme, recording,
                isThisDevice: recordingBlocksMirror),
          ],
        ],
      ),
    );
  }

  Widget _buildRecordingBanner(
    ThemeData theme,
    ScrcpyRecordStatus recording, {
    required bool isThisDevice,
  }) {
    final accent =
        isThisDevice ? theme.colorScheme.error : theme.colorScheme.tertiary;
    final elapsed = recording.elapsedSeconds;
    final titleText = isThisDevice
        ? tr('scrcpy.recordingActiveOnCard', {'seconds': elapsed.toString()})
        : tr('scrcpy.recordingActiveOther');
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: accent.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withAlpha(120)),
      ),
      child: Row(
        children: [
          Icon(
            isThisDevice ? Icons.fiber_manual_record : Icons.info_outline,
            size: 14,
            color: accent,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              titleText,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: accent, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
