// Dart mirror of backend `ScrcpyOptions` (see
// backend/internal/server/scrcpy_options.go).
//
// Field names match the JSON tags on the Go side, so jsonEncode/decode
// works without any custom converters. The defaults match the Go
// DefaultScrcpyOptions() — kept in sync by convention; if you change
// one side, change the other.
//
// Scrcpy 4.0 option reference:
//   doc/video.md    doc/audio.md    doc/window.md
//   doc/control.md  doc/camera.md   doc/recording.md
class ScrcpyOptions {
  // ── Video ───────────────────────────────────────────────────────
  final int maxSize; // --max-size=N, 0 = unlimited
  final String? videoBitRate; // --video-bit-rate=8M
  final int maxFps; // --max-fps=N, 0 = unlimited
  final String? videoCodec; // h264|h265|av1
  final String? videoEncoder;
  final int videoBuffer; // ms
  final bool noMipmaps;
  final String? captureOrientation; // 0|90|180|270|flip...
  final String? displayOrientation;
  final String? crop; // 1224:1440:0:0
  final int angle;
  final int displayId;
  final String? renderFit; // letterbox|stretched|unscaled
  final String? backgroundColor;
  final int minSizeAlignment; // 1|2|4|8|16
  final bool noDownsizeOnError;
  final bool printFps;

  // ── Audio ───────────────────────────────────────────────────────
  final bool noAudio;
  final bool noAudioPlayback;
  final String? audioSource; // output|mic|mic-camcorder|...
  final String? audioCodec; // opus|aac|flac|raw
  final String? audioEncoder;
  final String? audioBitRate;
  final int audioBuffer; // ms
  final int audioOutputBuffer; // ms
  final bool audioDup; // Android 13+
  final bool requireAudio;

  // ── Camera ──────────────────────────────────────────────────────
  final String? videoSource; // display|camera
  final int cameraId;
  final String? cameraFacing; // front|back|external|any
  final String? cameraSize; // 1920x1080
  final String? cameraAr; // 4:3|1.6|sensor
  final int cameraFps;
  final bool cameraHighSpeed;
  final bool cameraTorch;
  final double cameraZoom; // 1.0 = no zoom

  // ── Window ──────────────────────────────────────────────────────
  final bool borderless;
  final String? windowTitle;
  final int windowX;
  final int windowY;
  final int windowWidth;
  final int windowHeight;
  final bool alwaysOnTop;
  final bool fullscreen;
  final bool disableScreensaver;
  final bool noWindow;
  final bool noWindowAspectRatioLock;

  // ── Control ─────────────────────────────────────────────────────
  final String? keyboard; // sdk|uhid|aoa|disabled
  final String? mouse; // sdk|uhid|aoa|disabled
  final bool noControl;
  final String? mouseBind; // xxxx[:xxxx]
  final bool preferText;
  final bool rawKeyEvents;
  final bool noKeyRepeat;
  final bool noMouseHover;
  final bool legacyPaste;
  final bool noClipboardAutosync;

  // ── Device ──────────────────────────────────────────────────────
  final bool stayAwake;
  final bool turnScreenOff;
  final bool keepActive;
  final bool showTouches;
  final bool powerOffOnClose;
  final bool noPowerOn;
  final int screenOffTimeout; // seconds
  final String? shortcutMod;

  // ── Recording ───────────────────────────────────────────────────
  final String? record; // absolute path
  final String? recordFormat; // mp4|mkv|opus|flac|wav|...
  final int timeLimit; // seconds
  final bool noPlayback;
  final bool noVideoPlayback;
  final String? pauseOnExit; // true|false|if-error

  const ScrcpyOptions({
    this.maxSize = 0,
    this.videoBitRate,
    this.maxFps = 0,
    this.videoCodec,
    this.videoEncoder,
    this.videoBuffer = 0,
    this.noMipmaps = false,
    this.captureOrientation,
    this.displayOrientation,
    this.crop,
    this.angle = 0,
    this.displayId = 0,
    this.renderFit,
    this.backgroundColor,
    this.minSizeAlignment = 0,
    this.noDownsizeOnError = false,
    this.printFps = false,
    this.noAudio = false,
    this.noAudioPlayback = false,
    this.audioSource,
    this.audioCodec,
    this.audioEncoder,
    this.audioBitRate,
    this.audioBuffer = 0,
    this.audioOutputBuffer = 0,
    this.audioDup = false,
    this.requireAudio = false,
    this.videoSource,
    this.cameraId = 0,
    this.cameraFacing,
    this.cameraSize,
    this.cameraAr,
    this.cameraFps = 0,
    this.cameraHighSpeed = false,
    this.cameraTorch = false,
    this.cameraZoom = 0,
    this.borderless = false,
    this.windowTitle,
    this.windowX = 0,
    this.windowY = 0,
    this.windowWidth = 0,
    this.windowHeight = 0,
    this.alwaysOnTop = false,
    this.fullscreen = false,
    this.disableScreensaver = false,
    this.noWindow = false,
    this.noWindowAspectRatioLock = false,
    this.keyboard,
    this.mouse,
    this.noControl = false,
    this.mouseBind,
    this.preferText = false,
    this.rawKeyEvents = false,
    this.noKeyRepeat = false,
    this.noMouseHover = false,
    this.legacyPaste = false,
    this.noClipboardAutosync = false,
    this.stayAwake = false,
    this.turnScreenOff = false,
    this.keepActive = false,
    this.showTouches = false,
    this.powerOffOnClose = false,
    this.noPowerOn = false,
    this.screenOffTimeout = 0,
    this.shortcutMod,
    this.record,
    this.recordFormat,
    this.timeLimit = 0,
    this.noPlayback = false,
    this.noVideoPlayback = false,
    this.pauseOnExit,
  });

  /// Conservative defaults — match the Go DefaultScrcpyOptions(). Use
  /// this when the user hasn't customized anything yet.
  factory ScrcpyOptions.defaults() => const ScrcpyOptions(
        maxSize: 1024,
        videoBitRate: '8M',
        videoCodec: 'h264',
        videoSource: 'display',
        audioSource: 'output',
        audioCodec: 'opus',
        audioBitRate: '128K',
        renderFit: 'letterbox',
        keyboard: 'sdk',
        mouse: 'sdk',
        stayAwake: true,
        borderless: true,
      );

  /// True if every field is at its zero value (the "no settings yet"
  /// case). Backend treats this the same as defaults.
  bool get isEmpty =>
      maxSize == 0 &&
      (videoBitRate == null || videoBitRate!.isEmpty) &&
      maxFps == 0 &&
      (videoCodec == null || videoCodec!.isEmpty) &&
      noAudio == false &&
      borderless == false &&
      (keyboard == null || keyboard!.isEmpty) &&
      (mouse == null || mouse!.isEmpty) &&
      stayAwake == false &&
      (videoSource == null || videoSource!.isEmpty) &&
      (record == null || record!.isEmpty);

  ScrcpyOptions copyWith({
    int? maxSize,
    String? videoBitRate,
    int? maxFps,
    String? videoCodec,
    String? videoEncoder,
    int? videoBuffer,
    bool? noMipmaps,
    String? captureOrientation,
    String? displayOrientation,
    String? crop,
    int? angle,
    int? displayId,
    String? renderFit,
    String? backgroundColor,
    int? minSizeAlignment,
    bool? noDownsizeOnError,
    bool? printFps,
    bool? noAudio,
    bool? noAudioPlayback,
    String? audioSource,
    String? audioCodec,
    String? audioEncoder,
    String? audioBitRate,
    int? audioBuffer,
    int? audioOutputBuffer,
    bool? audioDup,
    bool? requireAudio,
    String? videoSource,
    int? cameraId,
    String? cameraFacing,
    String? cameraSize,
    String? cameraAr,
    int? cameraFps,
    bool? cameraHighSpeed,
    bool? cameraTorch,
    double? cameraZoom,
    bool? borderless,
    String? windowTitle,
    int? windowX,
    int? windowY,
    int? windowWidth,
    int? windowHeight,
    bool? alwaysOnTop,
    bool? fullscreen,
    bool? disableScreensaver,
    bool? noWindow,
    bool? noWindowAspectRatioLock,
    String? keyboard,
    String? mouse,
    bool? noControl,
    String? mouseBind,
    bool? preferText,
    bool? rawKeyEvents,
    bool? noKeyRepeat,
    bool? noMouseHover,
    bool? legacyPaste,
    bool? noClipboardAutosync,
    bool? stayAwake,
    bool? turnScreenOff,
    bool? keepActive,
    bool? showTouches,
    bool? powerOffOnClose,
    bool? noPowerOn,
    int? screenOffTimeout,
    String? shortcutMod,
    String? record,
    String? recordFormat,
    int? timeLimit,
    bool? noPlayback,
    bool? noVideoPlayback,
    String? pauseOnExit,
  }) {
    return ScrcpyOptions(
      maxSize: maxSize ?? this.maxSize,
      videoBitRate: videoBitRate ?? this.videoBitRate,
      maxFps: maxFps ?? this.maxFps,
      videoCodec: videoCodec ?? this.videoCodec,
      videoEncoder: videoEncoder ?? this.videoEncoder,
      videoBuffer: videoBuffer ?? this.videoBuffer,
      noMipmaps: noMipmaps ?? this.noMipmaps,
      captureOrientation: captureOrientation ?? this.captureOrientation,
      displayOrientation: displayOrientation ?? this.displayOrientation,
      crop: crop ?? this.crop,
      angle: angle ?? this.angle,
      displayId: displayId ?? this.displayId,
      renderFit: renderFit ?? this.renderFit,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      minSizeAlignment: minSizeAlignment ?? this.minSizeAlignment,
      noDownsizeOnError: noDownsizeOnError ?? this.noDownsizeOnError,
      printFps: printFps ?? this.printFps,
      noAudio: noAudio ?? this.noAudio,
      noAudioPlayback: noAudioPlayback ?? this.noAudioPlayback,
      audioSource: audioSource ?? this.audioSource,
      audioCodec: audioCodec ?? this.audioCodec,
      audioEncoder: audioEncoder ?? this.audioEncoder,
      audioBitRate: audioBitRate ?? this.audioBitRate,
      audioBuffer: audioBuffer ?? this.audioBuffer,
      audioOutputBuffer: audioOutputBuffer ?? this.audioOutputBuffer,
      audioDup: audioDup ?? this.audioDup,
      requireAudio: requireAudio ?? this.requireAudio,
      videoSource: videoSource ?? this.videoSource,
      cameraId: cameraId ?? this.cameraId,
      cameraFacing: cameraFacing ?? this.cameraFacing,
      cameraSize: cameraSize ?? this.cameraSize,
      cameraAr: cameraAr ?? this.cameraAr,
      cameraFps: cameraFps ?? this.cameraFps,
      cameraHighSpeed: cameraHighSpeed ?? this.cameraHighSpeed,
      cameraTorch: cameraTorch ?? this.cameraTorch,
      cameraZoom: cameraZoom ?? this.cameraZoom,
      borderless: borderless ?? this.borderless,
      windowTitle: windowTitle ?? this.windowTitle,
      windowX: windowX ?? this.windowX,
      windowY: windowY ?? this.windowY,
      windowWidth: windowWidth ?? this.windowWidth,
      windowHeight: windowHeight ?? this.windowHeight,
      alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
      fullscreen: fullscreen ?? this.fullscreen,
      disableScreensaver: disableScreensaver ?? this.disableScreensaver,
      noWindow: noWindow ?? this.noWindow,
      noWindowAspectRatioLock:
          noWindowAspectRatioLock ?? this.noWindowAspectRatioLock,
      keyboard: keyboard ?? this.keyboard,
      mouse: mouse ?? this.mouse,
      noControl: noControl ?? this.noControl,
      mouseBind: mouseBind ?? this.mouseBind,
      preferText: preferText ?? this.preferText,
      rawKeyEvents: rawKeyEvents ?? this.rawKeyEvents,
      noKeyRepeat: noKeyRepeat ?? this.noKeyRepeat,
      noMouseHover: noMouseHover ?? this.noMouseHover,
      legacyPaste: legacyPaste ?? this.legacyPaste,
      noClipboardAutosync: noClipboardAutosync ?? this.noClipboardAutosync,
      stayAwake: stayAwake ?? this.stayAwake,
      turnScreenOff: turnScreenOff ?? this.turnScreenOff,
      keepActive: keepActive ?? this.keepActive,
      showTouches: showTouches ?? this.showTouches,
      powerOffOnClose: powerOffOnClose ?? this.powerOffOnClose,
      noPowerOn: noPowerOn ?? this.noPowerOn,
      screenOffTimeout: screenOffTimeout ?? this.screenOffTimeout,
      shortcutMod: shortcutMod ?? this.shortcutMod,
      record: record ?? this.record,
      recordFormat: recordFormat ?? this.recordFormat,
      timeLimit: timeLimit ?? this.timeLimit,
      noPlayback: noPlayback ?? this.noPlayback,
      noVideoPlayback: noVideoPlayback ?? this.noVideoPlayback,
      pauseOnExit: pauseOnExit ?? this.pauseOnExit,
    );
  }

  Map<String, dynamic> toJson() => {
        'max_size': maxSize,
        'video_bit_rate': videoBitRate,
        'max_fps': maxFps,
        'video_codec': videoCodec,
        'video_encoder': videoEncoder,
        'video_buffer': videoBuffer,
        'no_mipmaps': noMipmaps,
        'capture_orientation': captureOrientation,
        'display_orientation': displayOrientation,
        'crop': crop,
        'angle': angle,
        'display_id': displayId,
        'render_fit': renderFit,
        'background_color': backgroundColor,
        'min_size_alignment': minSizeAlignment,
        'no_downsize_on_error': noDownsizeOnError,
        'print_fps': printFps,
        'no_audio': noAudio,
        'no_audio_playback': noAudioPlayback,
        'audio_source': audioSource,
        'audio_codec': audioCodec,
        'audio_encoder': audioEncoder,
        'audio_bit_rate': audioBitRate,
        'audio_buffer': audioBuffer,
        'audio_output_buffer': audioOutputBuffer,
        'audio_dup': audioDup,
        'require_audio': requireAudio,
        'video_source': videoSource,
        'camera_id': cameraId,
        'camera_facing': cameraFacing,
        'camera_size': cameraSize,
        'camera_ar': cameraAr,
        'camera_fps': cameraFps,
        'camera_high_speed': cameraHighSpeed,
        'camera_torch': cameraTorch,
        'camera_zoom': cameraZoom,
        'borderless': borderless,
        'window_title': windowTitle,
        'window_x': windowX,
        'window_y': windowY,
        'window_width': windowWidth,
        'window_height': windowHeight,
        'always_on_top': alwaysOnTop,
        'fullscreen': fullscreen,
        'disable_screensaver': disableScreensaver,
        'no_window': noWindow,
        'no_window_aspect_ratio_lock': noWindowAspectRatioLock,
        'keyboard': keyboard,
        'mouse': mouse,
        'no_control': noControl,
        'mouse_bind': mouseBind,
        'prefer_text': preferText,
        'raw_key_events': rawKeyEvents,
        'no_key_repeat': noKeyRepeat,
        'no_mouse_hover': noMouseHover,
        'legacy_paste': legacyPaste,
        'no_clipboard_autosync': noClipboardAutosync,
        'stay_awake': stayAwake,
        'turn_screen_off': turnScreenOff,
        'keep_active': keepActive,
        'show_touches': showTouches,
        'power_off_on_close': powerOffOnClose,
        'no_power_on': noPowerOn,
        'screen_off_timeout': screenOffTimeout,
        'shortcut_mod': shortcutMod,
        'record': record,
        'record_format': recordFormat,
        'time_limit': timeLimit,
        'no_playback': noPlayback,
        'no_video_playback': noVideoPlayback,
        'pause_on_exit': pauseOnExit,
      };

  /// Wraps this options in the {"scrcpy_options": {...}} envelope the
  /// backend expects.
  Map<String, dynamic> toApiJson() => {'scrcpy_options': toJson()};

  factory ScrcpyOptions.fromJson(Map<String, dynamic> j) => ScrcpyOptions(
        maxSize: (j['max_size'] as num?)?.toInt() ?? 0,
        videoBitRate: j['video_bit_rate'] as String?,
        maxFps: (j['max_fps'] as num?)?.toInt() ?? 0,
        videoCodec: j['video_codec'] as String?,
        videoEncoder: j['video_encoder'] as String?,
        videoBuffer: (j['video_buffer'] as num?)?.toInt() ?? 0,
        noMipmaps: j['no_mipmaps'] == true,
        captureOrientation: j['capture_orientation'] as String?,
        displayOrientation: j['display_orientation'] as String?,
        crop: j['crop'] as String?,
        angle: (j['angle'] as num?)?.toInt() ?? 0,
        displayId: (j['display_id'] as num?)?.toInt() ?? 0,
        renderFit: j['render_fit'] as String?,
        backgroundColor: j['background_color'] as String?,
        minSizeAlignment: (j['min_size_alignment'] as num?)?.toInt() ?? 0,
        noDownsizeOnError: j['no_downsize_on_error'] == true,
        printFps: j['print_fps'] == true,
        noAudio: j['no_audio'] == true,
        noAudioPlayback: j['no_audio_playback'] == true,
        audioSource: j['audio_source'] as String?,
        audioCodec: j['audio_codec'] as String?,
        audioEncoder: j['audio_encoder'] as String?,
        audioBitRate: j['audio_bit_rate'] as String?,
        audioBuffer: (j['audio_buffer'] as num?)?.toInt() ?? 0,
        audioOutputBuffer: (j['audio_output_buffer'] as num?)?.toInt() ?? 0,
        audioDup: j['audio_dup'] == true,
        requireAudio: j['require_audio'] == true,
        videoSource: j['video_source'] as String?,
        cameraId: (j['camera_id'] as num?)?.toInt() ?? 0,
        cameraFacing: j['camera_facing'] as String?,
        cameraSize: j['camera_size'] as String?,
        cameraAr: j['camera_ar'] as String?,
        cameraFps: (j['camera_fps'] as num?)?.toInt() ?? 0,
        cameraHighSpeed: j['camera_high_speed'] == true,
        cameraTorch: j['camera_torch'] == true,
        cameraZoom: (j['camera_zoom'] as num?)?.toDouble() ?? 0,
        borderless: j['borderless'] == true,
        windowTitle: j['window_title'] as String?,
        windowX: (j['window_x'] as num?)?.toInt() ?? 0,
        windowY: (j['window_y'] as num?)?.toInt() ?? 0,
        windowWidth: (j['window_width'] as num?)?.toInt() ?? 0,
        windowHeight: (j['window_height'] as num?)?.toInt() ?? 0,
        alwaysOnTop: j['always_on_top'] == true,
        fullscreen: j['fullscreen'] == true,
        disableScreensaver: j['disable_screensaver'] == true,
        noWindow: j['no_window'] == true,
        noWindowAspectRatioLock: j['no_window_aspect_ratio_lock'] == true,
        keyboard: j['keyboard'] as String?,
        mouse: j['mouse'] as String?,
        noControl: j['no_control'] == true,
        mouseBind: j['mouse_bind'] as String?,
        preferText: j['prefer_text'] == true,
        rawKeyEvents: j['raw_key_events'] == true,
        noKeyRepeat: j['no_key_repeat'] == true,
        noMouseHover: j['no_mouse_hover'] == true,
        legacyPaste: j['legacy_paste'] == true,
        noClipboardAutosync: j['no_clipboard_autosync'] == true,
        stayAwake: j['stay_awake'] == true,
        turnScreenOff: j['turn_screen_off'] == true,
        keepActive: j['keep_active'] == true,
        showTouches: j['show_touches'] == true,
        powerOffOnClose: j['power_off_on_close'] == true,
        noPowerOn: j['no_power_on'] == true,
        screenOffTimeout: (j['screen_off_timeout'] as num?)?.toInt() ?? 0,
        shortcutMod: j['shortcut_mod'] as String?,
        record: j['record'] as String?,
        recordFormat: j['record_format'] as String?,
        timeLimit: (j['time_limit'] as num?)?.toInt() ?? 0,
        noPlayback: j['no_playback'] == true,
        noVideoPlayback: j['no_video_playback'] == true,
        pauseOnExit: j['pause_on_exit'] as String?,
      );
}
