// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_devices_dao.dart';

// ignore_for_file: type=lint
mixin _$SavedDevicesDaoMixin on DatabaseAccessor<AppDatabase> {
  $SavedDevicesTable get savedDevices => attachedDatabase.savedDevices;
  SavedDevicesDaoManager get managers => SavedDevicesDaoManager(this);
}

class SavedDevicesDaoManager {
  final _$SavedDevicesDaoMixin _db;
  SavedDevicesDaoManager(this._db);
  $$SavedDevicesTableTableManager get savedDevices =>
      $$SavedDevicesTableTableManager(_db.attachedDatabase, _db.savedDevices);
}
