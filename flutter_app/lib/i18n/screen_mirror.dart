// Scrcpy screen-mirror tab — bundled-binary screen casting + shortcut buttons.
//
// The actual video stream runs in scrcpy's own SDL window outside the
// Flutter app. This tab is just a control panel: start/stop casting,
// fire system-level shortcuts (home/back/etc.) at the device.

part of 'package:adb_tool/i18n.dart';

const _locScreenMirrorZh = <String, String>{
  // Sidebar / nav entry
  'screenMirror': '投屏',
  'screenMirrorHint': '通过 scrcpy 镜像设备屏幕（独立窗口）',

  // Page chrome
  'scrcpyTitle': '投屏 — {serial}',
  'scrcpyNoDevice': '请先在侧栏选择设备',
  'scrcpyRunning': '投屏中',
  'scrcpyStopped': '未投屏',
  'scrcpyElapsed': '已运行 {seconds}s',

  // Buttons
  'scrcpyStart': '开始投屏',
  'scrcpyStop': '结束投屏',
  'scrcpyRestart': '重启投屏',

  // Shortcut buttons
  'scrcpyShortcutHome': '主页',
  'scrcpyShortcutBack': '返回',
  'scrcpyShortcutRecents': '最近任务',
  'scrcpyShortcutPower': '电源',
  'scrcpyShortcutVolumeUp': '音量+',
  'scrcpyShortcutVolumeDown': '音量-',
  'scrcpyShortcutMenu': '菜单',

  // Hints / status
  'scrcpyWindowHint': '视频窗口由 scrcpy 自行弹出。如果没看到，检查任务栏/Dock。',
  'scrcpyStartFailed': '启动失败：{error}',
  'scrcpyStopFailed': '停止失败：{error}',
  'scrcpyShortcutFailed': '快捷操作失败：{error}',
  'scrcpyConfirmStop': '确认结束投屏？',
  'scrcpyConfirmStopBody': '关闭后视频窗口会立即消失。',
};

const _locScreenMirrorEn = <String, String>{
  'screenMirror': 'Mirror',
  'screenMirrorHint': 'Mirror device screen via bundled scrcpy (separate window)',

  'scrcpyTitle': 'Mirror — {serial}',
  'scrcpyNoDevice': 'Select a device in the sidebar first',
  'scrcpyRunning': 'Mirroring',
  'scrcpyStopped': 'Not mirroring',
  'scrcpyElapsed': '{seconds}s elapsed',

  'scrcpyStart': 'Start mirror',
  'scrcpyStop': 'Stop mirror',
  'scrcpyRestart': 'Restart mirror',

  'scrcpyShortcutHome': 'Home',
  'scrcpyShortcutBack': 'Back',
  'scrcpyShortcutRecents': 'Recents',
  'scrcpyShortcutPower': 'Power',
  'scrcpyShortcutVolumeUp': 'Vol+',
  'scrcpyShortcutVolumeDown': 'Vol−',
  'scrcpyShortcutMenu': 'Menu',

  'scrcpyWindowHint': 'The video window opens outside this app — check your taskbar/Dock.',
  'scrcpyStartFailed': 'Start failed: {error}',
  'scrcpyStopFailed': 'Stop failed: {error}',
  'scrcpyShortcutFailed': 'Shortcut failed: {error}',
  'scrcpyConfirmStop': 'Stop mirroring?',
  'scrcpyConfirmStopBody': 'The scrcpy window will close immediately.',
};