import 'dart:async';

import 'package:drift/drift.dart';

import '../database.dart';
import '../../models/scrcpy_options.dart';
import '../tables/scrcpy_options.dart';

part 'scrcpy_options_dao.g.dart';

@DriftAccessor(tables: [ScrcpyOptions_])
class ScrcpyOptionsDao extends DatabaseAccessor<AppDatabase>
    with _$ScrcpyOptionsDaoMixin {
  ScrcpyOptionsDao(super.db);

  Stream<ScrcpyOptions?> watchBySerial(String serial) {
    return (select(scrcpyOptions)
          ..where((t) => t.serial.equals(serial))
          ..limit(1))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _fromRow(row));
  }

  Future<ScrcpyOptions?> getBySerial(String serial) async {
    final row = await (select(scrcpyOptions)
          ..where((t) => t.serial.equals(serial))
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<void> upsert(String serial, ScrcpyOptions options) {
    return into(scrcpyOptions).insertOnConflictUpdate(
      ScrcpyOptions_Companion.insert(
        serial: serial,
        maxSize: options.maxSize,
        videoBitRate: Value(options.videoBitRate),
        maxFps: options.maxFps,
        videoCodec: Value(options.videoCodec),
        videoEncoder: Value(options.videoEncoder),
        videoBuffer: options.videoBuffer,
        noMipmaps: options.noMipmaps,
        captureOrientation: Value(options.captureOrientation),
        displayOrientation: Value(options.displayOrientation),
        crop: Value(options.crop),
        angle: options.angle,
        displayId: options.displayId,
        renderFit: Value(options.renderFit),
        backgroundColor: Value(options.backgroundColor),
        minSizeAlignment: options.minSizeAlignment,
        noDownsizeOnError: options.noDownsizeOnError,
        printFps: options.printFps,
        noAudio: options.noAudio,
        noAudioPlayback: options.noAudioPlayback,
        audioSource: Value(options.audioSource),
        audioCodec: Value(options.audioCodec),
        audioEncoder: Value(options.audioEncoder),
        audioBitRate: Value(options.audioBitRate),
        audioBuffer: options.audioBuffer,
        audioOutputBuffer: options.audioOutputBuffer,
        audioDup: options.audioDup,
        requireAudio: options.requireAudio,
        videoSource: Value(options.videoSource),
        cameraId: options.cameraId,
        cameraFacing: Value(options.cameraFacing),
        cameraSize: Value(options.cameraSize),
        cameraAr: Value(options.cameraAr),
        cameraFps: options.cameraFps,
        cameraHighSpeed: options.cameraHighSpeed,
        cameraTorch: options.cameraTorch,
        cameraZoom: options.cameraZoom,
        borderless: options.borderless,
        windowTitle: Value(options.windowTitle),
        windowX: options.windowX,
        windowY: options.windowY,
        windowWidth: options.windowWidth,
        windowHeight: options.windowHeight,
        alwaysOnTop: options.alwaysOnTop,
        fullscreen: options.fullscreen,
        disableScreensaver: options.disableScreensaver,
        noWindow: options.noWindow,
        noWindowAspectRatioLock: options.noWindowAspectRatioLock,
        keyboard: Value(options.keyboard),
        mouse: Value(options.mouse),
        noControl: options.noControl,
        mouseBind: Value(options.mouseBind),
        preferText: options.preferText,
        rawKeyEvents: options.rawKeyEvents,
        noKeyRepeat: options.noKeyRepeat,
        noMouseHover: options.noMouseHover,
        legacyPaste: options.legacyPaste,
        noClipboardAutosync: options.noClipboardAutosync,
        stayAwake: options.stayAwake,
        turnScreenOff: options.turnScreenOff,
        keepActive: options.keepActive,
        showTouches: options.showTouches,
        powerOffOnClose: options.powerOffOnClose,
        noPowerOn: options.noPowerOn,
        screenOffTimeout: options.screenOffTimeout,
        shortcutMod: Value(options.shortcutMod),
        recordEnabled: options.recordEnabled,
        record: Value(options.record),
        recordFormat: Value(options.recordFormat),
        timeLimit: options.timeLimit,
        noPlayback: options.noPlayback,
        noVideoPlayback: options.noVideoPlayback,
        pauseOnExit: Value(options.pauseOnExit),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<int> deleteBySerial(String serial) {
    return (delete(scrcpyOptions)..where((t) => t.serial.equals(serial))).go();
  }

  ScrcpyOptions _fromRow(ScrcpyOptions_Data row) {
    return ScrcpyOptions(
      maxSize: row.maxSize,
      videoBitRate: row.videoBitRate,
      maxFps: row.maxFps,
      videoCodec: row.videoCodec,
      videoEncoder: row.videoEncoder,
      videoBuffer: row.videoBuffer,
      noMipmaps: row.noMipmaps,
      captureOrientation: row.captureOrientation,
      displayOrientation: row.displayOrientation,
      crop: row.crop,
      angle: row.angle,
      displayId: row.displayId,
      renderFit: row.renderFit,
      backgroundColor: row.backgroundColor,
      minSizeAlignment: row.minSizeAlignment,
      noDownsizeOnError: row.noDownsizeOnError,
      printFps: row.printFps,
      noAudio: row.noAudio,
      noAudioPlayback: row.noAudioPlayback,
      audioSource: row.audioSource,
      audioCodec: row.audioCodec,
      audioEncoder: row.audioEncoder,
      audioBitRate: row.audioBitRate,
      audioBuffer: row.audioBuffer,
      audioOutputBuffer: row.audioOutputBuffer,
      audioDup: row.audioDup,
      requireAudio: row.requireAudio,
      videoSource: row.videoSource,
      cameraId: row.cameraId,
      cameraFacing: row.cameraFacing,
      cameraSize: row.cameraSize,
      cameraAr: row.cameraAr,
      cameraFps: row.cameraFps,
      cameraHighSpeed: row.cameraHighSpeed,
      cameraTorch: row.cameraTorch,
      cameraZoom: row.cameraZoom,
      borderless: row.borderless,
      windowTitle: row.windowTitle,
      windowX: row.windowX,
      windowY: row.windowY,
      windowWidth: row.windowWidth,
      windowHeight: row.windowHeight,
      alwaysOnTop: row.alwaysOnTop,
      fullscreen: row.fullscreen,
      disableScreensaver: row.disableScreensaver,
      noWindow: row.noWindow,
      noWindowAspectRatioLock: row.noWindowAspectRatioLock,
      keyboard: row.keyboard,
      mouse: row.mouse,
      noControl: row.noControl,
      mouseBind: row.mouseBind,
      preferText: row.preferText,
      rawKeyEvents: row.rawKeyEvents,
      noKeyRepeat: row.noKeyRepeat,
      noMouseHover: row.noMouseHover,
      legacyPaste: row.legacyPaste,
      noClipboardAutosync: row.noClipboardAutosync,
      stayAwake: row.stayAwake,
      turnScreenOff: row.turnScreenOff,
      keepActive: row.keepActive,
      showTouches: row.showTouches,
      powerOffOnClose: row.powerOffOnClose,
      noPowerOn: row.noPowerOn,
      screenOffTimeout: row.screenOffTimeout,
      shortcutMod: row.shortcutMod,
      recordEnabled: row.recordEnabled,
      record: row.record,
      recordFormat: row.recordFormat,
      timeLimit: row.timeLimit,
      noPlayback: row.noPlayback,
      noVideoPlayback: row.noVideoPlayback,
      pauseOnExit: row.pauseOnExit,
    );
  }
}
