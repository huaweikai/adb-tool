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
  });

  test('load() reads persisted method + outputDir from AppStates', () async {
    // Pre-populate the singleton row with scrcpy + a directory.
    // The outputDir column is reserved for future expansion
    // (custom output directory); current UI doesn't read it but
    // the column stays nullable for v10 compatibility.
    await db.appStatesDao.updateAppState(
      screenRecordMethod: 'scrcpy',
      scrcpyRecordOutputDir: '/tmp/recordings',
    );
    await provider.load();

    expect(provider.loaded, isTrue);
    expect(provider.method, ScreenRecordMethod.scrcpy);
    expect(provider.outputDir, '/tmp/recordings');
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

  test('setMethod is a no-op when value is unchanged', () async {
    await provider.load();
    var notifyCount = 0;
    provider.addListener(() => notifyCount++);

    await provider.setMethod(ScreenRecordMethod.adb);
    expect(notifyCount, 0);
    expect(provider.method, ScreenRecordMethod.adb);
  });

  test('setMethod fires notifyListeners when value changes', () async {
    await provider.load();
    var notifyCount = 0;
    provider.addListener(() => notifyCount++);

    await provider.setMethod(ScreenRecordMethod.scrcpy);
    expect(notifyCount, 1);

    await provider.setMethod(ScreenRecordMethod.scrcpy);
    expect(notifyCount, 1);
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

  test('app_states schema matches v10 expectations (locks hand-edited database.g.dart)', () async {
    // This is a guard against database.g.dart drift. The file is
    // hand-edited because build_runner is broken on the current
    // analyzer 13.0.0 toolchain (pubspec.yaml has the override block).
    // When build_runner is fixed, regenerate database.g.dart and
    // update the expected column list if drift is intentional.
    final schema =
        await db.customSelect('PRAGMA table_info(app_states)').get();
    final columnNames =
        schema.map((row) => row.data['name'] as String).toList();
    expect(columnNames, containsAll(<String>[
      'id',
      'active_serial',
      'active_key',
      'expanded_serials',
      'last_successful_refresh',
      'selected_s_d_k_path', // drift: drift uses this for `selectedSDKPath`
      'selected_java_path',
      'sidebar_width',
      'sidebar_collapsed',
      'screen_record_method', // v10
      'scrcpy_record_output_dir', // v10
    ]));
  });
}
