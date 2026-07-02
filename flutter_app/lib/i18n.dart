// Locale dictionary entry point.
//
// Each domain owns its own file under lib/i18n/*.dart. This file:
//   1. Pulls in all domain parts via `part` so their `_loc<Domain>Zh` / `_loc<Domain>En`
//      const maps share this library's private namespace.
//   2. Merges them into a single _loc keyed by language code.
//   3. Exposes the public translation API (tr / setLang / currentLang).
//
// To add a new domain:
//   - Create lib/i18n/<domain>.dart starting with `part of 'package:adb_tool/i18n.dart';`
//     and two `const _loc<Domain>Zh / En` maps.
//   - Add the corresponding `part 'i18n/<domain>.dart';` line below and spread
//     the new maps in `_loc`.
//
// To add a new language:
//   - For each domain file, add a `const _loc<Domain><Lang>` map.
//   - Extend the spread lists below to include each new map.

library;

part 'i18n/common.dart';
part 'i18n/sidebar.dart';
part 'i18n/logcat.dart';
part 'i18n/test_session.dart';
part 'i18n/session_history.dart';
part 'i18n/device_monitor.dart';
part 'i18n/adb_command.dart';
part 'i18n/app_manager.dart';
part 'i18n/file_browser.dart';
part 'i18n/device_info.dart';
part 'i18n/clipboard.dart';
part 'i18n/backend_log.dart';
part 'i18n/screen_mirror.dart';
part 'i18n/settings.dart';
part 'i18n/emulator.dart';

String _lang = 'zh';

const _loc = <String, Map<String, String>>{
  'zh': {
    ..._locCommonZh,
    ..._locSidebarZh,
    ..._locLogcatZh,
    ..._locTestSessionZh,
    ..._locSessionHistoryZh,
    ..._locDeviceMonitorZh,
    ..._locAdbCommandZh,
    ..._locAppManagerZh,
    ..._locFileBrowserZh,
    ..._locDeviceInfoZh,
    ..._locClipboardZh,
    ..._locBackendLogZh,
    ..._locScreenMirrorZh,
    ..._locSettingsZh,
    ..._locEmulatorZh,
  },
  'en': {
    ..._locCommonEn,
    ..._locSidebarEn,
    ..._locLogcatEn,
    ..._locTestSessionEn,
    ..._locSessionHistoryEn,
    ..._locDeviceMonitorEn,
    ..._locAdbCommandEn,
    ..._locAppManagerEn,
    ..._locFileBrowserEn,
    ..._locDeviceInfoEn,
    ..._locClipboardEn,
    ..._locBackendLogEn,
    ..._locScreenMirrorEn,
    ..._locSettingsEn,
    ..._locEmulatorEn,
  },
};

String tr(String key, [Map<String, String>? args]) {
  var s = _loc[_lang]?[key] ?? key;
  if (args != null) {
    for (final e in args.entries) {
      s = s.replaceAll('{${e.key}}', e.value);
    }
  }
  return s;
}

void setLang(String lang) {
  if (_loc.containsKey(lang)) _lang = lang;
}

String get currentLang => _lang;
