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
  /// Stable device identity (ro.serialno). Survives reconnects.
  /// Handed to `MirrorStateProvider` and `ScrcpySettingsProvider`
  /// for state lookups; the adb address is resolved internally
  /// by ApiClient when the mirror state actually starts the
  /// subprocess.
  String? get _selectedSerial => context.read<DeviceSerialScope>().serial;

  // Scrcpy subprocess state lives in MirrorStateProvider so the offline-
  // listener hook can mutate it from anywhere. This screen just watches
  // it for rebuilds and calls into it for start/stop.
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final mirror = context.read<MirrorStateProvider>();
      // refreshForSerial keys the scrcpy status lookup by stable
      // identity (the ApiClient resolves it to the current adb
      // address internally).
      final stable = _selectedSerial;
      if (stable != null) {
        mirror.refreshForSerial(stable);
      }
      _startPoll();
      // Tell the settings provider which device's options to surface
      // now that we have a build context. ScrcpySettings caches by
      // saved_devices.serial (= ro.serialno, the stable identity),
      // so the lookup key is the scope serial, not the adb-serial.
      context.read<ScrcpySettingsProvider>().setActiveSerial(_selectedSerial);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-key the settings cache when the user picks a different device.
    // The cache key is the stable identity (saved_devices.serial =
    // ro.serialno) — same as the initial setActiveSerial call above.
    final s = _selectedSerial;
    final settings = context.read<ScrcpySettingsProvider>();
    if (settings.current == null || s != _lastSeenSerial) {
      settings.setActiveSerial(s);
      _lastSeenSerial = s;
    }
  }

  String? _lastSeenSerial;

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
      if (!mounted) return;
      context.read<MirrorStateProvider>().refresh();
      // Also poll the windowless recording subprocess — when it's
      // in flight on the active device, the Start button here must
      // be disabled. Cheaper than a separate widget listening
      // (the recording provider has no offline hook because it has
      // nothing to clean up on its own — the subprocess exits when
      // the user clicks stop on the recording page).
      context.read<ScrcpyRecordStateProvider>().refresh();
    });
  }

  Future<void> _onStart() async {
    final s = _selectedSerial;
    if (s == null) return;
    final mirror = context.read<MirrorStateProvider>();
    if (mirror.busy) return;
    // Block Start when a windowless recording is in flight on the
    // active device — scrcpy is single-instance per host so we'd
    // either fail to start the mirror or kill the user's recording.
    // The reverse is OK (recording kills mirror gracefully, see
    // adb_scrcpy_record.go), but we don't want the mirror UI to
    // silently do that without the user seeing it.
    final recording = context.read<ScrcpyRecordStateProvider>().status;
    if (recording.running && recording.serial == s) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('scrcpy.recordingCantStartMirror')),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }
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
    final mirror = context.read<MirrorStateProvider>();
    if (mirror.busy) return;
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
      await mirror.stop();
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

    // `select` (not `watch`) so this pane only rebuilds when the fields
    // it actually consumes change. Both providers already de-dup
    // notifies on no-op polls; combined with the const settings panel
    // below, this keeps start/stop transitions from cascading into the
    // ScrcpySettingsPanel subtree.
    final status =
        context.select<MirrorStateProvider, ScrcpyStatus>((p) => p.status);
    final busy = context.select<MirrorStateProvider, bool>((p) => p.busy);
    final isOurs =
        context.select<MirrorStateProvider, bool>((p) => p.isOurs(stable));
    final recording = context
        .select<ScrcpyRecordStateProvider, ScrcpyRecordStatus>((p) => p.status);
    final isRunning = status.running && isOurs;
    // Recording is "blocking" the mirror when it's running on the
    // active device. Other-device recordings are surfaced as a
    // banner but don't disable the start button.
    final recordingBlocksMirror =
        recording.running && recording.serial == stable;

    // Responsive: side-by-side on wide windows, stacked on narrow ones.
    // scrcpy itself renders in its own SDL window, so the tab content
    // can afford to be more verbose than a typical mobile layout.
    return OfflineGuard(
      serial: stable,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const breakpoint = 720.0;
          final rightPane = _RightPane(
            serial: stable,
            isRunning: isRunning,
            elapsed: status.elapsedSeconds,
            busy: busy,
            recording: recording,
            recordingBlocksMirror: recordingBlocksMirror,
            onStart: _onStart,
            onStop: _onStop,
          );
          if (constraints.maxWidth >= breakpoint) {
            // Wide layout:
            //   Column(
            //     Expanded(Row(
            //       Expanded(4): Card(ScrcpySettingsPanel)         // left, scrolls
            //       Expanded(3): SingleChildScrollView(_RightPane)  // right, scrolls
            //     ))
            //   )
            //
            // Column + Expanded(Row) gives the Row a definite height. Each
            // side scrolls independently. The right pane is wrapped in
            // SingleChildScrollView so the status + button + hint +
            // shortcut reference table can all be reached by scrolling
            // the right column when the window is short.
            //
            // We deliberately avoid IntrinsicHeight + Row combos: passing
            // a loose unbounded cross-axis constraint into a Row that
            // contains a scroll child makes Stack-based children (e.g.
            // SegmentedButton inside ScrcpySettingsPanel) hit-test with
            // size=MISSING.
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
                          // _RightPane uses an internal LayoutBuilder:
                          // when it sees a bounded height (this case), it
                          // pins status/button/hint and lets
                          // ScrcpyShortcutReference fill the rest with its
                          // own internal scroll. No outer SingleChildScrollView
                          // here — that would conflict with the
                          // ListView in ScrcpyShortcutReference.
                          child: rightPane,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          // Narrow: outer ListView scrolls; rightPane is rendered as-is
          // (no inner SingleChildScrollView — that would nest a scroll
          // view inside another and blow up with "vertical viewport was
          // given unbounded height"). The ScrcpyShortcutReference is
          // already part of the rightPane, so no extra entry here.
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
    // Two layout modes:
    //   * Bounded height (wide layout: parent is Column > Expanded > Row
    //     > Expanded). Status / button / hint stay pinned at the top;
    //     the shortcut reference takes the remaining vertical space
    //     and scrolls its own list internally.
    //   * Unbounded height (narrow layout: this widget sits inside an
    //     outer ListView). We can't use Expanded inside an unbounded
    //     parent, so we just lay out everything in a single Column and
    //     let the outer ListView scroll the whole pane.
    return Card(
      margin: const EdgeInsets.fromLTRB(6, 12, 12, 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(builder: (context, constraints) {
          final statusCard = _buildStatusCard(theme, serial, isRunning, elapsed,
              recording, recordingBlocksMirror);
          // When a recording is blocking the mirror, the start
          // button stays rendered (so the user can see why nothing
          // happens) but is disabled with a tooltip explaining.
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
            // Wide layout: pin status/button/hint, let the shortcut
            // reference fill the rest and scroll internally.
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
          // Narrow layout: stack everything; outer ListView scrolls.
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
          // Recording-on-this-device banner. Sits under the mirror
          // status so the user can see both: "scrcpy is busy doing
          // a recording on top of your selected device, that's why
          // the Start button is grey". For recordings on OTHER
          // devices, we show a different message (awareness without
          // disabling local controls).
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
