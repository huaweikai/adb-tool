// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_states_dao.dart';

// ignore_for_file: type=lint
mixin _$AppStatesDaoMixin on DatabaseAccessor<AppDatabase> {
  $AppStatesTable get appStates => attachedDatabase.appStates;
  AppStatesDaoManager get managers => AppStatesDaoManager(this);
}

class AppStatesDaoManager {
  final _$AppStatesDaoMixin _db;
  AppStatesDaoManager(this._db);
  $$AppStatesTableTableManager get appStates =>
      $$AppStatesTableTableManager(_db.attachedDatabase, _db.appStates);
}
