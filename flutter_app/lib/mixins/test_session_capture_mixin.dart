// Capture mixin for the test-session screens.
//
// Unlike FileBrowserCaptureMixin, this one NEVER pops a save-location
// dialog or a video-preview dialog — the session is the destination.
// Every screenshot and recording goes straight into the active session's
// artifact directory + DB row, via TestSessionProvider.
//
// What it still shows:
//   - Watermark dialog (timestamp + optional step number)
//   - Pro image editor (if user opts in to the watermark dialog)
//
// State machine: per-device state lives on the SavedDevices row
// (recording_owner / recording_started_at / recording_is_saving).
// The mixin subscribes to that row, mutates it through the DAO, and
// toggles Android's show_touches developer setting so the recording
// shows touch feedback. No in-memory service is required — the DB is
// the single source of truth, which means navigating away and back
// (which disposes & rebuilds the State) does NOT lose progress.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:provider/provider.dart';

import '../db/database.dart';
import '../db/dao/saved_devices_dao.dart';
import '../i18n.dart';
import '../providers/recording_settings_provider.dart';
import '../providers/scrcpy_record_state_provider.dart';
import '../providers/test_session_provider.dart';
import '../services/api_client.dart';
import '../services/screen_capture_service.dart';
import '../services/screen_record_owner.dart';
import '../widgets/editor_i18n.dart';
import '../widgets/recording_settings_dialogs.dart';
import '../widgets/screenshot_watermark.dart';

mixin TestSessionCaptureMixin<T extends StatefulWidget> on State<T> {
  // ── State fields (owned by the implementing State) ──────────────────────
  bool get screenshotting;
  set screenshotting(bool value);

  // ── Dependencies (implemented by the State) ───────────────────────────
  ApiClient get apiClient;
  TestSessionProvider get sessionProvider;
  String? get serial;
  SavedDevicesDao get savedDevicesDao;

  /// Which owner this mixin claims when starting a recording. The
  /// test-session screen uses [ScreenRecordOwner.testSession]; the
  /// file-browser mixin uses [ScreenRecordOwner.fileBrowser]. The two
  /// values are mutually exclusive on the same device.
  ScreenRecordOwner get recordOwner => ScreenRecordOwner.testSession;

  // ── DB-backed recording state (subscribed) ───────────────────────────
  /// Latest device row from the SavedDevices table, or null if the
  /// device has never been seen. UI reads this for the button's
  /// label / onPressed; the mixin mutates the row through the DAO
  /// on every state transition.
  SavedDevice? _deviceRow;
  StreamSubscription<SavedDevice?>? _deviceSub;

  /// Per-second ticker used to refresh the elapsed-seconds readout.
  /// Runs only while a recording is in flight on the active device;
  /// cancelled when no recording, when the widget disposes, or when
  /// the active serial changes.
  Timer? _elapsedTicker;

  /// Scrcpy-method path: where the MP4 was being written while the
  /// recording was in flight. Set at start, consumed at stop. Null
  /// when using adb-mode recording or when idle.
  String? _scrcpyOutputPath;

  // ── Lifecycle hooks (must be called by the State) ─────────────────────
  /// Subscribe to the active device's row. Call from `initState` after
  /// super.initState. Safe to call multiple times — only the first
  /// call wires up the subscription.
  void initScreenRecordState() {
    if (_deviceSub != null) return;
    final s = serial;
    if (s == null) return;
    _deviceSub = savedDevicesDao.watchBySerial(s).listen(_onDeviceRow);
  }

  /// Cancel the row subscription and the per-second ticker. Call from
  /// `dispose` before super.dispose.
  void disposeScreenRecordState() {
    _deviceSub?.cancel();
    _deviceSub = null;
    _stopTicker();
  }

  /// Force-refresh _deviceRow from DB and trigger setState.
  /// Safety net: call after any DB write that modifies recording state
  /// so the UI always updates even if the stream missed the notification.
  Future<void> _syncDeviceRowFromDb() async {
    final s = serial;
    if (s == null) return;
    try {
      final row = await savedDevicesDao.getSavedDeviceBySerial(s);
      if (!mounted) return;
      _onDeviceRow(row);
    } catch (_) {}
  }

  void _onDeviceRow(SavedDevice? row) {
    _deviceRow = row;
    _restartTicker();
    if (mounted) setState(() {});
  }

  void _restartTicker() {
    _stopTicker();
    if (_deviceRow?.recordingOwner != null) {
      _elapsedTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _stopTicker() {
    _elapsedTicker?.cancel();
    _elapsedTicker = null;
  }

  // ── Read-side helpers (UI / buttons) ─────────────────────────────────
  /// Latest known device row, or null. UI uses this to render the
  /// recording button's label / onPressed.
  SavedDevice? get currentDeviceRow => _deviceRow;

  /// Whether the active device is currently being recorded by
  /// SOMEONE (any owner). UI uses this to render the disabled "in
  /// progress" hint on the other owner's button.
  bool isAnyOwnerRecording() => _deviceRow?.recordingOwner != null;

  /// Whether the active device is currently being recorded by
  /// another owner (not us).
  bool isOtherOwnerRecording() {
    final row = _deviceRow;
    if (row?.recordingOwner == null) return false;
    return row!.recordingOwner != recordOwner.dbValue;
  }

  /// Owner currently holding the recording on this device, or null
  /// when nobody is. Useful for the "recording in progress (in ...)"
  /// snackbar.
  ScreenRecordOwner? otherOwnerForRecording() {
    final row = _deviceRow;
    if (row?.recordingOwner == null) return null;
    final owner = ScreenRecordOwnerX.fromDb(row!.recordingOwner);
    return owner == recordOwner ? null : owner;
  }

  /// Whether we (this mixin's surface) are the ones currently
  /// recording. Drives the red "stop" button.
  bool get isOurRecording {
    final row = _deviceRow;
    if (row?.recordingOwner == null) return false;
    if (row!.recordingOwner != recordOwner.dbValue) return false;
    return !row.recordingIsSaving;
  }

  /// Whether the recording belongs to us AND the adb side has been
  /// stopped (we are now pulling the video / writing it). Drives
  /// the "保存中..." spinner.
  bool get isOurSaving {
    final row = _deviceRow;
    if (row?.recordingOwner == null) return false;
    if (row!.recordingOwner != recordOwner.dbValue) return false;
    return row.recordingIsSaving;
  }

  /// Elapsed seconds since the recording on this device started, or
  /// 0 when nobody is recording. Reads `recording_started_at` from
  /// the row so the value is always consistent with what the DB says
  /// — no drift between the per-second tick and the start time.
  int get elapsedSeconds {
    final row = _deviceRow;
    final startedAtMs = row?.recordingStartedAt;
    if (startedAtMs == null) return 0;
    return DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(startedAtMs))
        .inSeconds;
  }

  // ── Callbacks (implemented by the State) ─────────────────────────────
  /// Called after a screenshot has been written to the session
  /// artifacts directory + DB.
  Future<void> onScreenshotSaved(Uint8List bytes, String relativePath);

  /// Called after a recording has been written to the session
  /// artifacts directory + DB. Only invoked when bytes is non-empty
  /// AND the relative path is non-empty.
  Future<void> onVideoSaved(Uint8List bytes, String relativePath);

  /// Called when a recording stopped cleanly but produced no usable
  /// video (bytes empty). Default shows a "recording too short"
  /// snackbar. Override to customise.
  Future<void> onVideoDiscarded() async {
    _showSnackBar(tr('recordingTooShort'));
  }

  // ── Service handles ───────────────────────────────────────────────────
  late final ScreenCaptureService _capture =
      ScreenCaptureService(apiClient);

  // ── Public actions ─────────────────────────────────────────────────────
  Future<void> takeScreenshot() async {
    final s = serial;
    if (s == null || screenshotting) return;
    if (mounted) setState(() => screenshotting = true);
    try {
      final raw = await _capture.takeScreenshotBytes(s);
      if (raw == null) {
        if (!mounted) return;
        setState(() => screenshotting = false);
        _showSnackBar(tr('screenshotFailed'));
        return;
      }
      var bytes = raw;
      if (!mounted) return;
      setState(() => screenshotting = false);

      // Watermark dialog (timestamp + optional step number).
      final opts = await showWatermarkDialog(context);
      if (opts == null) return;
      if (opts.addTimestamp) {
        bytes = await addTimestampWatermark(bytes);
      }
      if (opts.stepNumber != null) {
        bytes = await addStepNumber(bytes, opts.stepNumber!);
      }
      if (!mounted) return;

      if (!opts.skipEdit) {
        if (!mounted) return;
        final editorCtx = context;
        // Open the editor. Once the user saves, the bytes are
        // written to the session and the DB row is inserted by the
        // provider.
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProImageEditor.memory(
              bytes,
              configs: kImageEditorConfigs,
              callbacks: ProImageEditorCallbacks(
                onImageEditingComplete: (edited) async {
                  final rel = await sessionProvider.saveScreenshotBytes(edited);
                  if (mounted) await onScreenshotSaved(edited, rel);
                  if (editorCtx.mounted) {
                    Navigator.of(editorCtx).pop(edited);
                  }
                },
              ),
            ),
          ),
        );
      } else {
        final rel = await sessionProvider.saveScreenshotBytes(bytes);
        if (mounted) await onScreenshotSaved(bytes, rel);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => screenshotting = false);
      _showSnackBar('${tr('screenshotFailed')}: $e');
    }
  }

  Future<void> startRecording() async {
    final s = serial;
    if (s == null) return;
    // Capture the provider BEFORE the first await so we don't reach
    // for a possibly-disposed BuildContext after the DB read.
    final settings = context.read<RecordingSettingsProvider>();
    // Always read the fresh row from DB — _deviceRow may still be null if
    // the stream hasn't emitted yet after a State rebuild.
    final row = await savedDevicesDao.getBySerial(s);
    if (row?.recordingOwner != null) {
      // Already recording on this device — refuse unless we are
      // somehow stale.
      final rowOwner = ScreenRecordOwnerX.fromDb(row!.recordingOwner!);
      if (rowOwner != null && rowOwner != recordOwner) {
        _showSnackBar(tr('recordInProgressOtherFmt',
            {'owner': tr(rowOwner.pageNameKey)}));
      } else {
        _showSnackBar(tr('recordingAlreadyRunning'));
      }
      return;
    }

    if (settings.method == ScreenRecordMethod.scrcpy) {
      await _startScrcpyRecording(s, settings);
    } else {
      await _startAdbRecording(s);
    }
  }

  Future<void> _startAdbRecording(String s) async {
    final startedAtMs = DateTime.now().millisecondsSinceEpoch;
    try {
      // Stamp the device row FIRST so the other surface sees us
      // as soon as possible (the row triggers their stream).
      await savedDevicesDao.setScreenRecord(
        s,
        owner: recordOwner.dbValue,
        startedAtMs: startedAtMs,
      );
      // Best-effort: enable Android touch feedback. Failure here
      // doesn't block the recording itself.
      try {
        await apiClient.setShowTouches(s, true);
      } catch (e) {
        debugPrint('[ScreenRecord] show_touches on failed: $e');
      }
      // Actually fire the adb-side screenrecord.
      await _capture.startScreenRecord(s);
      // Session-side bookkeeping: append a "recording started"
      // event to the active session's timeline.
      if (sessionProvider.hasRunningSession) {
        await sessionProvider.markScreenRecordStarted();
      }
      _showSnackBar(tr('recordingStarted'));
    } catch (e) {
      // Failure: roll back the DB row so the device doesn't show
      // "recording in progress" forever.
      try {
        await savedDevicesDao.clearScreenRecord(s);
      } catch (_) {}
      try {
        await apiClient.setShowTouches(s, false);
      } catch (_) {}
      if (!mounted) return;
      _showSnackBar('${tr('recordingFailed')}: $e');
    }
  }

  Future<void> _startScrcpyRecording(
      String s, RecordingSettingsProvider settings) async {
    // Capture the provider BEFORE the first await so we don't reach
    // for a possibly-disposed BuildContext after the DB write. Going
    // through the provider (not the service layer directly) means the
    // mirror page's "scrcpy is busy recording" banner appears
    // synchronously instead of waiting for the next 2s poll.
    final recordState = context.read<ScrcpyRecordStateProvider>();
    final startedAtMs = DateTime.now().millisecondsSinceEpoch;
    try {
      await savedDevicesDao.setScreenRecord(
        s,
        owner: recordOwner.dbValue,
        startedAtMs: startedAtMs,
      );
      final path = await recordState.start(s);
      _scrcpyOutputPath = path.isEmpty ? null : path;
      if (sessionProvider.hasRunningSession) {
        await sessionProvider.markScreenRecordStarted();
      }
      _showSnackBar(tr('recordingStarted'));
    } on ScrcpyRecordBusyException catch (e) {
      if (!mounted) {
        _scrcpyOutputPath = null;
        try {
          await savedDevicesDao.clearScreenRecord(s);
        } catch (_) {}
        return;
      }
      final ok = await showScrcpyBusyConfirmDialog(
        context,
        busy: e,
        activeSerial: s,
      );
      if (ok != true) {
        _scrcpyOutputPath = null;
        try {
          await savedDevicesDao.clearScreenRecord(s);
        } catch (_) {}
        return;
      }
      try {
        final path = await recordState.start(s, force: true);
        _scrcpyOutputPath = path.isEmpty ? null : path;
        if (sessionProvider.hasRunningSession) {
          await sessionProvider.markScreenRecordStarted();
        }
      } catch (e2) {
        _scrcpyOutputPath = null;
        try {
          await savedDevicesDao.clearScreenRecord(s);
        } catch (_) {}
        if (!mounted) return;
        _showSnackBar('${tr('recording.startFailed')}: $e2');
        return;
      }
      if (!mounted) return;
      _showSnackBar(tr('recordingStarted'));
    } catch (e) {
      _scrcpyOutputPath = null;
      try {
        await savedDevicesDao.clearScreenRecord(s);
      } catch (_) {}
      if (!mounted) return;
      _showSnackBar('${tr('recording.startFailed')}: $e');
    }
  }

  Future<void> stopRecording() async {
    final s = serial;
    if (s == null) return;
    final row = _deviceRow;

    // Refuse if the recording doesn't belong to us.
    if (row?.recordingOwner != null &&
        row!.recordingOwner != recordOwner.dbValue) {
      final other = ScreenRecordOwnerX.fromDb(row.recordingOwner);
      if (other != null) {
        _showSnackBar(tr('recordInProgressOtherFmt',
            {'owner': tr(other.pageNameKey)}));
      }
      return;
    }

    // Already saving — second click is a no-op.
    if (row?.recordingIsSaving ?? false) {
      return;
    }

    // No active recording at all — also a no-op.
    if (row?.recordingOwner == null) {
      return;
    }

    final settings = context.read<RecordingSettingsProvider>();
    try {
      // Flip to saving BEFORE we touch the backend so the UI shows
      // the "保存中..." spinner for the duration of the stop.
      await savedDevicesDao.setScreenRecordSaving(s, true);
      if (settings.method == ScreenRecordMethod.scrcpy) {
        await _stopScrcpyRecording(s);
      } else {
        await _stopAdbRecording(s);
      }
    } catch (e) {
      try {
        await savedDevicesDao.clearScreenRecord(s);
        await _syncDeviceRowFromDb();
      } catch (_) {}
      try {
        await apiClient.setShowTouches(s, false);
      } catch (_) {}
      if (!mounted) return;
      _showSnackBar('${tr('recordingStopFailed')}: $e');
    }
  }

  Future<void> _stopAdbRecording(String s) async {
    final bytes = await _capture.stopScreenRecordAndPull(s);
    if (!mounted) {
      // Widget gone: still clean up.
      try {
        await savedDevicesDao.clearScreenRecord(s);
      } catch (_) {}
      try {
        await apiClient.setShowTouches(s, false);
      } catch (_) {}
      return;
    }
    String? rel;
    final hasUsableBytes = bytes.isNotEmpty;
    if (hasUsableBytes) {
      rel = await sessionProvider.saveVideoBytes(bytes);
    }
    await savedDevicesDao.clearScreenRecord(s);
    await _syncDeviceRowFromDb();
    try {
      await apiClient.setShowTouches(s, false);
    } catch (e) {
      debugPrint('[ScreenRecord] show_touches off failed: $e');
    }
    if (hasUsableBytes && rel != null && rel.isNotEmpty) {
      await onVideoSaved(bytes, rel);
    } else {
      await onVideoDiscarded();
    }
  }

  Future<void> _stopScrcpyRecording(String s) async {
    final path = _scrcpyOutputPath;
    try {
      await _capture.stopScrcpyRecording();
      if (!mounted) {
        _scrcpyOutputPath = null;
        try {
          await savedDevicesDao.clearScreenRecord(s);
        } catch (_) {}
        if (path != null) {
          try {
            await _capture.discardScrcpyRecording(path);
          } catch (_) {}
        }
        return;
      }
      final bytes = path != null
          ? await _capture.readScrcpyRecording(path)
          : Uint8List(0);
      _scrcpyOutputPath = null;
      String? rel;
      final hasUsableBytes = bytes.isNotEmpty;
      if (hasUsableBytes) {
        rel = await sessionProvider.saveVideoBytes(bytes);
      }
      await savedDevicesDao.clearScreenRecord(s);
      await _syncDeviceRowFromDb();
      if (hasUsableBytes && rel != null && rel.isNotEmpty) {
        await onVideoSaved(bytes, rel);
      } else {
        await onVideoDiscarded();
      }
      // Sandbox cleanup. The session has its own copy under
      // <session_dir>/<relative_path>; the file under
      // ~/.adb-tool/scrcpy_recordings is just a temp staging area
      // and is no longer needed. Best-effort: AV scanners on
      // Windows occasionally hold the handle briefly, in which
      // case the cleanup fails silently and the file gets swept
      // on the next session sweep.
      if (path != null) {
        try {
          await _capture.discardScrcpyRecording(path);
        } catch (e) {
          debugPrint('[ScreenRecord] sandbox cleanup failed: $e');
          if (mounted) {
            _showSnackBar(
              tr('recording.sandboxCleanupFailed', {'path': path}),
            );
          }
        }
      }
    } catch (e) {
      _scrcpyOutputPath = null;
      rethrow;
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
