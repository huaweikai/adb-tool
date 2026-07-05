// Unified screen capture mixin — replaces FileBrowserCaptureMixin and
// TestSessionCaptureMixin. Configured by [captureMode]:
//
//   - fileBrowser: screenshots go to a user-chosen local file (plus
//     optionally archived to a running test session); recording stops
//     cleanly with `onVideoSaved(bytes)`.
//   - testSession: screenshots are saved directly to the active test
//     session; recording marks the session and saves video bytes into
//     the session artifact directory.
//
// State management: per-device state lives on the SavedDevices row
// (recording_owner / recording_started_at / recording_is_saving).
// The mixin subscribes to that row, mutates it through the DAO, and
// toggles Android's show_touches developer setting so the recording
// shows touch feedback. The DB is the single source of truth; navigating
// away and back (which disposes & rebuilds the State) does NOT lose
// progress.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
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
import '../services/recording_strategy.dart';
import '../services/screen_record_owner.dart';
import '../widgets/recording_settings_dialogs.dart';
import '../widgets/screenshot_watermark.dart';
import '../widgets/editor_i18n.dart';

enum CaptureMode { fileBrowser, testSession }

mixin ScreenCaptureMixin<T extends StatefulWidget> on State<T> {
  // ── Configuration ──────────────────────────────────────────────────────
  CaptureMode get captureMode;

  // ── Dependencies (must be provided by the State) ───────────────────────
  ApiClient get apiClient;
  TestSessionProvider get sessionProvider;
  SavedDevicesDao get savedDevicesDao;
  String? get serial;

  // ── State fields required from the State ───────────────────────────────
  bool get screenshotting;
  set screenshotting(bool value);

  /// True while a file transfer is in progress. Used to gate recording
  /// and screenshot actions. Only relevant for fileBrowser mode;
  /// testSession screens can ignore this.
  bool isTransferring = false;

  // ── Callbacks ──────────────────────────────────────────────────────────
  /// Called after a screenshot has been saved (either to local file or to
  /// the session, depending on [captureMode]). [path] is the local file
  /// path for fileBrowser mode, or the session relative path for
  /// testSession mode; may be null on failure.
  Future<void> onScreenshotSaved(Uint8List bytes, String? path);

  /// Called after a video recording has been saved. [path] is the local
  /// file path of the recorded video. The mixin has already handled
  /// session-side saving if in testSession mode.
  /// Only invoked when [path] is non-null.
  Future<void> onVideoSaved(String path);

  /// Called when a recording stopped cleanly but produced no usable video.
  /// Default shows a "recording too short" snackbar.
  Future<void> onVideoDiscarded() async {
    _showSnackBar(tr('recordingTooShort'));
  }

  // ── Recording state ────────────────────────────────────────────────────
  ScreenCaptureService? _captureService;
  RecordingStrategy? _strategy;
  SavedDevice? _deviceRow;
  StreamSubscription<SavedDevice?>? _deviceSub;
  Timer? _elapsedTicker;

  // ── Lifecycle hooks ────────────────────────────────────────────────────
  void initScreenRecordState() {
    if (_deviceSub != null) return;
    final s = serial;
    if (s == null) return;
    _deviceSub = savedDevicesDao.watchBySerial(s).listen(_onDeviceRow);
  }

  void disposeScreenRecordState() {
    _deviceSub?.cancel();
    _deviceSub = null;
    _stopTicker();
  }

  ScreenCaptureService _capture() =>
      _captureService ??= ScreenCaptureService(apiClient);

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

  // ── Read-side helpers ──────────────────────────────────────────────────
  SavedDevice? get currentDeviceRow => _deviceRow;

  bool isAnyOwnerRecording() => _deviceRow?.recordingOwner != null;

  bool isOtherOwnerRecording() {
    final row = _deviceRow;
    if (row?.recordingOwner == null) return false;
    return row!.recordingOwner != recordOwner.dbValue;
  }

  ScreenRecordOwner? otherOwnerForRecording() {
    final row = _deviceRow;
    if (row?.recordingOwner == null) return null;
    final owner = ScreenRecordOwnerX.fromDb(row!.recordingOwner);
    return owner == recordOwner ? null : owner;
  }

  bool get isOurRecording {
    final row = _deviceRow;
    if (row?.recordingOwner == null) return false;
    if (row!.recordingOwner != recordOwner.dbValue) return false;
    return !row.recordingIsSaving;
  }

  bool get isOurSaving {
    final row = _deviceRow;
    if (row?.recordingOwner == null) return false;
    if (row!.recordingOwner != recordOwner.dbValue) return false;
    return row.recordingIsSaving;
  }

  int get elapsedSeconds {
    final row = _deviceRow;
    final startedAtMs = row?.recordingStartedAt;
    if (startedAtMs == null) return 0;
    return DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(startedAtMs))
        .inSeconds;
  }

  ScreenRecordOwner get recordOwner => captureMode == CaptureMode.testSession
      ? ScreenRecordOwner.testSession
      : ScreenRecordOwner.fileBrowser;

  // ── Screenshot ─────────────────────────────────────────────────────────
  Future<void> takeScreenshot() async {
    final s = serial;
    if (s == null || screenshotting) return;
    if (mounted) setState(() => screenshotting = true);
    try {
      final raw = await _capture().takeScreenshotBytes(s);
      if (raw == null) {
        if (!mounted) return;
        setState(() => screenshotting = false);
        _showSnackBar(tr('screenshotFailed'));
        return;
      }
      var bytes = raw;
      if (!mounted) return;
      setState(() => screenshotting = false);

      final opts = await showWatermarkDialog(context);
      if (opts == null) return;
      if (opts.addTimestamp) {
        bytes = await addTimestampWatermark(bytes);
      }
      if (opts.stepNumber != null) {
        bytes = await addStepNumber(bytes, opts.stepNumber!);
      }
      if (!mounted) return;

      if (captureMode == CaptureMode.testSession) {
        // Test session: always save to session, optional editor
        await _saveTestSessionScreenshot(bytes, opts);
      } else {
        // File browser: local file save + optional session archive
        await _saveFileBrowserScreenshot(bytes, opts);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => screenshotting = false);
      _showSnackBar('${tr('screenshotFailed')}: $e');
    }
  }

  Future<void> _saveTestSessionScreenshot(Uint8List bytes, WatermarkOpts opts) async {
    if (!opts.skipEdit) {
      if (!mounted) return;
      final editorCtx = context;
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
  }

  Future<void> _saveFileBrowserScreenshot(Uint8List bytes, WatermarkOpts opts) async {
    String? localPath;
    if (opts.skipEdit) {
      final location = await getSaveLocation(
        suggestedName: 'screenshot-${DateTime.now().millisecondsSinceEpoch}.png',
        confirmButtonText: tr('saveScreenshot'),
      );
      if (location != null) {
        await File(location.path).writeAsBytes(bytes);
        localPath = location.path;
      }
      if (sessionProvider.hasRunningSession) {
        await sessionProvider.saveScreenshotBytes(bytes);
      }
      await onScreenshotSaved(bytes, localPath);
    } else {
      if (!mounted) return;
      final editorCtx = context;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProImageEditor.memory(
            bytes,
            configs: kImageEditorConfigs,
            callbacks: ProImageEditorCallbacks(
              onImageEditingComplete: (edited) async {
                final location = await getSaveLocation(
                  suggestedName:
                      'screenshot-${DateTime.now().millisecondsSinceEpoch}.png',
                  confirmButtonText: tr('saveScreenshot'),
                );
                if (location != null) {
                  await File(location.path).writeAsBytes(edited);
                  localPath = location.path;
                }
                if (sessionProvider.hasRunningSession) {
                  await sessionProvider.saveScreenshotBytes(edited);
                }
                await onScreenshotSaved(edited, localPath);
                if (editorCtx.mounted) {
                  Navigator.of(editorCtx).pop(edited);
                }
              },
            ),
          ),
        ),
      );
    }
  }

  // ── Recording ─────────────────────────────────────────────────────────
  Future<void> startRecording() async {
    final s = serial;
    if (s == null) return;
    final settings = context.read<RecordingSettingsProvider>();
    final recordState = context.read<ScrcpyRecordStateProvider>();
    final row = await savedDevicesDao.getBySerial(s);
    if (row?.recordingOwner != null) {
      final rowOwner = ScreenRecordOwnerX.fromDb(row!.recordingOwner!);
      if (rowOwner != null && rowOwner != recordOwner) {
        _showSnackBar(tr('recordInProgressOtherFmt',
            {'owner': tr(rowOwner.pageNameKey)}));
      } else {
        _showSnackBar(tr('recordingAlreadyRunning'));
      }
      return;
    }

    final startedAtMs = DateTime.now().millisecondsSinceEpoch;
    final strategy = RecordingStrategy.create(
      settings.method,
      serial: s,
      api: apiClient,
      capture: _capture(),
      recordState: recordState,
    );
    _strategy = strategy;

    try {
      await savedDevicesDao.setScreenRecord(
        s,
        owner: recordOwner.dbValue,
        startedAtMs: startedAtMs,
      );
      await strategy.start();
      if (captureMode == CaptureMode.testSession) {
        await sessionProvider.markScreenRecordStarted();
      }
    } on ScrcpyRecordBusyException catch (e) {
      _strategy = null;
      if (!mounted) {
        try { await savedDevicesDao.clearScreenRecord(s); } catch (_) {}
        return;
      }
      final ok = await showScrcpyBusyConfirmDialog(
        context,
        busy: e,
        activeSerial: s,
      );
      if (ok != true) {
        try { await savedDevicesDao.clearScreenRecord(s); } catch (_) {}
        return;
      }
      try {
        await savedDevicesDao.setScreenRecord(
          s,
          owner: recordOwner.dbValue,
          startedAtMs: startedAtMs,
        );
        await strategy.start(force: true);
        if (captureMode == CaptureMode.testSession) {
          await sessionProvider.markScreenRecordStarted();
        }
        _strategy = strategy;
      } catch (e2) {
        _strategy = null;
        try { await savedDevicesDao.clearScreenRecord(s); } catch (_) {}
        try { await strategy.cleanup(); } catch (_) {}
        if (!mounted) return;
        _showSnackBar('${tr('recording.startFailed')}: $e2');
        return;
      }
    } catch (e) {
      _strategy = null;
      try { await savedDevicesDao.clearScreenRecord(s); } catch (_) {}
      try { await strategy.cleanup(); } catch (_) {}
      if (!mounted) return;
      _showSnackBar('${tr('recordingFailed')}: $e');
      return;
    }
    _showSnackBar(tr('recordingStarted'));
  }

  Future<void> stopRecording() async {
    final s = serial;
    if (s == null) return;
    final row = _deviceRow;

    if (row?.recordingOwner != null &&
        row!.recordingOwner != recordOwner.dbValue) {
      final other = ScreenRecordOwnerX.fromDb(row.recordingOwner);
      if (other != null) {
        _showSnackBar(tr('recordInProgressOtherFmt',
            {'owner': tr(other.pageNameKey)}));
      }
      return;
    }

    if (row?.recordingIsSaving ?? false) return;
    if (row?.recordingOwner == null) return;

    final strategy = _strategy;
    _strategy = null;
    if (strategy == null) return;

    try {
      await savedDevicesDao.setScreenRecordSaving(s, true);
      final srcPath = await strategy.stop();
      String? savedPath;

      if (srcPath != null) {
        if (captureMode == CaptureMode.testSession) {
          savedPath = await sessionProvider.saveVideoFile(srcPath);
        } else {
          savedPath = srcPath;
        }
      }

      await savedDevicesDao.clearScreenRecord(s);
      await _syncDeviceRowFromDb();

      if (savedPath != null) {
        await onVideoSaved(savedPath);
        // Consumer has finished with the file (copied to chosen location
        // or saved to session); now safe to delete the source.
        await strategy.cleanup();
      } else {
        await strategy.cleanup();
        await onVideoDiscarded();
      }
    } catch (e) {
      try { await savedDevicesDao.clearScreenRecord(s); } catch (_) {}
      try { await _syncDeviceRowFromDb(); } catch (_) {}
      try { await strategy.cleanup(); } catch (_) {}
      if (!mounted) return;
      _showSnackBar('${tr('recordingStopFailed')}: $e');
    }
  }

  // ── Formatting ─────────────────────────────────────────────────────────
  String formatSeconds(int total) {
    final m = total ~/ 60;
    final s = total % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget buildRecordingButton() {
    final s = serial;
    final row = currentDeviceRow;

    if (row?.recordingOwner != null &&
        row!.recordingOwner != recordOwner.dbValue) {
      final other = ScreenRecordOwnerX.fromDb(row.recordingOwner);
      return FilledButton.tonal(
        onPressed: null,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(fontSize: 12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fiber_manual_record, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              other == null
                  ? tr('recordInProgressOther')
                  : tr('recordInProgressOtherFmt',
                      {'owner': tr(other.pageNameKey)}),
              style: TextStyle(
                color: Colors.grey.shade700, fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
    if (isOurSaving) {
      return FilledButton.tonal(
        onPressed: null,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(fontSize: 12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 6),
            Text(tr('recordSaving')),
          ],
        ),
      );
    }
    if (isOurRecording) {
      return FilledButton.tonal(
        onPressed: stopRecording,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(fontSize: 12),
          backgroundColor: Colors.red.shade400,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stop, size: 16, color: Colors.white),
            const SizedBox(width: 4),
            Text(formatSeconds(elapsedSeconds),
                style: const TextStyle(
                    color: Colors.white, fontFamily: 'Menlo')),
          ],
        ),
      );
    }
    return FilledButton.tonal(
      onPressed: s == null ? null : startRecording,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 12),
        backgroundColor: Colors.red.shade100,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.fiber_manual_record, size: 16, color: Colors.red),
          const SizedBox(width: 4),
          Text(tr('record'), style: const TextStyle(color: Colors.red)),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
