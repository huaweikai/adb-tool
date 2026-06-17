// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SavedDevicesTable extends SavedDevices
    with TableInfo<$SavedDevicesTable, SavedDevice> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedDevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serialMeta = const VerificationMeta('serial');
  @override
  late final GeneratedColumn<String> serial = GeneratedColumn<String>(
      'serial', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
      'model', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _brandMeta = const VerificationMeta('brand');
  @override
  late final GeneratedColumn<String> brand = GeneratedColumn<String>(
      'brand', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sdkMeta = const VerificationMeta('sdk');
  @override
  late final GeneratedColumn<String> sdk = GeneratedColumn<String>(
      'sdk', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isConnectedMeta =
      const VerificationMeta('isConnected');
  @override
  late final GeneratedColumn<bool> isConnected = GeneratedColumn<bool>(
      'is_connected', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_connected" IN (0, 1))'));
  static const VerificationMeta _firstSeenAtMeta =
      const VerificationMeta('firstSeenAt');
  @override
  late final GeneratedColumn<DateTime> firstSeenAt = GeneratedColumn<DateTime>(
      'first_seen_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _lastSeenAtMeta =
      const VerificationMeta('lastSeenAt');
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
      'last_seen_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [serial, model, brand, sdk, isConnected, firstSeenAt, lastSeenAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_devices';
  @override
  VerificationContext validateIntegrity(Insertable<SavedDevice> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('serial')) {
      context.handle(_serialMeta,
          serial.isAcceptableOrUnknown(data['serial']!, _serialMeta));
    } else if (isInserting) {
      context.missing(_serialMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
          _modelMeta, model.isAcceptableOrUnknown(data['model']!, _modelMeta));
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('brand')) {
      context.handle(
          _brandMeta, brand.isAcceptableOrUnknown(data['brand']!, _brandMeta));
    } else if (isInserting) {
      context.missing(_brandMeta);
    }
    if (data.containsKey('sdk')) {
      context.handle(
          _sdkMeta, sdk.isAcceptableOrUnknown(data['sdk']!, _sdkMeta));
    } else if (isInserting) {
      context.missing(_sdkMeta);
    }
    if (data.containsKey('is_connected')) {
      context.handle(
          _isConnectedMeta,
          isConnected.isAcceptableOrUnknown(
              data['is_connected']!, _isConnectedMeta));
    } else if (isInserting) {
      context.missing(_isConnectedMeta);
    }
    if (data.containsKey('first_seen_at')) {
      context.handle(
          _firstSeenAtMeta,
          firstSeenAt.isAcceptableOrUnknown(
              data['first_seen_at']!, _firstSeenAtMeta));
    } else if (isInserting) {
      context.missing(_firstSeenAtMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
          _lastSeenAtMeta,
          lastSeenAt.isAcceptableOrUnknown(
              data['last_seen_at']!, _lastSeenAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serial};
  @override
  SavedDevice map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedDevice(
      serial: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}serial'])!,
      model: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}model'])!,
      brand: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}brand'])!,
      sdk: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sdk'])!,
      isConnected: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_connected'])!,
      firstSeenAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}first_seen_at'])!,
      lastSeenAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_seen_at']),
    );
  }

  @override
  $SavedDevicesTable createAlias(String alias) {
    return $SavedDevicesTable(attachedDatabase, alias);
  }
}

class SavedDevice extends DataClass implements Insertable<SavedDevice> {
  final String serial;
  final String model;
  final String brand;
  final String sdk;
  final bool isConnected;
  final DateTime firstSeenAt;
  final DateTime? lastSeenAt;
  const SavedDevice(
      {required this.serial,
      required this.model,
      required this.brand,
      required this.sdk,
      required this.isConnected,
      required this.firstSeenAt,
      this.lastSeenAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['serial'] = Variable<String>(serial);
    map['model'] = Variable<String>(model);
    map['brand'] = Variable<String>(brand);
    map['sdk'] = Variable<String>(sdk);
    map['is_connected'] = Variable<bool>(isConnected);
    map['first_seen_at'] = Variable<DateTime>(firstSeenAt);
    if (!nullToAbsent || lastSeenAt != null) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    }
    return map;
  }

  SavedDevicesCompanion toCompanion(bool nullToAbsent) {
    return SavedDevicesCompanion(
      serial: Value(serial),
      model: Value(model),
      brand: Value(brand),
      sdk: Value(sdk),
      isConnected: Value(isConnected),
      firstSeenAt: Value(firstSeenAt),
      lastSeenAt: lastSeenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeenAt),
    );
  }

  factory SavedDevice.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedDevice(
      serial: serializer.fromJson<String>(json['serial']),
      model: serializer.fromJson<String>(json['model']),
      brand: serializer.fromJson<String>(json['brand']),
      sdk: serializer.fromJson<String>(json['sdk']),
      isConnected: serializer.fromJson<bool>(json['isConnected']),
      firstSeenAt: serializer.fromJson<DateTime>(json['firstSeenAt']),
      lastSeenAt: serializer.fromJson<DateTime?>(json['lastSeenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serial': serializer.toJson<String>(serial),
      'model': serializer.toJson<String>(model),
      'brand': serializer.toJson<String>(brand),
      'sdk': serializer.toJson<String>(sdk),
      'isConnected': serializer.toJson<bool>(isConnected),
      'firstSeenAt': serializer.toJson<DateTime>(firstSeenAt),
      'lastSeenAt': serializer.toJson<DateTime?>(lastSeenAt),
    };
  }

  SavedDevice copyWith(
          {String? serial,
          String? model,
          String? brand,
          String? sdk,
          bool? isConnected,
          DateTime? firstSeenAt,
          Value<DateTime?> lastSeenAt = const Value.absent()}) =>
      SavedDevice(
        serial: serial ?? this.serial,
        model: model ?? this.model,
        brand: brand ?? this.brand,
        sdk: sdk ?? this.sdk,
        isConnected: isConnected ?? this.isConnected,
        firstSeenAt: firstSeenAt ?? this.firstSeenAt,
        lastSeenAt: lastSeenAt.present ? lastSeenAt.value : this.lastSeenAt,
      );
  SavedDevice copyWithCompanion(SavedDevicesCompanion data) {
    return SavedDevice(
      serial: data.serial.present ? data.serial.value : this.serial,
      model: data.model.present ? data.model.value : this.model,
      brand: data.brand.present ? data.brand.value : this.brand,
      sdk: data.sdk.present ? data.sdk.value : this.sdk,
      isConnected:
          data.isConnected.present ? data.isConnected.value : this.isConnected,
      firstSeenAt:
          data.firstSeenAt.present ? data.firstSeenAt.value : this.firstSeenAt,
      lastSeenAt:
          data.lastSeenAt.present ? data.lastSeenAt.value : this.lastSeenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedDevice(')
          ..write('serial: $serial, ')
          ..write('model: $model, ')
          ..write('brand: $brand, ')
          ..write('sdk: $sdk, ')
          ..write('isConnected: $isConnected, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('lastSeenAt: $lastSeenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      serial, model, brand, sdk, isConnected, firstSeenAt, lastSeenAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedDevice &&
          other.serial == this.serial &&
          other.model == this.model &&
          other.brand == this.brand &&
          other.sdk == this.sdk &&
          other.isConnected == this.isConnected &&
          other.firstSeenAt == this.firstSeenAt &&
          other.lastSeenAt == this.lastSeenAt);
}

class SavedDevicesCompanion extends UpdateCompanion<SavedDevice> {
  final Value<String> serial;
  final Value<String> model;
  final Value<String> brand;
  final Value<String> sdk;
  final Value<bool> isConnected;
  final Value<DateTime> firstSeenAt;
  final Value<DateTime?> lastSeenAt;
  final Value<int> rowid;
  const SavedDevicesCompanion({
    this.serial = const Value.absent(),
    this.model = const Value.absent(),
    this.brand = const Value.absent(),
    this.sdk = const Value.absent(),
    this.isConnected = const Value.absent(),
    this.firstSeenAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedDevicesCompanion.insert({
    required String serial,
    required String model,
    required String brand,
    required String sdk,
    required bool isConnected,
    required DateTime firstSeenAt,
    this.lastSeenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : serial = Value(serial),
        model = Value(model),
        brand = Value(brand),
        sdk = Value(sdk),
        isConnected = Value(isConnected),
        firstSeenAt = Value(firstSeenAt);
  static Insertable<SavedDevice> custom({
    Expression<String>? serial,
    Expression<String>? model,
    Expression<String>? brand,
    Expression<String>? sdk,
    Expression<bool>? isConnected,
    Expression<DateTime>? firstSeenAt,
    Expression<DateTime>? lastSeenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serial != null) 'serial': serial,
      if (model != null) 'model': model,
      if (brand != null) 'brand': brand,
      if (sdk != null) 'sdk': sdk,
      if (isConnected != null) 'is_connected': isConnected,
      if (firstSeenAt != null) 'first_seen_at': firstSeenAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedDevicesCompanion copyWith(
      {Value<String>? serial,
      Value<String>? model,
      Value<String>? brand,
      Value<String>? sdk,
      Value<bool>? isConnected,
      Value<DateTime>? firstSeenAt,
      Value<DateTime?>? lastSeenAt,
      Value<int>? rowid}) {
    return SavedDevicesCompanion(
      serial: serial ?? this.serial,
      model: model ?? this.model,
      brand: brand ?? this.brand,
      sdk: sdk ?? this.sdk,
      isConnected: isConnected ?? this.isConnected,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serial.present) {
      map['serial'] = Variable<String>(serial.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (brand.present) {
      map['brand'] = Variable<String>(brand.value);
    }
    if (sdk.present) {
      map['sdk'] = Variable<String>(sdk.value);
    }
    if (isConnected.present) {
      map['is_connected'] = Variable<bool>(isConnected.value);
    }
    if (firstSeenAt.present) {
      map['first_seen_at'] = Variable<DateTime>(firstSeenAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedDevicesCompanion(')
          ..write('serial: $serial, ')
          ..write('model: $model, ')
          ..write('brand: $brand, ')
          ..write('sdk: $sdk, ')
          ..write('isConnected: $isConnected, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppStatesTable extends AppStates
    with TableInfo<$AppStatesTable, AppState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _activeSerialMeta =
      const VerificationMeta('activeSerial');
  @override
  late final GeneratedColumn<String> activeSerial = GeneratedColumn<String>(
      'active_serial', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _activeKeyMeta =
      const VerificationMeta('activeKey');
  @override
  late final GeneratedColumn<String> activeKey = GeneratedColumn<String>(
      'active_key', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _expandedSerialsMeta =
      const VerificationMeta('expandedSerials');
  @override
  late final GeneratedColumn<String> expandedSerials = GeneratedColumn<String>(
      'expanded_serials', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastSuccessfulRefreshMeta =
      const VerificationMeta('lastSuccessfulRefresh');
  @override
  late final GeneratedColumn<DateTime> lastSuccessfulRefresh =
      GeneratedColumn<DateTime>('last_successful_refresh', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, activeSerial, activeKey, expandedSerials, lastSuccessfulRefresh];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_states';
  @override
  VerificationContext validateIntegrity(Insertable<AppState> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('active_serial')) {
      context.handle(
          _activeSerialMeta,
          activeSerial.isAcceptableOrUnknown(
              data['active_serial']!, _activeSerialMeta));
    }
    if (data.containsKey('active_key')) {
      context.handle(_activeKeyMeta,
          activeKey.isAcceptableOrUnknown(data['active_key']!, _activeKeyMeta));
    }
    if (data.containsKey('expanded_serials')) {
      context.handle(
          _expandedSerialsMeta,
          expandedSerials.isAcceptableOrUnknown(
              data['expanded_serials']!, _expandedSerialsMeta));
    } else if (isInserting) {
      context.missing(_expandedSerialsMeta);
    }
    if (data.containsKey('last_successful_refresh')) {
      context.handle(
          _lastSuccessfulRefreshMeta,
          lastSuccessfulRefresh.isAcceptableOrUnknown(
              data['last_successful_refresh']!, _lastSuccessfulRefreshMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppState(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      activeSerial: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}active_serial']),
      activeKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}active_key']),
      expandedSerials: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}expanded_serials'])!,
      lastSuccessfulRefresh: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}last_successful_refresh']),
    );
  }

  @override
  $AppStatesTable createAlias(String alias) {
    return $AppStatesTable(attachedDatabase, alias);
  }
}

class AppState extends DataClass implements Insertable<AppState> {
  final int id;
  final String? activeSerial;
  final String? activeKey;
  final String expandedSerials;
  final DateTime? lastSuccessfulRefresh;
  const AppState(
      {required this.id,
      this.activeSerial,
      this.activeKey,
      required this.expandedSerials,
      this.lastSuccessfulRefresh});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || activeSerial != null) {
      map['active_serial'] = Variable<String>(activeSerial);
    }
    if (!nullToAbsent || activeKey != null) {
      map['active_key'] = Variable<String>(activeKey);
    }
    map['expanded_serials'] = Variable<String>(expandedSerials);
    if (!nullToAbsent || lastSuccessfulRefresh != null) {
      map['last_successful_refresh'] =
          Variable<DateTime>(lastSuccessfulRefresh);
    }
    return map;
  }

  AppStatesCompanion toCompanion(bool nullToAbsent) {
    return AppStatesCompanion(
      id: Value(id),
      activeSerial: activeSerial == null && nullToAbsent
          ? const Value.absent()
          : Value(activeSerial),
      activeKey: activeKey == null && nullToAbsent
          ? const Value.absent()
          : Value(activeKey),
      expandedSerials: Value(expandedSerials),
      lastSuccessfulRefresh: lastSuccessfulRefresh == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSuccessfulRefresh),
    );
  }

  factory AppState.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppState(
      id: serializer.fromJson<int>(json['id']),
      activeSerial: serializer.fromJson<String?>(json['activeSerial']),
      activeKey: serializer.fromJson<String?>(json['activeKey']),
      expandedSerials: serializer.fromJson<String>(json['expandedSerials']),
      lastSuccessfulRefresh:
          serializer.fromJson<DateTime?>(json['lastSuccessfulRefresh']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'activeSerial': serializer.toJson<String?>(activeSerial),
      'activeKey': serializer.toJson<String?>(activeKey),
      'expandedSerials': serializer.toJson<String>(expandedSerials),
      'lastSuccessfulRefresh':
          serializer.toJson<DateTime?>(lastSuccessfulRefresh),
    };
  }

  AppState copyWith(
          {int? id,
          Value<String?> activeSerial = const Value.absent(),
          Value<String?> activeKey = const Value.absent(),
          String? expandedSerials,
          Value<DateTime?> lastSuccessfulRefresh = const Value.absent()}) =>
      AppState(
        id: id ?? this.id,
        activeSerial:
            activeSerial.present ? activeSerial.value : this.activeSerial,
        activeKey: activeKey.present ? activeKey.value : this.activeKey,
        expandedSerials: expandedSerials ?? this.expandedSerials,
        lastSuccessfulRefresh: lastSuccessfulRefresh.present
            ? lastSuccessfulRefresh.value
            : this.lastSuccessfulRefresh,
      );
  AppState copyWithCompanion(AppStatesCompanion data) {
    return AppState(
      id: data.id.present ? data.id.value : this.id,
      activeSerial: data.activeSerial.present
          ? data.activeSerial.value
          : this.activeSerial,
      activeKey: data.activeKey.present ? data.activeKey.value : this.activeKey,
      expandedSerials: data.expandedSerials.present
          ? data.expandedSerials.value
          : this.expandedSerials,
      lastSuccessfulRefresh: data.lastSuccessfulRefresh.present
          ? data.lastSuccessfulRefresh.value
          : this.lastSuccessfulRefresh,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppState(')
          ..write('id: $id, ')
          ..write('activeSerial: $activeSerial, ')
          ..write('activeKey: $activeKey, ')
          ..write('expandedSerials: $expandedSerials, ')
          ..write('lastSuccessfulRefresh: $lastSuccessfulRefresh')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, activeSerial, activeKey, expandedSerials, lastSuccessfulRefresh);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppState &&
          other.id == this.id &&
          other.activeSerial == this.activeSerial &&
          other.activeKey == this.activeKey &&
          other.expandedSerials == this.expandedSerials &&
          other.lastSuccessfulRefresh == this.lastSuccessfulRefresh);
}

class AppStatesCompanion extends UpdateCompanion<AppState> {
  final Value<int> id;
  final Value<String?> activeSerial;
  final Value<String?> activeKey;
  final Value<String> expandedSerials;
  final Value<DateTime?> lastSuccessfulRefresh;
  const AppStatesCompanion({
    this.id = const Value.absent(),
    this.activeSerial = const Value.absent(),
    this.activeKey = const Value.absent(),
    this.expandedSerials = const Value.absent(),
    this.lastSuccessfulRefresh = const Value.absent(),
  });
  AppStatesCompanion.insert({
    this.id = const Value.absent(),
    this.activeSerial = const Value.absent(),
    this.activeKey = const Value.absent(),
    required String expandedSerials,
    this.lastSuccessfulRefresh = const Value.absent(),
  }) : expandedSerials = Value(expandedSerials);
  static Insertable<AppState> custom({
    Expression<int>? id,
    Expression<String>? activeSerial,
    Expression<String>? activeKey,
    Expression<String>? expandedSerials,
    Expression<DateTime>? lastSuccessfulRefresh,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (activeSerial != null) 'active_serial': activeSerial,
      if (activeKey != null) 'active_key': activeKey,
      if (expandedSerials != null) 'expanded_serials': expandedSerials,
      if (lastSuccessfulRefresh != null)
        'last_successful_refresh': lastSuccessfulRefresh,
    });
  }

  AppStatesCompanion copyWith(
      {Value<int>? id,
      Value<String?>? activeSerial,
      Value<String?>? activeKey,
      Value<String>? expandedSerials,
      Value<DateTime?>? lastSuccessfulRefresh}) {
    return AppStatesCompanion(
      id: id ?? this.id,
      activeSerial: activeSerial ?? this.activeSerial,
      activeKey: activeKey ?? this.activeKey,
      expandedSerials: expandedSerials ?? this.expandedSerials,
      lastSuccessfulRefresh:
          lastSuccessfulRefresh ?? this.lastSuccessfulRefresh,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (activeSerial.present) {
      map['active_serial'] = Variable<String>(activeSerial.value);
    }
    if (activeKey.present) {
      map['active_key'] = Variable<String>(activeKey.value);
    }
    if (expandedSerials.present) {
      map['expanded_serials'] = Variable<String>(expandedSerials.value);
    }
    if (lastSuccessfulRefresh.present) {
      map['last_successful_refresh'] =
          Variable<DateTime>(lastSuccessfulRefresh.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppStatesCompanion(')
          ..write('id: $id, ')
          ..write('activeSerial: $activeSerial, ')
          ..write('activeKey: $activeKey, ')
          ..write('expandedSerials: $expandedSerials, ')
          ..write('lastSuccessfulRefresh: $lastSuccessfulRefresh')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SavedDevicesTable savedDevices = $SavedDevicesTable(this);
  late final $AppStatesTable appStates = $AppStatesTable(this);
  late final SavedDevicesDao savedDevicesDao =
      SavedDevicesDao(this as AppDatabase);
  late final AppStatesDao appStatesDao = AppStatesDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [savedDevices, appStates];
}

typedef $$SavedDevicesTableCreateCompanionBuilder = SavedDevicesCompanion
    Function({
  required String serial,
  required String model,
  required String brand,
  required String sdk,
  required bool isConnected,
  required DateTime firstSeenAt,
  Value<DateTime?> lastSeenAt,
  Value<int> rowid,
});
typedef $$SavedDevicesTableUpdateCompanionBuilder = SavedDevicesCompanion
    Function({
  Value<String> serial,
  Value<String> model,
  Value<String> brand,
  Value<String> sdk,
  Value<bool> isConnected,
  Value<DateTime> firstSeenAt,
  Value<DateTime?> lastSeenAt,
  Value<int> rowid,
});

class $$SavedDevicesTableFilterComposer
    extends Composer<_$AppDatabase, $SavedDevicesTable> {
  $$SavedDevicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serial => $composableBuilder(
      column: $table.serial, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get model => $composableBuilder(
      column: $table.model, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get brand => $composableBuilder(
      column: $table.brand, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sdk => $composableBuilder(
      column: $table.sdk, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isConnected => $composableBuilder(
      column: $table.isConnected, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get firstSeenAt => $composableBuilder(
      column: $table.firstSeenAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => ColumnFilters(column));
}

class $$SavedDevicesTableOrderingComposer
    extends Composer<_$AppDatabase, $SavedDevicesTable> {
  $$SavedDevicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serial => $composableBuilder(
      column: $table.serial, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get model => $composableBuilder(
      column: $table.model, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get brand => $composableBuilder(
      column: $table.brand, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sdk => $composableBuilder(
      column: $table.sdk, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isConnected => $composableBuilder(
      column: $table.isConnected, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get firstSeenAt => $composableBuilder(
      column: $table.firstSeenAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => ColumnOrderings(column));
}

class $$SavedDevicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavedDevicesTable> {
  $$SavedDevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serial =>
      $composableBuilder(column: $table.serial, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get brand =>
      $composableBuilder(column: $table.brand, builder: (column) => column);

  GeneratedColumn<String> get sdk =>
      $composableBuilder(column: $table.sdk, builder: (column) => column);

  GeneratedColumn<bool> get isConnected => $composableBuilder(
      column: $table.isConnected, builder: (column) => column);

  GeneratedColumn<DateTime> get firstSeenAt => $composableBuilder(
      column: $table.firstSeenAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => column);
}

class $$SavedDevicesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SavedDevicesTable,
    SavedDevice,
    $$SavedDevicesTableFilterComposer,
    $$SavedDevicesTableOrderingComposer,
    $$SavedDevicesTableAnnotationComposer,
    $$SavedDevicesTableCreateCompanionBuilder,
    $$SavedDevicesTableUpdateCompanionBuilder,
    (
      SavedDevice,
      BaseReferences<_$AppDatabase, $SavedDevicesTable, SavedDevice>
    ),
    SavedDevice,
    PrefetchHooks Function()> {
  $$SavedDevicesTableTableManager(_$AppDatabase db, $SavedDevicesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedDevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedDevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedDevicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> serial = const Value.absent(),
            Value<String> model = const Value.absent(),
            Value<String> brand = const Value.absent(),
            Value<String> sdk = const Value.absent(),
            Value<bool> isConnected = const Value.absent(),
            Value<DateTime> firstSeenAt = const Value.absent(),
            Value<DateTime?> lastSeenAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SavedDevicesCompanion(
            serial: serial,
            model: model,
            brand: brand,
            sdk: sdk,
            isConnected: isConnected,
            firstSeenAt: firstSeenAt,
            lastSeenAt: lastSeenAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String serial,
            required String model,
            required String brand,
            required String sdk,
            required bool isConnected,
            required DateTime firstSeenAt,
            Value<DateTime?> lastSeenAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SavedDevicesCompanion.insert(
            serial: serial,
            model: model,
            brand: brand,
            sdk: sdk,
            isConnected: isConnected,
            firstSeenAt: firstSeenAt,
            lastSeenAt: lastSeenAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SavedDevicesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SavedDevicesTable,
    SavedDevice,
    $$SavedDevicesTableFilterComposer,
    $$SavedDevicesTableOrderingComposer,
    $$SavedDevicesTableAnnotationComposer,
    $$SavedDevicesTableCreateCompanionBuilder,
    $$SavedDevicesTableUpdateCompanionBuilder,
    (
      SavedDevice,
      BaseReferences<_$AppDatabase, $SavedDevicesTable, SavedDevice>
    ),
    SavedDevice,
    PrefetchHooks Function()>;
typedef $$AppStatesTableCreateCompanionBuilder = AppStatesCompanion Function({
  Value<int> id,
  Value<String?> activeSerial,
  Value<String?> activeKey,
  required String expandedSerials,
  Value<DateTime?> lastSuccessfulRefresh,
});
typedef $$AppStatesTableUpdateCompanionBuilder = AppStatesCompanion Function({
  Value<int> id,
  Value<String?> activeSerial,
  Value<String?> activeKey,
  Value<String> expandedSerials,
  Value<DateTime?> lastSuccessfulRefresh,
});

class $$AppStatesTableFilterComposer
    extends Composer<_$AppDatabase, $AppStatesTable> {
  $$AppStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get activeSerial => $composableBuilder(
      column: $table.activeSerial, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get activeKey => $composableBuilder(
      column: $table.activeKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get expandedSerials => $composableBuilder(
      column: $table.expandedSerials,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSuccessfulRefresh => $composableBuilder(
      column: $table.lastSuccessfulRefresh,
      builder: (column) => ColumnFilters(column));
}

class $$AppStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $AppStatesTable> {
  $$AppStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get activeSerial => $composableBuilder(
      column: $table.activeSerial,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get activeKey => $composableBuilder(
      column: $table.activeKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get expandedSerials => $composableBuilder(
      column: $table.expandedSerials,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSuccessfulRefresh => $composableBuilder(
      column: $table.lastSuccessfulRefresh,
      builder: (column) => ColumnOrderings(column));
}

class $$AppStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppStatesTable> {
  $$AppStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get activeSerial => $composableBuilder(
      column: $table.activeSerial, builder: (column) => column);

  GeneratedColumn<String> get activeKey =>
      $composableBuilder(column: $table.activeKey, builder: (column) => column);

  GeneratedColumn<String> get expandedSerials => $composableBuilder(
      column: $table.expandedSerials, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSuccessfulRefresh => $composableBuilder(
      column: $table.lastSuccessfulRefresh, builder: (column) => column);
}

class $$AppStatesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppStatesTable,
    AppState,
    $$AppStatesTableFilterComposer,
    $$AppStatesTableOrderingComposer,
    $$AppStatesTableAnnotationComposer,
    $$AppStatesTableCreateCompanionBuilder,
    $$AppStatesTableUpdateCompanionBuilder,
    (AppState, BaseReferences<_$AppDatabase, $AppStatesTable, AppState>),
    AppState,
    PrefetchHooks Function()> {
  $$AppStatesTableTableManager(_$AppDatabase db, $AppStatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> activeSerial = const Value.absent(),
            Value<String?> activeKey = const Value.absent(),
            Value<String> expandedSerials = const Value.absent(),
            Value<DateTime?> lastSuccessfulRefresh = const Value.absent(),
          }) =>
              AppStatesCompanion(
            id: id,
            activeSerial: activeSerial,
            activeKey: activeKey,
            expandedSerials: expandedSerials,
            lastSuccessfulRefresh: lastSuccessfulRefresh,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> activeSerial = const Value.absent(),
            Value<String?> activeKey = const Value.absent(),
            required String expandedSerials,
            Value<DateTime?> lastSuccessfulRefresh = const Value.absent(),
          }) =>
              AppStatesCompanion.insert(
            id: id,
            activeSerial: activeSerial,
            activeKey: activeKey,
            expandedSerials: expandedSerials,
            lastSuccessfulRefresh: lastSuccessfulRefresh,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppStatesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppStatesTable,
    AppState,
    $$AppStatesTableFilterComposer,
    $$AppStatesTableOrderingComposer,
    $$AppStatesTableAnnotationComposer,
    $$AppStatesTableCreateCompanionBuilder,
    $$AppStatesTableUpdateCompanionBuilder,
    (AppState, BaseReferences<_$AppDatabase, $AppStatesTable, AppState>),
    AppState,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SavedDevicesTableTableManager get savedDevices =>
      $$SavedDevicesTableTableManager(_db, _db.savedDevices);
  $$AppStatesTableTableManager get appStates =>
      $$AppStatesTableTableManager(_db, _db.appStates);
}
