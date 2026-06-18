// Global floating action button that appears whenever any device has an
// in-flight screen recording.
//
// Layout: always a child of the home-screen root (passed as a positioned
// widget in a Stack). When tapped:
//   - 1 active recording → calls onNavigate immediately
//   - N > 1 active recordings → shows a PopupMenu so the user can pick
//
// Architecture note: the FAB is "global" in the sense that it lives above
// every tab and survives tab switches. It does NOT span the entire app
// (i.e. not above dialogs / sheets / system overlays) — those are handled
// by the OS natively.
import 'dart:async';
import 'package:flutter/material.dart';
import '../db/database.dart';
import '../i18n.dart';
import '../providers/test_session_provider.dart';
import '../services/screen_record_owner.dart';

/// One device that currently has an active recording in flight.
class _ActiveRecording {
  final String serial;
  final String deviceName; // displayName from SavedDevice
  final String? sessionName; // null means file_browser recording
  final int startedAtMs; // epoch ms for elapsed time
  final ScreenRecordOwner owner;

  const _ActiveRecording({
    required this.serial,
    required this.deviceName,
    this.sessionName,
    required this.startedAtMs,
    required this.owner,
  });

  String get elapsedLabel {
    final secs =
        (DateTime.now().millisecondsSinceEpoch - startedAtMs) ~/ 1000;
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// Signature called when the user picks a recording to jump to.
typedef OnNavigateToSession = void Function(String serial);

class RecordingOverlay extends StatefulWidget {
  final AppDatabase db;
  final TestSessionProvider sessionProvider;
  final OnNavigateToSession onNavigateToSession;

  const RecordingOverlay({
    super.key,
    required this.db,
    required this.sessionProvider,
    required this.onNavigateToSession,
  });

  @override
  State<RecordingOverlay> createState() => _RecordingOverlayState();
}

class _RecordingOverlayState extends State<RecordingOverlay> {
  // Tick every second so the elapsed label updates in the popup.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Stream 1: all saved devices (to find recording owners)
        StreamBuilder<List<SavedDevice>>(
          stream: widget.db.savedDevicesDao.watchAllSavedDevices(),
          builder: (context, devicesSnap) {
            if (!devicesSnap.hasData) return const SizedBox.shrink();

            // Stream 2: all active (running) sessions
            return StreamBuilder<List<TestSessionRow>>(
              stream: widget.sessionProvider.watchAllActiveSessions(),
              builder: (context, sessionsSnap) {
                final sessions = sessionsSnap.data ?? [];
                // Map serial → session name for quick lookup
                final sessionNameBySerial = {
                  for (final s in sessions) s.deviceSerial: s.name,
                };

                final recordings = <_ActiveRecording>[];
                for (final d in devicesSnap.data!) {
                  // Only show FAB for in-flight recording (not saving).
                  // Once saving starts, the recording is done from the user's
                  // perspective — the FAB should disappear immediately.
                  if (d.recordingOwner != null &&
                      d.recordingStartedAt != null &&
                      !d.recordingIsSaving) {
                    recordings.add(_ActiveRecording(
                      serial: d.serial,
                      deviceName: d.displayName,
                      sessionName: sessionNameBySerial[d.serial],
                      startedAtMs: d.recordingStartedAt!,
                      owner: ScreenRecordOwnerX.fromDb(d.recordingOwner!) ??
                             ScreenRecordOwner.fileBrowser,
                    ));
                  }
                }

                if (recordings.isEmpty) return const SizedBox.shrink();

                return Positioned(
                  bottom: 24,
                  right: 24,
                  child: recordings.length == 1
                      ? _buildSingleFab(recordings.single)
                      : _buildMultiFab(recordings),
                );
              },
            );
          },
        ),
      ],
    );
  }

  /// Single recording: a simple FAB that navigates directly on tap.
  Widget _buildSingleFab(_ActiveRecording r) {
    return FloatingActionButton.extended(
      heroTag: 'recording_fab_single',
      backgroundColor: Colors.red,
      onPressed: () => widget.onNavigateToSession(r.serial),
      icon: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record, color: Colors.white, size: 14),
          SizedBox(width: 4),
        ],
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            r.elapsedLabel,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Menlo',
              fontSize: 13,
            ),
          ),
          if (r.sessionName != null) ...[
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(
                r.sessionName!,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Multiple recordings: a FAB with badge that opens a popup with the list.
  Widget _buildMultiFab(List<_ActiveRecording> recordings) {
    return PopupMenuButton<_ActiveRecording>(
      tooltip: tr('recordingActiveDevices', {'count': recordings.length.toString()}),
      onSelected: (r) => widget.onNavigateToSession(r.serial),
      itemBuilder: (context) => recordings.map((r) {
        return PopupMenuItem<_ActiveRecording>(
          value: r,
          child: Row(
            children: [
              const Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      r.deviceName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (r.sessionName != null)
                      Text(
                        r.sessionName!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                r.elapsedLabel,
                style: const TextStyle(
                  fontFamily: 'Menlo',
                  fontSize: 12,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: FloatingActionButton(
        heroTag: 'recording_fab_multi',
        backgroundColor: Colors.red,
        onPressed: null, // PopupMenuButton handles the tap
        child: Badge(
          label: Text('${recordings.length}'),
          child: const Icon(Icons.fiber_manual_record, color: Colors.white),
        ),
      ),
    );
  }
}
