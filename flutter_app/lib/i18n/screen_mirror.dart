// Scrcpy screen-mirror tab — bundled-binary screen casting + shortcut buttons.
//
// The actual video stream runs in scrcpy's own SDL window outside the
// Flutter app. This tab is just a control panel: start/stop casting
// and tweak per-device scrcpy options. The "shortcuts" surface on the
// tab is a *reference* of scrcpy's own keyboard shortcuts (pressed
// while the scrcpy window is focused) — see ScrcpyShortcutReference.

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

  // Hints / status
  'scrcpyWindowHint': '视频窗口由 scrcpy 自行弹出。如果没看到，检查任务栏/Dock。',
  'scrcpyStartFailed': '启动失败：{error}',
  'scrcpyStopFailed': '停止失败：{error}',
  'scrcpyConfirmStop': '确认结束投屏？',
  'scrcpyConfirmStopBody': '关闭后视频窗口会立即消失。',

  // Settings panel (left side)
  'scrcpyPanelTitle': '投屏设置',
  'scrcpyReset': '恢复默认',

  // Section headers
  'scrcpySectionVideoSource': '视频源',
  'scrcpySectionVideo': '视频',
  'scrcpySectionAudio': '音频',
  'scrcpySectionWindow': '窗口',
  'scrcpySectionControl': '控制',
  'scrcpySectionDevice': '设备',
  'scrcpySectionRecording': '录制',

  // Video source
  'scrcpySourceDisplay': '屏幕',
  'scrcpySourceCamera': '摄像头',

  // Video
  'scrcpyMaxSize': '最大尺寸',
  'scrcpyBitRate': '码率',
  'scrcpyMaxFps': '最高帧率',
  'scrcpyCodec': '编码',
  'scrcpyUnlimited': '不限',
  'scrcpyUnsetLimit': '解锁 (使用不限)',
  'scrcpySetLimit': '锁定 (使用限制)',

  // Audio
  'scrcpyNoAudio': '静音',
  'scrcpyAudioSource': '音频源',

  // Window
  'scrcpyBorderless': '无标题栏',
  'scrcpyAlwaysOnTop': '窗口置顶',
  'scrcpyFullscreen': '全屏启动',
  'scrcpyDisableScreensaver': '禁用屏幕保护',

  // Control
  'scrcpyKeyboard': '键盘模式',
  'scrcpyMouse': '鼠标模式',
  'scrcpyNoControl': '只读（不控制设备）',
  'scrcpyNoControlHint': '开启后只能看，不能操作',

  // Device
  'scrcpyStayAwake': '保持唤醒',
  'scrcpyTurnScreenOff': '立即息屏',
  'scrcpyTurnScreenOffHint': '镜像时关闭手机屏幕',
  'scrcpyKeepActive': '持续保活',
  'scrcpyKeepActiveHint': 'scrcpy 4.0+：定时发送用户活动信号',
  'scrcpyShowTouches': '显示触摸点',

  // Camera (when video source = camera)
  'scrcpyCameraFacing': '摄像头朝向',
  'scrcpyCameraFps': '摄像头帧率',
  'scrcpyCameraTorch': '闪光灯',

  // Recording
  'scrcpyRecordEnable': '同时录制到文件',
  'scrcpyRecordFolder': '保存目录',
  'scrcpyChangeFolder': '更换目录',
  'scrcpyRecordFormat': '格式',
  'scrcpyRecordFolderNotFound': '录屏保存目录不存在，请重新选择',
  'scrcpyTimeLimit': '录制时长',

  // Shortcut reference (scrcpy built-in shortcuts)
  'scrcpyRefTitle': 'Scrcpy 快捷键参考',
  'scrcpyRefHint': '点击投屏窗口使其获得焦点后按下快捷键即可生效。',
  'scrcpyRefPlatformWin': 'Windows',
  'scrcpyRefPlatformMac': 'macOS',
  'scrcpyRefPlatformOther': 'Linux / Other',
  'scrcpyRefActionQuit': '退出投屏',
  'scrcpyRefActionFullscreen': '切换全屏',
  'scrcpyRefActionHome': '主页',
  'scrcpyRefActionBack': '返回',
  'scrcpyRefActionRecents': '最近任务',
  'scrcpyRefActionMenu': '菜单',
  'scrcpyRefActionPower': '电源',
  'scrcpyRefActionVolumeUp': '音量+',
  'scrcpyRefActionVolumeDown': '音量-',
  'scrcpyRefActionScreenOff': '息屏（保持镜像）',
  'scrcpyRefActionScreenOn': '亮屏',
  'scrcpyRefActionRotateDevice': '旋转设备',
  'scrcpyRefActionExpandNotif': '展开通知栏',
  'scrcpyRefActionCollapsePanels': '收起通知栏',
  'scrcpyRefActionCopy': '复制（设备侧）',
  'scrcpyRefActionCut': '剪切',
  'scrcpyRefActionPaste': '同步剪贴板+粘贴',
  'scrcpyRefActionPause': '暂停显示',
  'scrcpyRefActionUnpause': '恢复显示',
  'scrcpyRefActionResetVideo': '重置视频捕获',
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

  'scrcpyWindowHint': 'The video window opens outside this app — check your taskbar/Dock.',
  'scrcpyStartFailed': 'Start failed: {error}',
  'scrcpyStopFailed': 'Stop failed: {error}',
  'scrcpyConfirmStop': 'Stop mirroring?',
  'scrcpyConfirmStopBody': 'The scrcpy window will close immediately.',

  'scrcpyPanelTitle': 'Mirror settings',
  'scrcpyReset': 'Reset',

  'scrcpySectionVideoSource': 'Video source',
  'scrcpySectionVideo': 'Video',
  'scrcpySectionAudio': 'Audio',
  'scrcpySectionWindow': 'Window',
  'scrcpySectionControl': 'Control',
  'scrcpySectionDevice': 'Device',
  'scrcpySectionRecording': 'Recording',

  'scrcpySourceDisplay': 'Display',
  'scrcpySourceCamera': 'Camera',

  'scrcpyMaxSize': 'Max size',
  'scrcpyBitRate': 'Bit rate',
  'scrcpyMaxFps': 'Max FPS',
  'scrcpyCodec': 'Codec',
  'scrcpyUnlimited': 'unlimited',
  'scrcpyUnsetLimit': 'Unlock (use unlimited)',
  'scrcpySetLimit': 'Lock (use limit)',

  'scrcpyNoAudio': 'Mute',
  'scrcpyAudioSource': 'Audio source',

  'scrcpyBorderless': 'Borderless',
  'scrcpyAlwaysOnTop': 'Always on top',
  'scrcpyFullscreen': 'Start fullscreen',
  'scrcpyDisableScreensaver': 'Disable screensaver',

  'scrcpyKeyboard': 'Keyboard mode',
  'scrcpyMouse': 'Mouse mode',
  'scrcpyNoControl': 'Read-only (no device control)',
  'scrcpyNoControlHint': 'You can watch but not interact',

  'scrcpyStayAwake': 'Stay awake',
  'scrcpyTurnScreenOff': 'Turn screen off',
  'scrcpyTurnScreenOffHint': 'Mirror while the device screen is off',
  'scrcpyKeepActive': 'Keep active',
  'scrcpyKeepActiveHint': 'scrcpy 4.0+: simulate user activity',
  'scrcpyShowTouches': 'Show touches',

  'scrcpyCameraFacing': 'Camera facing',
  'scrcpyCameraFps': 'Camera FPS',
  'scrcpyCameraTorch': 'Torch',

  'scrcpyRecordEnable': 'Record to file',
  'scrcpyRecordFolder': 'Save folder',
  'scrcpyChangeFolder': 'Change folder',
  'scrcpyRecordFormat': 'Format',
  'scrcpyRecordFolderNotFound': 'Recording folder does not exist, please reselect',
  'scrcpyTimeLimit': 'Time limit',

  'scrcpyRefTitle': 'Scrcpy shortcuts',
  'scrcpyRefHint': 'Click into the scrcpy window to focus it, then press the shortcut.',
  'scrcpyRefPlatformWin': 'Windows',
  'scrcpyRefPlatformMac': 'macOS',
  'scrcpyRefPlatformOther': 'Linux / Other',
  'scrcpyRefActionQuit': 'Quit mirror',
  'scrcpyRefActionFullscreen': 'Toggle fullscreen',
  'scrcpyRefActionHome': 'Home',
  'scrcpyRefActionBack': 'Back',
  'scrcpyRefActionRecents': 'Recents',
  'scrcpyRefActionMenu': 'Menu',
  'scrcpyRefActionPower': 'Power',
  'scrcpyRefActionVolumeUp': 'Vol+',
  'scrcpyRefActionVolumeDown': 'Vol−',
  'scrcpyRefActionScreenOff': 'Screen off (keep mirroring)',
  'scrcpyRefActionScreenOn': 'Screen on',
  'scrcpyRefActionRotateDevice': 'Rotate device',
  'scrcpyRefActionExpandNotif': 'Expand notification',
  'scrcpyRefActionCollapsePanels': 'Collapse panels',
  'scrcpyRefActionCopy': 'Copy (device side)',
  'scrcpyRefActionCut': 'Cut',
  'scrcpyRefActionPaste': 'Sync clipboard + paste',
  'scrcpyRefActionPause': 'Pause display',
  'scrcpyRefActionUnpause': 'Resume display',
  'scrcpyRefActionResetVideo': 'Reset video capture',
};
