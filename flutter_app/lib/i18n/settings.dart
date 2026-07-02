// i18n keys for the global Settings page (录屏 + 缓存 + 关于 sections)
// and the cross-screen "scrcpy is busy" prompts that show up both in
// the capture mixin (start recording) and the mirror page (start mirror
// when scrcpy is recording).
//
// Keys are namespaced:
//   - `settings.*`          for the Settings page UI
//   - `recording.*`         for cross-screen recording-method prompts
//                            (file-browser / test-session / mirror)
//   - `scrcpy.*`            for the mirror page's recording indicator
part of 'package:adb_tool/i18n.dart';

const _locSettingsZh = <String, String>{
  // ── screens/settings_screen.dart ───────────────────────────────
  'settings.title': '设置',
  'settings.sectionRecording': '录屏',
  'settings.sectionCache': '缓存',
  'settings.sectionAbout': '关于',

  // 录屏 section
  'settings.recording.methodAdb': 'ADB (内置)',
  'settings.recording.methodAdbDesc':
      '使用 adb screenrecord。无需配置。',
  'settings.recording.methodScrcpy': 'scrcpy (无窗口)',
  'settings.recording.methodScrcpyDesc':
      '使用 scrcpy 录屏，无弹出窗口。适合部分 ADB 录屏有问题的设备。',
  'settings.recording.savedToast': '设置已保存',

  // 缓存 section
  'settings.cache.cleanup': '清理所有 adb-tool 缓存',
  'settings.cache.cleanupDesc':
      '清空 adb / scrcpy 解压缓存、模拟器实例、已下载系统镜像等。可选择保留 Android SDK。',
  'settings.cache.cleanupButton': '清理',

  // 关于 section
  'settings.about.appName': 'ADB Tool',
  'settings.about.version': '版本',
  'settings.about.build': '构建号',
  'settings.about.copyright': '© ADB Tool contributors',

  // ── Capture mixin / mirror page cross-screen prompts ─────────────
  'recording.scrcpyBusyMirrorTitle': '检测到 scrcpy 投屏正在运行',
  'recording.scrcpyBusyMirrorBody':
      '开始录屏将停止当前投屏会话，是否继续？',
  'recording.scrcpyBusyRecordTitle': '检测到 scrcpy 已在录屏',
  'recording.scrcpyBusyRecordBody':
      '设备 {serial} 正在 scrcpy 录屏。一次只能运行一个 scrcpy 进程。',
  'recording.scrcpyBusyContinue': '停止投屏并录屏',
  'recording.scrcpyBusyCancel': '取消',
  'recording.startFailed': '启动录屏失败：{error}',
  'recording.stopFailed': '停止录屏失败：{error}',
  'recording.fileSaved': '录屏已保存到 {path}',
  'recording.fileSavedNotif': '录屏文件：{path}',

  // ── Mirror page integration ────────────────────────────────────
  'scrcpy.recordingActiveOnCard': '录屏中 {seconds}s',
  'scrcpy.recordingActiveOther': '另一台设备正在录屏',
  'scrcpy.recordingCantStartMirror': 'scrcpy 正在录屏，无法启动投屏',
};

const _locSettingsEn = <String, String>{
  'settings.title': 'Settings',
  'settings.sectionRecording': 'Recording',
  'settings.sectionCache': 'Cache',
  'settings.sectionAbout': 'About',

  'settings.recording.methodAdb': 'ADB (built-in)',
  'settings.recording.methodAdbDesc':
      'Use the bundled `adb screenrecord`. No setup needed.',
  'settings.recording.methodScrcpy': 'scrcpy (windowless)',
  'settings.recording.methodScrcpyDesc':
      'Use the bundled scrcpy to record silently. Works around `adb screenrecord` bugs on some devices.',
  'settings.recording.savedToast': 'Settings saved',

  'settings.cache.cleanup': 'Clean all adb-tool caches',
  'settings.cache.cleanupDesc':
      'Wipe adb / scrcpy extract cache, emulator instances, downloaded system images, etc. The Android SDK can be preserved.',
  'settings.cache.cleanupButton': 'Clean',

  'settings.about.appName': 'ADB Tool',
  'settings.about.version': 'Version',
  'settings.about.build': 'Build',
  'settings.about.copyright': '© ADB Tool contributors',

  'recording.scrcpyBusyMirrorTitle': 'scrcpy mirror is running',
  'recording.scrcpyBusyMirrorBody':
      'Starting a recording will stop the current mirror session. Continue?',
  'recording.scrcpyBusyRecordTitle': 'scrcpy is already recording',
  'recording.scrcpyBusyRecordBody':
      'Device {serial} is recording via scrcpy. Only one scrcpy process can run at a time.',
  'recording.scrcpyBusyContinue': 'Stop mirror and record',
  'recording.scrcpyBusyCancel': 'Cancel',
  'recording.startFailed': 'Failed to start recording: {error}',
  'recording.stopFailed': 'Failed to stop recording: {error}',
  'recording.fileSaved': 'Recording saved to {path}',
  'recording.fileSavedNotif': 'Recording file: {path}',

  'scrcpy.recordingActiveOnCard': 'Recording {seconds}s',
  'scrcpy.recordingActiveOther': 'Another device is recording',
  'scrcpy.recordingCantStartMirror': 'scrcpy is recording — cannot start mirror',
};
