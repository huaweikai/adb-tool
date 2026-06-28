import 'package:flutter/material.dart';

const adbCommandQuickGroups = [
  AdbCommandActionGroup(
    titleKey: 'quickGroupDeviceInfo',
    icon: Icons.phone_android,
    actions: [
      AdbCommandQuickAction('quickActionBasicInfo',
          'shell getprop ro.product.model', Icons.info_outline),
      AdbCommandQuickAction('quickActionAndroidVersion',
          'shell getprop ro.build.version.release', Icons.android),
      AdbCommandQuickAction('quickActionDeviceSerial', 'get-serialno',
          Icons.confirmation_number_outlined),
      AdbCommandQuickAction('quickActionBatteryStatus', 'shell dumpsys battery',
          Icons.battery_full),
    ],
  ),
  // Device-control cluster — volume / brightness / rotation / airplane /
  // dark mode. All are toggle-style commands that testers hit over and
  // over; bundling them in one group keeps them one tap away instead of
  // buried in the Storage / Maintenance groups.
  //
  // Placed second (right after Device Info) because testers want these
  // toggles one scroll away, not at the bottom of the list.
  //
  // Why two-stage commands (e.g., settings put + am broadcast): some
  // toggles (airplane mode, dark mode) need both a settings write and a
  // config-change broadcast for the system to actually re-render. We
  // run them via `sh -c "..."` so the shell composes both calls.
  AdbCommandActionGroup(
    titleKey: 'quickGroupDeviceControl',
    icon: Icons.tune,
    actions: [
      // Volume — keyevents route through AudioManager; works on all
      // Android versions and doesn't need a media-session running.
      AdbCommandQuickAction(
          'quickActionVolumeUp', 'shell input keyevent 24', Icons.volume_up),
      AdbCommandQuickAction('quickActionVolumeDown', 'shell input keyevent 25',
          Icons.volume_down),

      // Brightness — 0..255, but we step to 30 / 200 (not extremes) so
      // testers don't think the screen died.
      AdbCommandQuickAction(
          'quickActionBrightnessUp',
          'shell settings put system screen_brightness 200',
          Icons.brightness_high),
      AdbCommandQuickAction(
          'quickActionBrightnessDown',
          'shell settings put system screen_brightness 30',
          Icons.brightness_low),

      // Rotation lock — accelerometer_rotation 0 stops the auto-rotate
      // sensor, user_rotation isn't pinned so the current angle stays.
      // Toggling back to 1 re-enables auto-rotate.
      AdbCommandQuickAction(
          'quickActionRotationLock',
          'shell settings put system accelerometer_rotation 0',
          Icons.screen_lock_rotation),
      AdbCommandQuickAction(
          'quickActionRotationUnlock',
          'shell settings put system accelerometer_rotation 1',
          Icons.screen_lock_rotation_outlined),

      // Airplane mode — settings write alone doesn't refresh the
      // connectivity stack; we also broadcast the action so the system
      // re-evaluates WiFi / cell state immediately.
      AdbCommandQuickAction(
          'quickActionAirplaneModeOn',
          'shell sh -c "settings put global airplane_mode_on 1 && am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true"',
          Icons.airplanemode_active),
      AdbCommandQuickAction(
          'quickActionAirplaneModeOff',
          'shell sh -c "settings put global airplane_mode_on 0 && am broadcast -a android.intent.action.AIRPLANE_MODE --ez state false"',
          Icons.airplanemode_inactive),

      // Dark mode — `cmd uimode night yes/no` is the only Android API
      // way to flip uiMode without an Activity context. Works on API
      // 29+; older devices silently ignore.
      AdbCommandQuickAction('quickActionDarkModeOn',
          'shell cmd uimode night yes', Icons.dark_mode),
      AdbCommandQuickAction('quickActionDarkModeOff',
          'shell cmd uimode night no', Icons.light_mode),
    ],
  ),
  AdbCommandActionGroup(
    titleKey: 'quickGroupScreenControl',
    icon: Icons.screenshot_monitor,
    actions: [
      AdbCommandQuickAction(
          'quickActionResolution', 'shell wm size', Icons.aspect_ratio),
      AdbCommandQuickAction(
          'quickActionScreenDensity', 'shell wm density', Icons.density_medium),
      AdbCommandQuickAction('quickActionWakeScreen', 'shell input keyevent 224',
          Icons.light_mode),
      AdbCommandQuickAction('quickActionPowerKey', 'shell input keyevent 26',
          Icons.power_settings_new),
    ],
  ),
  AdbCommandActionGroup(
    titleKey: 'quickGroupKeySimulation',
    icon: Icons.touch_app,
    actions: [
      AdbCommandQuickAction(
          'quickActionHome', 'shell input keyevent 3', Icons.home),
      AdbCommandQuickAction(
          'quickActionBack', 'shell input keyevent 4', Icons.arrow_back),
      AdbCommandQuickAction(
          'quickActionRecents', 'shell input keyevent 187', Icons.dynamic_feed),
      AdbCommandQuickAction(
          'quickActionMenuKey', 'shell input keyevent 82', Icons.menu),
    ],
  ),
  AdbCommandActionGroup(
    titleKey: 'quickGroupDebugDiagnostics',
    icon: Icons.bug_report,
    actions: [
      AdbCommandQuickAction('quickActionCurrentActivity',
          'shell dumpsys activity top', Icons.layers),
      AdbCommandQuickAction(
          'quickActionCurrentFocus',
          'shell sh -c "dumpsys window | grep -E \'mCurrentFocus|mFocusedApp\'"',
          Icons.center_focus_strong),
      AdbCommandQuickAction(
          'quickActionCpuTop', 'shell top -n 1 -m 10', Icons.memory),
      AdbCommandQuickAction(
          'quickActionProcessList', 'shell ps -A', Icons.account_tree),
    ],
  ),
  AdbCommandActionGroup(
    titleKey: 'quickGroupTestingHelpers',
    icon: Icons.science_outlined,
    actions: [
      AdbCommandQuickAction(
        'quickActionEnableAlwaysFinishActivities',
        'shell settings put global always_finish_activities 1',
        Icons.running_with_errors,
        confirm: true,
      ),
      AdbCommandQuickAction(
        'quickActionDisableAlwaysFinishActivities',
        'shell settings put global always_finish_activities 0',
        Icons.task_alt,
        confirm: true,
      ),
      AdbCommandQuickAction('quickActionEnableShowTouches',
          'shell settings put system show_touches 1', Icons.touch_app),
      AdbCommandQuickAction('quickActionDisableShowTouches',
          'shell settings put system show_touches 0', Icons.touch_app_outlined),
      AdbCommandQuickAction('quickActionEnablePointerLocation',
          'shell settings put system pointer_location 1', Icons.ads_click),
      AdbCommandQuickAction(
          'quickActionDisablePointerLocation',
          'shell settings put system pointer_location 0',
          Icons.ads_click_outlined),
    ],
  ),
  AdbCommandActionGroup(
    titleKey: 'quickGroupStorageNetwork',
    icon: Icons.storage,
    actions: [
      AdbCommandQuickAction(
          'quickActionStorageSpace', 'shell df -h', Icons.sd_storage),
      AdbCommandQuickAction(
          'quickActionNetworkAddress', 'shell ip addr show', Icons.wifi),
      AdbCommandQuickAction(
          'quickActionRouteInfo', 'shell ip route', Icons.route),
      AdbCommandQuickAction('quickActionConnectionStatus',
          'shell dumpsys connectivity', Icons.hub),
    ],
  ),
  AdbCommandActionGroup(
    titleKey: 'quickGroupMaintenance',
    icon: Icons.build_circle,
    actions: [
      AdbCommandQuickAction(
          'quickActionClearLogcat', 'logcat -c', Icons.cleaning_services,
          confirm: true),
      AdbCommandQuickAction(
          'quickActionAdbOverWifi', 'tcpip 5555', Icons.wifi_tethering,
          confirm: true),
      AdbCommandQuickAction('quickActionRestoreUsbAdb', 'usb', Icons.usb,
          confirm: true),
      AdbCommandQuickAction(
          'quickActionRebootDevice', 'reboot', Icons.restart_alt,
          confirm: true, destructive: true),
    ],
  ),
  AdbCommandActionGroup(
    titleKey: 'quickGroupIntent',
    icon: Icons.open_in_browser,
    actions: [
      AdbCommandQuickAction('quickActionViewUrl', '', Icons.language,
          dialog: true),
      AdbCommandQuickAction('quickActionDeepLink', '', Icons.link,
          dialog: true),
      AdbCommandQuickAction('quickActionCustomIntent', '', Icons.tune,
          customIntent: true),
    ],
  ),
  // Device-control cluster — volume / brightness / rotation / airplane /
  // dark mode. All are toggle-style commands that testers hit over and
  // over; bundling them in one group keeps them one tap away instead of
  // buried in the Storage / Maintenance groups.
  //
  // (Device Control group moved to position 2 — see top of list.)
];

class AdbCommandActionGroup {
  final String titleKey;
  final IconData icon;
  final List<AdbCommandQuickAction> actions;

  const AdbCommandActionGroup({
    required this.titleKey,
    required this.icon,
    required this.actions,
  });
}

class AdbCommandQuickAction {
  final String labelKey;
  final String command;
  final IconData icon;
  final bool confirm;
  final bool destructive;
  final bool dialog;
  final bool customIntent;

  const AdbCommandQuickAction(
    this.labelKey,
    this.command,
    this.icon, {
    this.confirm = false,
    this.destructive = false,
    this.dialog = false,
    this.customIntent = false,
  });
}
