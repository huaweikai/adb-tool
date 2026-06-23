// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scrcpy_options_dao.dart';

// ignore_for_file: type=lint
mixin _$ScrcpyOptionsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ScrcpyOptions_Table get scrcpyOptions => attachedDatabase.scrcpyOptions;
  ScrcpyOptionsDaoManager get managers => ScrcpyOptionsDaoManager(this);
}

class ScrcpyOptionsDaoManager {
  final _$ScrcpyOptionsDaoMixin _db;
  ScrcpyOptionsDaoManager(this._db);
  $$ScrcpyOptions_TableTableManager get scrcpyOptions =>
      $$ScrcpyOptions_TableTableManager(
          _db.attachedDatabase, _db.scrcpyOptions);
}
