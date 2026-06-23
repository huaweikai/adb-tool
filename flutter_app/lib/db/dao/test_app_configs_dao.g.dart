// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test_app_configs_dao.dart';

// ignore_for_file: type=lint
mixin _$TestAppConfigsDaoMixin on DatabaseAccessor<AppDatabase> {
  $TestAppConfigsTable get testAppConfigs => attachedDatabase.testAppConfigs;
  TestAppConfigsDaoManager get managers => TestAppConfigsDaoManager(this);
}

class TestAppConfigsDaoManager {
  final _$TestAppConfigsDaoMixin _db;
  TestAppConfigsDaoManager(this._db);
  $$TestAppConfigsTableTableManager get testAppConfigs =>
      $$TestAppConfigsTableTableManager(
          _db.attachedDatabase, _db.testAppConfigs);
}
