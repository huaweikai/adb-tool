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

class $TestSessionsTable extends TestSessions
    with TableInfo<$TestSessionsTable, TestSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TestSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<TestSessionStatus, int> status =
      GeneratedColumn<int>('status', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<TestSessionStatus>(
              $TestSessionsTable.$converterstatus);
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
      'started_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _endedAtMeta =
      const VerificationMeta('endedAt');
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
      'ended_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deviceSerialMeta =
      const VerificationMeta('deviceSerial');
  @override
  late final GeneratedColumn<String> deviceSerial = GeneratedColumn<String>(
      'device_serial', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES saved_devices (serial)'));
  static const VerificationMeta _deviceModelMeta =
      const VerificationMeta('deviceModel');
  @override
  late final GeneratedColumn<String> deviceModel = GeneratedColumn<String>(
      'device_model', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _deviceBrandMeta =
      const VerificationMeta('deviceBrand');
  @override
  late final GeneratedColumn<String> deviceBrand = GeneratedColumn<String>(
      'device_brand', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _deviceSdkMeta =
      const VerificationMeta('deviceSdk');
  @override
  late final GeneratedColumn<String> deviceSdk = GeneratedColumn<String>(
      'device_sdk', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _packageNameMeta =
      const VerificationMeta('packageName');
  @override
  late final GeneratedColumn<String> packageName = GeneratedColumn<String>(
      'package_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        type,
        status,
        startedAt,
        endedAt,
        deviceSerial,
        deviceModel,
        deviceBrand,
        deviceSdk,
        packageName,
        note
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'test_sessions';
  @override
  VerificationContext validateIntegrity(Insertable<TestSessionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(_endedAtMeta,
          endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta));
    }
    if (data.containsKey('device_serial')) {
      context.handle(
          _deviceSerialMeta,
          deviceSerial.isAcceptableOrUnknown(
              data['device_serial']!, _deviceSerialMeta));
    } else if (isInserting) {
      context.missing(_deviceSerialMeta);
    }
    if (data.containsKey('device_model')) {
      context.handle(
          _deviceModelMeta,
          deviceModel.isAcceptableOrUnknown(
              data['device_model']!, _deviceModelMeta));
    }
    if (data.containsKey('device_brand')) {
      context.handle(
          _deviceBrandMeta,
          deviceBrand.isAcceptableOrUnknown(
              data['device_brand']!, _deviceBrandMeta));
    }
    if (data.containsKey('device_sdk')) {
      context.handle(_deviceSdkMeta,
          deviceSdk.isAcceptableOrUnknown(data['device_sdk']!, _deviceSdkMeta));
    }
    if (data.containsKey('package_name')) {
      context.handle(
          _packageNameMeta,
          packageName.isAcceptableOrUnknown(
              data['package_name']!, _packageNameMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TestSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TestSessionRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      status: $TestSessionsTable.$converterstatus.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!),
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}started_at'])!,
      endedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}ended_at']),
      deviceSerial: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_serial'])!,
      deviceModel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_model'])!,
      deviceBrand: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_brand'])!,
      deviceSdk: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_sdk'])!,
      packageName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}package_name'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note'])!,
    );
  }

  @override
  $TestSessionsTable createAlias(String alias) {
    return $TestSessionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TestSessionStatus, int, int> $converterstatus =
      const EnumIndexConverter<TestSessionStatus>(TestSessionStatus.values);
}

class TestSessionRow extends DataClass implements Insertable<TestSessionRow> {
  final String id;
  final String name;
  final String type;
  final TestSessionStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String deviceSerial;
  final String deviceModel;
  final String deviceBrand;
  final String deviceSdk;
  final String packageName;
  final String note;
  const TestSessionRow(
      {required this.id,
      required this.name,
      required this.type,
      required this.status,
      required this.startedAt,
      this.endedAt,
      required this.deviceSerial,
      required this.deviceModel,
      required this.deviceBrand,
      required this.deviceSdk,
      required this.packageName,
      required this.note});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    {
      map['status'] =
          Variable<int>($TestSessionsTable.$converterstatus.toSql(status));
    }
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['device_serial'] = Variable<String>(deviceSerial);
    map['device_model'] = Variable<String>(deviceModel);
    map['device_brand'] = Variable<String>(deviceBrand);
    map['device_sdk'] = Variable<String>(deviceSdk);
    map['package_name'] = Variable<String>(packageName);
    map['note'] = Variable<String>(note);
    return map;
  }

  TestSessionsCompanion toCompanion(bool nullToAbsent) {
    return TestSessionsCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      status: Value(status),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      deviceSerial: Value(deviceSerial),
      deviceModel: Value(deviceModel),
      deviceBrand: Value(deviceBrand),
      deviceSdk: Value(deviceSdk),
      packageName: Value(packageName),
      note: Value(note),
    );
  }

  factory TestSessionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TestSessionRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      status: $TestSessionsTable.$converterstatus
          .fromJson(serializer.fromJson<int>(json['status'])),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      deviceSerial: serializer.fromJson<String>(json['deviceSerial']),
      deviceModel: serializer.fromJson<String>(json['deviceModel']),
      deviceBrand: serializer.fromJson<String>(json['deviceBrand']),
      deviceSdk: serializer.fromJson<String>(json['deviceSdk']),
      packageName: serializer.fromJson<String>(json['packageName']),
      note: serializer.fromJson<String>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'status': serializer
          .toJson<int>($TestSessionsTable.$converterstatus.toJson(status)),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'deviceSerial': serializer.toJson<String>(deviceSerial),
      'deviceModel': serializer.toJson<String>(deviceModel),
      'deviceBrand': serializer.toJson<String>(deviceBrand),
      'deviceSdk': serializer.toJson<String>(deviceSdk),
      'packageName': serializer.toJson<String>(packageName),
      'note': serializer.toJson<String>(note),
    };
  }

  TestSessionRow copyWith(
          {String? id,
          String? name,
          String? type,
          TestSessionStatus? status,
          DateTime? startedAt,
          Value<DateTime?> endedAt = const Value.absent(),
          String? deviceSerial,
          String? deviceModel,
          String? deviceBrand,
          String? deviceSdk,
          String? packageName,
          String? note}) =>
      TestSessionRow(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        status: status ?? this.status,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt.present ? endedAt.value : this.endedAt,
        deviceSerial: deviceSerial ?? this.deviceSerial,
        deviceModel: deviceModel ?? this.deviceModel,
        deviceBrand: deviceBrand ?? this.deviceBrand,
        deviceSdk: deviceSdk ?? this.deviceSdk,
        packageName: packageName ?? this.packageName,
        note: note ?? this.note,
      );
  TestSessionRow copyWithCompanion(TestSessionsCompanion data) {
    return TestSessionRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      status: data.status.present ? data.status.value : this.status,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      deviceSerial: data.deviceSerial.present
          ? data.deviceSerial.value
          : this.deviceSerial,
      deviceModel:
          data.deviceModel.present ? data.deviceModel.value : this.deviceModel,
      deviceBrand:
          data.deviceBrand.present ? data.deviceBrand.value : this.deviceBrand,
      deviceSdk: data.deviceSdk.present ? data.deviceSdk.value : this.deviceSdk,
      packageName:
          data.packageName.present ? data.packageName.value : this.packageName,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TestSessionRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('deviceSerial: $deviceSerial, ')
          ..write('deviceModel: $deviceModel, ')
          ..write('deviceBrand: $deviceBrand, ')
          ..write('deviceSdk: $deviceSdk, ')
          ..write('packageName: $packageName, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, type, status, startedAt, endedAt,
      deviceSerial, deviceModel, deviceBrand, deviceSdk, packageName, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TestSessionRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.status == this.status &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.deviceSerial == this.deviceSerial &&
          other.deviceModel == this.deviceModel &&
          other.deviceBrand == this.deviceBrand &&
          other.deviceSdk == this.deviceSdk &&
          other.packageName == this.packageName &&
          other.note == this.note);
}

class TestSessionsCompanion extends UpdateCompanion<TestSessionRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> type;
  final Value<TestSessionStatus> status;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<String> deviceSerial;
  final Value<String> deviceModel;
  final Value<String> deviceBrand;
  final Value<String> deviceSdk;
  final Value<String> packageName;
  final Value<String> note;
  final Value<int> rowid;
  const TestSessionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.status = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.deviceSerial = const Value.absent(),
    this.deviceModel = const Value.absent(),
    this.deviceBrand = const Value.absent(),
    this.deviceSdk = const Value.absent(),
    this.packageName = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TestSessionsCompanion.insert({
    required String id,
    required String name,
    required String type,
    required TestSessionStatus status,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    required String deviceSerial,
    this.deviceModel = const Value.absent(),
    this.deviceBrand = const Value.absent(),
    this.deviceSdk = const Value.absent(),
    this.packageName = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        type = Value(type),
        status = Value(status),
        startedAt = Value(startedAt),
        deviceSerial = Value(deviceSerial);
  static Insertable<TestSessionRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<int>? status,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<String>? deviceSerial,
    Expression<String>? deviceModel,
    Expression<String>? deviceBrand,
    Expression<String>? deviceSdk,
    Expression<String>? packageName,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (status != null) 'status': status,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (deviceSerial != null) 'device_serial': deviceSerial,
      if (deviceModel != null) 'device_model': deviceModel,
      if (deviceBrand != null) 'device_brand': deviceBrand,
      if (deviceSdk != null) 'device_sdk': deviceSdk,
      if (packageName != null) 'package_name': packageName,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TestSessionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? type,
      Value<TestSessionStatus>? status,
      Value<DateTime>? startedAt,
      Value<DateTime?>? endedAt,
      Value<String>? deviceSerial,
      Value<String>? deviceModel,
      Value<String>? deviceBrand,
      Value<String>? deviceSdk,
      Value<String>? packageName,
      Value<String>? note,
      Value<int>? rowid}) {
    return TestSessionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      deviceSerial: deviceSerial ?? this.deviceSerial,
      deviceModel: deviceModel ?? this.deviceModel,
      deviceBrand: deviceBrand ?? this.deviceBrand,
      deviceSdk: deviceSdk ?? this.deviceSdk,
      packageName: packageName ?? this.packageName,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(
          $TestSessionsTable.$converterstatus.toSql(status.value));
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (deviceSerial.present) {
      map['device_serial'] = Variable<String>(deviceSerial.value);
    }
    if (deviceModel.present) {
      map['device_model'] = Variable<String>(deviceModel.value);
    }
    if (deviceBrand.present) {
      map['device_brand'] = Variable<String>(deviceBrand.value);
    }
    if (deviceSdk.present) {
      map['device_sdk'] = Variable<String>(deviceSdk.value);
    }
    if (packageName.present) {
      map['package_name'] = Variable<String>(packageName.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TestSessionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('deviceSerial: $deviceSerial, ')
          ..write('deviceModel: $deviceModel, ')
          ..write('deviceBrand: $deviceBrand, ')
          ..write('deviceSdk: $deviceSdk, ')
          ..write('packageName: $packageName, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TestSessionEventsTable extends TestSessionEvents
    with TableInfo<$TestSessionEventsTable, TestSessionEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TestSessionEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES test_sessions (id) ON DELETE CASCADE'));
  @override
  late final GeneratedColumnWithTypeConverter<TestSessionEventType, int> type =
      GeneratedColumn<int>('type', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<TestSessionEventType>(
              $TestSessionEventsTable.$convertertype);
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<DateTime> time = GeneratedColumn<DateTime>(
      'time', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
      'detail', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, sessionId, type, time, title, detail, filePath];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'test_session_events';
  @override
  VerificationContext validateIntegrity(
      Insertable<TestSessionEventRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('time')) {
      context.handle(
          _timeMeta, time.isAcceptableOrUnknown(data['time']!, _timeMeta));
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('detail')) {
      context.handle(_detailMeta,
          detail.isAcceptableOrUnknown(data['detail']!, _detailMeta));
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TestSessionEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TestSessionEventRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      type: $TestSessionEventsTable.$convertertype.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}type'])!),
      time: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}time'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      detail: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}detail'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path']),
    );
  }

  @override
  $TestSessionEventsTable createAlias(String alias) {
    return $TestSessionEventsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TestSessionEventType, int, int> $convertertype =
      const EnumIndexConverter<TestSessionEventType>(
          TestSessionEventType.values);
}

class TestSessionEventRow extends DataClass
    implements Insertable<TestSessionEventRow> {
  final String id;
  final String sessionId;
  final TestSessionEventType type;
  final DateTime time;
  final String title;
  final String detail;
  final String? filePath;
  const TestSessionEventRow(
      {required this.id,
      required this.sessionId,
      required this.type,
      required this.time,
      required this.title,
      required this.detail,
      this.filePath});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    {
      map['type'] =
          Variable<int>($TestSessionEventsTable.$convertertype.toSql(type));
    }
    map['time'] = Variable<DateTime>(time);
    map['title'] = Variable<String>(title);
    map['detail'] = Variable<String>(detail);
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    return map;
  }

  TestSessionEventsCompanion toCompanion(bool nullToAbsent) {
    return TestSessionEventsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      type: Value(type),
      time: Value(time),
      title: Value(title),
      detail: Value(detail),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
    );
  }

  factory TestSessionEventRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TestSessionEventRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      type: $TestSessionEventsTable.$convertertype
          .fromJson(serializer.fromJson<int>(json['type'])),
      time: serializer.fromJson<DateTime>(json['time']),
      title: serializer.fromJson<String>(json['title']),
      detail: serializer.fromJson<String>(json['detail']),
      filePath: serializer.fromJson<String?>(json['filePath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'type': serializer
          .toJson<int>($TestSessionEventsTable.$convertertype.toJson(type)),
      'time': serializer.toJson<DateTime>(time),
      'title': serializer.toJson<String>(title),
      'detail': serializer.toJson<String>(detail),
      'filePath': serializer.toJson<String?>(filePath),
    };
  }

  TestSessionEventRow copyWith(
          {String? id,
          String? sessionId,
          TestSessionEventType? type,
          DateTime? time,
          String? title,
          String? detail,
          Value<String?> filePath = const Value.absent()}) =>
      TestSessionEventRow(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        type: type ?? this.type,
        time: time ?? this.time,
        title: title ?? this.title,
        detail: detail ?? this.detail,
        filePath: filePath.present ? filePath.value : this.filePath,
      );
  TestSessionEventRow copyWithCompanion(TestSessionEventsCompanion data) {
    return TestSessionEventRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      type: data.type.present ? data.type.value : this.type,
      time: data.time.present ? data.time.value : this.time,
      title: data.title.present ? data.title.value : this.title,
      detail: data.detail.present ? data.detail.value : this.detail,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TestSessionEventRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('type: $type, ')
          ..write('time: $time, ')
          ..write('title: $title, ')
          ..write('detail: $detail, ')
          ..write('filePath: $filePath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sessionId, type, time, title, detail, filePath);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TestSessionEventRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.type == this.type &&
          other.time == this.time &&
          other.title == this.title &&
          other.detail == this.detail &&
          other.filePath == this.filePath);
}

class TestSessionEventsCompanion extends UpdateCompanion<TestSessionEventRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<TestSessionEventType> type;
  final Value<DateTime> time;
  final Value<String> title;
  final Value<String> detail;
  final Value<String?> filePath;
  final Value<int> rowid;
  const TestSessionEventsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.type = const Value.absent(),
    this.time = const Value.absent(),
    this.title = const Value.absent(),
    this.detail = const Value.absent(),
    this.filePath = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TestSessionEventsCompanion.insert({
    required String id,
    required String sessionId,
    required TestSessionEventType type,
    required DateTime time,
    required String title,
    this.detail = const Value.absent(),
    this.filePath = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sessionId = Value(sessionId),
        type = Value(type),
        time = Value(time),
        title = Value(title);
  static Insertable<TestSessionEventRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<int>? type,
    Expression<DateTime>? time,
    Expression<String>? title,
    Expression<String>? detail,
    Expression<String>? filePath,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (type != null) 'type': type,
      if (time != null) 'time': time,
      if (title != null) 'title': title,
      if (detail != null) 'detail': detail,
      if (filePath != null) 'file_path': filePath,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TestSessionEventsCompanion copyWith(
      {Value<String>? id,
      Value<String>? sessionId,
      Value<TestSessionEventType>? type,
      Value<DateTime>? time,
      Value<String>? title,
      Value<String>? detail,
      Value<String?>? filePath,
      Value<int>? rowid}) {
    return TestSessionEventsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      type: type ?? this.type,
      time: time ?? this.time,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      filePath: filePath ?? this.filePath,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(
          $TestSessionEventsTable.$convertertype.toSql(type.value));
    }
    if (time.present) {
      map['time'] = Variable<DateTime>(time.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TestSessionEventsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('type: $type, ')
          ..write('time: $time, ')
          ..write('title: $title, ')
          ..write('detail: $detail, ')
          ..write('filePath: $filePath, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TestSessionArtifactsTable extends TestSessionArtifacts
    with TableInfo<$TestSessionArtifactsTable, TestSessionArtifactRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TestSessionArtifactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES test_sessions (id) ON DELETE CASCADE'));
  @override
  late final GeneratedColumnWithTypeConverter<TestSessionArtifactKind, int>
      kind = GeneratedColumn<int>('kind', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<TestSessionArtifactKind>(
              $TestSessionArtifactsTable.$converterkind);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
      'path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
      'size', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [id, sessionId, kind, name, path, createdAt, size];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'test_session_artifacts';
  @override
  VerificationContext validateIntegrity(
      Insertable<TestSessionArtifactRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
          _pathMeta, path.isAcceptableOrUnknown(data['path']!, _pathMeta));
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
          _sizeMeta, size.isAcceptableOrUnknown(data['size']!, _sizeMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TestSessionArtifactRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TestSessionArtifactRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      kind: $TestSessionArtifactsTable.$converterkind.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}kind'])!),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      path: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}path'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      size: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}size'])!,
    );
  }

  @override
  $TestSessionArtifactsTable createAlias(String alias) {
    return $TestSessionArtifactsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TestSessionArtifactKind, int, int> $converterkind =
      const EnumIndexConverter<TestSessionArtifactKind>(
          TestSessionArtifactKind.values);
}

class TestSessionArtifactRow extends DataClass
    implements Insertable<TestSessionArtifactRow> {
  final String id;
  final String sessionId;
  final TestSessionArtifactKind kind;
  final String name;
  final String path;
  final DateTime createdAt;
  final int size;
  const TestSessionArtifactRow(
      {required this.id,
      required this.sessionId,
      required this.kind,
      required this.name,
      required this.path,
      required this.createdAt,
      required this.size});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    {
      map['kind'] =
          Variable<int>($TestSessionArtifactsTable.$converterkind.toSql(kind));
    }
    map['name'] = Variable<String>(name);
    map['path'] = Variable<String>(path);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['size'] = Variable<int>(size);
    return map;
  }

  TestSessionArtifactsCompanion toCompanion(bool nullToAbsent) {
    return TestSessionArtifactsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      kind: Value(kind),
      name: Value(name),
      path: Value(path),
      createdAt: Value(createdAt),
      size: Value(size),
    );
  }

  factory TestSessionArtifactRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TestSessionArtifactRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      kind: $TestSessionArtifactsTable.$converterkind
          .fromJson(serializer.fromJson<int>(json['kind'])),
      name: serializer.fromJson<String>(json['name']),
      path: serializer.fromJson<String>(json['path']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      size: serializer.fromJson<int>(json['size']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'kind': serializer
          .toJson<int>($TestSessionArtifactsTable.$converterkind.toJson(kind)),
      'name': serializer.toJson<String>(name),
      'path': serializer.toJson<String>(path),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'size': serializer.toJson<int>(size),
    };
  }

  TestSessionArtifactRow copyWith(
          {String? id,
          String? sessionId,
          TestSessionArtifactKind? kind,
          String? name,
          String? path,
          DateTime? createdAt,
          int? size}) =>
      TestSessionArtifactRow(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        kind: kind ?? this.kind,
        name: name ?? this.name,
        path: path ?? this.path,
        createdAt: createdAt ?? this.createdAt,
        size: size ?? this.size,
      );
  TestSessionArtifactRow copyWithCompanion(TestSessionArtifactsCompanion data) {
    return TestSessionArtifactRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      path: data.path.present ? data.path.value : this.path,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      size: data.size.present ? data.size.value : this.size,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TestSessionArtifactRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('path: $path, ')
          ..write('createdAt: $createdAt, ')
          ..write('size: $size')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sessionId, kind, name, path, createdAt, size);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TestSessionArtifactRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.path == this.path &&
          other.createdAt == this.createdAt &&
          other.size == this.size);
}

class TestSessionArtifactsCompanion
    extends UpdateCompanion<TestSessionArtifactRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<TestSessionArtifactKind> kind;
  final Value<String> name;
  final Value<String> path;
  final Value<DateTime> createdAt;
  final Value<int> size;
  final Value<int> rowid;
  const TestSessionArtifactsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.path = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.size = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TestSessionArtifactsCompanion.insert({
    required String id,
    required String sessionId,
    required TestSessionArtifactKind kind,
    required String name,
    required String path,
    required DateTime createdAt,
    this.size = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sessionId = Value(sessionId),
        kind = Value(kind),
        name = Value(name),
        path = Value(path),
        createdAt = Value(createdAt);
  static Insertable<TestSessionArtifactRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<int>? kind,
    Expression<String>? name,
    Expression<String>? path,
    Expression<DateTime>? createdAt,
    Expression<int>? size,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (path != null) 'path': path,
      if (createdAt != null) 'created_at': createdAt,
      if (size != null) 'size': size,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TestSessionArtifactsCompanion copyWith(
      {Value<String>? id,
      Value<String>? sessionId,
      Value<TestSessionArtifactKind>? kind,
      Value<String>? name,
      Value<String>? path,
      Value<DateTime>? createdAt,
      Value<int>? size,
      Value<int>? rowid}) {
    return TestSessionArtifactsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      path: path ?? this.path,
      createdAt: createdAt ?? this.createdAt,
      size: size ?? this.size,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(
          $TestSessionArtifactsTable.$converterkind.toSql(kind.value));
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TestSessionArtifactsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('path: $path, ')
          ..write('createdAt: $createdAt, ')
          ..write('size: $size, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TestSessionNotesTable extends TestSessionNotes
    with TableInfo<$TestSessionNotesTable, TestSessionNoteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TestSessionNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES test_sessions (id) ON DELETE CASCADE'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, sessionId, createdAt, content];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'test_session_notes';
  @override
  VerificationContext validateIntegrity(Insertable<TestSessionNoteRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TestSessionNoteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TestSessionNoteRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
    );
  }

  @override
  $TestSessionNotesTable createAlias(String alias) {
    return $TestSessionNotesTable(attachedDatabase, alias);
  }
}

class TestSessionNoteRow extends DataClass
    implements Insertable<TestSessionNoteRow> {
  final String id;
  final String sessionId;
  final DateTime createdAt;
  final String content;
  const TestSessionNoteRow(
      {required this.id,
      required this.sessionId,
      required this.createdAt,
      required this.content});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['content'] = Variable<String>(content);
    return map;
  }

  TestSessionNotesCompanion toCompanion(bool nullToAbsent) {
    return TestSessionNotesCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      createdAt: Value(createdAt),
      content: Value(content),
    );
  }

  factory TestSessionNoteRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TestSessionNoteRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      content: serializer.fromJson<String>(json['content']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'content': serializer.toJson<String>(content),
    };
  }

  TestSessionNoteRow copyWith(
          {String? id,
          String? sessionId,
          DateTime? createdAt,
          String? content}) =>
      TestSessionNoteRow(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        createdAt: createdAt ?? this.createdAt,
        content: content ?? this.content,
      );
  TestSessionNoteRow copyWithCompanion(TestSessionNotesCompanion data) {
    return TestSessionNoteRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      content: data.content.present ? data.content.value : this.content,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TestSessionNoteRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, createdAt, content);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TestSessionNoteRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.createdAt == this.createdAt &&
          other.content == this.content);
}

class TestSessionNotesCompanion extends UpdateCompanion<TestSessionNoteRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<DateTime> createdAt;
  final Value<String> content;
  final Value<int> rowid;
  const TestSessionNotesCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.content = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TestSessionNotesCompanion.insert({
    required String id,
    required String sessionId,
    required DateTime createdAt,
    required String content,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sessionId = Value(sessionId),
        createdAt = Value(createdAt),
        content = Value(content);
  static Insertable<TestSessionNoteRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<DateTime>? createdAt,
    Expression<String>? content,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (createdAt != null) 'created_at': createdAt,
      if (content != null) 'content': content,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TestSessionNotesCompanion copyWith(
      {Value<String>? id,
      Value<String>? sessionId,
      Value<DateTime>? createdAt,
      Value<String>? content,
      Value<int>? rowid}) {
    return TestSessionNotesCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      createdAt: createdAt ?? this.createdAt,
      content: content ?? this.content,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TestSessionNotesCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('content: $content, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TestSessionIssuesTable extends TestSessionIssues
    with TableInfo<$TestSessionIssuesTable, TestSessionIssueRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TestSessionIssuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES test_sessions (id) ON DELETE CASCADE'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<TestSessionIssueType, int> type =
      GeneratedColumn<int>('type', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<TestSessionIssueType>(
              $TestSessionIssuesTable.$convertertype);
  @override
  late final GeneratedColumnWithTypeConverter<TestSessionIssueSeverity, int>
      severity = GeneratedColumn<int>('severity', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<TestSessionIssueSeverity>(
              $TestSessionIssuesTable.$converterseverity);
  static const VerificationMeta _stepsMeta = const VerificationMeta('steps');
  @override
  late final GeneratedColumn<String> steps = GeneratedColumn<String>(
      'steps', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _expectedMeta =
      const VerificationMeta('expected');
  @override
  late final GeneratedColumn<String> expected = GeneratedColumn<String>(
      'expected', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _actualMeta = const VerificationMeta('actual');
  @override
  late final GeneratedColumn<String> actual = GeneratedColumn<String>(
      'actual', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sessionId,
        createdAt,
        title,
        type,
        severity,
        steps,
        expected,
        actual,
        note
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'test_session_issues';
  @override
  VerificationContext validateIntegrity(
      Insertable<TestSessionIssueRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('steps')) {
      context.handle(
          _stepsMeta, steps.isAcceptableOrUnknown(data['steps']!, _stepsMeta));
    }
    if (data.containsKey('expected')) {
      context.handle(_expectedMeta,
          expected.isAcceptableOrUnknown(data['expected']!, _expectedMeta));
    }
    if (data.containsKey('actual')) {
      context.handle(_actualMeta,
          actual.isAcceptableOrUnknown(data['actual']!, _actualMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TestSessionIssueRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TestSessionIssueRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      type: $TestSessionIssuesTable.$convertertype.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}type'])!),
      severity: $TestSessionIssuesTable.$converterseverity.fromSql(
          attachedDatabase.typeMapping
              .read(DriftSqlType.int, data['${effectivePrefix}severity'])!),
      steps: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}steps'])!,
      expected: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}expected'])!,
      actual: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}actual'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note'])!,
    );
  }

  @override
  $TestSessionIssuesTable createAlias(String alias) {
    return $TestSessionIssuesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TestSessionIssueType, int, int> $convertertype =
      const EnumIndexConverter<TestSessionIssueType>(
          TestSessionIssueType.values);
  static JsonTypeConverter2<TestSessionIssueSeverity, int, int>
      $converterseverity = const EnumIndexConverter<TestSessionIssueSeverity>(
          TestSessionIssueSeverity.values);
}

class TestSessionIssueRow extends DataClass
    implements Insertable<TestSessionIssueRow> {
  final String id;
  final String sessionId;
  final DateTime createdAt;
  final String title;
  final TestSessionIssueType type;
  final TestSessionIssueSeverity severity;
  final String steps;
  final String expected;
  final String actual;
  final String note;
  const TestSessionIssueRow(
      {required this.id,
      required this.sessionId,
      required this.createdAt,
      required this.title,
      required this.type,
      required this.severity,
      required this.steps,
      required this.expected,
      required this.actual,
      required this.note});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['title'] = Variable<String>(title);
    {
      map['type'] =
          Variable<int>($TestSessionIssuesTable.$convertertype.toSql(type));
    }
    {
      map['severity'] = Variable<int>(
          $TestSessionIssuesTable.$converterseverity.toSql(severity));
    }
    map['steps'] = Variable<String>(steps);
    map['expected'] = Variable<String>(expected);
    map['actual'] = Variable<String>(actual);
    map['note'] = Variable<String>(note);
    return map;
  }

  TestSessionIssuesCompanion toCompanion(bool nullToAbsent) {
    return TestSessionIssuesCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      createdAt: Value(createdAt),
      title: Value(title),
      type: Value(type),
      severity: Value(severity),
      steps: Value(steps),
      expected: Value(expected),
      actual: Value(actual),
      note: Value(note),
    );
  }

  factory TestSessionIssueRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TestSessionIssueRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      title: serializer.fromJson<String>(json['title']),
      type: $TestSessionIssuesTable.$convertertype
          .fromJson(serializer.fromJson<int>(json['type'])),
      severity: $TestSessionIssuesTable.$converterseverity
          .fromJson(serializer.fromJson<int>(json['severity'])),
      steps: serializer.fromJson<String>(json['steps']),
      expected: serializer.fromJson<String>(json['expected']),
      actual: serializer.fromJson<String>(json['actual']),
      note: serializer.fromJson<String>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'title': serializer.toJson<String>(title),
      'type': serializer
          .toJson<int>($TestSessionIssuesTable.$convertertype.toJson(type)),
      'severity': serializer.toJson<int>(
          $TestSessionIssuesTable.$converterseverity.toJson(severity)),
      'steps': serializer.toJson<String>(steps),
      'expected': serializer.toJson<String>(expected),
      'actual': serializer.toJson<String>(actual),
      'note': serializer.toJson<String>(note),
    };
  }

  TestSessionIssueRow copyWith(
          {String? id,
          String? sessionId,
          DateTime? createdAt,
          String? title,
          TestSessionIssueType? type,
          TestSessionIssueSeverity? severity,
          String? steps,
          String? expected,
          String? actual,
          String? note}) =>
      TestSessionIssueRow(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        createdAt: createdAt ?? this.createdAt,
        title: title ?? this.title,
        type: type ?? this.type,
        severity: severity ?? this.severity,
        steps: steps ?? this.steps,
        expected: expected ?? this.expected,
        actual: actual ?? this.actual,
        note: note ?? this.note,
      );
  TestSessionIssueRow copyWithCompanion(TestSessionIssuesCompanion data) {
    return TestSessionIssueRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      title: data.title.present ? data.title.value : this.title,
      type: data.type.present ? data.type.value : this.type,
      severity: data.severity.present ? data.severity.value : this.severity,
      steps: data.steps.present ? data.steps.value : this.steps,
      expected: data.expected.present ? data.expected.value : this.expected,
      actual: data.actual.present ? data.actual.value : this.actual,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TestSessionIssueRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('title: $title, ')
          ..write('type: $type, ')
          ..write('severity: $severity, ')
          ..write('steps: $steps, ')
          ..write('expected: $expected, ')
          ..write('actual: $actual, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, createdAt, title, type,
      severity, steps, expected, actual, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TestSessionIssueRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.createdAt == this.createdAt &&
          other.title == this.title &&
          other.type == this.type &&
          other.severity == this.severity &&
          other.steps == this.steps &&
          other.expected == this.expected &&
          other.actual == this.actual &&
          other.note == this.note);
}

class TestSessionIssuesCompanion extends UpdateCompanion<TestSessionIssueRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<DateTime> createdAt;
  final Value<String> title;
  final Value<TestSessionIssueType> type;
  final Value<TestSessionIssueSeverity> severity;
  final Value<String> steps;
  final Value<String> expected;
  final Value<String> actual;
  final Value<String> note;
  final Value<int> rowid;
  const TestSessionIssuesCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.title = const Value.absent(),
    this.type = const Value.absent(),
    this.severity = const Value.absent(),
    this.steps = const Value.absent(),
    this.expected = const Value.absent(),
    this.actual = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TestSessionIssuesCompanion.insert({
    required String id,
    required String sessionId,
    required DateTime createdAt,
    required String title,
    required TestSessionIssueType type,
    required TestSessionIssueSeverity severity,
    this.steps = const Value.absent(),
    this.expected = const Value.absent(),
    this.actual = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sessionId = Value(sessionId),
        createdAt = Value(createdAt),
        title = Value(title),
        type = Value(type),
        severity = Value(severity);
  static Insertable<TestSessionIssueRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<DateTime>? createdAt,
    Expression<String>? title,
    Expression<int>? type,
    Expression<int>? severity,
    Expression<String>? steps,
    Expression<String>? expected,
    Expression<String>? actual,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (createdAt != null) 'created_at': createdAt,
      if (title != null) 'title': title,
      if (type != null) 'type': type,
      if (severity != null) 'severity': severity,
      if (steps != null) 'steps': steps,
      if (expected != null) 'expected': expected,
      if (actual != null) 'actual': actual,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TestSessionIssuesCompanion copyWith(
      {Value<String>? id,
      Value<String>? sessionId,
      Value<DateTime>? createdAt,
      Value<String>? title,
      Value<TestSessionIssueType>? type,
      Value<TestSessionIssueSeverity>? severity,
      Value<String>? steps,
      Value<String>? expected,
      Value<String>? actual,
      Value<String>? note,
      Value<int>? rowid}) {
    return TestSessionIssuesCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      createdAt: createdAt ?? this.createdAt,
      title: title ?? this.title,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      steps: steps ?? this.steps,
      expected: expected ?? this.expected,
      actual: actual ?? this.actual,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(
          $TestSessionIssuesTable.$convertertype.toSql(type.value));
    }
    if (severity.present) {
      map['severity'] = Variable<int>(
          $TestSessionIssuesTable.$converterseverity.toSql(severity.value));
    }
    if (steps.present) {
      map['steps'] = Variable<String>(steps.value);
    }
    if (expected.present) {
      map['expected'] = Variable<String>(expected.value);
    }
    if (actual.present) {
      map['actual'] = Variable<String>(actual.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TestSessionIssuesCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('title: $title, ')
          ..write('type: $type, ')
          ..write('severity: $severity, ')
          ..write('steps: $steps, ')
          ..write('expected: $expected, ')
          ..write('actual: $actual, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TestSessionPlanItemsTable extends TestSessionPlanItems
    with TableInfo<$TestSessionPlanItemsTable, TestSessionPlanItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TestSessionPlanItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES test_sessions (id) ON DELETE CASCADE'));
  static const VerificationMeta _flowNameMeta =
      const VerificationMeta('flowName');
  @override
  late final GeneratedColumn<String> flowName = GeneratedColumn<String>(
      'flow_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _stepMeta = const VerificationMeta('step');
  @override
  late final GeneratedColumn<String> step = GeneratedColumn<String>(
      'step', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<TestSessionPlanStatus, int>
      status = GeneratedColumn<int>('status', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<TestSessionPlanStatus>(
              $TestSessionPlanItemsTable.$converterstatus);
  static const VerificationMeta _messageMeta =
      const VerificationMeta('message');
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
      'message', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
      'started_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sessionId,
        flowName,
        step,
        status,
        message,
        startedAt,
        updatedAt,
        sortOrder
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'test_session_plan_items';
  @override
  VerificationContext validateIntegrity(
      Insertable<TestSessionPlanItemRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('flow_name')) {
      context.handle(_flowNameMeta,
          flowName.isAcceptableOrUnknown(data['flow_name']!, _flowNameMeta));
    } else if (isInserting) {
      context.missing(_flowNameMeta);
    }
    if (data.containsKey('step')) {
      context.handle(
          _stepMeta, step.isAcceptableOrUnknown(data['step']!, _stepMeta));
    } else if (isInserting) {
      context.missing(_stepMeta);
    }
    if (data.containsKey('message')) {
      context.handle(_messageMeta,
          message.isAcceptableOrUnknown(data['message']!, _messageMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TestSessionPlanItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TestSessionPlanItemRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      flowName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}flow_name'])!,
      step: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}step'])!,
      status: $TestSessionPlanItemsTable.$converterstatus.fromSql(
          attachedDatabase.typeMapping
              .read(DriftSqlType.int, data['${effectivePrefix}status'])!),
      message: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message'])!,
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}started_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
    );
  }

  @override
  $TestSessionPlanItemsTable createAlias(String alias) {
    return $TestSessionPlanItemsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TestSessionPlanStatus, int, int> $converterstatus =
      const EnumIndexConverter<TestSessionPlanStatus>(
          TestSessionPlanStatus.values);
}

class TestSessionPlanItemRow extends DataClass
    implements Insertable<TestSessionPlanItemRow> {
  final String id;
  final String sessionId;
  final String flowName;
  final String step;
  final TestSessionPlanStatus status;
  final String message;
  final DateTime? startedAt;
  final DateTime? updatedAt;
  final int sortOrder;
  const TestSessionPlanItemRow(
      {required this.id,
      required this.sessionId,
      required this.flowName,
      required this.step,
      required this.status,
      required this.message,
      this.startedAt,
      this.updatedAt,
      required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['flow_name'] = Variable<String>(flowName);
    map['step'] = Variable<String>(step);
    {
      map['status'] = Variable<int>(
          $TestSessionPlanItemsTable.$converterstatus.toSql(status));
    }
    map['message'] = Variable<String>(message);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<DateTime>(startedAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  TestSessionPlanItemsCompanion toCompanion(bool nullToAbsent) {
    return TestSessionPlanItemsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      flowName: Value(flowName),
      step: Value(step),
      status: Value(status),
      message: Value(message),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      sortOrder: Value(sortOrder),
    );
  }

  factory TestSessionPlanItemRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TestSessionPlanItemRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      flowName: serializer.fromJson<String>(json['flowName']),
      step: serializer.fromJson<String>(json['step']),
      status: $TestSessionPlanItemsTable.$converterstatus
          .fromJson(serializer.fromJson<int>(json['status'])),
      message: serializer.fromJson<String>(json['message']),
      startedAt: serializer.fromJson<DateTime?>(json['startedAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'flowName': serializer.toJson<String>(flowName),
      'step': serializer.toJson<String>(step),
      'status': serializer.toJson<int>(
          $TestSessionPlanItemsTable.$converterstatus.toJson(status)),
      'message': serializer.toJson<String>(message),
      'startedAt': serializer.toJson<DateTime?>(startedAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  TestSessionPlanItemRow copyWith(
          {String? id,
          String? sessionId,
          String? flowName,
          String? step,
          TestSessionPlanStatus? status,
          String? message,
          Value<DateTime?> startedAt = const Value.absent(),
          Value<DateTime?> updatedAt = const Value.absent(),
          int? sortOrder}) =>
      TestSessionPlanItemRow(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        flowName: flowName ?? this.flowName,
        step: step ?? this.step,
        status: status ?? this.status,
        message: message ?? this.message,
        startedAt: startedAt.present ? startedAt.value : this.startedAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  TestSessionPlanItemRow copyWithCompanion(TestSessionPlanItemsCompanion data) {
    return TestSessionPlanItemRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      flowName: data.flowName.present ? data.flowName.value : this.flowName,
      step: data.step.present ? data.step.value : this.step,
      status: data.status.present ? data.status.value : this.status,
      message: data.message.present ? data.message.value : this.message,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TestSessionPlanItemRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('flowName: $flowName, ')
          ..write('step: $step, ')
          ..write('status: $status, ')
          ..write('message: $message, ')
          ..write('startedAt: $startedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, flowName, step, status,
      message, startedAt, updatedAt, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TestSessionPlanItemRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.flowName == this.flowName &&
          other.step == this.step &&
          other.status == this.status &&
          other.message == this.message &&
          other.startedAt == this.startedAt &&
          other.updatedAt == this.updatedAt &&
          other.sortOrder == this.sortOrder);
}

class TestSessionPlanItemsCompanion
    extends UpdateCompanion<TestSessionPlanItemRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> flowName;
  final Value<String> step;
  final Value<TestSessionPlanStatus> status;
  final Value<String> message;
  final Value<DateTime?> startedAt;
  final Value<DateTime?> updatedAt;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const TestSessionPlanItemsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.flowName = const Value.absent(),
    this.step = const Value.absent(),
    this.status = const Value.absent(),
    this.message = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TestSessionPlanItemsCompanion.insert({
    required String id,
    required String sessionId,
    required String flowName,
    required String step,
    required TestSessionPlanStatus status,
    this.message = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sessionId = Value(sessionId),
        flowName = Value(flowName),
        step = Value(step),
        status = Value(status);
  static Insertable<TestSessionPlanItemRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? flowName,
    Expression<String>? step,
    Expression<int>? status,
    Expression<String>? message,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (flowName != null) 'flow_name': flowName,
      if (step != null) 'step': step,
      if (status != null) 'status': status,
      if (message != null) 'message': message,
      if (startedAt != null) 'started_at': startedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TestSessionPlanItemsCompanion copyWith(
      {Value<String>? id,
      Value<String>? sessionId,
      Value<String>? flowName,
      Value<String>? step,
      Value<TestSessionPlanStatus>? status,
      Value<String>? message,
      Value<DateTime?>? startedAt,
      Value<DateTime?>? updatedAt,
      Value<int>? sortOrder,
      Value<int>? rowid}) {
    return TestSessionPlanItemsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      flowName: flowName ?? this.flowName,
      step: step ?? this.step,
      status: status ?? this.status,
      message: message ?? this.message,
      startedAt: startedAt ?? this.startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (flowName.present) {
      map['flow_name'] = Variable<String>(flowName.value);
    }
    if (step.present) {
      map['step'] = Variable<String>(step.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(
          $TestSessionPlanItemsTable.$converterstatus.toSql(status.value));
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TestSessionPlanItemsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('flowName: $flowName, ')
          ..write('step: $step, ')
          ..write('status: $status, ')
          ..write('message: $message, ')
          ..write('startedAt: $startedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TestSessionIssueArtifactsTable extends TestSessionIssueArtifacts
    with
        TableInfo<$TestSessionIssueArtifactsTable,
            TestSessionIssueArtifactRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TestSessionIssueArtifactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _issueIdMeta =
      const VerificationMeta('issueId');
  @override
  late final GeneratedColumn<String> issueId = GeneratedColumn<String>(
      'issue_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES test_session_issues (id) ON DELETE CASCADE'));
  static const VerificationMeta _artifactIdMeta =
      const VerificationMeta('artifactId');
  @override
  late final GeneratedColumn<String> artifactId = GeneratedColumn<String>(
      'artifact_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES test_session_artifacts (id) ON DELETE CASCADE'));
  @override
  List<GeneratedColumn> get $columns => [issueId, artifactId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'test_session_issue_artifacts';
  @override
  VerificationContext validateIntegrity(
      Insertable<TestSessionIssueArtifactRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('issue_id')) {
      context.handle(_issueIdMeta,
          issueId.isAcceptableOrUnknown(data['issue_id']!, _issueIdMeta));
    } else if (isInserting) {
      context.missing(_issueIdMeta);
    }
    if (data.containsKey('artifact_id')) {
      context.handle(
          _artifactIdMeta,
          artifactId.isAcceptableOrUnknown(
              data['artifact_id']!, _artifactIdMeta));
    } else if (isInserting) {
      context.missing(_artifactIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {issueId, artifactId};
  @override
  TestSessionIssueArtifactRow map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TestSessionIssueArtifactRow(
      issueId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}issue_id'])!,
      artifactId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artifact_id'])!,
    );
  }

  @override
  $TestSessionIssueArtifactsTable createAlias(String alias) {
    return $TestSessionIssueArtifactsTable(attachedDatabase, alias);
  }
}

class TestSessionIssueArtifactRow extends DataClass
    implements Insertable<TestSessionIssueArtifactRow> {
  final String issueId;
  final String artifactId;
  const TestSessionIssueArtifactRow(
      {required this.issueId, required this.artifactId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['issue_id'] = Variable<String>(issueId);
    map['artifact_id'] = Variable<String>(artifactId);
    return map;
  }

  TestSessionIssueArtifactsCompanion toCompanion(bool nullToAbsent) {
    return TestSessionIssueArtifactsCompanion(
      issueId: Value(issueId),
      artifactId: Value(artifactId),
    );
  }

  factory TestSessionIssueArtifactRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TestSessionIssueArtifactRow(
      issueId: serializer.fromJson<String>(json['issueId']),
      artifactId: serializer.fromJson<String>(json['artifactId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'issueId': serializer.toJson<String>(issueId),
      'artifactId': serializer.toJson<String>(artifactId),
    };
  }

  TestSessionIssueArtifactRow copyWith({String? issueId, String? artifactId}) =>
      TestSessionIssueArtifactRow(
        issueId: issueId ?? this.issueId,
        artifactId: artifactId ?? this.artifactId,
      );
  TestSessionIssueArtifactRow copyWithCompanion(
      TestSessionIssueArtifactsCompanion data) {
    return TestSessionIssueArtifactRow(
      issueId: data.issueId.present ? data.issueId.value : this.issueId,
      artifactId:
          data.artifactId.present ? data.artifactId.value : this.artifactId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TestSessionIssueArtifactRow(')
          ..write('issueId: $issueId, ')
          ..write('artifactId: $artifactId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(issueId, artifactId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TestSessionIssueArtifactRow &&
          other.issueId == this.issueId &&
          other.artifactId == this.artifactId);
}

class TestSessionIssueArtifactsCompanion
    extends UpdateCompanion<TestSessionIssueArtifactRow> {
  final Value<String> issueId;
  final Value<String> artifactId;
  final Value<int> rowid;
  const TestSessionIssueArtifactsCompanion({
    this.issueId = const Value.absent(),
    this.artifactId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TestSessionIssueArtifactsCompanion.insert({
    required String issueId,
    required String artifactId,
    this.rowid = const Value.absent(),
  })  : issueId = Value(issueId),
        artifactId = Value(artifactId);
  static Insertable<TestSessionIssueArtifactRow> custom({
    Expression<String>? issueId,
    Expression<String>? artifactId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (issueId != null) 'issue_id': issueId,
      if (artifactId != null) 'artifact_id': artifactId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TestSessionIssueArtifactsCompanion copyWith(
      {Value<String>? issueId, Value<String>? artifactId, Value<int>? rowid}) {
    return TestSessionIssueArtifactsCompanion(
      issueId: issueId ?? this.issueId,
      artifactId: artifactId ?? this.artifactId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (issueId.present) {
      map['issue_id'] = Variable<String>(issueId.value);
    }
    if (artifactId.present) {
      map['artifact_id'] = Variable<String>(artifactId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TestSessionIssueArtifactsCompanion(')
          ..write('issueId: $issueId, ')
          ..write('artifactId: $artifactId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SavedDevicesTable savedDevices = $SavedDevicesTable(this);
  late final $AppStatesTable appStates = $AppStatesTable(this);
  late final $TestSessionsTable testSessions = $TestSessionsTable(this);
  late final $TestSessionEventsTable testSessionEvents =
      $TestSessionEventsTable(this);
  late final $TestSessionArtifactsTable testSessionArtifacts =
      $TestSessionArtifactsTable(this);
  late final $TestSessionNotesTable testSessionNotes =
      $TestSessionNotesTable(this);
  late final $TestSessionIssuesTable testSessionIssues =
      $TestSessionIssuesTable(this);
  late final $TestSessionPlanItemsTable testSessionPlanItems =
      $TestSessionPlanItemsTable(this);
  late final $TestSessionIssueArtifactsTable testSessionIssueArtifacts =
      $TestSessionIssueArtifactsTable(this);
  late final SavedDevicesDao savedDevicesDao =
      SavedDevicesDao(this as AppDatabase);
  late final AppStatesDao appStatesDao = AppStatesDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        savedDevices,
        appStates,
        testSessions,
        testSessionEvents,
        testSessionArtifacts,
        testSessionNotes,
        testSessionIssues,
        testSessionPlanItems,
        testSessionIssueArtifacts
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('test_sessions',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('test_session_events', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('test_sessions',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('test_session_artifacts', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('test_sessions',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('test_session_notes', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('test_sessions',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('test_session_issues', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('test_sessions',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('test_session_plan_items', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('test_session_issues',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('test_session_issue_artifacts',
                  kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('test_session_artifacts',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('test_session_issue_artifacts',
                  kind: UpdateKind.delete),
            ],
          ),
        ],
      );
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

final class $$SavedDevicesTableReferences
    extends BaseReferences<_$AppDatabase, $SavedDevicesTable, SavedDevice> {
  $$SavedDevicesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TestSessionsTable, List<TestSessionRow>>
      _testSessionsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.testSessions,
              aliasName: 'saved_devices__serial__test_sessions__device_serial');

  $$TestSessionsTableProcessedTableManager get testSessionsRefs {
    final manager = $$TestSessionsTableTableManager($_db, $_db.testSessions)
        .filter((f) =>
            f.deviceSerial.serial.sqlEquals($_itemColumn<String>('serial')!));

    final cache = $_typedResult.readTableOrNull(_testSessionsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

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

  Expression<bool> testSessionsRefs(
      Expression<bool> Function($$TestSessionsTableFilterComposer f) f) {
    final $$TestSessionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.serial,
        referencedTable: $db.testSessions,
        getReferencedColumn: (t) => t.deviceSerial,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestSessionsTableFilterComposer(
              $db: $db,
              $table: $db.testSessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
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

  Expression<T> testSessionsRefs<T extends Object>(
      Expression<T> Function($$TestSessionsTableAnnotationComposer a) f) {
    final $$TestSessionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.serial,
        referencedTable: $db.testSessions,
        getReferencedColumn: (t) => t.deviceSerial,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestSessionsTableAnnotationComposer(
              $db: $db,
              $table: $db.testSessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
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
    (SavedDevice, $$SavedDevicesTableReferences),
    SavedDevice,
    PrefetchHooks Function({bool testSessionsRefs})> {
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
              .map((e) => (
                    e.readTable(table),
                    $$SavedDevicesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({testSessionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (testSessionsRefs) db.testSessions],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (testSessionsRefs)
                    await $_getPrefetchedData<SavedDevice, $SavedDevicesTable,
                            TestSessionRow>(
                        currentTable: table,
                        referencedTable: $$SavedDevicesTableReferences
                            ._testSessionsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SavedDevicesTableReferences(db, table, p0)
                                .testSessionsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.deviceSerial == item.serial),
                        typedResults: items)
                ];
              },
            );
          },
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
    (SavedDevice, $$SavedDevicesTableReferences),
    SavedDevice,
    PrefetchHooks Function({bool testSessionsRefs})>;
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
typedef $$TestSessionsTableCreateCompanionBuilder = TestSessionsCompanion
    Function({
  required String id,
  required String name,
  required String type,
  required TestSessionStatus status,
  required DateTime startedAt,
  Value<DateTime?> endedAt,
  required String deviceSerial,
  Value<String> deviceModel,
  Value<String> deviceBrand,
  Value<String> deviceSdk,
  Value<String> packageName,
  Value<String> note,
  Value<int> rowid,
});
typedef $$TestSessionsTableUpdateCompanionBuilder = TestSessionsCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<String> type,
  Value<TestSessionStatus> status,
  Value<DateTime> startedAt,
  Value<DateTime?> endedAt,
  Value<String> deviceSerial,
  Value<String> deviceModel,
  Value<String> deviceBrand,
  Value<String> deviceSdk,
  Value<String> packageName,
  Value<String> note,
  Value<int> rowid,
});

final class $$TestSessionsTableReferences
    extends BaseReferences<_$AppDatabase, $TestSessionsTable, TestSessionRow> {
  $$TestSessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SavedDevicesTable _deviceSerialTable(_$AppDatabase db) =>
      db.savedDevices
          .createAlias('test_sessions__device_serial__saved_devices__serial');

  $$SavedDevicesTableProcessedTableManager get deviceSerial {
    final $_column = $_itemColumn<String>('device_serial')!;

    final manager = $$SavedDevicesTableTableManager($_db, $_db.savedDevices)
        .filter((f) => f.serial.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_deviceSerialTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$TestSessionEventsTable, List<TestSessionEventRow>>
      _testSessionEventsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.testSessionEvents,
              aliasName: 'test_sessions__id__test_session_events__session_id');

  $$TestSessionEventsTableProcessedTableManager get testSessionEventsRefs {
    final manager = $$TestSessionEventsTableTableManager(
            $_db, $_db.testSessionEvents)
        .filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_testSessionEventsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$TestSessionArtifactsTable,
      List<TestSessionArtifactRow>> _testSessionArtifactsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.testSessionArtifacts,
          aliasName: 'test_sessions__id__test_session_artifacts__session_id');

  $$TestSessionArtifactsTableProcessedTableManager
      get testSessionArtifactsRefs {
    final manager = $$TestSessionArtifactsTableTableManager(
            $_db, $_db.testSessionArtifacts)
        .filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_testSessionArtifactsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$TestSessionNotesTable, List<TestSessionNoteRow>>
      _testSessionNotesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.testSessionNotes,
              aliasName: 'test_sessions__id__test_session_notes__session_id');

  $$TestSessionNotesTableProcessedTableManager get testSessionNotesRefs {
    final manager = $$TestSessionNotesTableTableManager(
            $_db, $_db.testSessionNotes)
        .filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_testSessionNotesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$TestSessionIssuesTable, List<TestSessionIssueRow>>
      _testSessionIssuesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.testSessionIssues,
              aliasName: 'test_sessions__id__test_session_issues__session_id');

  $$TestSessionIssuesTableProcessedTableManager get testSessionIssuesRefs {
    final manager = $$TestSessionIssuesTableTableManager(
            $_db, $_db.testSessionIssues)
        .filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_testSessionIssuesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$TestSessionPlanItemsTable,
      List<TestSessionPlanItemRow>> _testSessionPlanItemsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.testSessionPlanItems,
          aliasName: 'test_sessions__id__test_session_plan_items__session_id');

  $$TestSessionPlanItemsTableProcessedTableManager
      get testSessionPlanItemsRefs {
    final manager = $$TestSessionPlanItemsTableTableManager(
            $_db, $_db.testSessionPlanItems)
        .filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_testSessionPlanItemsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$TestSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $TestSessionsTable> {
  $$TestSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<TestSessionStatus, TestSessionStatus, int>
      get status => $composableBuilder(
          column: $table.status,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
      column: $table.endedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceModel => $composableBuilder(
      column: $table.deviceModel, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceBrand => $composableBuilder(
      column: $table.deviceBrand, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceSdk => $composableBuilder(
      column: $table.deviceSdk, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get packageName => $composableBuilder(
      column: $table.packageName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  $$SavedDevicesTableFilterComposer get deviceSerial {
    final $$SavedDevicesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.deviceSerial,
        referencedTable: $db.savedDevices,
        getReferencedColumn: (t) => t.serial,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SavedDevicesTableFilterComposer(
              $db: $db,
              $table: $db.savedDevices,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> testSessionEventsRefs(
      Expression<bool> Function($$TestSessionEventsTableFilterComposer f) f) {
    final $$TestSessionEventsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.testSessionEvents,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestSessionEventsTableFilterComposer(
              $db: $db,
              $table: $db.testSessionEvents,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> testSessionArtifactsRefs(
      Expression<bool> Function($$TestSessionArtifactsTableFilterComposer f)
          f) {
    final $$TestSessionArtifactsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.testSessionArtifacts,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestSessionArtifactsTableFilterComposer(
              $db: $db,
              $table: $db.testSessionArtifacts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> testSessionNotesRefs(
      Expression<bool> Function($$TestSessionNotesTableFilterComposer f) f) {
    final $$TestSessionNotesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.testSessionNotes,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestSessionNotesTableFilterComposer(
              $db: $db,
              $table: $db.testSessionNotes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> testSessionIssuesRefs(
      Expression<bool> Function($$TestSessionIssuesTableFilterComposer f) f) {
    final $$TestSessionIssuesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.testSessionIssues,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestSessionIssuesTableFilterComposer(
              $db: $db,
              $table: $db.testSessionIssues,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> testSessionPlanItemsRefs(
      Expression<bool> Function($$TestSessionPlanItemsTableFilterComposer f)
          f) {
    final $$TestSessionPlanItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.testSessionPlanItems,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestSessionPlanItemsTableFilterComposer(
              $db: $db,
              $table: $db.testSessionPlanItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$TestSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TestSessionsTable> {
  $$TestSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
      column: $table.endedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceModel => $composableBuilder(
      column: $table.deviceModel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceBrand => $composableBuilder(
      column: $table.deviceBrand, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceSdk => $composableBuilder(
      column: $table.deviceSdk, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get packageName => $composableBuilder(
      column: $table.packageName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  $$SavedDevicesTableOrderingComposer get deviceSerial {
    final $$SavedDevicesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.deviceSerial,
        referencedTable: $db.savedDevices,
        getReferencedColumn: (t) => t.serial,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SavedDevicesTableOrderingComposer(
              $db: $db,
              $table: $db.savedDevices,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TestSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TestSessionsTable> {
  $$TestSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TestSessionStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceModel => $composableBuilder(
      column: $table.deviceModel, builder: (column) => column);

  GeneratedColumn<String> get deviceBrand => $composableBuilder(
      column: $table.deviceBrand, builder: (column) => column);

  GeneratedColumn<String> get deviceSdk =>
      $composableBuilder(column: $table.deviceSdk, builder: (column) => column);

  GeneratedColumn<String> get packageName => $composableBuilder(
      column: $table.packageName, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  $$SavedDevicesTableAnnotationComposer get deviceSerial {
    final $$SavedDevicesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.deviceSerial,
        referencedTable: $db.savedDevices,
        getReferencedColumn: (t) => t.serial,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SavedDevicesTableAnnotationComposer(
              $db: $db,
              $table: $db.savedDevices,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> testSessionEventsRefs<T extends Object>(
      Expression<T> Function($$TestSessionEventsTableAnnotationComposer a) f) {
    final $$TestSessionEventsTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.testSessionEvents,
            getReferencedColumn: (t) => t.sessionId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$TestSessionEventsTableAnnotationComposer(
                  $db: $db,
                  $table: $db.testSessionEvents,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> testSessionArtifactsRefs<T extends Object>(
      Expression<T> Function($$TestSessionArtifactsTableAnnotationComposer a)
          f) {
    final $$TestSessionArtifactsTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.testSessionArtifacts,
            getReferencedColumn: (t) => t.sessionId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$TestSessionArtifactsTableAnnotationComposer(
                  $db: $db,
                  $table: $db.testSessionArtifacts,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> testSessionNotesRefs<T extends Object>(
      Expression<T> Function($$TestSessionNotesTableAnnotationComposer a) f) {
    final $$TestSessionNotesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.testSessionNotes,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestSessionNotesTableAnnotationComposer(
              $db: $db,
              $table: $db.testSessionNotes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> testSessionIssuesRefs<T extends Object>(
      Expression<T> Function($$TestSessionIssuesTableAnnotationComposer a) f) {
    final $$TestSessionIssuesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.testSessionIssues,
            getReferencedColumn: (t) => t.sessionId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$TestSessionIssuesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.testSessionIssues,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> testSessionPlanItemsRefs<T extends Object>(
      Expression<T> Function($$TestSessionPlanItemsTableAnnotationComposer a)
          f) {
    final $$TestSessionPlanItemsTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.testSessionPlanItems,
            getReferencedColumn: (t) => t.sessionId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$TestSessionPlanItemsTableAnnotationComposer(
                  $db: $db,
                  $table: $db.testSessionPlanItems,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$TestSessionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TestSessionsTable,
    TestSessionRow,
    $$TestSessionsTableFilterComposer,
    $$TestSessionsTableOrderingComposer,
    $$TestSessionsTableAnnotationComposer,
    $$TestSessionsTableCreateCompanionBuilder,
    $$TestSessionsTableUpdateCompanionBuilder,
    (TestSessionRow, $$TestSessionsTableReferences),
    TestSessionRow,
    PrefetchHooks Function(
        {bool deviceSerial,
        bool testSessionEventsRefs,
        bool testSessionArtifactsRefs,
        bool testSessionNotesRefs,
        bool testSessionIssuesRefs,
        bool testSessionPlanItemsRefs})> {
  $$TestSessionsTableTableManager(_$AppDatabase db, $TestSessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TestSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TestSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TestSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<TestSessionStatus> status = const Value.absent(),
            Value<DateTime> startedAt = const Value.absent(),
            Value<DateTime?> endedAt = const Value.absent(),
            Value<String> deviceSerial = const Value.absent(),
            Value<String> deviceModel = const Value.absent(),
            Value<String> deviceBrand = const Value.absent(),
            Value<String> deviceSdk = const Value.absent(),
            Value<String> packageName = const Value.absent(),
            Value<String> note = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TestSessionsCompanion(
            id: id,
            name: name,
            type: type,
            status: status,
            startedAt: startedAt,
            endedAt: endedAt,
            deviceSerial: deviceSerial,
            deviceModel: deviceModel,
            deviceBrand: deviceBrand,
            deviceSdk: deviceSdk,
            packageName: packageName,
            note: note,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String type,
            required TestSessionStatus status,
            required DateTime startedAt,
            Value<DateTime?> endedAt = const Value.absent(),
            required String deviceSerial,
            Value<String> deviceModel = const Value.absent(),
            Value<String> deviceBrand = const Value.absent(),
            Value<String> deviceSdk = const Value.absent(),
            Value<String> packageName = const Value.absent(),
            Value<String> note = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TestSessionsCompanion.insert(
            id: id,
            name: name,
            type: type,
            status: status,
            startedAt: startedAt,
            endedAt: endedAt,
            deviceSerial: deviceSerial,
            deviceModel: deviceModel,
            deviceBrand: deviceBrand,
            deviceSdk: deviceSdk,
            packageName: packageName,
            note: note,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$TestSessionsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {deviceSerial = false,
              testSessionEventsRefs = false,
              testSessionArtifactsRefs = false,
              testSessionNotesRefs = false,
              testSessionIssuesRefs = false,
              testSessionPlanItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (testSessionEventsRefs) db.testSessionEvents,
                if (testSessionArtifactsRefs) db.testSessionArtifacts,
                if (testSessionNotesRefs) db.testSessionNotes,
                if (testSessionIssuesRefs) db.testSessionIssues,
                if (testSessionPlanItemsRefs) db.testSessionPlanItems
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (deviceSerial) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.deviceSerial,
                    referencedTable:
                        $$TestSessionsTableReferences._deviceSerialTable(db),
                    referencedColumn: $$TestSessionsTableReferences
                        ._deviceSerialTable(db)
                        .serial,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (testSessionEventsRefs)
                    await $_getPrefetchedData<TestSessionRow,
                            $TestSessionsTable, TestSessionEventRow>(
                        currentTable: table,
                        referencedTable: $$TestSessionsTableReferences
                            ._testSessionEventsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$TestSessionsTableReferences(db, table, p0)
                                .testSessionEventsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.sessionId == item.id),
                        typedResults: items),
                  if (testSessionArtifactsRefs)
                    await $_getPrefetchedData<TestSessionRow,
                            $TestSessionsTable, TestSessionArtifactRow>(
                        currentTable: table,
                        referencedTable: $$TestSessionsTableReferences
                            ._testSessionArtifactsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$TestSessionsTableReferences(db, table, p0)
                                .testSessionArtifactsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.sessionId == item.id),
                        typedResults: items),
                  if (testSessionNotesRefs)
                    await $_getPrefetchedData<TestSessionRow,
                            $TestSessionsTable, TestSessionNoteRow>(
                        currentTable: table,
                        referencedTable: $$TestSessionsTableReferences
                            ._testSessionNotesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$TestSessionsTableReferences(db, table, p0)
                                .testSessionNotesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.sessionId == item.id),
                        typedResults: items),
                  if (testSessionIssuesRefs)
                    await $_getPrefetchedData<TestSessionRow,
                            $TestSessionsTable, TestSessionIssueRow>(
                        currentTable: table,
                        referencedTable: $$TestSessionsTableReferences
                            ._testSessionIssuesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$TestSessionsTableReferences(db, table, p0)
                                .testSessionIssuesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.sessionId == item.id),
                        typedResults: items),
                  if (testSessionPlanItemsRefs)
                    await $_getPrefetchedData<TestSessionRow,
                            $TestSessionsTable, TestSessionPlanItemRow>(
                        currentTable: table,
                        referencedTable: $$TestSessionsTableReferences
                            ._testSessionPlanItemsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$TestSessionsTableReferences(db, table, p0)
                                .testSessionPlanItemsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.sessionId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$TestSessionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TestSessionsTable,
    TestSessionRow,
    $$TestSessionsTableFilterComposer,
    $$TestSessionsTableOrderingComposer,
    $$TestSessionsTableAnnotationComposer,
    $$TestSessionsTableCreateCompanionBuilder,
    $$TestSessionsTableUpdateCompanionBuilder,
    (TestSessionRow, $$TestSessionsTableReferences),
    TestSessionRow,
    PrefetchHooks Function(
        {bool deviceSerial,
        bool testSessionEventsRefs,
        bool testSessionArtifactsRefs,
        bool testSessionNotesRefs,
        bool testSessionIssuesRefs,
        bool testSessionPlanItemsRefs})>;
typedef $$TestSessionEventsTableCreateCompanionBuilder
    = TestSessionEventsCompanion Function({
  required String id,
  required String sessionId,
  required TestSessionEventType type,
  required DateTime time,
  required String title,
  Value<String> detail,
  Value<String?> filePath,
  Value<int> rowid,
});
typedef $$TestSessionEventsTableUpdateCompanionBuilder
    = TestSessionEventsCompanion Function({
  Value<String> id,
  Value<String> sessionId,
  Value<TestSessionEventType> type,
  Value<DateTime> time,
  Value<String> title,
  Value<String> detail,
  Value<String?> filePath,
  Value<int> rowid,
});

final class $$TestSessionEventsTableReferences extends BaseReferences<
    _$AppDatabase, $TestSessionEventsTable, TestSessionEventRow> {
  $$TestSessionEventsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $TestSessionsTable _sessionIdTable(_$AppDatabase db) => db.testSessions
      .createAlias('test_session_events__session_id__test_sessions__id');

  $$TestSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$TestSessionsTableTableManager($_db, $_db.testSessions)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$TestSessionEventsTableFilterComposer
    extends Composer<_$AppDatabase, $TestSessionEventsTable> {
  $$TestSessionEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<TestSessionEventType, TestSessionEventType,
          int>
      get type => $composableBuilder(
          column: $table.type,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<DateTime> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get detail => $composableBuilder(
      column: $table.detail, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  $$TestSessionsTableFilterComposer get sessionId {
    final $$TestSessionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.testSessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestSessionsTableFilterComposer(
              $db: $db,
              $table: $db.testSessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TestSessionEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $TestSessionEventsTable> {
  $$TestSessionEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get time => $composableBuilder(
      column: $table.time, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get detail => $composableBuilder(
      column: $table.detail, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  $$TestSessionsTableOrderingComposer get sessionId {
    final $$TestSessionsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.testSessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestSessionsTableOrderingComposer(
              $db: $db,
              $table: $db.testSessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TestSessionEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TestSessionEventsTable> {
  $$TestSessionEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TestSessionEventType, int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  $$TestSessionsTableAnnotationComposer get sessionId {
    final $$TestSessionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.testSessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestSessionsTableAnnotationComposer(
              $db: $db,
              $table: $db.testSessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TestSessionEventsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TestSessionEventsTable,
    TestSessionEventRow,
    $$TestSessionEventsTableFilterComposer,
    $$TestSessionEventsTableOrderingComposer,
    $$TestSessionEventsTableAnnotationComposer,
    $$TestSessionEventsTableCreateCompanionBuilder,
    $$TestSessionEventsTableUpdateCompanionBuilder,
    (TestSessionEventRow, $$TestSessionEventsTableReferences),
    TestSessionEventRow,
    PrefetchHooks Function({bool sessionId})> {
  $$TestSessionEventsTableTableManager(
      _$AppDatabase db, $TestSessionEventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TestSessionEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TestSessionEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TestSessionEventsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> sessionId = const Value.absent(),
            Value<TestSessionEventType> type = const Value.absent(),
            Value<DateTime> time = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> detail = const Value.absent(),
            Value<String?> filePath = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TestSessionEventsCompanion(
            id: id,
            sessionId: sessionId,
            type: type,
            time: time,
            title: title,
            detail: detail,
            filePath: filePath,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String sessionId,
            required TestSessionEventType type,
            required DateTime time,
            required String title,
            Value<String> detail = const Value.absent(),
            Value<String?> filePath = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TestSessionEventsCompanion.insert(
            id: id,
            sessionId: sessionId,
            type: type,
            time: time,
            title: title,
            detail: detail,
            filePath: filePath,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$TestSessionEventsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (sessionId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.sessionId,
                    referencedTable:
                        $$TestSessionEventsTableReferences._sessionIdTable(db),
                    referencedColumn: $$TestSessionEventsTableReferences
                        ._sessionIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$TestSessionEventsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TestSessionEventsTable,
    TestSessionEventRow,
    $$TestSessionEventsTableFilterComposer,
    $$TestSessionEventsTableOrderingComposer,
    $$TestSessionEventsTableAnnotationComposer,
    $$TestSessionEventsTableCreateCompanionBuilder,
    $$TestSessionEventsTableUpdateCompanionBuilder,
    (TestSessionEventRow, $$TestSessionEventsTableReferences),
    TestSessionEventRow,
    PrefetchHooks Function({bool sessionId})>;
typedef $$TestSessionArtifactsTableCreateCompanionBuilder
    = TestSessionArtifactsCompanion Function({
  required String id,
  required String sessionId,
  required TestSessionArtifactKind kind,
  required String name,
  required String path,
  required DateTime createdAt,
  Value<int> size,
  Value<int> rowid,
});
typedef $$TestSessionArtifactsTableUpdateCompanionBuilder
    = TestSessionArtifactsCompanion Function({
  Value<String> id,
  Value<String> sessionId,
  Value<TestSessionArtifactKind> kind,
  Value<String> name,
  Value<String> path,
  Value<DateTime> createdAt,
  Value<int> size,
  Value<int> rowid,
});

final class $$TestSessionArtifactsTableReferences extends BaseReferences<
    _$AppDatabase, $TestSessionArtifactsTable, TestSessionArtifactRow> {
  $$TestSessionArtifactsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $TestSessionsTable _sessionIdTable(_$AppDatabase db) => db.testSessions
      .createAlias('test_session_artifacts__session_id__test_sessions__id');

  $$TestSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$TestSessionsTableTableManager($_db, $_db.testSessions)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$TestSessionIssueArtifactsTable,
      List<TestSessionIssueArtifactRow>> _testSessionIssueArtifactsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.testSessionIssueArtifacts,
          aliasName:
              'test_session_artifacts__id__test_session_issue_artifacts__artifact_id');

  $$TestSessionIssueArtifactsTableProcessedTableManager
      get testSessionIssueArtifactsRefs {
    final manager = $$TestSessionIssueArtifactsTableTableManager(
            $_db, $_db.testSessionIssueArtifacts)
        .filter((f) => f.artifactId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult
        .readTableOrNull(_testSessionIssueArtifactsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$TestSessionArtifactsTableFilterComposer
    extends Composer<_$AppDatabase, $TestSessionArtifactsTable> {
  $$TestSessionArtifactsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<TestSessionArtifactKind,
          TestSessionArtifactKind, int>
      get kind => $composableBuilder(
          column: $table.kind,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get path => $composableBuilder(
      column: $table.path, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get size => $composableBuilder(
      column: $table.size, builder: (column) => ColumnFilters(column));

  $$TestSessionsTableFilterComposer get sessionId {
    final $$TestSessionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.testSessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestSessionsTableFilterComposer(
              $db: $db,
              $table: $db.testSessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> testSessionIssueArtifactsRefs(
      Expression<bool> Function(
              $$TestSessionIssueArtifactsTableFilterComposer f)
          f) {
    final $$TestSessionIssueArtifactsTableFilterComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.testSessionIssueArtifacts,
            getReferencedColumn: (t) => t.artifactId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$TestSessionIssueArtifactsTableFilterComposer(
                  $db: $db,
                  $table: $db.testSessionIssueArtifacts,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$TestSessionArtifactsTableOrderingComposer
    extends Composer<_$AppDatabase, $TestSessionArtifactsTable> {
  $$TestSessionArtifactsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get path => $composableBuilder(
      column: $table.path, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get size => $composableBuilder(
      column: $table.size, builder: (column) => ColumnOrderings(column));

  $$TestSessionsTableOrderingComposer get sessionId {
    final $$TestSessionsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.testSessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestSessionsTableOrderingComposer(
              $db: $db,
              $table: $db.testSessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TestSessionArtifactsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TestSessionArtifactsTable> {
  $$TestSessionArtifactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TestSessionArtifactKind, int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  $$TestSessionsTableAnnotationComposer get sessionId {
    final $$TestSessionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.testSessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestSessionsTableAnnotationComposer(
              $db: $db,
              $table: $db.testSessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> testSessionIssueArtifactsRefs<T extends Object>(
      Expression<T> Function(
              $$TestSessionIssueArtifactsTableAnnotationComposer a)
          f) {
    final $$TestSessionIssueArtifactsTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.testSessionIssueArtifacts,
            getReferencedColumn: (t) => t.artifactId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$TestSessionIssueArtifactsTableAnnotationComposer(
                  $db: $db,
                  $table: $db.testSessionIssueArtifacts,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$TestSessionArtifactsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TestSessionArtifactsTable,
    TestSessionArtifactRow,
    $$TestSessionArtifactsTableFilterComposer,
    $$TestSessionArtifactsTableOrderingComposer,
    $$TestSessionArtifactsTableAnnotationComposer,
    $$TestSessionArtifactsTableCreateCompanionBuilder,
    $$TestSessionArtifactsTableUpdateCompanionBuilder,
    (TestSessionArtifactRow, $$TestSessionArtifactsTableReferences),
    TestSessionArtifactRow,
    PrefetchHooks Function(
        {bool sessionId, bool testSessionIssueArtifactsRefs})> {
  $$TestSessionArtifactsTableTableManager(
      _$AppDatabase db, $TestSessionArtifactsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TestSessionArtifactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TestSessionArtifactsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TestSessionArtifactsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> sessionId = const Value.absent(),
            Value<TestSessionArtifactKind> kind = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> path = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> size = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TestSessionArtifactsCompanion(
            id: id,
            sessionId: sessionId,
            kind: kind,
            name: name,
            path: path,
            createdAt: createdAt,
            size: size,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String sessionId,
            required TestSessionArtifactKind kind,
            required String name,
            required String path,
            required DateTime createdAt,
            Value<int> size = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TestSessionArtifactsCompanion.insert(
            id: id,
            sessionId: sessionId,
            kind: kind,
            name: name,
            path: path,
            createdAt: createdAt,
            size: size,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$TestSessionArtifactsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {sessionId = false, testSessionIssueArtifactsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (testSessionIssueArtifactsRefs) db.testSessionIssueArtifacts
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (sessionId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.sessionId,
                    referencedTable: $$TestSessionArtifactsTableReferences
                        ._sessionIdTable(db),
                    referencedColumn: $$TestSessionArtifactsTableReferences
                        ._sessionIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (testSessionIssueArtifactsRefs)
                    await $_getPrefetchedData<
                            TestSessionArtifactRow,
                            $TestSessionArtifactsTable,
                            TestSessionIssueArtifactRow>(
                        currentTable: table,
                        referencedTable: $$TestSessionArtifactsTableReferences
                            ._testSessionIssueArtifactsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$TestSessionArtifactsTableReferences(db, table, p0)
                                .testSessionIssueArtifactsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.artifactId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$TestSessionArtifactsTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $TestSessionArtifactsTable,
        TestSessionArtifactRow,
        $$TestSessionArtifactsTableFilterComposer,
        $$TestSessionArtifactsTableOrderingComposer,
        $$TestSessionArtifactsTableAnnotationComposer,
        $$TestSessionArtifactsTableCreateCompanionBuilder,
        $$TestSessionArtifactsTableUpdateCompanionBuilder,
        (TestSessionArtifactRow, $$TestSessionArtifactsTableReferences),
        TestSessionArtifactRow,
        PrefetchHooks Function(
            {bool sessionId, bool testSessionIssueArtifactsRefs})>;
typedef $$TestSessionNotesTableCreateCompanionBuilder
    = TestSessionNotesCompanion Function({
  required String id,
  required String sessionId,
  required DateTime createdAt,
  required String content,
  Value<int> rowid,
});
typedef $$TestSessionNotesTableUpdateCompanionBuilder
    = TestSessionNotesCompanion Function({
  Value<String> id,
  Value<String> sessionId,
  Value<DateTime> createdAt,
  Value<String> content,
  Value<int> rowid,
});

final class $$TestSessionNotesTableReferences extends BaseReferences<
    _$AppDatabase, $TestSessionNotesTable, TestSessionNoteRow> {
  $$TestSessionNotesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $TestSessionsTable _sessionIdTable(_$AppDatabase db) => db.testSessions
      .createAlias('test_session_notes__session_id__test_sessions__id');

  $$TestSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$TestSessionsTableTableManager($_db, $_db.testSessions)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$TestSessionNotesTableFilterComposer
    extends Composer<_$AppDatabase, $TestSessionNotesTable> {
  $$TestSessionNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  $$TestSessionsTableFilterComposer get sessionId {
    final $$TestSessionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.testSessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestSessionsTableFilterComposer(
              $db: $db,
              $table: $db.testSessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TestSessionNotesTableOrderingComposer
    extends Composer<_$AppDatabase, $TestSessionNotesTable> {
  $$TestSessionNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  $$TestSessionsTableOrderingComposer get sessionId {
    final $$TestSessionsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.testSessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestSessionsTableOrderingComposer(
              $db: $db,
              $table: $db.testSessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TestSessionNotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TestSessionNotesTable> {
  $$TestSessionNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  $$TestSessionsTableAnnotationComposer get sessionId {
    final $$TestSessionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.testSessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestSessionsTableAnnotationComposer(
              $db: $db,
              $table: $db.testSessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TestSessionNotesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TestSessionNotesTable,
    TestSessionNoteRow,
    $$TestSessionNotesTableFilterComposer,
    $$TestSessionNotesTableOrderingComposer,
    $$TestSessionNotesTableAnnotationComposer,
    $$TestSessionNotesTableCreateCompanionBuilder,
    $$TestSessionNotesTableUpdateCompanionBuilder,
    (TestSessionNoteRow, $$TestSessionNotesTableReferences),
    TestSessionNoteRow,
    PrefetchHooks Function({bool sessionId})> {
  $$TestSessionNotesTableTableManager(
      _$AppDatabase db, $TestSessionNotesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TestSessionNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TestSessionNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TestSessionNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> sessionId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TestSessionNotesCompanion(
            id: id,
            sessionId: sessionId,
            createdAt: createdAt,
            content: content,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String sessionId,
            required DateTime createdAt,
            required String content,
            Value<int> rowid = const Value.absent(),
          }) =>
              TestSessionNotesCompanion.insert(
            id: id,
            sessionId: sessionId,
            createdAt: createdAt,
            content: content,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$TestSessionNotesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (sessionId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.sessionId,
                    referencedTable:
                        $$TestSessionNotesTableReferences._sessionIdTable(db),
                    referencedColumn: $$TestSessionNotesTableReferences
                        ._sessionIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$TestSessionNotesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TestSessionNotesTable,
    TestSessionNoteRow,
    $$TestSessionNotesTableFilterComposer,
    $$TestSessionNotesTableOrderingComposer,
    $$TestSessionNotesTableAnnotationComposer,
    $$TestSessionNotesTableCreateCompanionBuilder,
    $$TestSessionNotesTableUpdateCompanionBuilder,
    (TestSessionNoteRow, $$TestSessionNotesTableReferences),
    TestSessionNoteRow,
    PrefetchHooks Function({bool sessionId})>;
typedef $$TestSessionIssuesTableCreateCompanionBuilder
    = TestSessionIssuesCompanion Function({
  required String id,
  required String sessionId,
  required DateTime createdAt,
  required String title,
  required TestSessionIssueType type,
  required TestSessionIssueSeverity severity,
  Value<String> steps,
  Value<String> expected,
  Value<String> actual,
  Value<String> note,
  Value<int> rowid,
});
typedef $$TestSessionIssuesTableUpdateCompanionBuilder
    = TestSessionIssuesCompanion Function({
  Value<String> id,
  Value<String> sessionId,
  Value<DateTime> createdAt,
  Value<String> title,
  Value<TestSessionIssueType> type,
  Value<TestSessionIssueSeverity> severity,
  Value<String> steps,
  Value<String> expected,
  Value<String> actual,
  Value<String> note,
  Value<int> rowid,
});

final class $$TestSessionIssuesTableReferences extends BaseReferences<
    _$AppDatabase, $TestSessionIssuesTable, TestSessionIssueRow> {
  $$TestSessionIssuesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $TestSessionsTable _sessionIdTable(_$AppDatabase db) => db.testSessions
      .createAlias('test_session_issues__session_id__test_sessions__id');

  $$TestSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$TestSessionsTableTableManager($_db, $_db.testSessions)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$TestSessionIssueArtifactsTable,
      List<TestSessionIssueArtifactRow>> _testSessionIssueArtifactsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.testSessionIssueArtifacts,
          aliasName:
              'test_session_issues__id__test_session_issue_artifacts__issue_id');

  $$TestSessionIssueArtifactsTableProcessedTableManager
      get testSessionIssueArtifactsRefs {
    final manager = $$TestSessionIssueArtifactsTableTableManager(
            $_db, $_db.testSessionIssueArtifacts)
        .filter((f) => f.issueId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult
        .readTableOrNull(_testSessionIssueArtifactsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$TestSessionIssuesTableFilterComposer
    extends Composer<_$AppDatabase, $TestSessionIssuesTable> {
  $$TestSessionIssuesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<TestSessionIssueType, TestSessionIssueType,
          int>
      get type => $composableBuilder(
          column: $table.type,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<TestSessionIssueSeverity,
          TestSessionIssueSeverity, int>
      get severity => $composableBuilder(
          column: $table.severity,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get steps => $composableBuilder(
      column: $table.steps, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get expected => $composableBuilder(
      column: $table.expected, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get actual => $composableBuilder(
      column: $table.actual, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  $$TestSessionsTableFilterComposer get sessionId {
    final $$TestSessionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.testSessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestSessionsTableFilterComposer(
              $db: $db,
              $table: $db.testSessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> testSessionIssueArtifactsRefs(
      Expression<bool> Function(
              $$TestSessionIssueArtifactsTableFilterComposer f)
          f) {
    final $$TestSessionIssueArtifactsTableFilterComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.testSessionIssueArtifacts,
            getReferencedColumn: (t) => t.issueId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$TestSessionIssueArtifactsTableFilterComposer(
                  $db: $db,
                  $table: $db.testSessionIssueArtifacts,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$TestSessionIssuesTableOrderingComposer
    extends Composer<_$AppDatabase, $TestSessionIssuesTable> {
  $$TestSessionIssuesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get severity => $composableBuilder(
      column: $table.severity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get steps => $composableBuilder(
      column: $table.steps, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get expected => $composableBuilder(
      column: $table.expected, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get actual => $composableBuilder(
      column: $table.actual, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  $$TestSessionsTableOrderingComposer get sessionId {
    final $$TestSessionsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.testSessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestSessionsTableOrderingComposer(
              $db: $db,
              $table: $db.testSessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TestSessionIssuesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TestSessionIssuesTable> {
  $$TestSessionIssuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TestSessionIssueType, int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TestSessionIssueSeverity, int>
      get severity => $composableBuilder(
          column: $table.severity, builder: (column) => column);

  GeneratedColumn<String> get steps =>
      $composableBuilder(column: $table.steps, builder: (column) => column);

  GeneratedColumn<String> get expected =>
      $composableBuilder(column: $table.expected, builder: (column) => column);

  GeneratedColumn<String> get actual =>
      $composableBuilder(column: $table.actual, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  $$TestSessionsTableAnnotationComposer get sessionId {
    final $$TestSessionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.testSessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestSessionsTableAnnotationComposer(
              $db: $db,
              $table: $db.testSessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> testSessionIssueArtifactsRefs<T extends Object>(
      Expression<T> Function(
              $$TestSessionIssueArtifactsTableAnnotationComposer a)
          f) {
    final $$TestSessionIssueArtifactsTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.testSessionIssueArtifacts,
            getReferencedColumn: (t) => t.issueId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$TestSessionIssueArtifactsTableAnnotationComposer(
                  $db: $db,
                  $table: $db.testSessionIssueArtifacts,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$TestSessionIssuesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TestSessionIssuesTable,
    TestSessionIssueRow,
    $$TestSessionIssuesTableFilterComposer,
    $$TestSessionIssuesTableOrderingComposer,
    $$TestSessionIssuesTableAnnotationComposer,
    $$TestSessionIssuesTableCreateCompanionBuilder,
    $$TestSessionIssuesTableUpdateCompanionBuilder,
    (TestSessionIssueRow, $$TestSessionIssuesTableReferences),
    TestSessionIssueRow,
    PrefetchHooks Function(
        {bool sessionId, bool testSessionIssueArtifactsRefs})> {
  $$TestSessionIssuesTableTableManager(
      _$AppDatabase db, $TestSessionIssuesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TestSessionIssuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TestSessionIssuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TestSessionIssuesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> sessionId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<TestSessionIssueType> type = const Value.absent(),
            Value<TestSessionIssueSeverity> severity = const Value.absent(),
            Value<String> steps = const Value.absent(),
            Value<String> expected = const Value.absent(),
            Value<String> actual = const Value.absent(),
            Value<String> note = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TestSessionIssuesCompanion(
            id: id,
            sessionId: sessionId,
            createdAt: createdAt,
            title: title,
            type: type,
            severity: severity,
            steps: steps,
            expected: expected,
            actual: actual,
            note: note,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String sessionId,
            required DateTime createdAt,
            required String title,
            required TestSessionIssueType type,
            required TestSessionIssueSeverity severity,
            Value<String> steps = const Value.absent(),
            Value<String> expected = const Value.absent(),
            Value<String> actual = const Value.absent(),
            Value<String> note = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TestSessionIssuesCompanion.insert(
            id: id,
            sessionId: sessionId,
            createdAt: createdAt,
            title: title,
            type: type,
            severity: severity,
            steps: steps,
            expected: expected,
            actual: actual,
            note: note,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$TestSessionIssuesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {sessionId = false, testSessionIssueArtifactsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (testSessionIssueArtifactsRefs) db.testSessionIssueArtifacts
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (sessionId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.sessionId,
                    referencedTable:
                        $$TestSessionIssuesTableReferences._sessionIdTable(db),
                    referencedColumn: $$TestSessionIssuesTableReferences
                        ._sessionIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (testSessionIssueArtifactsRefs)
                    await $_getPrefetchedData<
                            TestSessionIssueRow,
                            $TestSessionIssuesTable,
                            TestSessionIssueArtifactRow>(
                        currentTable: table,
                        referencedTable: $$TestSessionIssuesTableReferences
                            ._testSessionIssueArtifactsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$TestSessionIssuesTableReferences(db, table, p0)
                                .testSessionIssueArtifactsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.issueId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$TestSessionIssuesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TestSessionIssuesTable,
    TestSessionIssueRow,
    $$TestSessionIssuesTableFilterComposer,
    $$TestSessionIssuesTableOrderingComposer,
    $$TestSessionIssuesTableAnnotationComposer,
    $$TestSessionIssuesTableCreateCompanionBuilder,
    $$TestSessionIssuesTableUpdateCompanionBuilder,
    (TestSessionIssueRow, $$TestSessionIssuesTableReferences),
    TestSessionIssueRow,
    PrefetchHooks Function(
        {bool sessionId, bool testSessionIssueArtifactsRefs})>;
typedef $$TestSessionPlanItemsTableCreateCompanionBuilder
    = TestSessionPlanItemsCompanion Function({
  required String id,
  required String sessionId,
  required String flowName,
  required String step,
  required TestSessionPlanStatus status,
  Value<String> message,
  Value<DateTime?> startedAt,
  Value<DateTime?> updatedAt,
  Value<int> sortOrder,
  Value<int> rowid,
});
typedef $$TestSessionPlanItemsTableUpdateCompanionBuilder
    = TestSessionPlanItemsCompanion Function({
  Value<String> id,
  Value<String> sessionId,
  Value<String> flowName,
  Value<String> step,
  Value<TestSessionPlanStatus> status,
  Value<String> message,
  Value<DateTime?> startedAt,
  Value<DateTime?> updatedAt,
  Value<int> sortOrder,
  Value<int> rowid,
});

final class $$TestSessionPlanItemsTableReferences extends BaseReferences<
    _$AppDatabase, $TestSessionPlanItemsTable, TestSessionPlanItemRow> {
  $$TestSessionPlanItemsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $TestSessionsTable _sessionIdTable(_$AppDatabase db) => db.testSessions
      .createAlias('test_session_plan_items__session_id__test_sessions__id');

  $$TestSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$TestSessionsTableTableManager($_db, $_db.testSessions)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$TestSessionPlanItemsTableFilterComposer
    extends Composer<_$AppDatabase, $TestSessionPlanItemsTable> {
  $$TestSessionPlanItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get flowName => $composableBuilder(
      column: $table.flowName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get step => $composableBuilder(
      column: $table.step, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<TestSessionPlanStatus, TestSessionPlanStatus,
          int>
      get status => $composableBuilder(
          column: $table.status,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get message => $composableBuilder(
      column: $table.message, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  $$TestSessionsTableFilterComposer get sessionId {
    final $$TestSessionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.testSessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestSessionsTableFilterComposer(
              $db: $db,
              $table: $db.testSessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TestSessionPlanItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $TestSessionPlanItemsTable> {
  $$TestSessionPlanItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get flowName => $composableBuilder(
      column: $table.flowName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get step => $composableBuilder(
      column: $table.step, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get message => $composableBuilder(
      column: $table.message, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  $$TestSessionsTableOrderingComposer get sessionId {
    final $$TestSessionsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.testSessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestSessionsTableOrderingComposer(
              $db: $db,
              $table: $db.testSessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TestSessionPlanItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TestSessionPlanItemsTable> {
  $$TestSessionPlanItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get flowName =>
      $composableBuilder(column: $table.flowName, builder: (column) => column);

  GeneratedColumn<String> get step =>
      $composableBuilder(column: $table.step, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TestSessionPlanStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$TestSessionsTableAnnotationComposer get sessionId {
    final $$TestSessionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.testSessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestSessionsTableAnnotationComposer(
              $db: $db,
              $table: $db.testSessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TestSessionPlanItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TestSessionPlanItemsTable,
    TestSessionPlanItemRow,
    $$TestSessionPlanItemsTableFilterComposer,
    $$TestSessionPlanItemsTableOrderingComposer,
    $$TestSessionPlanItemsTableAnnotationComposer,
    $$TestSessionPlanItemsTableCreateCompanionBuilder,
    $$TestSessionPlanItemsTableUpdateCompanionBuilder,
    (TestSessionPlanItemRow, $$TestSessionPlanItemsTableReferences),
    TestSessionPlanItemRow,
    PrefetchHooks Function({bool sessionId})> {
  $$TestSessionPlanItemsTableTableManager(
      _$AppDatabase db, $TestSessionPlanItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TestSessionPlanItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TestSessionPlanItemsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TestSessionPlanItemsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> sessionId = const Value.absent(),
            Value<String> flowName = const Value.absent(),
            Value<String> step = const Value.absent(),
            Value<TestSessionPlanStatus> status = const Value.absent(),
            Value<String> message = const Value.absent(),
            Value<DateTime?> startedAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TestSessionPlanItemsCompanion(
            id: id,
            sessionId: sessionId,
            flowName: flowName,
            step: step,
            status: status,
            message: message,
            startedAt: startedAt,
            updatedAt: updatedAt,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String sessionId,
            required String flowName,
            required String step,
            required TestSessionPlanStatus status,
            Value<String> message = const Value.absent(),
            Value<DateTime?> startedAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TestSessionPlanItemsCompanion.insert(
            id: id,
            sessionId: sessionId,
            flowName: flowName,
            step: step,
            status: status,
            message: message,
            startedAt: startedAt,
            updatedAt: updatedAt,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$TestSessionPlanItemsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (sessionId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.sessionId,
                    referencedTable: $$TestSessionPlanItemsTableReferences
                        ._sessionIdTable(db),
                    referencedColumn: $$TestSessionPlanItemsTableReferences
                        ._sessionIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$TestSessionPlanItemsTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $TestSessionPlanItemsTable,
        TestSessionPlanItemRow,
        $$TestSessionPlanItemsTableFilterComposer,
        $$TestSessionPlanItemsTableOrderingComposer,
        $$TestSessionPlanItemsTableAnnotationComposer,
        $$TestSessionPlanItemsTableCreateCompanionBuilder,
        $$TestSessionPlanItemsTableUpdateCompanionBuilder,
        (TestSessionPlanItemRow, $$TestSessionPlanItemsTableReferences),
        TestSessionPlanItemRow,
        PrefetchHooks Function({bool sessionId})>;
typedef $$TestSessionIssueArtifactsTableCreateCompanionBuilder
    = TestSessionIssueArtifactsCompanion Function({
  required String issueId,
  required String artifactId,
  Value<int> rowid,
});
typedef $$TestSessionIssueArtifactsTableUpdateCompanionBuilder
    = TestSessionIssueArtifactsCompanion Function({
  Value<String> issueId,
  Value<String> artifactId,
  Value<int> rowid,
});

final class $$TestSessionIssueArtifactsTableReferences extends BaseReferences<
    _$AppDatabase,
    $TestSessionIssueArtifactsTable,
    TestSessionIssueArtifactRow> {
  $$TestSessionIssueArtifactsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $TestSessionIssuesTable _issueIdTable(_$AppDatabase db) =>
      db.testSessionIssues.createAlias(
          'test_session_issue_artifacts__issue_id__test_session_issues__id');

  $$TestSessionIssuesTableProcessedTableManager get issueId {
    final $_column = $_itemColumn<String>('issue_id')!;

    final manager =
        $$TestSessionIssuesTableTableManager($_db, $_db.testSessionIssues)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_issueIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $TestSessionArtifactsTable _artifactIdTable(_$AppDatabase db) =>
      db.testSessionArtifacts.createAlias(
          'test_session_issue_artifacts__artifact_id__test_session_artifacts__id');

  $$TestSessionArtifactsTableProcessedTableManager get artifactId {
    final $_column = $_itemColumn<String>('artifact_id')!;

    final manager =
        $$TestSessionArtifactsTableTableManager($_db, $_db.testSessionArtifacts)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_artifactIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$TestSessionIssueArtifactsTableFilterComposer
    extends Composer<_$AppDatabase, $TestSessionIssueArtifactsTable> {
  $$TestSessionIssueArtifactsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TestSessionIssuesTableFilterComposer get issueId {
    final $$TestSessionIssuesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.issueId,
        referencedTable: $db.testSessionIssues,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestSessionIssuesTableFilterComposer(
              $db: $db,
              $table: $db.testSessionIssues,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$TestSessionArtifactsTableFilterComposer get artifactId {
    final $$TestSessionArtifactsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.artifactId,
        referencedTable: $db.testSessionArtifacts,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestSessionArtifactsTableFilterComposer(
              $db: $db,
              $table: $db.testSessionArtifacts,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TestSessionIssueArtifactsTableOrderingComposer
    extends Composer<_$AppDatabase, $TestSessionIssueArtifactsTable> {
  $$TestSessionIssueArtifactsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TestSessionIssuesTableOrderingComposer get issueId {
    final $$TestSessionIssuesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.issueId,
        referencedTable: $db.testSessionIssues,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TestSessionIssuesTableOrderingComposer(
              $db: $db,
              $table: $db.testSessionIssues,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$TestSessionArtifactsTableOrderingComposer get artifactId {
    final $$TestSessionArtifactsTableOrderingComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.artifactId,
            referencedTable: $db.testSessionArtifacts,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$TestSessionArtifactsTableOrderingComposer(
                  $db: $db,
                  $table: $db.testSessionArtifacts,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return composer;
  }
}

class $$TestSessionIssueArtifactsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TestSessionIssueArtifactsTable> {
  $$TestSessionIssueArtifactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TestSessionIssuesTableAnnotationComposer get issueId {
    final $$TestSessionIssuesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.issueId,
            referencedTable: $db.testSessionIssues,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$TestSessionIssuesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.testSessionIssues,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return composer;
  }

  $$TestSessionArtifactsTableAnnotationComposer get artifactId {
    final $$TestSessionArtifactsTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.artifactId,
            referencedTable: $db.testSessionArtifacts,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$TestSessionArtifactsTableAnnotationComposer(
                  $db: $db,
                  $table: $db.testSessionArtifacts,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return composer;
  }
}

class $$TestSessionIssueArtifactsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TestSessionIssueArtifactsTable,
    TestSessionIssueArtifactRow,
    $$TestSessionIssueArtifactsTableFilterComposer,
    $$TestSessionIssueArtifactsTableOrderingComposer,
    $$TestSessionIssueArtifactsTableAnnotationComposer,
    $$TestSessionIssueArtifactsTableCreateCompanionBuilder,
    $$TestSessionIssueArtifactsTableUpdateCompanionBuilder,
    (TestSessionIssueArtifactRow, $$TestSessionIssueArtifactsTableReferences),
    TestSessionIssueArtifactRow,
    PrefetchHooks Function({bool issueId, bool artifactId})> {
  $$TestSessionIssueArtifactsTableTableManager(
      _$AppDatabase db, $TestSessionIssueArtifactsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TestSessionIssueArtifactsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$TestSessionIssueArtifactsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TestSessionIssueArtifactsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> issueId = const Value.absent(),
            Value<String> artifactId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TestSessionIssueArtifactsCompanion(
            issueId: issueId,
            artifactId: artifactId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String issueId,
            required String artifactId,
            Value<int> rowid = const Value.absent(),
          }) =>
              TestSessionIssueArtifactsCompanion.insert(
            issueId: issueId,
            artifactId: artifactId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$TestSessionIssueArtifactsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({issueId = false, artifactId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (issueId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.issueId,
                    referencedTable: $$TestSessionIssueArtifactsTableReferences
                        ._issueIdTable(db),
                    referencedColumn: $$TestSessionIssueArtifactsTableReferences
                        ._issueIdTable(db)
                        .id,
                  ) as T;
                }
                if (artifactId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.artifactId,
                    referencedTable: $$TestSessionIssueArtifactsTableReferences
                        ._artifactIdTable(db),
                    referencedColumn: $$TestSessionIssueArtifactsTableReferences
                        ._artifactIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$TestSessionIssueArtifactsTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $TestSessionIssueArtifactsTable,
        TestSessionIssueArtifactRow,
        $$TestSessionIssueArtifactsTableFilterComposer,
        $$TestSessionIssueArtifactsTableOrderingComposer,
        $$TestSessionIssueArtifactsTableAnnotationComposer,
        $$TestSessionIssueArtifactsTableCreateCompanionBuilder,
        $$TestSessionIssueArtifactsTableUpdateCompanionBuilder,
        (
          TestSessionIssueArtifactRow,
          $$TestSessionIssueArtifactsTableReferences
        ),
        TestSessionIssueArtifactRow,
        PrefetchHooks Function({bool issueId, bool artifactId})>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SavedDevicesTableTableManager get savedDevices =>
      $$SavedDevicesTableTableManager(_db, _db.savedDevices);
  $$AppStatesTableTableManager get appStates =>
      $$AppStatesTableTableManager(_db, _db.appStates);
  $$TestSessionsTableTableManager get testSessions =>
      $$TestSessionsTableTableManager(_db, _db.testSessions);
  $$TestSessionEventsTableTableManager get testSessionEvents =>
      $$TestSessionEventsTableTableManager(_db, _db.testSessionEvents);
  $$TestSessionArtifactsTableTableManager get testSessionArtifacts =>
      $$TestSessionArtifactsTableTableManager(_db, _db.testSessionArtifacts);
  $$TestSessionNotesTableTableManager get testSessionNotes =>
      $$TestSessionNotesTableTableManager(_db, _db.testSessionNotes);
  $$TestSessionIssuesTableTableManager get testSessionIssues =>
      $$TestSessionIssuesTableTableManager(_db, _db.testSessionIssues);
  $$TestSessionPlanItemsTableTableManager get testSessionPlanItems =>
      $$TestSessionPlanItemsTableTableManager(_db, _db.testSessionPlanItems);
  $$TestSessionIssueArtifactsTableTableManager get testSessionIssueArtifacts =>
      $$TestSessionIssueArtifactsTableTableManager(
          _db, _db.testSessionIssueArtifacts);
}
