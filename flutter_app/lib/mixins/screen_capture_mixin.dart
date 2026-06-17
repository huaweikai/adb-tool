import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import '../i18n.dart';
import '../services/api_client.dart';
import '../providers/test_session_provider.dart';
import '../widgets/screenshot_watermark.dart';
import '../widgets/editor_i18n.dart';

/// 截图 / 录屏能力的 mixin，供 FileBrowserScreen 和 TestSessionScreen 共用。
///
/// 提供方 State 需要实现：
/// - `ApiClient get apiClient`
/// - `TestSessionProvider get sessionProvider`
/// - `String? get serial`
/// - `Future<void> onScreenshotSaved(Uint8List bytes, String? localPath)>`
/// - `Future<void> onVideoSaved(Uint8List bytes)>`
mixin ScreenCaptureMixin<T extends StatefulWidget> on State<T> {
  // ── 状态字段（由提供方以 late 或直接字段形式持有）───────────────
  bool get recording;
  set recording(bool value);
  bool get recordSaving;
  set recordSaving(bool value);
  int get recordSeconds;
  set recordSeconds(int value);
  bool get screenshotting;
  set screenshotting(bool value);
  Timer? get recordTimer;
  set recordTimer(Timer? value);

  // 传输状态，State 设置 isTransferring 来启用/禁用传输锁
  bool isTransferring = false;

  // ── 依赖获取（由提供方实现）────────────────────────────────────
  ApiClient get apiClient;
  TestSessionProvider get sessionProvider;
  String? get serial;

  // ── 回调（由提供方实现）────────────────────────────────────────
  /// 截图/录屏保存完成时回调，bytes 是图片/视频原始数据。
  /// 可选地返回保存的本地路径。
  Future<void> onScreenshotSaved(Uint8List bytes, String? localPath);
  Future<void> onVideoSaved(Uint8List bytes);

  // ── 公开操作方法（由提供方 expose 给 UI）────────────────────────
  Future<void> startRecording() async {
    final s = serial;
    if (s == null || recording || recordSaving) return;
    try {
      await apiClient.screenRecordAction(s, 'start');
      if (sessionProvider.hasRunningSession) {
        await sessionProvider.markScreenRecordStarted();
      }
      if (!mounted) return;
      recording = true;
      recordSaving = false;
      recordSeconds = 0;
      recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) recordSeconds++;
      });
      _showSnackBar(tr('recordingStarted'));
    } catch (e) {
      _showSnackBar('${tr('recordingFailed')}: $e');
    }
  }

  Future<void> stopRecording() async {
    final s = serial;
    if (s == null || recordSaving || !recording) return;
    recordTimer?.cancel();
    recordSaving = true;
    try {
      await apiClient.screenRecordAction(s, 'stop');
      if (!mounted) return;
      final bytes = Uint8List.fromList(await apiClient.pullRecordedVideo(s));
      if (!mounted) return;
      recording = false;
      recordSaving = false;
      recordSeconds = 0;
      await onVideoSaved(bytes);
    } catch (e) {
      if (!mounted) return;
      recording = false;
      recordSaving = false;
      recordSeconds = 0;
      _showSnackBar('${tr('recordingStopFailed')}: $e');
    }
  }

  Future<void> takeScreenshot() async {
    final s = serial;
    if (s == null || screenshotting) return;
    screenshotting = true;
    try {
      final b64 = await apiClient.takeScreenshot(s);
      if (b64 == null) {
        if (!mounted) return;
        screenshotting = false;
        _showSnackBar(tr('screenshotFailed'));
        return;
      }
      if (!mounted) return;
      screenshotting = false;
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
      screenshotting = false;
      _showSnackBar('${tr('screenshotFailed')}: $e');
    }
  }

  String formatSeconds(int total) {
    final m = total ~/ 60;
    final s = total % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget buildRecordingButton() {
    if (recordSaving) {
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
            Text(tr('saving')),
          ],
        ),
      );
    }
    if (recording) {
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
            Text(formatSeconds(recordSeconds),
                style: const TextStyle(color: Colors.white, fontFamily: 'Menlo')),
          ],
        ),
      );
    }
    return FilledButton.tonal(
      onPressed: serial == null ? null : startRecording,
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
