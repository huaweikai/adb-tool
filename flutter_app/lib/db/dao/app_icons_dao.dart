import 'package:drift/drift.dart';
import '../database.dart';

class AppIconsDao {
  final AppDatabase _db;
  AppIconsDao(this._db);

  Future<List<Map<String, dynamic>>> getAll() async {
    final rows = await _db.customSelect('SELECT * FROM app_icons').get();
    return rows.map((r) => r.data).toList();
  }

  Future<void> upsert(String pkg, String iconUrl) async {
    await _db.customInsert(
      'INSERT OR REPLACE INTO app_icons (package, icon_url) VALUES (?, ?)',
      variables: [Variable(pkg), Variable(iconUrl)],
    );
  }

  Future<void> clear() async {
    await _db.customStatement('DELETE FROM app_icons');
  }
}
