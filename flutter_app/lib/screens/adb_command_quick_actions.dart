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
