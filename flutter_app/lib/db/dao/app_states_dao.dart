// DAO for the AppStates singleton row.
//
// The table always holds exactly one row. The first read auto-creates it
// with default values (empty expansion list).
import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/app_states.dart';

part 'app_states_dao.g.dart';

@DriftAccessor(tables: [AppStates])
class AppStatesDao extends DatabaseAccessor<AppDatabase>
    with _$AppStatesDaoMixin {
  AppStatesDao(super.db);

  /// Get the singleton row, creating it on first access.
  Future<AppState> getAppState() async {
    final states = await select(appStates).get();
    if (states.isEmpty) {
      final id = await into(appStates).insert(
        AppStatesCompanion.insert(expandedSerials: '[]'),
      );
      return (select(appStates)..where((t) => t.id.equals(id))).getSingle();
    }
    return states.first;
  }

  /// Watch the singleton row. Emits `null` if the row is missing.
  Stream<AppState?> watchAppState() {
    return (select(appStates)..limit(1)).watchSingleOrNull();
  }

  /// Patch one or more fields on the singleton row. Pass only the fields you
  /// want to change — others are left untouched.
  Future<void> updateAppState({
    String? activeSerial,
    String? activeKey,
    List<String>? expandedSerials,
    DateTime? lastSuccessfulRefresh,
  }) async {
    final state = await getAppState();
    await (update(appStates)..where((t) => t.id.equals(state.id))).write(
      AppStatesCompanion(
        activeSerial: activeSerial != null ? Value(activeSerial) : const Value.absent(),
        activeKey: activeKey != null ? Value(activeKey) : const Value.absent(),
        expandedSerials: expandedSerials != null
            ? Value(_listToJson(expandedSerials))
            : const Value.absent(),
        lastSuccessfulRefresh: lastSuccessfulRefresh != null
            ? Value(lastSuccessfulRefresh)
            : const Value.absent(),
      ),
    );
  }

  /// Parse the expanded-serials JSON array.
  Future<List<String>> getExpandedSerials() async {
    final state = await getAppState();
    return _jsonToList(state.expandedSerials);
  }

  /// Read the active sidebar key (e.g. "<serial>_logcat" or "_backend_logs").
  Future<String?> getActiveKey() async {
    final state = await getAppState();
    return state.activeKey;
  }

  /// Read the currently active device serial.
  Future<String?> getActiveSerial() async {
    final state = await getAppState();
    return state.activeSerial;
  }

  // --- JSON helpers --------------------------------------------------------

  String _listToJson(List<String> list) {
    return '[${list.map((s) => '"$s"').join(',')}]';
  }

  List<String> _jsonToList(String json) {
    if (json.isEmpty || json == '[]') return [];
    final content = json.substring(1, json.length - 1);
    if (content.isEmpty) return [];
    return content.split(',').map((s) => s.trim().replaceAll('"', '')).toList();
  }
}
