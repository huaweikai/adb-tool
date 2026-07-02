// Unit tests for RecordingSettingsProvider — the v10 cross-cutting
// preference that drives the capture-mixin recording method branch.
//
// We exercise the provider directly (no widget tree) so the test
// runs fast and covers the DB write/read cycle, the ScreenRecordMethod
// enum round-trip, and the scrcpyConfigured helper. The provider
// uses ChangeNotifier so we also add a listener to confirm writes
// fire notifications.
import 'package:adb_tool/db/database.dart';
import 'package:adb_tool/providers/recording_settings_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late RecordingSettingsProvider provider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    provider = RecordingSettingsProvider(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  test('defaults to adb method with no output dir before load()', () {
    expect(provider.method, ScreenRecordMethod.adb);
    expect(provider.outputDir, isNull);
    expect(provider.loaded, isFalse);
    expect(provider.scrcpyConfigured, isFalse);
  });

  test('load() reads persisted method + outputDir from AppStates', () async {
    // Pre-populate the singleton row with scrcpy + a directory.
    await db.appStatesDao.updateAppState(
      screenRecordMethod: 'scrcpy',
      scrcpyRecordOutputDir: '/tmp/recordings',
    );
    await provider.load();

    expect(provider.loaded, isTrue);
    expect(provider.method, ScreenRecordMethod.scrcpy);
    expect(provider.outputDir, '/tmp/recordings');
    expect(provider.scrcpyConfigured, isTrue);
  });

  test('setMethod persists and notifies listeners', () async {
    var notifyCount = 0;
    provider.addListener(() => notifyCount++);

    await provider.setMethod(ScreenRecordMethod.scrcpy);
    expect(provider.method, ScreenRecordMethod.scrcpy);
    expect(notifyCount, 1);

    // Re-reading the DB confirms persistence.
    final state = await db.appStatesDao.getAppState();
    expect(state.screenRecordMethod, 'scrcpy');
  });

  test('setOutputDir stores and clearOutputDir unsets', () async {
    await provider.setOutputDir('/tmp/foo');
    expect(provider.outputDir, '/tmp/foo');

    final state = await db.appStatesDao.getAppState();
    expect(state.scrcpyRecordOutputDir, '/tmp/foo');

    await provider.setOutputDir(null);
    expect(provider.outputDir, isNull);

    final after = await db.appStatesDao.getAppState();
    expect(after.scrcpyRecordOutputDir, isNull);
  });

  test('scrcpyConfigured requires both method=scrcpy AND a directory', () async {
    expect(provider.scrcpyConfigured, isFalse); // method=adb, no dir

    // Switching the method alone isn't enough — we still need a dir.
    await provider.setMethod(ScreenRecordMethod.scrcpy);
    expect(provider.scrcpyConfigured, isFalse); // no dir yet

    await provider.setOutputDir('/tmp/foo');
    expect(provider.scrcpyConfigured, isTrue);

    // Going back to adb turns it off even with a dir set.
    await provider.setMethod(ScreenRecordMethod.adb);
    expect(provider.scrcpyConfigured, isFalse);
  });

  test('ScreenRecordMethod.fromDb round-trips both values', () {
    expect(ScreenRecordMethod.fromDb('adb'), ScreenRecordMethod.adb);
    expect(ScreenRecordMethod.fromDb('scrcpy'), ScreenRecordMethod.scrcpy);
    // Unknown / future values fall back to adb so a row that has
    // been hand-edited can't crash the app.
    expect(ScreenRecordMethod.fromDb('something-else'), ScreenRecordMethod.adb);
    expect(ScreenRecordMethod.fromDb(''), ScreenRecordMethod.adb);
  });

  test('v10 schema adds the two new columns to app_states', () async {
    await db.appStatesDao.getAppState(); // ensure row exists
    final schema =
        await db.customSelect('PRAGMA table_info(app_states)').get();
    final columnNames = schema.map((row) => row.data['name']).toList();
    expect(columnNames, containsAll([
      'screen_record_method',
      'scrcpy_record_output_dir',
    ]));
  });
}
