// Capture mixin used by the file-browser screen. Pops a save-location
// dialog for every screenshot (and a video-preview dialog after every
// recording), independently of any test session. If a test session is
// currently running on the same device, the screenshot is ALSO archived
// into the session — the user gets both a local copy and a session entry.
//
// For the test-session screens, see `TestSessionCaptureMixin` (in
// `lib/mixins/test_session_capture_mixin.dart`) — that one skips the
// save dialog entirely and writes straight to the session.
//
// State management: per-device state lives on the SavedDevices row
// (recording_owner / recording_started_at / recording_is_saving). The
// mixin subscribes to that row, mutates it through the DAO, and
// toggles Android's show_touches developer setting so the recording
// shows touch feedback. No in-memory service is required — the DB is
// the single source of truth, which means navigating away and back
// (which disposes & rebuilds the State) does NOT lose progress.
//
// Recording method (v10+): the mixin branches on
// `RecordingSettingsProvider.method` — adb (legacy `adb screenrecord`)
// or scrcpy (windowless `scrcpy --no-window --record=…`). The DB row
// and the per-second elapsed ticker are method-agnostic; only the
// start/stop and the "where does the file come from" bits differ.
//
// Required state members:
// - `ApiClient get apiClient`
// - `TestSessionProvider get sessionProvider`
// - `SavedDevicesDao get savedDevicesDao`
// - `String? get serial`
// - `Future<void> onScreenshotSaved(Uint8List bytes, String? localPath)`
// - `Future<void> onVideoSaved(Uint8List bytes)`
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:provider/provider.dart';

import '../db/database.dart';
import '../db/dao/saved_devices_dao.dart';
import '../i18n.dart';
import '../services/api_client.dart';
import '../services/screen_capture_service.dart';
import '../services/screen_record_owner.dart';
import '../providers/recording_settings_provider.dart';
import '../providers/test_session_provider.dart';
import '../widgets/recording_settings_dialogs.dart';
import '../widgets/screenshot_watermark.dart';
import '../widgets/editor_i18n.dart';

mixin FileBrowserCaptureMixin<T extends StatefulWidget> on State<T> {
  // ── State fields (owned by the implementing State) ──────────────────────
  bool get screenshotting;
  set screenshotting(bool value);

  // 传输状态，State 设置 isTransferring 来启用/禁用传输锁
  bool isTransferring = false;

  // ── 依赖获取（由提供方实现）────────────────────────────────────
  ApiClient get apiClient;
  TestSessionProvider get sessionProvider;
  SavedDevicesDao get savedDevicesDao;
  String? get serial;

  // ── DB-backed recording state (subscribed) ───────────────────────────
  SavedDevice? _deviceRow;
  StreamSubscription<SavedDevice?>? _deviceSub;
  Timer? _elapsedTicker;

  // Scrcpy-mode state: the path the recording is being written to
  // (set at start, consumed at stop). Null in adb mode or while
  // idle. We keep it in-memory because the file is on the host
  // filesystem and there's no DB row to query for it.
  String? _scrcpyOutputPath;

  // Service handle — same pattern as TestSessionCaptureMixin. The
  // service is stateless so a single late-final instance is enough.
  late final ScreenCaptureService _capture =
      ScreenCaptureService(apiClient);

  // ── Lifecycle hooks ─────────────────────────────────────────────────
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

  // ── 回调（由提供方实现）────────────────────────────────────────
  /// 截图/录屏保存完成时回调，bytes 是图片/视频原始数据。
  /// 可选地返回保存的本地路径。
  Future<void> onScreenshotSaved(Uint8List bytes, String? localPath);

  /// Called after a recording has been pulled from the device AND
  /// the bytes look usable. Only invoked when `bytes.isNotEmpty`.
  Future<void> onVideoSaved(Uint8List bytes);

  /// Called when a recording stopped cleanly but produced no usable
  /// video (bytes empty). Default shows a "recording too short"
  /// snackbar. Override to customise.
  Future<void> onVideoDiscarded() async {
    _showSnackBar(tr('recordingTooShort'));
  }

  // ── Owner identity ─────────────────────────────────────────────
  ScreenRecordOwner get recordOwner => ScreenRecordOwner.fileBrowser;

  // ── Read-side helpers ─────────────────────────────────────────
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

  // ── 公开操作方法（由提供方 expose 给 UI）────────────────────────
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
      final rowOwner = ScreenRecordOwnerX.fromDb(row!.recordingOwner!);
      if (rowOwner != null && rowOwner != recordOwner) {
        _showSnackBar(tr('recordInProgressOtherFmt',
            {'owner': tr(rowOwner.pageNameKey)}));
      } else {
        _showSnackBar(tr('recordingAlreadyRunning'));
      }
      return;
    }

    // Branch on the user's chosen recording method. Both paths stamp
    // the device row FIRST (so the other surface sees us immediately
    // via the DB stream) and share the same error-rollback contract.
    if (settings.method == ScreenRecordMethod.scrcpy) {
      await _startScrcpyRecording(s, settings);
    } else {
      await _startAdbRecording(s);
    }
  }

  /// ADB-method path (legacy `adb screenrecord`). Kept as its own
  /// private method so the new scrcpy path is a clear sibling rather
  /// than an inline if/else inside startRecording.
  Future<void> _startAdbRecording(String s) async {
    final startedAtMs = DateTime.now().millisecondsSinceEpoch;
    try {
      // Stamp the device row FIRST.
      await savedDevicesDao.setScreenRecord(
        s,
        owner: recordOwner.dbValue,
        startedAtMs: startedAtMs,
      );
      try {
        await apiClient.setShowTouches(s, true);
      } catch (e) {
        debugPrint('[ScreenRecord] show_touches on failed: $e');
      }
      await apiClient.screenRecordAction(s, 'start');
      // NOTE: we do NOT call sessionProvider.markScreenRecordStarted() here.
      // Only the test-session mixin (which actually owns the session's
      // video artifacts) should insert a "开始录屏" event into the session
      // timeline. A recording started from the file browser is a
      // standalone action — it has nothing to do with the session.
      _showSnackBar(tr('recordingStarted'));
    } catch (e) {
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

  /// Scrcpy-method path. Validates that the user has picked an output
  /// directory, then runs the conflict-confirm flow (mirror in flight
  /// → dialog) before starting. The recording subprocess writes the
  /// MP4 directly to host disk; we just remember the path so the
  /// stop path can read it back.
  Future<void> _startScrcpyRecording(
      String s, RecordingSettingsProvider settings) async {
    if (!settings.scrcpyConfigured) {
      _showSnackBar(tr('screenRecord.scrcpyRequiresDir'));
      return;
    }

    final dir = settings.outputDir!;
    final filename =
        'adb-tool-record_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final outputPath = '$dir${Platform.pathSeparator}$filename';
    _scrcpyOutputPath = outputPath;

    final startedAtMs = DateTime.now().millisecondsSinceEpoch;
    try {
      // Stamp the device row first so the FAB / other surface sees
      // us mid-start (the scrcpy spawn is a few hundred ms).
      await savedDevicesDao.setScreenRecord(
        s,
        owner: recordOwner.dbValue,
        startedAtMs: startedAtMs,
      );
      await _capture.startScrcpyRecording(s, outputPath);
      _showSnackBar(tr('recordingStarted'));
    } on ScrcpyRecordBusyException catch (e) {
      // Mirror-busy → offer to preempt. Record-busy → dismiss-only
      // dialog (force can't help: the backend won't preempt another
      // recording either way).
      if (!mounted) {
        _scrcpyOutputPath = null;
        try {
          await savedDevicesDao.clearScreenRecord(s);
        } catch (_) {}
        return;
      }
      final ok = await showScrcpyBusyConfirmDialog(context, busy: e);
      if (ok != true) {
        _scrcpyOutputPath = null;
        try {
          await savedDevicesDao.clearScreenRecord(s);
        } catch (_) {}
        return;
      }
      try {
        await _capture.startScrcpyRecording(s, outputPath, force: true);
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

    if (row?.recordingOwner != null &&
        row!.recordingOwner != recordOwner.dbValue) {
      final other = ScreenRecordOwnerX.fromDb(row.recordingOwner);
      if (other != null) {
        _showSnackBar(tr('recordInProgressOtherFmt',
            {'owner': tr(other.pageNameKey)}));
      }
      return;
    }

    if (row?.recordingIsSaving ?? false) {
      return;
    }

    if (row?.recordingOwner == null) {
      return;
    }

    // Same DB-stamp-first contract as start: flip to saving so the
    // UI shows the spinner, then do the actual stop. Both adb and
    // scrcpy paths clear the DB row before invoking onVideoSaved so
    // the cross-page FAB updates immediately.
    final settings = context.read<RecordingSettingsProvider>();
    try {
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

  /// ADB-method stop: SIGINT the on-device screenrecord, pull the
  /// resulting MP4, hand the bytes to onVideoSaved.
  Future<void> _stopAdbRecording(String s) async {
    try {
      await apiClient.screenRecordAction(s, 'stop');
      if (!mounted) {
        try {
          await savedDevicesDao.clearScreenRecord(s);
        } catch (_) {}
        try {
          await apiClient.setShowTouches(s, false);
        } catch (_) {}
        return;
      }
      final bytes =
          Uint8List.fromList(await apiClient.pullRecordedVideo(s));
      await savedDevicesDao.clearScreenRecord(s);
      await _syncDeviceRowFromDb();
      try {
        await apiClient.setShowTouches(s, false);
      } catch (e) {
        debugPrint('[ScreenRecord] show_touches off failed: $e');
      }
      if (bytes.isNotEmpty) {
        await onVideoSaved(bytes);
      } else {
        await onVideoDiscarded();
      }
    } catch (e) {
      // Re-throw so the outer stopRecording catch cleans up DB.
      rethrow;
    }
  }

  /// Scrcpy-method stop: graceful kill the subprocess (scrcpy
  /// finalizes the MP4 muxer), then read the file off disk. Same
  /// bytes-to-onVideoSaved contract as the adb path so the host
  /// screen's save logic is method-agnostic.
  Future<void> _stopScrcpyRecording(String s) async {
    final path = _scrcpyOutputPath;
    try {
      await _capture.stopScrcpyRecording();
      if (!mounted) {
        _scrcpyOutputPath = null;
        try {
          await savedDevicesDao.clearScreenRecord(s);
        } catch (_) {}
        return;
      }
      final bytes = path != null
          ? await _capture.readScrcpyRecording(path)
          : Uint8List(0);
      _scrcpyOutputPath = null;
      await savedDevicesDao.clearScreenRecord(s);
      await _syncDeviceRowFromDb();
      if (bytes.isNotEmpty) {
        await onVideoSaved(bytes);
      } else {
        await onVideoDiscarded();
      }
    } catch (e) {
      _scrcpyOutputPath = null;
      rethrow;
    }
  }

  Future<void> takeScreenshot() async {
    final s = serial;
    if (s == null || screenshotting) return;
    if (mounted) setState(() => screenshotting = true);
    try {
      final b64 = await apiClient.takeScreenshot(s);
      if (b64 == null) {
        if (!mounted) return;
        setState(() => screenshotting = false);
        _showSnackBar(tr('screenshotFailed'));
        return;
      }
      if (!mounted) return;
      setState(() => screenshotting = false);
      var bytes = base64Decode(b64);
      if (!mounted) return;

      // 水印选项
      final opts = await showWatermarkDialog(context);
      if (opts == null) return;
      if (opts.addTimestamp) {
        bytes = await addTimestampWatermark(bytes);
      }
      if (opts.stepNumber != null) {
        bytes = await addStepNumber(bytes, opts.stepNumber!);
      }

      if (!mounted) return;

      // 保存路径
      String? localPath;
      if (opts.skipEdit) {
        if (sessionProvider.hasRunningSession) {
          await sessionProvider.saveScreenshotBytes(bytes);
        }
        final location = await getSaveLocation(
          suggestedName: 'screenshot-${DateTime.now().millisecondsSinceEpoch}.png',
          confirmButtonText: tr('saveScreenshot'),
        );
        if (location != null) {
          await File(location.path).writeAsBytes(bytes);
          localPath = location.path;
        }
        await onScreenshotSaved(bytes, localPath);
      } else {
        if (!mounted) return;
        // Capture the outer context so we can pop the editor route
        // ourselves after the async callback completes — ProImageEditor
        // 9.x does not auto-pop once the callback goes async.
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
    } catch (e) {
      if (!mounted) return;
      setState(() => screenshotting = false);
      _showSnackBar('${tr('screenshotFailed')}: $e');
    }
  }

  String formatSeconds(int total) {
    final m = total ~/ 60;
    final s = total % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Recording button with five visual states. All state comes from
  /// the active device's SavedDevices row (no local State fields, so
  /// navigating away and back doesn't tear the UI down):
  ///
  ///   1. another owner is recording  → disabled, "录屏中(在{owner})"
  ///   2. we are saving (pulling)     → disabled, "保存中..." + spinner
  ///   3. we are recording            → red stop button with timer
  ///   4. we are not recording        → red-100 tonal, "录屏"
  Widget buildRecordingButton() {
    final s = serial;
    final row = currentDeviceRow;

    // ── 1. Another surface is recording — read-only hint ───────
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
            const Icon(Icons.fiber_manual_record,
                size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              other == null
                  ? tr('recordInProgressOther')
                  : tr('recordInProgressOtherFmt',
                      {'owner': tr(other.pageNameKey)}),
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
    // ── 2. We are saving (pulling) — spinner + "保存中..." ─────
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
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 6),
            Text(tr('recordSaving')),
          ],
        ),
      );
    }
    // ── 3. We are recording — red stop button with timer ───────
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
    // ── 4. Idle — start button ────────────────────────────────
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
