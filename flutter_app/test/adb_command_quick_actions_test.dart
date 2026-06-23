import 'package:adb_tool/screens/adb_command_quick_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('adbCommandQuickGroups', () {
    test('contains testing helper actions for common QA workflows', () {
      final testingGroup = adbCommandQuickGroups.singleWhere(
        (group) => group.titleKey == 'quickGroupTestingHelpers',
      );

      expect(
        testingGroup.actions.map((action) => action.labelKey),
        containsAll([
          'quickActionEnableAlwaysFinishActivities',
          'quickActionDisableAlwaysFinishActivities',
          'quickActionEnableShowTouches',
          'quickActionDisableShowTouches',
        ]),
      );
    });

    test('testing helper actions avoid unstable foreground parsing commands',
        () {
      final testingGroup = adbCommandQuickGroups.singleWhere(
        (group) => group.titleKey == 'quickGroupTestingHelpers',
      );
      final labelKeys = testingGroup.actions.map((action) => action.labelKey);
      final commands = testingGroup.actions.map((action) => action.command);

      expect(labelKeys, isNot(contains('quickActionRecreateActivity')));
      expect(labelKeys, isNot(contains('quickActionSendTrimMemory')));
      expect(commands.join('\n'), isNot(contains('dumpsys window')));
      expect(commands.join('\n'), isNot(contains('send-trim-memory')));
    });

    test('always finish activities actions write global setting values', () {
      final testingGroup = adbCommandQuickGroups.singleWhere(
        (group) => group.titleKey == 'quickGroupTestingHelpers',
      );
      final enableAction = testingGroup.actions.singleWhere(
        (action) =>
            action.labelKey == 'quickActionEnableAlwaysFinishActivities',
      );
      final disableAction = testingGroup.actions.singleWhere(
        (action) =>
            action.labelKey == 'quickActionDisableAlwaysFinishActivities',
      );

      expect(enableAction.confirm, isTrue);
      expect(disableAction.confirm, isTrue);
      expect(
        enableAction.command,
        'shell settings put global always_finish_activities 1',
      );
      expect(
        disableAction.command,
        'shell settings put global always_finish_activities 0',
      );
    });
  });
}
