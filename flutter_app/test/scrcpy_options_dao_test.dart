import 'package:adb_tool/db/database.dart';
import 'package:adb_tool/models/scrcpy_options.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('upsert stores scrcpy options as expanded database columns', () async {
    final options = ScrcpyOptions.defaults().copyWith(
      maxSize: 2048,
      videoBitRate: '12M',
      maxFps: 60,
      noAudio: true,
      cameraZoom: 1.5,
      windowTitle: 'Pixel Mirror',
      alwaysOnTop: true,
      keyboard: 'uhid',
      stayAwake: false,
      recordFormat: 'mkv',
      timeLimit: 120,
    );

    await db.scrcpyOptionsDao.upsert('device-1', options);

    final saved = await db.scrcpyOptionsDao.getBySerial('device-1');
    expect(saved?.maxSize, 2048);
    expect(saved?.videoBitRate, '12M');
    expect(saved?.maxFps, 60);
    expect(saved?.noAudio, isTrue);
    expect(saved?.cameraZoom, 1.5);
    expect(saved?.windowTitle, 'Pixel Mirror');
    expect(saved?.alwaysOnTop, isTrue);
    expect(saved?.keyboard, 'uhid');
    expect(saved?.stayAwake, isFalse);
    expect(saved?.recordFormat, 'mkv');
    expect(saved?.timeLimit, 120);

    final schema = await db.customSelect('PRAGMA table_info(scrcpy_options)').get();
    final columnNames = schema.map((row) => row.data['name']).toList();
    expect(columnNames, isNot(contains('options_json')));
    expect(columnNames, containsAll([
      'serial',
      'max_size',
      'video_bit_rate',
      'no_audio',
      'camera_zoom',
      'window_title',
      'always_on_top',
      'record_format',
      'updated_at',
    ]));

    final rows = await db.customSelect('SELECT * FROM scrcpy_options').get();
    expect(rows, hasLength(1));
    expect(rows.single.data['max_size'], 2048);
    expect(rows.single.data['video_bit_rate'], '12M');
    expect(rows.single.data['no_audio'], 1);
    expect(rows.single.data['camera_zoom'], 1.5);
    expect(rows.single.data['window_title'], 'Pixel Mirror');
    expect(rows.single.data['always_on_top'], 1);
    expect(rows.single.data['record_format'], 'mkv');
  });
}
