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

import '../db/database.dart';
import '../db/dao/saved_devices_dao.dart';
import '../i18n.dart';
import '../services/api_client.dart';
import '../services/screen_record_owner.dart';
import '../providers/test_session_provider.dart';
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
    final row = _deviceRow;
    if (row?.recordingOwner != null) {
      final other = otherOwnerForRecording();
      if (other != null) {
        _showSnackBar(tr('recordInProgressOtherFmt',
            {'owner': tr(other.pageNameKey)}));
      } else {
        _showSnackBar(tr('recordingAlreadyRunning'));
      }
      return;
    }

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
      // Tag the active session (if any) so the test-session screen
      // sees us as the owner too.
      if (sessionProvider.hasRunningSession) {
        await sessionProvider.markScreenRecordStarted();
      }
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

    try {
      await savedDevicesDao.setScreenRecordSaving(s, true);
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
      try {
        await savedDevicesDao.clearScreenRecord(s);
      } catch (_) {}
      try {
        await apiClient.setShowTouches(s, false);
      } catch (_) {}
      if (!mounted) return;
      _showSnackBar('${tr('recordingStopFailed')}: $e');
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
