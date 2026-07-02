// i18n keys for the screen-recording settings page and the scrcpy-
// mode recording flow.
//
// Keys are namespaced as `screenRecord.*` for the settings page UI
// and `recording.*` for the cross-screen "scrcpy is busy" prompts
// that show up both here and in the mirror page.
part of 'package:adb_tool/i18n.dart';

const _locScreenRecordingZh = <String, String>{
  // ── screens/recording_settings_screen.dart ───────────────────────────
  'screenRecord.title': '录屏设置',
  'screenRecord.method': '录屏方式',
  'screenRecord.methodAdb': 'ADB (内置)',
  'screenRecord.methodAdbDesc': '使用 adb screenrecord。无需配置。',
  'screenRecord.methodScrcpy': 'scrcpy (无窗口)',
  'screenRecord.methodScrcpyDesc': '使用 scrcpy 录屏，无弹出窗口。适合部分 ADB 录屏有问题的设备。',
  'screenRecord.scrcpyOutputDir': '保存目录',
  'screenRecord.chooseDir': '选择目录',
  'screenRecord.dirNotSet': '尚未选择目录',
  'screenRecord.dirHelp':
      '录屏文件会保存到此目录下的 `adb-tool-record_<时间戳>.mp4`。',
  'screenRecord.dirMissing': '目录不存在或不可写，请重新选择',
  'screenRecord.savedToast': '设置已保存',
  'screenRecord.scrcpyRequiresDir':
      '请先在录屏设置中选择保存目录再使用 scrcpy 录屏',

  // ── Capture mixin / mirror page cross-screen prompts ─────────────────
  'recording.scrcpyBusyMirrorTitle': '检测到 scrcpy 投屏正在运行',
  'recording.scrcpyBusyMirrorBody':
      '开始录屏将停止当前投屏会话，是否继续？',
  'recording.scrcpyBusyRecordTitle': '检测到 scrcpy 已在录屏',
  'recording.scrcpyBusyRecordBody':
      '另一台设备正在使用 scrcpy 录屏。一次只能运行一个 scrcpy 进程。',
  'recording.scrcpyBusyContinue': '停止投屏并录屏',
  'recording.scrcpyBusyCancel': '取消',
  'recording.startFailed': '启动录屏失败：{error}',
  'recording.stopFailed': '停止录屏失败：{error}',
  'recording.fileSaved': '录屏已保存到 {path}',
  'recording.fileSavedNotif': '录屏文件：{path}',

  // ── Mirror page integration ───────────────────────────────────────
  'scrcpy.recordingActiveOnCard': '录屏中 {seconds}s',
  'scrcpy.recordingActiveOther': '另一台设备正在录屏',
  'scrcpy.recordingCantStartMirror': 'scrcpy 正在录屏，无法启动投屏',
  'scrcpy.recordingToPath': '保存到：{path}',
  'scrcpy.recordingStopOnlyHere': '请到录屏页面停止',
};

const _locScreenRecordingEn = <String, String>{
  'screenRecord.title': 'Screen Recording',
  'screenRecord.method': 'Recording method',
  'screenRecord.methodAdb': 'ADB (built-in)',
  'screenRecord.methodAdbDesc':
      'Use the bundled `adb screenrecord`. No setup needed.',
  'screenRecord.methodScrcpy': 'scrcpy (windowless)',
  'screenRecord.methodScrcpyDesc':
      'Use the bundled scrcpy to record silently. Works around `adb screenrecord` bugs on some devices.',
  'screenRecord.scrcpyOutputDir': 'Save folder',
  'screenRecord.chooseDir': 'Choose folder',
  'screenRecord.dirNotSet': 'No folder selected',
  'screenRecord.dirHelp':
      'Recordings are saved as `adb-tool-record_<timestamp>.mp4` under this folder.',
  'screenRecord.dirMissing': 'Folder is missing or not writable — please pick another',
  'screenRecord.savedToast': 'Settings saved',
  'screenRecord.scrcpyRequiresDir':
      'Pick a save folder in Recording settings before using scrcpy mode',

  'recording.scrcpyBusyMirrorTitle': 'scrcpy mirror is running',
  'recording.scrcpyBusyMirrorBody':
      'Starting a recording will stop the current mirror session. Continue?',
  'recording.scrcpyBusyRecordTitle': 'scrcpy is already recording',
  'recording.scrcpyBusyRecordBody':
      'Another scrcpy recording is in flight. Only one scrcpy process can run at a time.',
  'recording.scrcpyBusyContinue': 'Stop mirror and record',
  'recording.scrcpyBusyCancel': 'Cancel',
  'recording.startFailed': 'Failed to start recording: {error}',
  'recording.stopFailed': 'Failed to stop recording: {error}',
  'recording.fileSaved': 'Recording saved to {path}',
  'recording.fileSavedNotif': 'Recording file: {path}',

  'scrcpy.recordingActiveOnCard': 'Recording {seconds}s',
  'scrcpy.recordingActiveOther': 'Another device is recording',
  'scrcpy.recordingCantStartMirror': 'scrcpy is recording — cannot start mirror',
  'scrcpy.recordingToPath': 'Saving to: {path}',
  'scrcpy.recordingStopOnlyHere': 'Stop from the recording surface',
};
