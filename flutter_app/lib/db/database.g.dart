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
  static const VerificationMeta _recordingOwnerMeta =
      const VerificationMeta('recordingOwner');
  @override
  late final GeneratedColumn<String> recordingOwner = GeneratedColumn<String>(
      'recording_owner', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _recordingStartedAtMeta =
      const VerificationMeta('recordingStartedAt');
  @override
  late final GeneratedColumn<int> recordingStartedAt = GeneratedColumn<int>(
      'recording_started_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _recordingIsSavingMeta =
      const VerificationMeta('recordingIsSaving');
  @override
  late final GeneratedColumn<bool> recordingIsSaving = GeneratedColumn<bool>(
      'recording_is_saving', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("recording_is_saving" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        serial,
        model,
        brand,
        sdk,
        isConnected,
        firstSeenAt,
        lastSeenAt,
        recordingOwner,
        recordingStartedAt,
        recordingIsSaving
      ];
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
    if (data.containsKey('recording_owner')) {
      context.handle(
          _recordingOwnerMeta,
          recordingOwner.isAcceptableOrUnknown(
              data['recording_owner']!, _recordingOwnerMeta));
    }
    if (data.containsKey('recording_started_at')) {
      context.handle(
          _recordingStartedAtMeta,
          recordingStartedAt.isAcceptableOrUnknown(
              data['recording_started_at']!, _recordingStartedAtMeta));
    }
    if (data.containsKey('recording_is_saving')) {
      context.handle(
          _recordingIsSavingMeta,
          recordingIsSaving.isAcceptableOrUnknown(
              data['recording_is_saving']!, _recordingIsSavingMeta));
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
      recordingOwner: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recording_owner']),
      recordingStartedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}recording_started_at']),
      recordingIsSaving: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}recording_is_saving'])!,
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

  /// Who owns the in-flight screen recording on this device. One of
  /// `null` (idle) / `'file_browser'` / `'test_session'`. Set when a
  /// recording starts, cleared when it ends (success, failure, or
  /// abandoned).
  final String? recordingOwner;

  /// Wall-clock time the in-flight recording started. `null` when
  /// [recordingOwner] is null. Used by the UI to compute elapsed
  /// seconds = `DateTime.now() - recordingStartedAt` without needing
  /// a per-second DB write.
  final int? recordingStartedAt;

  /// True while the recording has been stopped on the adb side and
  /// the bytes are being pulled / written to disk. While true, the
  /// "停止" button is disabled and shows a "保存中..." spinner.
  final bool recordingIsSaving;
  const SavedDevice(
      {required this.serial,
      required this.model,
      required this.brand,
      required this.sdk,
      required this.isConnected,
      required this.firstSeenAt,
      this.lastSeenAt,
      this.recordingOwner,
      this.recordingStartedAt,
      required this.recordingIsSaving});
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
    if (!nullToAbsent || recordingOwner != null) {
      map['recording_owner'] = Variable<String>(recordingOwner);
    }
    if (!nullToAbsent || recordingStartedAt != null) {
      map['recording_started_at'] = Variable<int>(recordingStartedAt);
    }
    map['recording_is_saving'] = Variable<bool>(recordingIsSaving);
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
      recordingOwner: recordingOwner == null && nullToAbsent
          ? const Value.absent()
          : Value(recordingOwner),
      recordingStartedAt: recordingStartedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(recordingStartedAt),
      recordingIsSaving: Value(recordingIsSaving),
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
      recordingOwner: serializer.fromJson<String?>(json['recordingOwner']),
      recordingStartedAt: serializer.fromJson<int?>(json['recordingStartedAt']),
      recordingIsSaving: serializer.fromJson<bool>(json['recordingIsSaving']),
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
      'recordingOwner': serializer.toJson<String?>(recordingOwner),
      'recordingStartedAt': serializer.toJson<int?>(recordingStartedAt),
      'recordingIsSaving': serializer.toJson<bool>(recordingIsSaving),
    };
  }

  SavedDevice copyWith(
          {String? serial,
          String? model,
          String? brand,
          String? sdk,
          bool? isConnected,
          DateTime? firstSeenAt,
          Value<DateTime?> lastSeenAt = const Value.absent(),
          Value<String?> recordingOwner = const Value.absent(),
          Value<int?> recordingStartedAt = const Value.absent(),
          bool? recordingIsSaving}) =>
      SavedDevice(
        serial: serial ?? this.serial,
        model: model ?? this.model,
        brand: brand ?? this.brand,
        sdk: sdk ?? this.sdk,
        isConnected: isConnected ?? this.isConnected,
        firstSeenAt: firstSeenAt ?? this.firstSeenAt,
        lastSeenAt: lastSeenAt.present ? lastSeenAt.value : this.lastSeenAt,
        recordingOwner:
            recordingOwner.present ? recordingOwner.value : this.recordingOwner,
        recordingStartedAt: recordingStartedAt.present
            ? recordingStartedAt.value
            : this.recordingStartedAt,
        recordingIsSaving: recordingIsSaving ?? this.recordingIsSaving,
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
      recordingOwner: data.recordingOwner.present
          ? data.recordingOwner.value
          : this.recordingOwner,
      recordingStartedAt: data.recordingStartedAt.present
          ? data.recordingStartedAt.value
          : this.recordingStartedAt,
      recordingIsSaving: data.recordingIsSaving.present
          ? data.recordingIsSaving.value
          : this.recordingIsSaving,
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
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('recordingOwner: $recordingOwner, ')
          ..write('recordingStartedAt: $recordingStartedAt, ')
          ..write('recordingIsSaving: $recordingIsSaving')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      serial,
      model,
      brand,
      sdk,
      isConnected,
      firstSeenAt,
      lastSeenAt,
      recordingOwner,
      recordingStartedAt,
      recordingIsSaving);
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
          other.lastSeenAt == this.lastSeenAt &&
          other.recordingOwner == this.recordingOwner &&
          other.recordingStartedAt == this.recordingStartedAt &&
          other.recordingIsSaving == this.recordingIsSaving);
}

class SavedDevicesCompanion extends UpdateCompanion<SavedDevice> {
  final Value<String> serial;
  final Value<String> model;
  final Value<String> brand;
  final Value<String> sdk;
  final Value<bool> isConnected;
  final Value<DateTime> firstSeenAt;
  final Value<DateTime?> lastSeenAt;
  final Value<String?> recordingOwner;
  final Value<int?> recordingStartedAt;
  final Value<bool> recordingIsSaving;
  final Value<int> rowid;
  const SavedDevicesCompanion({
    this.serial = const Value.absent(),
    this.model = const Value.absent(),
    this.brand = const Value.absent(),
    this.sdk = const Value.absent(),
    this.isConnected = const Value.absent(),
    this.firstSeenAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.recordingOwner = const Value.absent(),
    this.recordingStartedAt = const Value.absent(),
    this.recordingIsSaving = const Value.absent(),
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
    this.recordingOwner = const Value.absent(),
    this.recordingStartedAt = const Value.absent(),
    this.recordingIsSaving = const Value.absent(),
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
    Expression<String>? recordingOwner,
    Expression<int>? recordingStartedAt,
    Expression<bool>? recordingIsSaving,
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
      if (recordingOwner != null) 'recording_owner': recordingOwner,
      if (recordingStartedAt != null)
        'recording_started_at': recordingStartedAt,
      if (recordingIsSaving != null) 'recording_is_saving': recordingIsSaving,
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
      Value<String?>? recordingOwner,
      Value<int?>? recordingStartedAt,
      Value<bool>? recordingIsSaving,
      Value<int>? rowid}) {
    return SavedDevicesCompanion(
      serial: serial ?? this.serial,
      model: model ?? this.model,
      brand: brand ?? this.brand,
      sdk: sdk ?? this.sdk,
      isConnected: isConnected ?? this.isConnected,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      recordingOwner: recordingOwner ?? this.recordingOwner,
      recordingStartedAt: recordingStartedAt ?? this.recordingStartedAt,
      recordingIsSaving: recordingIsSaving ?? this.recordingIsSaving,
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
    if (recordingOwner.present) {
      map['recording_owner'] = Variable<String>(recordingOwner.value);
    }
    if (recordingStartedAt.present) {
      map['recording_started_at'] = Variable<int>(recordingStartedAt.value);
    }
    if (recordingIsSaving.present) {
      map['recording_is_saving'] = Variable<bool>(recordingIsSaving.value);
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
          ..write('recordingOwner: $recordingOwner, ')
          ..write('recordingStartedAt: $recordingStartedAt, ')
          ..write('recordingIsSaving: $recordingIsSaving, ')
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

class $ScrcpyOptions_Table extends ScrcpyOptions_
    with TableInfo<$ScrcpyOptions_Table, ScrcpyOptions_Data> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScrcpyOptions_Table(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serialMeta = const VerificationMeta('serial');
  @override
  late final GeneratedColumn<String> serial = GeneratedColumn<String>(
      'serial', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _maxSizeMeta =
      const VerificationMeta('maxSize');
  @override
  late final GeneratedColumn<int> maxSize = GeneratedColumn<int>(
      'max_size', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _videoBitRateMeta =
      const VerificationMeta('videoBitRate');
  @override
  late final GeneratedColumn<String> videoBitRate = GeneratedColumn<String>(
      'video_bit_rate', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _maxFpsMeta = const VerificationMeta('maxFps');
  @override
  late final GeneratedColumn<int> maxFps = GeneratedColumn<int>(
      'max_fps', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _videoCodecMeta =
      const VerificationMeta('videoCodec');
  @override
  late final GeneratedColumn<String> videoCodec = GeneratedColumn<String>(
      'video_codec', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _videoEncoderMeta =
      const VerificationMeta('videoEncoder');
  @override
  late final GeneratedColumn<String> videoEncoder = GeneratedColumn<String>(
      'video_encoder', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _videoBufferMeta =
      const VerificationMeta('videoBuffer');
  @override
  late final GeneratedColumn<int> videoBuffer = GeneratedColumn<int>(
      'video_buffer', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _noMipmapsMeta =
      const VerificationMeta('noMipmaps');
  @override
  late final GeneratedColumn<bool> noMipmaps = GeneratedColumn<bool>(
      'no_mipmaps', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("no_mipmaps" IN (0, 1))'));
  static const VerificationMeta _captureOrientationMeta =
      const VerificationMeta('captureOrientation');
  @override
  late final GeneratedColumn<String> captureOrientation =
      GeneratedColumn<String>('capture_orientation', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _displayOrientationMeta =
      const VerificationMeta('displayOrientation');
  @override
  late final GeneratedColumn<String> displayOrientation =
      GeneratedColumn<String>('display_orientation', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cropMeta = const VerificationMeta('crop');
  @override
  late final GeneratedColumn<String> crop = GeneratedColumn<String>(
      'crop', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _angleMeta = const VerificationMeta('angle');
  @override
  late final GeneratedColumn<int> angle = GeneratedColumn<int>(
      'angle', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _displayIdMeta =
      const VerificationMeta('displayId');
  @override
  late final GeneratedColumn<int> displayId = GeneratedColumn<int>(
      'display_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _renderFitMeta =
      const VerificationMeta('renderFit');
  @override
  late final GeneratedColumn<String> renderFit = GeneratedColumn<String>(
      'render_fit', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _backgroundColorMeta =
      const VerificationMeta('backgroundColor');
  @override
  late final GeneratedColumn<String> backgroundColor = GeneratedColumn<String>(
      'background_color', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _minSizeAlignmentMeta =
      const VerificationMeta('minSizeAlignment');
  @override
  late final GeneratedColumn<int> minSizeAlignment = GeneratedColumn<int>(
      'min_size_alignment', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _noDownsizeOnErrorMeta =
      const VerificationMeta('noDownsizeOnError');
  @override
  late final GeneratedColumn<bool> noDownsizeOnError = GeneratedColumn<bool>(
      'no_downsize_on_error', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("no_downsize_on_error" IN (0, 1))'));
  static const VerificationMeta _printFpsMeta =
      const VerificationMeta('printFps');
  @override
  late final GeneratedColumn<bool> printFps = GeneratedColumn<bool>(
      'print_fps', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("print_fps" IN (0, 1))'));
  static const VerificationMeta _noAudioMeta =
      const VerificationMeta('noAudio');
  @override
  late final GeneratedColumn<bool> noAudio = GeneratedColumn<bool>(
      'no_audio', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("no_audio" IN (0, 1))'));
  static const VerificationMeta _noAudioPlaybackMeta =
      const VerificationMeta('noAudioPlayback');
  @override
  late final GeneratedColumn<bool> noAudioPlayback = GeneratedColumn<bool>(
      'no_audio_playback', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("no_audio_playback" IN (0, 1))'));
  static const VerificationMeta _audioSourceMeta =
      const VerificationMeta('audioSource');
  @override
  late final GeneratedColumn<String> audioSource = GeneratedColumn<String>(
      'audio_source', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _audioCodecMeta =
      const VerificationMeta('audioCodec');
  @override
  late final GeneratedColumn<String> audioCodec = GeneratedColumn<String>(
      'audio_codec', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _audioEncoderMeta =
      const VerificationMeta('audioEncoder');
  @override
  late final GeneratedColumn<String> audioEncoder = GeneratedColumn<String>(
      'audio_encoder', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _audioBitRateMeta =
      const VerificationMeta('audioBitRate');
  @override
  late final GeneratedColumn<String> audioBitRate = GeneratedColumn<String>(
      'audio_bit_rate', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _audioBufferMeta =
      const VerificationMeta('audioBuffer');
  @override
  late final GeneratedColumn<int> audioBuffer = GeneratedColumn<int>(
      'audio_buffer', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _audioOutputBufferMeta =
      const VerificationMeta('audioOutputBuffer');
  @override
  late final GeneratedColumn<int> audioOutputBuffer = GeneratedColumn<int>(
      'audio_output_buffer', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _audioDupMeta =
      const VerificationMeta('audioDup');
  @override
  late final GeneratedColumn<bool> audioDup = GeneratedColumn<bool>(
      'audio_dup', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("audio_dup" IN (0, 1))'));
  static const VerificationMeta _requireAudioMeta =
      const VerificationMeta('requireAudio');
  @override
  late final GeneratedColumn<bool> requireAudio = GeneratedColumn<bool>(
      'require_audio', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("require_audio" IN (0, 1))'));
  static const VerificationMeta _videoSourceMeta =
      const VerificationMeta('videoSource');
  @override
  late final GeneratedColumn<String> videoSource = GeneratedColumn<String>(
      'video_source', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cameraIdMeta =
      const VerificationMeta('cameraId');
  @override
  late final GeneratedColumn<int> cameraId = GeneratedColumn<int>(
      'camera_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _cameraFacingMeta =
      const VerificationMeta('cameraFacing');
  @override
  late final GeneratedColumn<String> cameraFacing = GeneratedColumn<String>(
      'camera_facing', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cameraSizeMeta =
      const VerificationMeta('cameraSize');
  @override
  late final GeneratedColumn<String> cameraSize = GeneratedColumn<String>(
      'camera_size', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cameraArMeta =
      const VerificationMeta('cameraAr');
  @override
  late final GeneratedColumn<String> cameraAr = GeneratedColumn<String>(
      'camera_ar', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cameraFpsMeta =
      const VerificationMeta('cameraFps');
  @override
  late final GeneratedColumn<int> cameraFps = GeneratedColumn<int>(
      'camera_fps', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _cameraHighSpeedMeta =
      const VerificationMeta('cameraHighSpeed');
  @override
  late final GeneratedColumn<bool> cameraHighSpeed = GeneratedColumn<bool>(
      'camera_high_speed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("camera_high_speed" IN (0, 1))'));
  static const VerificationMeta _cameraTorchMeta =
      const VerificationMeta('cameraTorch');
  @override
  late final GeneratedColumn<bool> cameraTorch = GeneratedColumn<bool>(
      'camera_torch', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("camera_torch" IN (0, 1))'));
  static const VerificationMeta _cameraZoomMeta =
      const VerificationMeta('cameraZoom');
  @override
  late final GeneratedColumn<double> cameraZoom = GeneratedColumn<double>(
      'camera_zoom', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _borderlessMeta =
      const VerificationMeta('borderless');
  @override
  late final GeneratedColumn<bool> borderless = GeneratedColumn<bool>(
      'borderless', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("borderless" IN (0, 1))'));
  static const VerificationMeta _windowTitleMeta =
      const VerificationMeta('windowTitle');
  @override
  late final GeneratedColumn<String> windowTitle = GeneratedColumn<String>(
      'window_title', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _windowXMeta =
      const VerificationMeta('windowX');
  @override
  late final GeneratedColumn<int> windowX = GeneratedColumn<int>(
      'window_x', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _windowYMeta =
      const VerificationMeta('windowY');
  @override
  late final GeneratedColumn<int> windowY = GeneratedColumn<int>(
      'window_y', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _windowWidthMeta =
      const VerificationMeta('windowWidth');
  @override
  late final GeneratedColumn<int> windowWidth = GeneratedColumn<int>(
      'window_width', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _windowHeightMeta =
      const VerificationMeta('windowHeight');
  @override
  late final GeneratedColumn<int> windowHeight = GeneratedColumn<int>(
      'window_height', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _alwaysOnTopMeta =
      const VerificationMeta('alwaysOnTop');
  @override
  late final GeneratedColumn<bool> alwaysOnTop = GeneratedColumn<bool>(
      'always_on_top', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("always_on_top" IN (0, 1))'));
  static const VerificationMeta _fullscreenMeta =
      const VerificationMeta('fullscreen');
  @override
  late final GeneratedColumn<bool> fullscreen = GeneratedColumn<bool>(
      'fullscreen', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("fullscreen" IN (0, 1))'));
  static const VerificationMeta _disableScreensaverMeta =
      const VerificationMeta('disableScreensaver');
  @override
  late final GeneratedColumn<bool> disableScreensaver = GeneratedColumn<bool>(
      'disable_screensaver', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("disable_screensaver" IN (0, 1))'));
  static const VerificationMeta _noWindowMeta =
      const VerificationMeta('noWindow');
  @override
  late final GeneratedColumn<bool> noWindow = GeneratedColumn<bool>(
      'no_window', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("no_window" IN (0, 1))'));
  static const VerificationMeta _noWindowAspectRatioLockMeta =
      const VerificationMeta('noWindowAspectRatioLock');
  @override
  late final GeneratedColumn<bool> noWindowAspectRatioLock =
      GeneratedColumn<bool>('no_window_aspect_ratio_lock', aliasedName, false,
          type: DriftSqlType.bool,
          requiredDuringInsert: true,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'CHECK ("no_window_aspect_ratio_lock" IN (0, 1))'));
  static const VerificationMeta _keyboardMeta =
      const VerificationMeta('keyboard');
  @override
  late final GeneratedColumn<String> keyboard = GeneratedColumn<String>(
      'keyboard', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _mouseMeta = const VerificationMeta('mouse');
  @override
  late final GeneratedColumn<String> mouse = GeneratedColumn<String>(
      'mouse', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _noControlMeta =
      const VerificationMeta('noControl');
  @override
  late final GeneratedColumn<bool> noControl = GeneratedColumn<bool>(
      'no_control', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("no_control" IN (0, 1))'));
  static const VerificationMeta _mouseBindMeta =
      const VerificationMeta('mouseBind');
  @override
  late final GeneratedColumn<String> mouseBind = GeneratedColumn<String>(
      'mouse_bind', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _preferTextMeta =
      const VerificationMeta('preferText');
  @override
  late final GeneratedColumn<bool> preferText = GeneratedColumn<bool>(
      'prefer_text', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("prefer_text" IN (0, 1))'));
  static const VerificationMeta _rawKeyEventsMeta =
      const VerificationMeta('rawKeyEvents');
  @override
  late final GeneratedColumn<bool> rawKeyEvents = GeneratedColumn<bool>(
      'raw_key_events', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("raw_key_events" IN (0, 1))'));
  static const VerificationMeta _noKeyRepeatMeta =
      const VerificationMeta('noKeyRepeat');
  @override
  late final GeneratedColumn<bool> noKeyRepeat = GeneratedColumn<bool>(
      'no_key_repeat', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("no_key_repeat" IN (0, 1))'));
  static const VerificationMeta _noMouseHoverMeta =
      const VerificationMeta('noMouseHover');
  @override
  late final GeneratedColumn<bool> noMouseHover = GeneratedColumn<bool>(
      'no_mouse_hover', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("no_mouse_hover" IN (0, 1))'));
  static const VerificationMeta _legacyPasteMeta =
      const VerificationMeta('legacyPaste');
  @override
  late final GeneratedColumn<bool> legacyPaste = GeneratedColumn<bool>(
      'legacy_paste', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("legacy_paste" IN (0, 1))'));
  static const VerificationMeta _noClipboardAutosyncMeta =
      const VerificationMeta('noClipboardAutosync');
  @override
  late final GeneratedColumn<bool> noClipboardAutosync = GeneratedColumn<bool>(
      'no_clipboard_autosync', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("no_clipboard_autosync" IN (0, 1))'));
  static const VerificationMeta _stayAwakeMeta =
      const VerificationMeta('stayAwake');
  @override
  late final GeneratedColumn<bool> stayAwake = GeneratedColumn<bool>(
      'stay_awake', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("stay_awake" IN (0, 1))'));
  static const VerificationMeta _turnScreenOffMeta =
      const VerificationMeta('turnScreenOff');
  @override
  late final GeneratedColumn<bool> turnScreenOff = GeneratedColumn<bool>(
      'turn_screen_off', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("turn_screen_off" IN (0, 1))'));
  static const VerificationMeta _keepActiveMeta =
      const VerificationMeta('keepActive');
  @override
  late final GeneratedColumn<bool> keepActive = GeneratedColumn<bool>(
      'keep_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("keep_active" IN (0, 1))'));
  static const VerificationMeta _showTouchesMeta =
      const VerificationMeta('showTouches');
  @override
  late final GeneratedColumn<bool> showTouches = GeneratedColumn<bool>(
      'show_touches', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("show_touches" IN (0, 1))'));
  static const VerificationMeta _powerOffOnCloseMeta =
      const VerificationMeta('powerOffOnClose');
  @override
  late final GeneratedColumn<bool> powerOffOnClose = GeneratedColumn<bool>(
      'power_off_on_close', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("power_off_on_close" IN (0, 1))'));
  static const VerificationMeta _noPowerOnMeta =
      const VerificationMeta('noPowerOn');
  @override
  late final GeneratedColumn<bool> noPowerOn = GeneratedColumn<bool>(
      'no_power_on', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("no_power_on" IN (0, 1))'));
  static const VerificationMeta _screenOffTimeoutMeta =
      const VerificationMeta('screenOffTimeout');
  @override
  late final GeneratedColumn<int> screenOffTimeout = GeneratedColumn<int>(
      'screen_off_timeout', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _shortcutModMeta =
      const VerificationMeta('shortcutMod');
  @override
  late final GeneratedColumn<String> shortcutMod = GeneratedColumn<String>(
      'shortcut_mod', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _recordEnabledMeta =
      const VerificationMeta('recordEnabled');
  @override
  late final GeneratedColumn<bool> recordEnabled = GeneratedColumn<bool>(
      'record_enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("record_enabled" IN (0, 1))'));
  static const VerificationMeta _recordMeta = const VerificationMeta('record');
  @override
  late final GeneratedColumn<String> record = GeneratedColumn<String>(
      'record', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _recordFormatMeta =
      const VerificationMeta('recordFormat');
  @override
  late final GeneratedColumn<String> recordFormat = GeneratedColumn<String>(
      'record_format', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _timeLimitMeta =
      const VerificationMeta('timeLimit');
  @override
  late final GeneratedColumn<int> timeLimit = GeneratedColumn<int>(
      'time_limit', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _noPlaybackMeta =
      const VerificationMeta('noPlayback');
  @override
  late final GeneratedColumn<bool> noPlayback = GeneratedColumn<bool>(
      'no_playback', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("no_playback" IN (0, 1))'));
  static const VerificationMeta _noVideoPlaybackMeta =
      const VerificationMeta('noVideoPlayback');
  @override
  late final GeneratedColumn<bool> noVideoPlayback = GeneratedColumn<bool>(
      'no_video_playback', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("no_video_playback" IN (0, 1))'));
  static const VerificationMeta _pauseOnExitMeta =
      const VerificationMeta('pauseOnExit');
  @override
  late final GeneratedColumn<String> pauseOnExit = GeneratedColumn<String>(
      'pause_on_exit', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        serial,
        maxSize,
        videoBitRate,
        maxFps,
        videoCodec,
        videoEncoder,
        videoBuffer,
        noMipmaps,
        captureOrientation,
        displayOrientation,
        crop,
        angle,
        displayId,
        renderFit,
        backgroundColor,
        minSizeAlignment,
        noDownsizeOnError,
        printFps,
        noAudio,
        noAudioPlayback,
        audioSource,
        audioCodec,
        audioEncoder,
        audioBitRate,
        audioBuffer,
        audioOutputBuffer,
        audioDup,
        requireAudio,
        videoSource,
        cameraId,
        cameraFacing,
        cameraSize,
        cameraAr,
        cameraFps,
        cameraHighSpeed,
        cameraTorch,
        cameraZoom,
        borderless,
        windowTitle,
        windowX,
        windowY,
        windowWidth,
        windowHeight,
        alwaysOnTop,
        fullscreen,
        disableScreensaver,
        noWindow,
        noWindowAspectRatioLock,
        keyboard,
        mouse,
        noControl,
        mouseBind,
        preferText,
        rawKeyEvents,
        noKeyRepeat,
        noMouseHover,
        legacyPaste,
        noClipboardAutosync,
        stayAwake,
        turnScreenOff,
        keepActive,
        showTouches,
        powerOffOnClose,
        noPowerOn,
        screenOffTimeout,
        shortcutMod,
        recordEnabled,
        record,
        recordFormat,
        timeLimit,
        noPlayback,
        noVideoPlayback,
        pauseOnExit,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scrcpy_options';
  @override
  VerificationContext validateIntegrity(Insertable<ScrcpyOptions_Data> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('serial')) {
      context.handle(_serialMeta,
          serial.isAcceptableOrUnknown(data['serial']!, _serialMeta));
    } else if (isInserting) {
      context.missing(_serialMeta);
    }
    if (data.containsKey('max_size')) {
      context.handle(_maxSizeMeta,
          maxSize.isAcceptableOrUnknown(data['max_size']!, _maxSizeMeta));
    } else if (isInserting) {
      context.missing(_maxSizeMeta);
    }
    if (data.containsKey('video_bit_rate')) {
      context.handle(
          _videoBitRateMeta,
          videoBitRate.isAcceptableOrUnknown(
              data['video_bit_rate']!, _videoBitRateMeta));
    }
    if (data.containsKey('max_fps')) {
      context.handle(_maxFpsMeta,
          maxFps.isAcceptableOrUnknown(data['max_fps']!, _maxFpsMeta));
    } else if (isInserting) {
      context.missing(_maxFpsMeta);
    }
    if (data.containsKey('video_codec')) {
      context.handle(
          _videoCodecMeta,
          videoCodec.isAcceptableOrUnknown(
              data['video_codec']!, _videoCodecMeta));
    }
    if (data.containsKey('video_encoder')) {
      context.handle(
          _videoEncoderMeta,
          videoEncoder.isAcceptableOrUnknown(
              data['video_encoder']!, _videoEncoderMeta));
    }
    if (data.containsKey('video_buffer')) {
      context.handle(
          _videoBufferMeta,
          videoBuffer.isAcceptableOrUnknown(
              data['video_buffer']!, _videoBufferMeta));
    } else if (isInserting) {
      context.missing(_videoBufferMeta);
    }
    if (data.containsKey('no_mipmaps')) {
      context.handle(_noMipmapsMeta,
          noMipmaps.isAcceptableOrUnknown(data['no_mipmaps']!, _noMipmapsMeta));
    } else if (isInserting) {
      context.missing(_noMipmapsMeta);
    }
    if (data.containsKey('capture_orientation')) {
      context.handle(
          _captureOrientationMeta,
          captureOrientation.isAcceptableOrUnknown(
              data['capture_orientation']!, _captureOrientationMeta));
    }
    if (data.containsKey('display_orientation')) {
      context.handle(
          _displayOrientationMeta,
          displayOrientation.isAcceptableOrUnknown(
              data['display_orientation']!, _displayOrientationMeta));
    }
    if (data.containsKey('crop')) {
      context.handle(
          _cropMeta, crop.isAcceptableOrUnknown(data['crop']!, _cropMeta));
    }
    if (data.containsKey('angle')) {
      context.handle(
          _angleMeta, angle.isAcceptableOrUnknown(data['angle']!, _angleMeta));
    } else if (isInserting) {
      context.missing(_angleMeta);
    }
    if (data.containsKey('display_id')) {
      context.handle(_displayIdMeta,
          displayId.isAcceptableOrUnknown(data['display_id']!, _displayIdMeta));
    } else if (isInserting) {
      context.missing(_displayIdMeta);
    }
    if (data.containsKey('render_fit')) {
      context.handle(_renderFitMeta,
          renderFit.isAcceptableOrUnknown(data['render_fit']!, _renderFitMeta));
    }
    if (data.containsKey('background_color')) {
      context.handle(
          _backgroundColorMeta,
          backgroundColor.isAcceptableOrUnknown(
              data['background_color']!, _backgroundColorMeta));
    }
    if (data.containsKey('min_size_alignment')) {
      context.handle(
          _minSizeAlignmentMeta,
          minSizeAlignment.isAcceptableOrUnknown(
              data['min_size_alignment']!, _minSizeAlignmentMeta));
    } else if (isInserting) {
      context.missing(_minSizeAlignmentMeta);
    }
    if (data.containsKey('no_downsize_on_error')) {
      context.handle(
          _noDownsizeOnErrorMeta,
          noDownsizeOnError.isAcceptableOrUnknown(
              data['no_downsize_on_error']!, _noDownsizeOnErrorMeta));
    } else if (isInserting) {
      context.missing(_noDownsizeOnErrorMeta);
    }
    if (data.containsKey('print_fps')) {
      context.handle(_printFpsMeta,
          printFps.isAcceptableOrUnknown(data['print_fps']!, _printFpsMeta));
    } else if (isInserting) {
      context.missing(_printFpsMeta);
    }
    if (data.containsKey('no_audio')) {
      context.handle(_noAudioMeta,
          noAudio.isAcceptableOrUnknown(data['no_audio']!, _noAudioMeta));
    } else if (isInserting) {
      context.missing(_noAudioMeta);
    }
    if (data.containsKey('no_audio_playback')) {
      context.handle(
          _noAudioPlaybackMeta,
          noAudioPlayback.isAcceptableOrUnknown(
              data['no_audio_playback']!, _noAudioPlaybackMeta));
    } else if (isInserting) {
      context.missing(_noAudioPlaybackMeta);
    }
    if (data.containsKey('audio_source')) {
      context.handle(
          _audioSourceMeta,
          audioSource.isAcceptableOrUnknown(
              data['audio_source']!, _audioSourceMeta));
    }
    if (data.containsKey('audio_codec')) {
      context.handle(
          _audioCodecMeta,
          audioCodec.isAcceptableOrUnknown(
              data['audio_codec']!, _audioCodecMeta));
    }
    if (data.containsKey('audio_encoder')) {
      context.handle(
          _audioEncoderMeta,
          audioEncoder.isAcceptableOrUnknown(
              data['audio_encoder']!, _audioEncoderMeta));
    }
    if (data.containsKey('audio_bit_rate')) {
      context.handle(
          _audioBitRateMeta,
          audioBitRate.isAcceptableOrUnknown(
              data['audio_bit_rate']!, _audioBitRateMeta));
    }
    if (data.containsKey('audio_buffer')) {
      context.handle(
          _audioBufferMeta,
          audioBuffer.isAcceptableOrUnknown(
              data['audio_buffer']!, _audioBufferMeta));
    } else if (isInserting) {
      context.missing(_audioBufferMeta);
    }
    if (data.containsKey('audio_output_buffer')) {
      context.handle(
          _audioOutputBufferMeta,
          audioOutputBuffer.isAcceptableOrUnknown(
              data['audio_output_buffer']!, _audioOutputBufferMeta));
    } else if (isInserting) {
      context.missing(_audioOutputBufferMeta);
    }
    if (data.containsKey('audio_dup')) {
      context.handle(_audioDupMeta,
          audioDup.isAcceptableOrUnknown(data['audio_dup']!, _audioDupMeta));
    } else if (isInserting) {
      context.missing(_audioDupMeta);
    }
    if (data.containsKey('require_audio')) {
      context.handle(
          _requireAudioMeta,
          requireAudio.isAcceptableOrUnknown(
              data['require_audio']!, _requireAudioMeta));
    } else if (isInserting) {
      context.missing(_requireAudioMeta);
    }
    if (data.containsKey('video_source')) {
      context.handle(
          _videoSourceMeta,
          videoSource.isAcceptableOrUnknown(
              data['video_source']!, _videoSourceMeta));
    }
    if (data.containsKey('camera_id')) {
      context.handle(_cameraIdMeta,
          cameraId.isAcceptableOrUnknown(data['camera_id']!, _cameraIdMeta));
    } else if (isInserting) {
      context.missing(_cameraIdMeta);
    }
    if (data.containsKey('camera_facing')) {
      context.handle(
          _cameraFacingMeta,
          cameraFacing.isAcceptableOrUnknown(
              data['camera_facing']!, _cameraFacingMeta));
    }
    if (data.containsKey('camera_size')) {
      context.handle(
          _cameraSizeMeta,
          cameraSize.isAcceptableOrUnknown(
              data['camera_size']!, _cameraSizeMeta));
    }
    if (data.containsKey('camera_ar')) {
      context.handle(_cameraArMeta,
          cameraAr.isAcceptableOrUnknown(data['camera_ar']!, _cameraArMeta));
    }
    if (data.containsKey('camera_fps')) {
      context.handle(_cameraFpsMeta,
          cameraFps.isAcceptableOrUnknown(data['camera_fps']!, _cameraFpsMeta));
    } else if (isInserting) {
      context.missing(_cameraFpsMeta);
    }
    if (data.containsKey('camera_high_speed')) {
      context.handle(
          _cameraHighSpeedMeta,
          cameraHighSpeed.isAcceptableOrUnknown(
              data['camera_high_speed']!, _cameraHighSpeedMeta));
    } else if (isInserting) {
      context.missing(_cameraHighSpeedMeta);
    }
    if (data.containsKey('camera_torch')) {
      context.handle(
          _cameraTorchMeta,
          cameraTorch.isAcceptableOrUnknown(
              data['camera_torch']!, _cameraTorchMeta));
    } else if (isInserting) {
      context.missing(_cameraTorchMeta);
    }
    if (data.containsKey('camera_zoom')) {
      context.handle(
          _cameraZoomMeta,
          cameraZoom.isAcceptableOrUnknown(
              data['camera_zoom']!, _cameraZoomMeta));
    } else if (isInserting) {
      context.missing(_cameraZoomMeta);
    }
    if (data.containsKey('borderless')) {
      context.handle(
          _borderlessMeta,
          borderless.isAcceptableOrUnknown(
              data['borderless']!, _borderlessMeta));
    } else if (isInserting) {
      context.missing(_borderlessMeta);
    }
    if (data.containsKey('window_title')) {
      context.handle(
          _windowTitleMeta,
          windowTitle.isAcceptableOrUnknown(
              data['window_title']!, _windowTitleMeta));
    }
    if (data.containsKey('window_x')) {
      context.handle(_windowXMeta,
          windowX.isAcceptableOrUnknown(data['window_x']!, _windowXMeta));
    } else if (isInserting) {
      context.missing(_windowXMeta);
    }
    if (data.containsKey('window_y')) {
      context.handle(_windowYMeta,
          windowY.isAcceptableOrUnknown(data['window_y']!, _windowYMeta));
    } else if (isInserting) {
      context.missing(_windowYMeta);
    }
    if (data.containsKey('window_width')) {
      context.handle(
          _windowWidthMeta,
          windowWidth.isAcceptableOrUnknown(
              data['window_width']!, _windowWidthMeta));
    } else if (isInserting) {
      context.missing(_windowWidthMeta);
    }
    if (data.containsKey('window_height')) {
      context.handle(
          _windowHeightMeta,
          windowHeight.isAcceptableOrUnknown(
              data['window_height']!, _windowHeightMeta));
    } else if (isInserting) {
      context.missing(_windowHeightMeta);
    }
    if (data.containsKey('always_on_top')) {
      context.handle(
          _alwaysOnTopMeta,
          alwaysOnTop.isAcceptableOrUnknown(
              data['always_on_top']!, _alwaysOnTopMeta));
    } else if (isInserting) {
      context.missing(_alwaysOnTopMeta);
    }
    if (data.containsKey('fullscreen')) {
      context.handle(
          _fullscreenMeta,
          fullscreen.isAcceptableOrUnknown(
              data['fullscreen']!, _fullscreenMeta));
    } else if (isInserting) {
      context.missing(_fullscreenMeta);
    }
    if (data.containsKey('disable_screensaver')) {
      context.handle(
          _disableScreensaverMeta,
          disableScreensaver.isAcceptableOrUnknown(
              data['disable_screensaver']!, _disableScreensaverMeta));
    } else if (isInserting) {
      context.missing(_disableScreensaverMeta);
    }
    if (data.containsKey('no_window')) {
      context.handle(_noWindowMeta,
          noWindow.isAcceptableOrUnknown(data['no_window']!, _noWindowMeta));
    } else if (isInserting) {
      context.missing(_noWindowMeta);
    }
    if (data.containsKey('no_window_aspect_ratio_lock')) {
      context.handle(
          _noWindowAspectRatioLockMeta,
          noWindowAspectRatioLock.isAcceptableOrUnknown(
              data['no_window_aspect_ratio_lock']!,
              _noWindowAspectRatioLockMeta));
    } else if (isInserting) {
      context.missing(_noWindowAspectRatioLockMeta);
    }
    if (data.containsKey('keyboard')) {
      context.handle(_keyboardMeta,
          keyboard.isAcceptableOrUnknown(data['keyboard']!, _keyboardMeta));
    }
    if (data.containsKey('mouse')) {
      context.handle(
          _mouseMeta, mouse.isAcceptableOrUnknown(data['mouse']!, _mouseMeta));
    }
    if (data.containsKey('no_control')) {
      context.handle(_noControlMeta,
          noControl.isAcceptableOrUnknown(data['no_control']!, _noControlMeta));
    } else if (isInserting) {
      context.missing(_noControlMeta);
    }
    if (data.containsKey('mouse_bind')) {
      context.handle(_mouseBindMeta,
          mouseBind.isAcceptableOrUnknown(data['mouse_bind']!, _mouseBindMeta));
    }
    if (data.containsKey('prefer_text')) {
      context.handle(
          _preferTextMeta,
          preferText.isAcceptableOrUnknown(
              data['prefer_text']!, _preferTextMeta));
    } else if (isInserting) {
      context.missing(_preferTextMeta);
    }
    if (data.containsKey('raw_key_events')) {
      context.handle(
          _rawKeyEventsMeta,
          rawKeyEvents.isAcceptableOrUnknown(
              data['raw_key_events']!, _rawKeyEventsMeta));
    } else if (isInserting) {
      context.missing(_rawKeyEventsMeta);
    }
    if (data.containsKey('no_key_repeat')) {
      context.handle(
          _noKeyRepeatMeta,
          noKeyRepeat.isAcceptableOrUnknown(
              data['no_key_repeat']!, _noKeyRepeatMeta));
    } else if (isInserting) {
      context.missing(_noKeyRepeatMeta);
    }
    if (data.containsKey('no_mouse_hover')) {
      context.handle(
          _noMouseHoverMeta,
          noMouseHover.isAcceptableOrUnknown(
              data['no_mouse_hover']!, _noMouseHoverMeta));
    } else if (isInserting) {
      context.missing(_noMouseHoverMeta);
    }
    if (data.containsKey('legacy_paste')) {
      context.handle(
          _legacyPasteMeta,
          legacyPaste.isAcceptableOrUnknown(
              data['legacy_paste']!, _legacyPasteMeta));
    } else if (isInserting) {
      context.missing(_legacyPasteMeta);
    }
    if (data.containsKey('no_clipboard_autosync')) {
      context.handle(
          _noClipboardAutosyncMeta,
          noClipboardAutosync.isAcceptableOrUnknown(
              data['no_clipboard_autosync']!, _noClipboardAutosyncMeta));
    } else if (isInserting) {
      context.missing(_noClipboardAutosyncMeta);
    }
    if (data.containsKey('stay_awake')) {
      context.handle(_stayAwakeMeta,
          stayAwake.isAcceptableOrUnknown(data['stay_awake']!, _stayAwakeMeta));
    } else if (isInserting) {
      context.missing(_stayAwakeMeta);
    }
    if (data.containsKey('turn_screen_off')) {
      context.handle(
          _turnScreenOffMeta,
          turnScreenOff.isAcceptableOrUnknown(
              data['turn_screen_off']!, _turnScreenOffMeta));
    } else if (isInserting) {
      context.missing(_turnScreenOffMeta);
    }
    if (data.containsKey('keep_active')) {
      context.handle(
          _keepActiveMeta,
          keepActive.isAcceptableOrUnknown(
              data['keep_active']!, _keepActiveMeta));
    } else if (isInserting) {
      context.missing(_keepActiveMeta);
    }
    if (data.containsKey('show_touches')) {
      context.handle(
          _showTouchesMeta,
          showTouches.isAcceptableOrUnknown(
              data['show_touches']!, _showTouchesMeta));
    } else if (isInserting) {
      context.missing(_showTouchesMeta);
    }
    if (data.containsKey('power_off_on_close')) {
      context.handle(
          _powerOffOnCloseMeta,
          powerOffOnClose.isAcceptableOrUnknown(
              data['power_off_on_close']!, _powerOffOnCloseMeta));
    } else if (isInserting) {
      context.missing(_powerOffOnCloseMeta);
    }
    if (data.containsKey('no_power_on')) {
      context.handle(
          _noPowerOnMeta,
          noPowerOn.isAcceptableOrUnknown(
              data['no_power_on']!, _noPowerOnMeta));
    } else if (isInserting) {
      context.missing(_noPowerOnMeta);
    }
    if (data.containsKey('screen_off_timeout')) {
      context.handle(
          _screenOffTimeoutMeta,
          screenOffTimeout.isAcceptableOrUnknown(
              data['screen_off_timeout']!, _screenOffTimeoutMeta));
    } else if (isInserting) {
      context.missing(_screenOffTimeoutMeta);
    }
    if (data.containsKey('shortcut_mod')) {
      context.handle(
          _shortcutModMeta,
          shortcutMod.isAcceptableOrUnknown(
              data['shortcut_mod']!, _shortcutModMeta));
    }
    if (data.containsKey('record_enabled')) {
      context.handle(
          _recordEnabledMeta,
          recordEnabled.isAcceptableOrUnknown(
              data['record_enabled']!, _recordEnabledMeta));
    } else if (isInserting) {
      context.missing(_recordEnabledMeta);
    }
    if (data.containsKey('record')) {
      context.handle(_recordMeta,
          record.isAcceptableOrUnknown(data['record']!, _recordMeta));
    }
    if (data.containsKey('record_format')) {
      context.handle(
          _recordFormatMeta,
          recordFormat.isAcceptableOrUnknown(
              data['record_format']!, _recordFormatMeta));
    }
    if (data.containsKey('time_limit')) {
      context.handle(_timeLimitMeta,
          timeLimit.isAcceptableOrUnknown(data['time_limit']!, _timeLimitMeta));
    } else if (isInserting) {
      context.missing(_timeLimitMeta);
    }
    if (data.containsKey('no_playback')) {
      context.handle(
          _noPlaybackMeta,
          noPlayback.isAcceptableOrUnknown(
              data['no_playback']!, _noPlaybackMeta));
    } else if (isInserting) {
      context.missing(_noPlaybackMeta);
    }
    if (data.containsKey('no_video_playback')) {
      context.handle(
          _noVideoPlaybackMeta,
          noVideoPlayback.isAcceptableOrUnknown(
              data['no_video_playback']!, _noVideoPlaybackMeta));
    } else if (isInserting) {
      context.missing(_noVideoPlaybackMeta);
    }
    if (data.containsKey('pause_on_exit')) {
      context.handle(
          _pauseOnExitMeta,
          pauseOnExit.isAcceptableOrUnknown(
              data['pause_on_exit']!, _pauseOnExitMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serial};
  @override
  ScrcpyOptions_Data map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScrcpyOptions_Data(
      serial: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}serial'])!,
      maxSize: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}max_size'])!,
      videoBitRate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}video_bit_rate']),
      maxFps: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}max_fps'])!,
      videoCodec: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}video_codec']),
      videoEncoder: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}video_encoder']),
      videoBuffer: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}video_buffer'])!,
      noMipmaps: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}no_mipmaps'])!,
      captureOrientation: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}capture_orientation']),
      displayOrientation: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}display_orientation']),
      crop: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}crop']),
      angle: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}angle'])!,
      displayId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}display_id'])!,
      renderFit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}render_fit']),
      backgroundColor: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}background_color']),
      minSizeAlignment: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}min_size_alignment'])!,
      noDownsizeOnError: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}no_downsize_on_error'])!,
      printFps: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}print_fps'])!,
      noAudio: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}no_audio'])!,
      noAudioPlayback: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}no_audio_playback'])!,
      audioSource: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}audio_source']),
      audioCodec: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}audio_codec']),
      audioEncoder: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}audio_encoder']),
      audioBitRate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}audio_bit_rate']),
      audioBuffer: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}audio_buffer'])!,
      audioOutputBuffer: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}audio_output_buffer'])!,
      audioDup: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}audio_dup'])!,
      requireAudio: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}require_audio'])!,
      videoSource: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}video_source']),
      cameraId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}camera_id'])!,
      cameraFacing: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}camera_facing']),
      cameraSize: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}camera_size']),
      cameraAr: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}camera_ar']),
      cameraFps: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}camera_fps'])!,
      cameraHighSpeed: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}camera_high_speed'])!,
      cameraTorch: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}camera_torch'])!,
      cameraZoom: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}camera_zoom'])!,
      borderless: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}borderless'])!,
      windowTitle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}window_title']),
      windowX: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}window_x'])!,
      windowY: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}window_y'])!,
      windowWidth: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}window_width'])!,
      windowHeight: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}window_height'])!,
      alwaysOnTop: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}always_on_top'])!,
      fullscreen: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}fullscreen'])!,
      disableScreensaver: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}disable_screensaver'])!,
      noWindow: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}no_window'])!,
      noWindowAspectRatioLock: attachedDatabase.typeMapping.read(
          DriftSqlType.bool,
          data['${effectivePrefix}no_window_aspect_ratio_lock'])!,
      keyboard: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}keyboard']),
      mouse: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mouse']),
      noControl: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}no_control'])!,
      mouseBind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mouse_bind']),
      preferText: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}prefer_text'])!,
      rawKeyEvents: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}raw_key_events'])!,
      noKeyRepeat: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}no_key_repeat'])!,
      noMouseHover: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}no_mouse_hover'])!,
      legacyPaste: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}legacy_paste'])!,
      noClipboardAutosync: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}no_clipboard_autosync'])!,
      stayAwake: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}stay_awake'])!,
      turnScreenOff: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}turn_screen_off'])!,
      keepActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}keep_active'])!,
      showTouches: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}show_touches'])!,
      powerOffOnClose: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}power_off_on_close'])!,
      noPowerOn: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}no_power_on'])!,
      screenOffTimeout: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}screen_off_timeout'])!,
      shortcutMod: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}shortcut_mod']),
      recordEnabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}record_enabled'])!,
      record: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}record']),
      recordFormat: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}record_format']),
      timeLimit: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}time_limit'])!,
      noPlayback: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}no_playback'])!,
      noVideoPlayback: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}no_video_playback'])!,
      pauseOnExit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pause_on_exit']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ScrcpyOptions_Table createAlias(String alias) {
    return $ScrcpyOptions_Table(attachedDatabase, alias);
  }
}

class ScrcpyOptions_Data extends DataClass
    implements Insertable<ScrcpyOptions_Data> {
  final String serial;
  final int maxSize;
  final String? videoBitRate;
  final int maxFps;
  final String? videoCodec;
  final String? videoEncoder;
  final int videoBuffer;
  final bool noMipmaps;
  final String? captureOrientation;
  final String? displayOrientation;
  final String? crop;
  final int angle;
  final int displayId;
  final String? renderFit;
  final String? backgroundColor;
  final int minSizeAlignment;
  final bool noDownsizeOnError;
  final bool printFps;
  final bool noAudio;
  final bool noAudioPlayback;
  final String? audioSource;
  final String? audioCodec;
  final String? audioEncoder;
  final String? audioBitRate;
  final int audioBuffer;
  final int audioOutputBuffer;
  final bool audioDup;
  final bool requireAudio;
  final String? videoSource;
  final int cameraId;
  final String? cameraFacing;
  final String? cameraSize;
  final String? cameraAr;
  final int cameraFps;
  final bool cameraHighSpeed;
  final bool cameraTorch;
  final double cameraZoom;
  final bool borderless;
  final String? windowTitle;
  final int windowX;
  final int windowY;
  final int windowWidth;
  final int windowHeight;
  final bool alwaysOnTop;
  final bool fullscreen;
  final bool disableScreensaver;
  final bool noWindow;
  final bool noWindowAspectRatioLock;
  final String? keyboard;
  final String? mouse;
  final bool noControl;
  final String? mouseBind;
  final bool preferText;
  final bool rawKeyEvents;
  final bool noKeyRepeat;
  final bool noMouseHover;
  final bool legacyPaste;
  final bool noClipboardAutosync;
  final bool stayAwake;
  final bool turnScreenOff;
  final bool keepActive;
  final bool showTouches;
  final bool powerOffOnClose;
  final bool noPowerOn;
  final int screenOffTimeout;
  final String? shortcutMod;
  final bool recordEnabled;
  final String? record;
  final String? recordFormat;
  final int timeLimit;
  final bool noPlayback;
  final bool noVideoPlayback;
  final String? pauseOnExit;
  final DateTime updatedAt;
  const ScrcpyOptions_Data(
      {required this.serial,
      required this.maxSize,
      this.videoBitRate,
      required this.maxFps,
      this.videoCodec,
      this.videoEncoder,
      required this.videoBuffer,
      required this.noMipmaps,
      this.captureOrientation,
      this.displayOrientation,
      this.crop,
      required this.angle,
      required this.displayId,
      this.renderFit,
      this.backgroundColor,
      required this.minSizeAlignment,
      required this.noDownsizeOnError,
      required this.printFps,
      required this.noAudio,
      required this.noAudioPlayback,
      this.audioSource,
      this.audioCodec,
      this.audioEncoder,
      this.audioBitRate,
      required this.audioBuffer,
      required this.audioOutputBuffer,
      required this.audioDup,
      required this.requireAudio,
      this.videoSource,
      required this.cameraId,
      this.cameraFacing,
      this.cameraSize,
      this.cameraAr,
      required this.cameraFps,
      required this.cameraHighSpeed,
      required this.cameraTorch,
      required this.cameraZoom,
      required this.borderless,
      this.windowTitle,
      required this.windowX,
      required this.windowY,
      required this.windowWidth,
      required this.windowHeight,
      required this.alwaysOnTop,
      required this.fullscreen,
      required this.disableScreensaver,
      required this.noWindow,
      required this.noWindowAspectRatioLock,
      this.keyboard,
      this.mouse,
      required this.noControl,
      this.mouseBind,
      required this.preferText,
      required this.rawKeyEvents,
      required this.noKeyRepeat,
      required this.noMouseHover,
      required this.legacyPaste,
      required this.noClipboardAutosync,
      required this.stayAwake,
      required this.turnScreenOff,
      required this.keepActive,
      required this.showTouches,
      required this.powerOffOnClose,
      required this.noPowerOn,
      required this.screenOffTimeout,
      this.shortcutMod,
      required this.recordEnabled,
      this.record,
      this.recordFormat,
      required this.timeLimit,
      required this.noPlayback,
      required this.noVideoPlayback,
      this.pauseOnExit,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['serial'] = Variable<String>(serial);
    map['max_size'] = Variable<int>(maxSize);
    if (!nullToAbsent || videoBitRate != null) {
      map['video_bit_rate'] = Variable<String>(videoBitRate);
    }
    map['max_fps'] = Variable<int>(maxFps);
    if (!nullToAbsent || videoCodec != null) {
      map['video_codec'] = Variable<String>(videoCodec);
    }
    if (!nullToAbsent || videoEncoder != null) {
      map['video_encoder'] = Variable<String>(videoEncoder);
    }
    map['video_buffer'] = Variable<int>(videoBuffer);
    map['no_mipmaps'] = Variable<bool>(noMipmaps);
    if (!nullToAbsent || captureOrientation != null) {
      map['capture_orientation'] = Variable<String>(captureOrientation);
    }
    if (!nullToAbsent || displayOrientation != null) {
      map['display_orientation'] = Variable<String>(displayOrientation);
    }
    if (!nullToAbsent || crop != null) {
      map['crop'] = Variable<String>(crop);
    }
    map['angle'] = Variable<int>(angle);
    map['display_id'] = Variable<int>(displayId);
    if (!nullToAbsent || renderFit != null) {
      map['render_fit'] = Variable<String>(renderFit);
    }
    if (!nullToAbsent || backgroundColor != null) {
      map['background_color'] = Variable<String>(backgroundColor);
    }
    map['min_size_alignment'] = Variable<int>(minSizeAlignment);
    map['no_downsize_on_error'] = Variable<bool>(noDownsizeOnError);
    map['print_fps'] = Variable<bool>(printFps);
    map['no_audio'] = Variable<bool>(noAudio);
    map['no_audio_playback'] = Variable<bool>(noAudioPlayback);
    if (!nullToAbsent || audioSource != null) {
      map['audio_source'] = Variable<String>(audioSource);
    }
    if (!nullToAbsent || audioCodec != null) {
      map['audio_codec'] = Variable<String>(audioCodec);
    }
    if (!nullToAbsent || audioEncoder != null) {
      map['audio_encoder'] = Variable<String>(audioEncoder);
    }
    if (!nullToAbsent || audioBitRate != null) {
      map['audio_bit_rate'] = Variable<String>(audioBitRate);
    }
    map['audio_buffer'] = Variable<int>(audioBuffer);
    map['audio_output_buffer'] = Variable<int>(audioOutputBuffer);
    map['audio_dup'] = Variable<bool>(audioDup);
    map['require_audio'] = Variable<bool>(requireAudio);
    if (!nullToAbsent || videoSource != null) {
      map['video_source'] = Variable<String>(videoSource);
    }
    map['camera_id'] = Variable<int>(cameraId);
    if (!nullToAbsent || cameraFacing != null) {
      map['camera_facing'] = Variable<String>(cameraFacing);
    }
    if (!nullToAbsent || cameraSize != null) {
      map['camera_size'] = Variable<String>(cameraSize);
    }
    if (!nullToAbsent || cameraAr != null) {
      map['camera_ar'] = Variable<String>(cameraAr);
    }
    map['camera_fps'] = Variable<int>(cameraFps);
    map['camera_high_speed'] = Variable<bool>(cameraHighSpeed);
    map['camera_torch'] = Variable<bool>(cameraTorch);
    map['camera_zoom'] = Variable<double>(cameraZoom);
    map['borderless'] = Variable<bool>(borderless);
    if (!nullToAbsent || windowTitle != null) {
      map['window_title'] = Variable<String>(windowTitle);
    }
    map['window_x'] = Variable<int>(windowX);
    map['window_y'] = Variable<int>(windowY);
    map['window_width'] = Variable<int>(windowWidth);
    map['window_height'] = Variable<int>(windowHeight);
    map['always_on_top'] = Variable<bool>(alwaysOnTop);
    map['fullscreen'] = Variable<bool>(fullscreen);
    map['disable_screensaver'] = Variable<bool>(disableScreensaver);
    map['no_window'] = Variable<bool>(noWindow);
    map['no_window_aspect_ratio_lock'] =
        Variable<bool>(noWindowAspectRatioLock);
    if (!nullToAbsent || keyboard != null) {
      map['keyboard'] = Variable<String>(keyboard);
    }
    if (!nullToAbsent || mouse != null) {
      map['mouse'] = Variable<String>(mouse);
    }
    map['no_control'] = Variable<bool>(noControl);
    if (!nullToAbsent || mouseBind != null) {
      map['mouse_bind'] = Variable<String>(mouseBind);
    }
    map['prefer_text'] = Variable<bool>(preferText);
    map['raw_key_events'] = Variable<bool>(rawKeyEvents);
    map['no_key_repeat'] = Variable<bool>(noKeyRepeat);
    map['no_mouse_hover'] = Variable<bool>(noMouseHover);
    map['legacy_paste'] = Variable<bool>(legacyPaste);
    map['no_clipboard_autosync'] = Variable<bool>(noClipboardAutosync);
    map['stay_awake'] = Variable<bool>(stayAwake);
    map['turn_screen_off'] = Variable<bool>(turnScreenOff);
    map['keep_active'] = Variable<bool>(keepActive);
    map['show_touches'] = Variable<bool>(showTouches);
    map['power_off_on_close'] = Variable<bool>(powerOffOnClose);
    map['no_power_on'] = Variable<bool>(noPowerOn);
    map['screen_off_timeout'] = Variable<int>(screenOffTimeout);
    if (!nullToAbsent || shortcutMod != null) {
      map['shortcut_mod'] = Variable<String>(shortcutMod);
    }
    map['record_enabled'] = Variable<bool>(recordEnabled);
    if (!nullToAbsent || record != null) {
      map['record'] = Variable<String>(record);
    }
    if (!nullToAbsent || recordFormat != null) {
      map['record_format'] = Variable<String>(recordFormat);
    }
    map['time_limit'] = Variable<int>(timeLimit);
    map['no_playback'] = Variable<bool>(noPlayback);
    map['no_video_playback'] = Variable<bool>(noVideoPlayback);
    if (!nullToAbsent || pauseOnExit != null) {
      map['pause_on_exit'] = Variable<String>(pauseOnExit);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ScrcpyOptions_Companion toCompanion(bool nullToAbsent) {
    return ScrcpyOptions_Companion(
      serial: Value(serial),
      maxSize: Value(maxSize),
      videoBitRate: videoBitRate == null && nullToAbsent
          ? const Value.absent()
          : Value(videoBitRate),
      maxFps: Value(maxFps),
      videoCodec: videoCodec == null && nullToAbsent
          ? const Value.absent()
          : Value(videoCodec),
      videoEncoder: videoEncoder == null && nullToAbsent
          ? const Value.absent()
          : Value(videoEncoder),
      videoBuffer: Value(videoBuffer),
      noMipmaps: Value(noMipmaps),
      captureOrientation: captureOrientation == null && nullToAbsent
          ? const Value.absent()
          : Value(captureOrientation),
      displayOrientation: displayOrientation == null && nullToAbsent
          ? const Value.absent()
          : Value(displayOrientation),
      crop: crop == null && nullToAbsent ? const Value.absent() : Value(crop),
      angle: Value(angle),
      displayId: Value(displayId),
      renderFit: renderFit == null && nullToAbsent
          ? const Value.absent()
          : Value(renderFit),
      backgroundColor: backgroundColor == null && nullToAbsent
          ? const Value.absent()
          : Value(backgroundColor),
      minSizeAlignment: Value(minSizeAlignment),
      noDownsizeOnError: Value(noDownsizeOnError),
      printFps: Value(printFps),
      noAudio: Value(noAudio),
      noAudioPlayback: Value(noAudioPlayback),
      audioSource: audioSource == null && nullToAbsent
          ? const Value.absent()
          : Value(audioSource),
      audioCodec: audioCodec == null && nullToAbsent
          ? const Value.absent()
          : Value(audioCodec),
      audioEncoder: audioEncoder == null && nullToAbsent
          ? const Value.absent()
          : Value(audioEncoder),
      audioBitRate: audioBitRate == null && nullToAbsent
          ? const Value.absent()
          : Value(audioBitRate),
      audioBuffer: Value(audioBuffer),
      audioOutputBuffer: Value(audioOutputBuffer),
      audioDup: Value(audioDup),
      requireAudio: Value(requireAudio),
      videoSource: videoSource == null && nullToAbsent
          ? const Value.absent()
          : Value(videoSource),
      cameraId: Value(cameraId),
      cameraFacing: cameraFacing == null && nullToAbsent
          ? const Value.absent()
          : Value(cameraFacing),
      cameraSize: cameraSize == null && nullToAbsent
          ? const Value.absent()
          : Value(cameraSize),
      cameraAr: cameraAr == null && nullToAbsent
          ? const Value.absent()
          : Value(cameraAr),
      cameraFps: Value(cameraFps),
      cameraHighSpeed: Value(cameraHighSpeed),
      cameraTorch: Value(cameraTorch),
      cameraZoom: Value(cameraZoom),
      borderless: Value(borderless),
      windowTitle: windowTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(windowTitle),
      windowX: Value(windowX),
      windowY: Value(windowY),
      windowWidth: Value(windowWidth),
      windowHeight: Value(windowHeight),
      alwaysOnTop: Value(alwaysOnTop),
      fullscreen: Value(fullscreen),
      disableScreensaver: Value(disableScreensaver),
      noWindow: Value(noWindow),
      noWindowAspectRatioLock: Value(noWindowAspectRatioLock),
      keyboard: keyboard == null && nullToAbsent
          ? const Value.absent()
          : Value(keyboard),
      mouse:
          mouse == null && nullToAbsent ? const Value.absent() : Value(mouse),
      noControl: Value(noControl),
      mouseBind: mouseBind == null && nullToAbsent
          ? const Value.absent()
          : Value(mouseBind),
      preferText: Value(preferText),
      rawKeyEvents: Value(rawKeyEvents),
      noKeyRepeat: Value(noKeyRepeat),
      noMouseHover: Value(noMouseHover),
      legacyPaste: Value(legacyPaste),
      noClipboardAutosync: Value(noClipboardAutosync),
      stayAwake: Value(stayAwake),
      turnScreenOff: Value(turnScreenOff),
      keepActive: Value(keepActive),
      showTouches: Value(showTouches),
      powerOffOnClose: Value(powerOffOnClose),
      noPowerOn: Value(noPowerOn),
      screenOffTimeout: Value(screenOffTimeout),
      shortcutMod: shortcutMod == null && nullToAbsent
          ? const Value.absent()
          : Value(shortcutMod),
      recordEnabled: Value(recordEnabled),
      record:
          record == null && nullToAbsent ? const Value.absent() : Value(record),
      recordFormat: recordFormat == null && nullToAbsent
          ? const Value.absent()
          : Value(recordFormat),
      timeLimit: Value(timeLimit),
      noPlayback: Value(noPlayback),
      noVideoPlayback: Value(noVideoPlayback),
      pauseOnExit: pauseOnExit == null && nullToAbsent
          ? const Value.absent()
          : Value(pauseOnExit),
      updatedAt: Value(updatedAt),
    );
  }

  factory ScrcpyOptions_Data.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScrcpyOptions_Data(
      serial: serializer.fromJson<String>(json['serial']),
      maxSize: serializer.fromJson<int>(json['maxSize']),
      videoBitRate: serializer.fromJson<String?>(json['videoBitRate']),
      maxFps: serializer.fromJson<int>(json['maxFps']),
      videoCodec: serializer.fromJson<String?>(json['videoCodec']),
      videoEncoder: serializer.fromJson<String?>(json['videoEncoder']),
      videoBuffer: serializer.fromJson<int>(json['videoBuffer']),
      noMipmaps: serializer.fromJson<bool>(json['noMipmaps']),
      captureOrientation:
          serializer.fromJson<String?>(json['captureOrientation']),
      displayOrientation:
          serializer.fromJson<String?>(json['displayOrientation']),
      crop: serializer.fromJson<String?>(json['crop']),
      angle: serializer.fromJson<int>(json['angle']),
      displayId: serializer.fromJson<int>(json['displayId']),
      renderFit: serializer.fromJson<String?>(json['renderFit']),
      backgroundColor: serializer.fromJson<String?>(json['backgroundColor']),
      minSizeAlignment: serializer.fromJson<int>(json['minSizeAlignment']),
      noDownsizeOnError: serializer.fromJson<bool>(json['noDownsizeOnError']),
      printFps: serializer.fromJson<bool>(json['printFps']),
      noAudio: serializer.fromJson<bool>(json['noAudio']),
      noAudioPlayback: serializer.fromJson<bool>(json['noAudioPlayback']),
      audioSource: serializer.fromJson<String?>(json['audioSource']),
      audioCodec: serializer.fromJson<String?>(json['audioCodec']),
      audioEncoder: serializer.fromJson<String?>(json['audioEncoder']),
      audioBitRate: serializer.fromJson<String?>(json['audioBitRate']),
      audioBuffer: serializer.fromJson<int>(json['audioBuffer']),
      audioOutputBuffer: serializer.fromJson<int>(json['audioOutputBuffer']),
      audioDup: serializer.fromJson<bool>(json['audioDup']),
      requireAudio: serializer.fromJson<bool>(json['requireAudio']),
      videoSource: serializer.fromJson<String?>(json['videoSource']),
      cameraId: serializer.fromJson<int>(json['cameraId']),
      cameraFacing: serializer.fromJson<String?>(json['cameraFacing']),
      cameraSize: serializer.fromJson<String?>(json['cameraSize']),
      cameraAr: serializer.fromJson<String?>(json['cameraAr']),
      cameraFps: serializer.fromJson<int>(json['cameraFps']),
      cameraHighSpeed: serializer.fromJson<bool>(json['cameraHighSpeed']),
      cameraTorch: serializer.fromJson<bool>(json['cameraTorch']),
      cameraZoom: serializer.fromJson<double>(json['cameraZoom']),
      borderless: serializer.fromJson<bool>(json['borderless']),
      windowTitle: serializer.fromJson<String?>(json['windowTitle']),
      windowX: serializer.fromJson<int>(json['windowX']),
      windowY: serializer.fromJson<int>(json['windowY']),
      windowWidth: serializer.fromJson<int>(json['windowWidth']),
      windowHeight: serializer.fromJson<int>(json['windowHeight']),
      alwaysOnTop: serializer.fromJson<bool>(json['alwaysOnTop']),
      fullscreen: serializer.fromJson<bool>(json['fullscreen']),
      disableScreensaver: serializer.fromJson<bool>(json['disableScreensaver']),
      noWindow: serializer.fromJson<bool>(json['noWindow']),
      noWindowAspectRatioLock:
          serializer.fromJson<bool>(json['noWindowAspectRatioLock']),
      keyboard: serializer.fromJson<String?>(json['keyboard']),
      mouse: serializer.fromJson<String?>(json['mouse']),
      noControl: serializer.fromJson<bool>(json['noControl']),
      mouseBind: serializer.fromJson<String?>(json['mouseBind']),
      preferText: serializer.fromJson<bool>(json['preferText']),
      rawKeyEvents: serializer.fromJson<bool>(json['rawKeyEvents']),
      noKeyRepeat: serializer.fromJson<bool>(json['noKeyRepeat']),
      noMouseHover: serializer.fromJson<bool>(json['noMouseHover']),
      legacyPaste: serializer.fromJson<bool>(json['legacyPaste']),
      noClipboardAutosync:
          serializer.fromJson<bool>(json['noClipboardAutosync']),
      stayAwake: serializer.fromJson<bool>(json['stayAwake']),
      turnScreenOff: serializer.fromJson<bool>(json['turnScreenOff']),
      keepActive: serializer.fromJson<bool>(json['keepActive']),
      showTouches: serializer.fromJson<bool>(json['showTouches']),
      powerOffOnClose: serializer.fromJson<bool>(json['powerOffOnClose']),
      noPowerOn: serializer.fromJson<bool>(json['noPowerOn']),
      screenOffTimeout: serializer.fromJson<int>(json['screenOffTimeout']),
      shortcutMod: serializer.fromJson<String?>(json['shortcutMod']),
      recordEnabled: serializer.fromJson<bool>(json['recordEnabled']),
      record: serializer.fromJson<String?>(json['record']),
      recordFormat: serializer.fromJson<String?>(json['recordFormat']),
      timeLimit: serializer.fromJson<int>(json['timeLimit']),
      noPlayback: serializer.fromJson<bool>(json['noPlayback']),
      noVideoPlayback: serializer.fromJson<bool>(json['noVideoPlayback']),
      pauseOnExit: serializer.fromJson<String?>(json['pauseOnExit']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serial': serializer.toJson<String>(serial),
      'maxSize': serializer.toJson<int>(maxSize),
      'videoBitRate': serializer.toJson<String?>(videoBitRate),
      'maxFps': serializer.toJson<int>(maxFps),
      'videoCodec': serializer.toJson<String?>(videoCodec),
      'videoEncoder': serializer.toJson<String?>(videoEncoder),
      'videoBuffer': serializer.toJson<int>(videoBuffer),
      'noMipmaps': serializer.toJson<bool>(noMipmaps),
      'captureOrientation': serializer.toJson<String?>(captureOrientation),
      'displayOrientation': serializer.toJson<String?>(displayOrientation),
      'crop': serializer.toJson<String?>(crop),
      'angle': serializer.toJson<int>(angle),
      'displayId': serializer.toJson<int>(displayId),
      'renderFit': serializer.toJson<String?>(renderFit),
      'backgroundColor': serializer.toJson<String?>(backgroundColor),
      'minSizeAlignment': serializer.toJson<int>(minSizeAlignment),
      'noDownsizeOnError': serializer.toJson<bool>(noDownsizeOnError),
      'printFps': serializer.toJson<bool>(printFps),
      'noAudio': serializer.toJson<bool>(noAudio),
      'noAudioPlayback': serializer.toJson<bool>(noAudioPlayback),
      'audioSource': serializer.toJson<String?>(audioSource),
      'audioCodec': serializer.toJson<String?>(audioCodec),
      'audioEncoder': serializer.toJson<String?>(audioEncoder),
      'audioBitRate': serializer.toJson<String?>(audioBitRate),
      'audioBuffer': serializer.toJson<int>(audioBuffer),
      'audioOutputBuffer': serializer.toJson<int>(audioOutputBuffer),
      'audioDup': serializer.toJson<bool>(audioDup),
      'requireAudio': serializer.toJson<bool>(requireAudio),
      'videoSource': serializer.toJson<String?>(videoSource),
      'cameraId': serializer.toJson<int>(cameraId),
      'cameraFacing': serializer.toJson<String?>(cameraFacing),
      'cameraSize': serializer.toJson<String?>(cameraSize),
      'cameraAr': serializer.toJson<String?>(cameraAr),
      'cameraFps': serializer.toJson<int>(cameraFps),
      'cameraHighSpeed': serializer.toJson<bool>(cameraHighSpeed),
      'cameraTorch': serializer.toJson<bool>(cameraTorch),
      'cameraZoom': serializer.toJson<double>(cameraZoom),
      'borderless': serializer.toJson<bool>(borderless),
      'windowTitle': serializer.toJson<String?>(windowTitle),
      'windowX': serializer.toJson<int>(windowX),
      'windowY': serializer.toJson<int>(windowY),
      'windowWidth': serializer.toJson<int>(windowWidth),
      'windowHeight': serializer.toJson<int>(windowHeight),
      'alwaysOnTop': serializer.toJson<bool>(alwaysOnTop),
      'fullscreen': serializer.toJson<bool>(fullscreen),
      'disableScreensaver': serializer.toJson<bool>(disableScreensaver),
      'noWindow': serializer.toJson<bool>(noWindow),
      'noWindowAspectRatioLock':
          serializer.toJson<bool>(noWindowAspectRatioLock),
      'keyboard': serializer.toJson<String?>(keyboard),
      'mouse': serializer.toJson<String?>(mouse),
      'noControl': serializer.toJson<bool>(noControl),
      'mouseBind': serializer.toJson<String?>(mouseBind),
      'preferText': serializer.toJson<bool>(preferText),
      'rawKeyEvents': serializer.toJson<bool>(rawKeyEvents),
      'noKeyRepeat': serializer.toJson<bool>(noKeyRepeat),
      'noMouseHover': serializer.toJson<bool>(noMouseHover),
      'legacyPaste': serializer.toJson<bool>(legacyPaste),
      'noClipboardAutosync': serializer.toJson<bool>(noClipboardAutosync),
      'stayAwake': serializer.toJson<bool>(stayAwake),
      'turnScreenOff': serializer.toJson<bool>(turnScreenOff),
      'keepActive': serializer.toJson<bool>(keepActive),
      'showTouches': serializer.toJson<bool>(showTouches),
      'powerOffOnClose': serializer.toJson<bool>(powerOffOnClose),
      'noPowerOn': serializer.toJson<bool>(noPowerOn),
      'screenOffTimeout': serializer.toJson<int>(screenOffTimeout),
      'shortcutMod': serializer.toJson<String?>(shortcutMod),
      'recordEnabled': serializer.toJson<bool>(recordEnabled),
      'record': serializer.toJson<String?>(record),
      'recordFormat': serializer.toJson<String?>(recordFormat),
      'timeLimit': serializer.toJson<int>(timeLimit),
      'noPlayback': serializer.toJson<bool>(noPlayback),
      'noVideoPlayback': serializer.toJson<bool>(noVideoPlayback),
      'pauseOnExit': serializer.toJson<String?>(pauseOnExit),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ScrcpyOptions_Data copyWith(
          {String? serial,
          int? maxSize,
          Value<String?> videoBitRate = const Value.absent(),
          int? maxFps,
          Value<String?> videoCodec = const Value.absent(),
          Value<String?> videoEncoder = const Value.absent(),
          int? videoBuffer,
          bool? noMipmaps,
          Value<String?> captureOrientation = const Value.absent(),
          Value<String?> displayOrientation = const Value.absent(),
          Value<String?> crop = const Value.absent(),
          int? angle,
          int? displayId,
          Value<String?> renderFit = const Value.absent(),
          Value<String?> backgroundColor = const Value.absent(),
          int? minSizeAlignment,
          bool? noDownsizeOnError,
          bool? printFps,
          bool? noAudio,
          bool? noAudioPlayback,
          Value<String?> audioSource = const Value.absent(),
          Value<String?> audioCodec = const Value.absent(),
          Value<String?> audioEncoder = const Value.absent(),
          Value<String?> audioBitRate = const Value.absent(),
          int? audioBuffer,
          int? audioOutputBuffer,
          bool? audioDup,
          bool? requireAudio,
          Value<String?> videoSource = const Value.absent(),
          int? cameraId,
          Value<String?> cameraFacing = const Value.absent(),
          Value<String?> cameraSize = const Value.absent(),
          Value<String?> cameraAr = const Value.absent(),
          int? cameraFps,
          bool? cameraHighSpeed,
          bool? cameraTorch,
          double? cameraZoom,
          bool? borderless,
          Value<String?> windowTitle = const Value.absent(),
          int? windowX,
          int? windowY,
          int? windowWidth,
          int? windowHeight,
          bool? alwaysOnTop,
          bool? fullscreen,
          bool? disableScreensaver,
          bool? noWindow,
          bool? noWindowAspectRatioLock,
          Value<String?> keyboard = const Value.absent(),
          Value<String?> mouse = const Value.absent(),
          bool? noControl,
          Value<String?> mouseBind = const Value.absent(),
          bool? preferText,
          bool? rawKeyEvents,
          bool? noKeyRepeat,
          bool? noMouseHover,
          bool? legacyPaste,
          bool? noClipboardAutosync,
          bool? stayAwake,
          bool? turnScreenOff,
          bool? keepActive,
          bool? showTouches,
          bool? powerOffOnClose,
          bool? noPowerOn,
          int? screenOffTimeout,
          Value<String?> shortcutMod = const Value.absent(),
          bool? recordEnabled,
          Value<String?> record = const Value.absent(),
          Value<String?> recordFormat = const Value.absent(),
          int? timeLimit,
          bool? noPlayback,
          bool? noVideoPlayback,
          Value<String?> pauseOnExit = const Value.absent(),
          DateTime? updatedAt}) =>
      ScrcpyOptions_Data(
        serial: serial ?? this.serial,
        maxSize: maxSize ?? this.maxSize,
        videoBitRate:
            videoBitRate.present ? videoBitRate.value : this.videoBitRate,
        maxFps: maxFps ?? this.maxFps,
        videoCodec: videoCodec.present ? videoCodec.value : this.videoCodec,
        videoEncoder:
            videoEncoder.present ? videoEncoder.value : this.videoEncoder,
        videoBuffer: videoBuffer ?? this.videoBuffer,
        noMipmaps: noMipmaps ?? this.noMipmaps,
        captureOrientation: captureOrientation.present
            ? captureOrientation.value
            : this.captureOrientation,
        displayOrientation: displayOrientation.present
            ? displayOrientation.value
            : this.displayOrientation,
        crop: crop.present ? crop.value : this.crop,
        angle: angle ?? this.angle,
        displayId: displayId ?? this.displayId,
        renderFit: renderFit.present ? renderFit.value : this.renderFit,
        backgroundColor: backgroundColor.present
            ? backgroundColor.value
            : this.backgroundColor,
        minSizeAlignment: minSizeAlignment ?? this.minSizeAlignment,
        noDownsizeOnError: noDownsizeOnError ?? this.noDownsizeOnError,
        printFps: printFps ?? this.printFps,
        noAudio: noAudio ?? this.noAudio,
        noAudioPlayback: noAudioPlayback ?? this.noAudioPlayback,
        audioSource: audioSource.present ? audioSource.value : this.audioSource,
        audioCodec: audioCodec.present ? audioCodec.value : this.audioCodec,
        audioEncoder:
            audioEncoder.present ? audioEncoder.value : this.audioEncoder,
        audioBitRate:
            audioBitRate.present ? audioBitRate.value : this.audioBitRate,
        audioBuffer: audioBuffer ?? this.audioBuffer,
        audioOutputBuffer: audioOutputBuffer ?? this.audioOutputBuffer,
        audioDup: audioDup ?? this.audioDup,
        requireAudio: requireAudio ?? this.requireAudio,
        videoSource: videoSource.present ? videoSource.value : this.videoSource,
        cameraId: cameraId ?? this.cameraId,
        cameraFacing:
            cameraFacing.present ? cameraFacing.value : this.cameraFacing,
        cameraSize: cameraSize.present ? cameraSize.value : this.cameraSize,
        cameraAr: cameraAr.present ? cameraAr.value : this.cameraAr,
        cameraFps: cameraFps ?? this.cameraFps,
        cameraHighSpeed: cameraHighSpeed ?? this.cameraHighSpeed,
        cameraTorch: cameraTorch ?? this.cameraTorch,
        cameraZoom: cameraZoom ?? this.cameraZoom,
        borderless: borderless ?? this.borderless,
        windowTitle: windowTitle.present ? windowTitle.value : this.windowTitle,
        windowX: windowX ?? this.windowX,
        windowY: windowY ?? this.windowY,
        windowWidth: windowWidth ?? this.windowWidth,
        windowHeight: windowHeight ?? this.windowHeight,
        alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
        fullscreen: fullscreen ?? this.fullscreen,
        disableScreensaver: disableScreensaver ?? this.disableScreensaver,
        noWindow: noWindow ?? this.noWindow,
        noWindowAspectRatioLock:
            noWindowAspectRatioLock ?? this.noWindowAspectRatioLock,
        keyboard: keyboard.present ? keyboard.value : this.keyboard,
        mouse: mouse.present ? mouse.value : this.mouse,
        noControl: noControl ?? this.noControl,
        mouseBind: mouseBind.present ? mouseBind.value : this.mouseBind,
        preferText: preferText ?? this.preferText,
        rawKeyEvents: rawKeyEvents ?? this.rawKeyEvents,
        noKeyRepeat: noKeyRepeat ?? this.noKeyRepeat,
        noMouseHover: noMouseHover ?? this.noMouseHover,
        legacyPaste: legacyPaste ?? this.legacyPaste,
        noClipboardAutosync: noClipboardAutosync ?? this.noClipboardAutosync,
        stayAwake: stayAwake ?? this.stayAwake,
        turnScreenOff: turnScreenOff ?? this.turnScreenOff,
        keepActive: keepActive ?? this.keepActive,
        showTouches: showTouches ?? this.showTouches,
        powerOffOnClose: powerOffOnClose ?? this.powerOffOnClose,
        noPowerOn: noPowerOn ?? this.noPowerOn,
        screenOffTimeout: screenOffTimeout ?? this.screenOffTimeout,
        shortcutMod: shortcutMod.present ? shortcutMod.value : this.shortcutMod,
        recordEnabled: recordEnabled ?? this.recordEnabled,
        record: record.present ? record.value : this.record,
        recordFormat:
            recordFormat.present ? recordFormat.value : this.recordFormat,
        timeLimit: timeLimit ?? this.timeLimit,
        noPlayback: noPlayback ?? this.noPlayback,
        noVideoPlayback: noVideoPlayback ?? this.noVideoPlayback,
        pauseOnExit: pauseOnExit.present ? pauseOnExit.value : this.pauseOnExit,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ScrcpyOptions_Data copyWithCompanion(ScrcpyOptions_Companion data) {
    return ScrcpyOptions_Data(
      serial: data.serial.present ? data.serial.value : this.serial,
      maxSize: data.maxSize.present ? data.maxSize.value : this.maxSize,
      videoBitRate: data.videoBitRate.present
          ? data.videoBitRate.value
          : this.videoBitRate,
      maxFps: data.maxFps.present ? data.maxFps.value : this.maxFps,
      videoCodec:
          data.videoCodec.present ? data.videoCodec.value : this.videoCodec,
      videoEncoder: data.videoEncoder.present
          ? data.videoEncoder.value
          : this.videoEncoder,
      videoBuffer:
          data.videoBuffer.present ? data.videoBuffer.value : this.videoBuffer,
      noMipmaps: data.noMipmaps.present ? data.noMipmaps.value : this.noMipmaps,
      captureOrientation: data.captureOrientation.present
          ? data.captureOrientation.value
          : this.captureOrientation,
      displayOrientation: data.displayOrientation.present
          ? data.displayOrientation.value
          : this.displayOrientation,
      crop: data.crop.present ? data.crop.value : this.crop,
      angle: data.angle.present ? data.angle.value : this.angle,
      displayId: data.displayId.present ? data.displayId.value : this.displayId,
      renderFit: data.renderFit.present ? data.renderFit.value : this.renderFit,
      backgroundColor: data.backgroundColor.present
          ? data.backgroundColor.value
          : this.backgroundColor,
      minSizeAlignment: data.minSizeAlignment.present
          ? data.minSizeAlignment.value
          : this.minSizeAlignment,
      noDownsizeOnError: data.noDownsizeOnError.present
          ? data.noDownsizeOnError.value
          : this.noDownsizeOnError,
      printFps: data.printFps.present ? data.printFps.value : this.printFps,
      noAudio: data.noAudio.present ? data.noAudio.value : this.noAudio,
      noAudioPlayback: data.noAudioPlayback.present
          ? data.noAudioPlayback.value
          : this.noAudioPlayback,
      audioSource:
          data.audioSource.present ? data.audioSource.value : this.audioSource,
      audioCodec:
          data.audioCodec.present ? data.audioCodec.value : this.audioCodec,
      audioEncoder: data.audioEncoder.present
          ? data.audioEncoder.value
          : this.audioEncoder,
      audioBitRate: data.audioBitRate.present
          ? data.audioBitRate.value
          : this.audioBitRate,
      audioBuffer:
          data.audioBuffer.present ? data.audioBuffer.value : this.audioBuffer,
      audioOutputBuffer: data.audioOutputBuffer.present
          ? data.audioOutputBuffer.value
          : this.audioOutputBuffer,
      audioDup: data.audioDup.present ? data.audioDup.value : this.audioDup,
      requireAudio: data.requireAudio.present
          ? data.requireAudio.value
          : this.requireAudio,
      videoSource:
          data.videoSource.present ? data.videoSource.value : this.videoSource,
      cameraId: data.cameraId.present ? data.cameraId.value : this.cameraId,
      cameraFacing: data.cameraFacing.present
          ? data.cameraFacing.value
          : this.cameraFacing,
      cameraSize:
          data.cameraSize.present ? data.cameraSize.value : this.cameraSize,
      cameraAr: data.cameraAr.present ? data.cameraAr.value : this.cameraAr,
      cameraFps: data.cameraFps.present ? data.cameraFps.value : this.cameraFps,
      cameraHighSpeed: data.cameraHighSpeed.present
          ? data.cameraHighSpeed.value
          : this.cameraHighSpeed,
      cameraTorch:
          data.cameraTorch.present ? data.cameraTorch.value : this.cameraTorch,
      cameraZoom:
          data.cameraZoom.present ? data.cameraZoom.value : this.cameraZoom,
      borderless:
          data.borderless.present ? data.borderless.value : this.borderless,
      windowTitle:
          data.windowTitle.present ? data.windowTitle.value : this.windowTitle,
      windowX: data.windowX.present ? data.windowX.value : this.windowX,
      windowY: data.windowY.present ? data.windowY.value : this.windowY,
      windowWidth:
          data.windowWidth.present ? data.windowWidth.value : this.windowWidth,
      windowHeight: data.windowHeight.present
          ? data.windowHeight.value
          : this.windowHeight,
      alwaysOnTop:
          data.alwaysOnTop.present ? data.alwaysOnTop.value : this.alwaysOnTop,
      fullscreen:
          data.fullscreen.present ? data.fullscreen.value : this.fullscreen,
      disableScreensaver: data.disableScreensaver.present
          ? data.disableScreensaver.value
          : this.disableScreensaver,
      noWindow: data.noWindow.present ? data.noWindow.value : this.noWindow,
      noWindowAspectRatioLock: data.noWindowAspectRatioLock.present
          ? data.noWindowAspectRatioLock.value
          : this.noWindowAspectRatioLock,
      keyboard: data.keyboard.present ? data.keyboard.value : this.keyboard,
      mouse: data.mouse.present ? data.mouse.value : this.mouse,
      noControl: data.noControl.present ? data.noControl.value : this.noControl,
      mouseBind: data.mouseBind.present ? data.mouseBind.value : this.mouseBind,
      preferText:
          data.preferText.present ? data.preferText.value : this.preferText,
      rawKeyEvents: data.rawKeyEvents.present
          ? data.rawKeyEvents.value
          : this.rawKeyEvents,
      noKeyRepeat:
          data.noKeyRepeat.present ? data.noKeyRepeat.value : this.noKeyRepeat,
      noMouseHover: data.noMouseHover.present
          ? data.noMouseHover.value
          : this.noMouseHover,
      legacyPaste:
          data.legacyPaste.present ? data.legacyPaste.value : this.legacyPaste,
      noClipboardAutosync: data.noClipboardAutosync.present
          ? data.noClipboardAutosync.value
          : this.noClipboardAutosync,
      stayAwake: data.stayAwake.present ? data.stayAwake.value : this.stayAwake,
      turnScreenOff: data.turnScreenOff.present
          ? data.turnScreenOff.value
          : this.turnScreenOff,
      keepActive:
          data.keepActive.present ? data.keepActive.value : this.keepActive,
      showTouches:
          data.showTouches.present ? data.showTouches.value : this.showTouches,
      powerOffOnClose: data.powerOffOnClose.present
          ? data.powerOffOnClose.value
          : this.powerOffOnClose,
      noPowerOn: data.noPowerOn.present ? data.noPowerOn.value : this.noPowerOn,
      screenOffTimeout: data.screenOffTimeout.present
          ? data.screenOffTimeout.value
          : this.screenOffTimeout,
      shortcutMod:
          data.shortcutMod.present ? data.shortcutMod.value : this.shortcutMod,
      recordEnabled: data.recordEnabled.present
          ? data.recordEnabled.value
          : this.recordEnabled,
      record: data.record.present ? data.record.value : this.record,
      recordFormat: data.recordFormat.present
          ? data.recordFormat.value
          : this.recordFormat,
      timeLimit: data.timeLimit.present ? data.timeLimit.value : this.timeLimit,
      noPlayback:
          data.noPlayback.present ? data.noPlayback.value : this.noPlayback,
      noVideoPlayback: data.noVideoPlayback.present
          ? data.noVideoPlayback.value
          : this.noVideoPlayback,
      pauseOnExit:
          data.pauseOnExit.present ? data.pauseOnExit.value : this.pauseOnExit,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScrcpyOptions_Data(')
          ..write('serial: $serial, ')
          ..write('maxSize: $maxSize, ')
          ..write('videoBitRate: $videoBitRate, ')
          ..write('maxFps: $maxFps, ')
          ..write('videoCodec: $videoCodec, ')
          ..write('videoEncoder: $videoEncoder, ')
          ..write('videoBuffer: $videoBuffer, ')
          ..write('noMipmaps: $noMipmaps, ')
          ..write('captureOrientation: $captureOrientation, ')
          ..write('displayOrientation: $displayOrientation, ')
          ..write('crop: $crop, ')
          ..write('angle: $angle, ')
          ..write('displayId: $displayId, ')
          ..write('renderFit: $renderFit, ')
          ..write('backgroundColor: $backgroundColor, ')
          ..write('minSizeAlignment: $minSizeAlignment, ')
          ..write('noDownsizeOnError: $noDownsizeOnError, ')
          ..write('printFps: $printFps, ')
          ..write('noAudio: $noAudio, ')
          ..write('noAudioPlayback: $noAudioPlayback, ')
          ..write('audioSource: $audioSource, ')
          ..write('audioCodec: $audioCodec, ')
          ..write('audioEncoder: $audioEncoder, ')
          ..write('audioBitRate: $audioBitRate, ')
          ..write('audioBuffer: $audioBuffer, ')
          ..write('audioOutputBuffer: $audioOutputBuffer, ')
          ..write('audioDup: $audioDup, ')
          ..write('requireAudio: $requireAudio, ')
          ..write('videoSource: $videoSource, ')
          ..write('cameraId: $cameraId, ')
          ..write('cameraFacing: $cameraFacing, ')
          ..write('cameraSize: $cameraSize, ')
          ..write('cameraAr: $cameraAr, ')
          ..write('cameraFps: $cameraFps, ')
          ..write('cameraHighSpeed: $cameraHighSpeed, ')
          ..write('cameraTorch: $cameraTorch, ')
          ..write('cameraZoom: $cameraZoom, ')
          ..write('borderless: $borderless, ')
          ..write('windowTitle: $windowTitle, ')
          ..write('windowX: $windowX, ')
          ..write('windowY: $windowY, ')
          ..write('windowWidth: $windowWidth, ')
          ..write('windowHeight: $windowHeight, ')
          ..write('alwaysOnTop: $alwaysOnTop, ')
          ..write('fullscreen: $fullscreen, ')
          ..write('disableScreensaver: $disableScreensaver, ')
          ..write('noWindow: $noWindow, ')
          ..write('noWindowAspectRatioLock: $noWindowAspectRatioLock, ')
          ..write('keyboard: $keyboard, ')
          ..write('mouse: $mouse, ')
          ..write('noControl: $noControl, ')
          ..write('mouseBind: $mouseBind, ')
          ..write('preferText: $preferText, ')
          ..write('rawKeyEvents: $rawKeyEvents, ')
          ..write('noKeyRepeat: $noKeyRepeat, ')
          ..write('noMouseHover: $noMouseHover, ')
          ..write('legacyPaste: $legacyPaste, ')
          ..write('noClipboardAutosync: $noClipboardAutosync, ')
          ..write('stayAwake: $stayAwake, ')
          ..write('turnScreenOff: $turnScreenOff, ')
          ..write('keepActive: $keepActive, ')
          ..write('showTouches: $showTouches, ')
          ..write('powerOffOnClose: $powerOffOnClose, ')
          ..write('noPowerOn: $noPowerOn, ')
          ..write('screenOffTimeout: $screenOffTimeout, ')
          ..write('shortcutMod: $shortcutMod, ')
          ..write('recordEnabled: $recordEnabled, ')
          ..write('record: $record, ')
          ..write('recordFormat: $recordFormat, ')
          ..write('timeLimit: $timeLimit, ')
          ..write('noPlayback: $noPlayback, ')
          ..write('noVideoPlayback: $noVideoPlayback, ')
          ..write('pauseOnExit: $pauseOnExit, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        serial,
        maxSize,
        videoBitRate,
        maxFps,
        videoCodec,
        videoEncoder,
        videoBuffer,
        noMipmaps,
        captureOrientation,
        displayOrientation,
        crop,
        angle,
        displayId,
        renderFit,
        backgroundColor,
        minSizeAlignment,
        noDownsizeOnError,
        printFps,
        noAudio,
        noAudioPlayback,
        audioSource,
        audioCodec,
        audioEncoder,
        audioBitRate,
        audioBuffer,
        audioOutputBuffer,
        audioDup,
        requireAudio,
        videoSource,
        cameraId,
        cameraFacing,
        cameraSize,
        cameraAr,
        cameraFps,
        cameraHighSpeed,
        cameraTorch,
        cameraZoom,
        borderless,
        windowTitle,
        windowX,
        windowY,
        windowWidth,
        windowHeight,
        alwaysOnTop,
        fullscreen,
        disableScreensaver,
        noWindow,
        noWindowAspectRatioLock,
        keyboard,
        mouse,
        noControl,
        mouseBind,
        preferText,
        rawKeyEvents,
        noKeyRepeat,
        noMouseHover,
        legacyPaste,
        noClipboardAutosync,
        stayAwake,
        turnScreenOff,
        keepActive,
        showTouches,
        powerOffOnClose,
        noPowerOn,
        screenOffTimeout,
        shortcutMod,
        recordEnabled,
        record,
        recordFormat,
        timeLimit,
        noPlayback,
        noVideoPlayback,
        pauseOnExit,
        updatedAt
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScrcpyOptions_Data &&
          other.serial == this.serial &&
          other.maxSize == this.maxSize &&
          other.videoBitRate == this.videoBitRate &&
          other.maxFps == this.maxFps &&
          other.videoCodec == this.videoCodec &&
          other.videoEncoder == this.videoEncoder &&
          other.videoBuffer == this.videoBuffer &&
          other.noMipmaps == this.noMipmaps &&
          other.captureOrientation == this.captureOrientation &&
          other.displayOrientation == this.displayOrientation &&
          other.crop == this.crop &&
          other.angle == this.angle &&
          other.displayId == this.displayId &&
          other.renderFit == this.renderFit &&
          other.backgroundColor == this.backgroundColor &&
          other.minSizeAlignment == this.minSizeAlignment &&
          other.noDownsizeOnError == this.noDownsizeOnError &&
          other.printFps == this.printFps &&
          other.noAudio == this.noAudio &&
          other.noAudioPlayback == this.noAudioPlayback &&
          other.audioSource == this.audioSource &&
          other.audioCodec == this.audioCodec &&
          other.audioEncoder == this.audioEncoder &&
          other.audioBitRate == this.audioBitRate &&
          other.audioBuffer == this.audioBuffer &&
          other.audioOutputBuffer == this.audioOutputBuffer &&
          other.audioDup == this.audioDup &&
          other.requireAudio == this.requireAudio &&
          other.videoSource == this.videoSource &&
          other.cameraId == this.cameraId &&
          other.cameraFacing == this.cameraFacing &&
          other.cameraSize == this.cameraSize &&
          other.cameraAr == this.cameraAr &&
          other.cameraFps == this.cameraFps &&
          other.cameraHighSpeed == this.cameraHighSpeed &&
          other.cameraTorch == this.cameraTorch &&
          other.cameraZoom == this.cameraZoom &&
          other.borderless == this.borderless &&
          other.windowTitle == this.windowTitle &&
          other.windowX == this.windowX &&
          other.windowY == this.windowY &&
          other.windowWidth == this.windowWidth &&
          other.windowHeight == this.windowHeight &&
          other.alwaysOnTop == this.alwaysOnTop &&
          other.fullscreen == this.fullscreen &&
          other.disableScreensaver == this.disableScreensaver &&
          other.noWindow == this.noWindow &&
          other.noWindowAspectRatioLock == this.noWindowAspectRatioLock &&
          other.keyboard == this.keyboard &&
          other.mouse == this.mouse &&
          other.noControl == this.noControl &&
          other.mouseBind == this.mouseBind &&
          other.preferText == this.preferText &&
          other.rawKeyEvents == this.rawKeyEvents &&
          other.noKeyRepeat == this.noKeyRepeat &&
          other.noMouseHover == this.noMouseHover &&
          other.legacyPaste == this.legacyPaste &&
          other.noClipboardAutosync == this.noClipboardAutosync &&
          other.stayAwake == this.stayAwake &&
          other.turnScreenOff == this.turnScreenOff &&
          other.keepActive == this.keepActive &&
          other.showTouches == this.showTouches &&
          other.powerOffOnClose == this.powerOffOnClose &&
          other.noPowerOn == this.noPowerOn &&
          other.screenOffTimeout == this.screenOffTimeout &&
          other.shortcutMod == this.shortcutMod &&
          other.recordEnabled == this.recordEnabled &&
          other.record == this.record &&
          other.recordFormat == this.recordFormat &&
          other.timeLimit == this.timeLimit &&
          other.noPlayback == this.noPlayback &&
          other.noVideoPlayback == this.noVideoPlayback &&
          other.pauseOnExit == this.pauseOnExit &&
          other.updatedAt == this.updatedAt);
}

class ScrcpyOptions_Companion extends UpdateCompanion<ScrcpyOptions_Data> {
  final Value<String> serial;
  final Value<int> maxSize;
  final Value<String?> videoBitRate;
  final Value<int> maxFps;
  final Value<String?> videoCodec;
  final Value<String?> videoEncoder;
  final Value<int> videoBuffer;
  final Value<bool> noMipmaps;
  final Value<String?> captureOrientation;
  final Value<String?> displayOrientation;
  final Value<String?> crop;
  final Value<int> angle;
  final Value<int> displayId;
  final Value<String?> renderFit;
  final Value<String?> backgroundColor;
  final Value<int> minSizeAlignment;
  final Value<bool> noDownsizeOnError;
  final Value<bool> printFps;
  final Value<bool> noAudio;
  final Value<bool> noAudioPlayback;
  final Value<String?> audioSource;
  final Value<String?> audioCodec;
  final Value<String?> audioEncoder;
  final Value<String?> audioBitRate;
  final Value<int> audioBuffer;
  final Value<int> audioOutputBuffer;
  final Value<bool> audioDup;
  final Value<bool> requireAudio;
  final Value<String?> videoSource;
  final Value<int> cameraId;
  final Value<String?> cameraFacing;
  final Value<String?> cameraSize;
  final Value<String?> cameraAr;
  final Value<int> cameraFps;
  final Value<bool> cameraHighSpeed;
  final Value<bool> cameraTorch;
  final Value<double> cameraZoom;
  final Value<bool> borderless;
  final Value<String?> windowTitle;
  final Value<int> windowX;
  final Value<int> windowY;
  final Value<int> windowWidth;
  final Value<int> windowHeight;
  final Value<bool> alwaysOnTop;
  final Value<bool> fullscreen;
  final Value<bool> disableScreensaver;
  final Value<bool> noWindow;
  final Value<bool> noWindowAspectRatioLock;
  final Value<String?> keyboard;
  final Value<String?> mouse;
  final Value<bool> noControl;
  final Value<String?> mouseBind;
  final Value<bool> preferText;
  final Value<bool> rawKeyEvents;
  final Value<bool> noKeyRepeat;
  final Value<bool> noMouseHover;
  final Value<bool> legacyPaste;
  final Value<bool> noClipboardAutosync;
  final Value<bool> stayAwake;
  final Value<bool> turnScreenOff;
  final Value<bool> keepActive;
  final Value<bool> showTouches;
  final Value<bool> powerOffOnClose;
  final Value<bool> noPowerOn;
  final Value<int> screenOffTimeout;
  final Value<String?> shortcutMod;
  final Value<bool> recordEnabled;
  final Value<String?> record;
  final Value<String?> recordFormat;
  final Value<int> timeLimit;
  final Value<bool> noPlayback;
  final Value<bool> noVideoPlayback;
  final Value<String?> pauseOnExit;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ScrcpyOptions_Companion({
    this.serial = const Value.absent(),
    this.maxSize = const Value.absent(),
    this.videoBitRate = const Value.absent(),
    this.maxFps = const Value.absent(),
    this.videoCodec = const Value.absent(),
    this.videoEncoder = const Value.absent(),
    this.videoBuffer = const Value.absent(),
    this.noMipmaps = const Value.absent(),
    this.captureOrientation = const Value.absent(),
    this.displayOrientation = const Value.absent(),
    this.crop = const Value.absent(),
    this.angle = const Value.absent(),
    this.displayId = const Value.absent(),
    this.renderFit = const Value.absent(),
    this.backgroundColor = const Value.absent(),
    this.minSizeAlignment = const Value.absent(),
    this.noDownsizeOnError = const Value.absent(),
    this.printFps = const Value.absent(),
    this.noAudio = const Value.absent(),
    this.noAudioPlayback = const Value.absent(),
    this.audioSource = const Value.absent(),
    this.audioCodec = const Value.absent(),
    this.audioEncoder = const Value.absent(),
    this.audioBitRate = const Value.absent(),
    this.audioBuffer = const Value.absent(),
    this.audioOutputBuffer = const Value.absent(),
    this.audioDup = const Value.absent(),
    this.requireAudio = const Value.absent(),
    this.videoSource = const Value.absent(),
    this.cameraId = const Value.absent(),
    this.cameraFacing = const Value.absent(),
    this.cameraSize = const Value.absent(),
    this.cameraAr = const Value.absent(),
    this.cameraFps = const Value.absent(),
    this.cameraHighSpeed = const Value.absent(),
    this.cameraTorch = const Value.absent(),
    this.cameraZoom = const Value.absent(),
    this.borderless = const Value.absent(),
    this.windowTitle = const Value.absent(),
    this.windowX = const Value.absent(),
    this.windowY = const Value.absent(),
    this.windowWidth = const Value.absent(),
    this.windowHeight = const Value.absent(),
    this.alwaysOnTop = const Value.absent(),
    this.fullscreen = const Value.absent(),
    this.disableScreensaver = const Value.absent(),
    this.noWindow = const Value.absent(),
    this.noWindowAspectRatioLock = const Value.absent(),
    this.keyboard = const Value.absent(),
    this.mouse = const Value.absent(),
    this.noControl = const Value.absent(),
    this.mouseBind = const Value.absent(),
    this.preferText = const Value.absent(),
    this.rawKeyEvents = const Value.absent(),
    this.noKeyRepeat = const Value.absent(),
    this.noMouseHover = const Value.absent(),
    this.legacyPaste = const Value.absent(),
    this.noClipboardAutosync = const Value.absent(),
    this.stayAwake = const Value.absent(),
    this.turnScreenOff = const Value.absent(),
    this.keepActive = const Value.absent(),
    this.showTouches = const Value.absent(),
    this.powerOffOnClose = const Value.absent(),
    this.noPowerOn = const Value.absent(),
    this.screenOffTimeout = const Value.absent(),
    this.shortcutMod = const Value.absent(),
    this.recordEnabled = const Value.absent(),
    this.record = const Value.absent(),
    this.recordFormat = const Value.absent(),
    this.timeLimit = const Value.absent(),
    this.noPlayback = const Value.absent(),
    this.noVideoPlayback = const Value.absent(),
    this.pauseOnExit = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScrcpyOptions_Companion.insert({
    required String serial,
    required int maxSize,
    this.videoBitRate = const Value.absent(),
    required int maxFps,
    this.videoCodec = const Value.absent(),
    this.videoEncoder = const Value.absent(),
    required int videoBuffer,
    required bool noMipmaps,
    this.captureOrientation = const Value.absent(),
    this.displayOrientation = const Value.absent(),
    this.crop = const Value.absent(),
    required int angle,
    required int displayId,
    this.renderFit = const Value.absent(),
    this.backgroundColor = const Value.absent(),
    required int minSizeAlignment,
    required bool noDownsizeOnError,
    required bool printFps,
    required bool noAudio,
    required bool noAudioPlayback,
    this.audioSource = const Value.absent(),
    this.audioCodec = const Value.absent(),
    this.audioEncoder = const Value.absent(),
    this.audioBitRate = const Value.absent(),
    required int audioBuffer,
    required int audioOutputBuffer,
    required bool audioDup,
    required bool requireAudio,
    this.videoSource = const Value.absent(),
    required int cameraId,
    this.cameraFacing = const Value.absent(),
    this.cameraSize = const Value.absent(),
    this.cameraAr = const Value.absent(),
    required int cameraFps,
    required bool cameraHighSpeed,
    required bool cameraTorch,
    required double cameraZoom,
    required bool borderless,
    this.windowTitle = const Value.absent(),
    required int windowX,
    required int windowY,
    required int windowWidth,
    required int windowHeight,
    required bool alwaysOnTop,
    required bool fullscreen,
    required bool disableScreensaver,
    required bool noWindow,
    required bool noWindowAspectRatioLock,
    this.keyboard = const Value.absent(),
    this.mouse = const Value.absent(),
    required bool noControl,
    this.mouseBind = const Value.absent(),
    required bool preferText,
    required bool rawKeyEvents,
    required bool noKeyRepeat,
    required bool noMouseHover,
    required bool legacyPaste,
    required bool noClipboardAutosync,
    required bool stayAwake,
    required bool turnScreenOff,
    required bool keepActive,
    required bool showTouches,
    required bool powerOffOnClose,
    required bool noPowerOn,
    required int screenOffTimeout,
    this.shortcutMod = const Value.absent(),
    required bool recordEnabled,
    this.record = const Value.absent(),
    this.recordFormat = const Value.absent(),
    required int timeLimit,
    required bool noPlayback,
    required bool noVideoPlayback,
    this.pauseOnExit = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : serial = Value(serial),
        maxSize = Value(maxSize),
        maxFps = Value(maxFps),
        videoBuffer = Value(videoBuffer),
        noMipmaps = Value(noMipmaps),
        angle = Value(angle),
        displayId = Value(displayId),
        minSizeAlignment = Value(minSizeAlignment),
        noDownsizeOnError = Value(noDownsizeOnError),
        printFps = Value(printFps),
        noAudio = Value(noAudio),
        noAudioPlayback = Value(noAudioPlayback),
        audioBuffer = Value(audioBuffer),
        audioOutputBuffer = Value(audioOutputBuffer),
        audioDup = Value(audioDup),
        requireAudio = Value(requireAudio),
        cameraId = Value(cameraId),
        cameraFps = Value(cameraFps),
        cameraHighSpeed = Value(cameraHighSpeed),
        cameraTorch = Value(cameraTorch),
        cameraZoom = Value(cameraZoom),
        borderless = Value(borderless),
        windowX = Value(windowX),
        windowY = Value(windowY),
        windowWidth = Value(windowWidth),
        windowHeight = Value(windowHeight),
        alwaysOnTop = Value(alwaysOnTop),
        fullscreen = Value(fullscreen),
        disableScreensaver = Value(disableScreensaver),
        noWindow = Value(noWindow),
        noWindowAspectRatioLock = Value(noWindowAspectRatioLock),
        noControl = Value(noControl),
        preferText = Value(preferText),
        rawKeyEvents = Value(rawKeyEvents),
        noKeyRepeat = Value(noKeyRepeat),
        noMouseHover = Value(noMouseHover),
        legacyPaste = Value(legacyPaste),
        noClipboardAutosync = Value(noClipboardAutosync),
        stayAwake = Value(stayAwake),
        turnScreenOff = Value(turnScreenOff),
        keepActive = Value(keepActive),
        showTouches = Value(showTouches),
        powerOffOnClose = Value(powerOffOnClose),
        noPowerOn = Value(noPowerOn),
        screenOffTimeout = Value(screenOffTimeout),
        recordEnabled = Value(recordEnabled),
        timeLimit = Value(timeLimit),
        noPlayback = Value(noPlayback),
        noVideoPlayback = Value(noVideoPlayback),
        updatedAt = Value(updatedAt);
  static Insertable<ScrcpyOptions_Data> custom({
    Expression<String>? serial,
    Expression<int>? maxSize,
    Expression<String>? videoBitRate,
    Expression<int>? maxFps,
    Expression<String>? videoCodec,
    Expression<String>? videoEncoder,
    Expression<int>? videoBuffer,
    Expression<bool>? noMipmaps,
    Expression<String>? captureOrientation,
    Expression<String>? displayOrientation,
    Expression<String>? crop,
    Expression<int>? angle,
    Expression<int>? displayId,
    Expression<String>? renderFit,
    Expression<String>? backgroundColor,
    Expression<int>? minSizeAlignment,
    Expression<bool>? noDownsizeOnError,
    Expression<bool>? printFps,
    Expression<bool>? noAudio,
    Expression<bool>? noAudioPlayback,
    Expression<String>? audioSource,
    Expression<String>? audioCodec,
    Expression<String>? audioEncoder,
    Expression<String>? audioBitRate,
    Expression<int>? audioBuffer,
    Expression<int>? audioOutputBuffer,
    Expression<bool>? audioDup,
    Expression<bool>? requireAudio,
    Expression<String>? videoSource,
    Expression<int>? cameraId,
    Expression<String>? cameraFacing,
    Expression<String>? cameraSize,
    Expression<String>? cameraAr,
    Expression<int>? cameraFps,
    Expression<bool>? cameraHighSpeed,
    Expression<bool>? cameraTorch,
    Expression<double>? cameraZoom,
    Expression<bool>? borderless,
    Expression<String>? windowTitle,
    Expression<int>? windowX,
    Expression<int>? windowY,
    Expression<int>? windowWidth,
    Expression<int>? windowHeight,
    Expression<bool>? alwaysOnTop,
    Expression<bool>? fullscreen,
    Expression<bool>? disableScreensaver,
    Expression<bool>? noWindow,
    Expression<bool>? noWindowAspectRatioLock,
    Expression<String>? keyboard,
    Expression<String>? mouse,
    Expression<bool>? noControl,
    Expression<String>? mouseBind,
    Expression<bool>? preferText,
    Expression<bool>? rawKeyEvents,
    Expression<bool>? noKeyRepeat,
    Expression<bool>? noMouseHover,
    Expression<bool>? legacyPaste,
    Expression<bool>? noClipboardAutosync,
    Expression<bool>? stayAwake,
    Expression<bool>? turnScreenOff,
    Expression<bool>? keepActive,
    Expression<bool>? showTouches,
    Expression<bool>? powerOffOnClose,
    Expression<bool>? noPowerOn,
    Expression<int>? screenOffTimeout,
    Expression<String>? shortcutMod,
    Expression<bool>? recordEnabled,
    Expression<String>? record,
    Expression<String>? recordFormat,
    Expression<int>? timeLimit,
    Expression<bool>? noPlayback,
    Expression<bool>? noVideoPlayback,
    Expression<String>? pauseOnExit,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serial != null) 'serial': serial,
      if (maxSize != null) 'max_size': maxSize,
      if (videoBitRate != null) 'video_bit_rate': videoBitRate,
      if (maxFps != null) 'max_fps': maxFps,
      if (videoCodec != null) 'video_codec': videoCodec,
      if (videoEncoder != null) 'video_encoder': videoEncoder,
      if (videoBuffer != null) 'video_buffer': videoBuffer,
      if (noMipmaps != null) 'no_mipmaps': noMipmaps,
      if (captureOrientation != null) 'capture_orientation': captureOrientation,
      if (displayOrientation != null) 'display_orientation': displayOrientation,
      if (crop != null) 'crop': crop,
      if (angle != null) 'angle': angle,
      if (displayId != null) 'display_id': displayId,
      if (renderFit != null) 'render_fit': renderFit,
      if (backgroundColor != null) 'background_color': backgroundColor,
      if (minSizeAlignment != null) 'min_size_alignment': minSizeAlignment,
      if (noDownsizeOnError != null) 'no_downsize_on_error': noDownsizeOnError,
      if (printFps != null) 'print_fps': printFps,
      if (noAudio != null) 'no_audio': noAudio,
      if (noAudioPlayback != null) 'no_audio_playback': noAudioPlayback,
      if (audioSource != null) 'audio_source': audioSource,
      if (audioCodec != null) 'audio_codec': audioCodec,
      if (audioEncoder != null) 'audio_encoder': audioEncoder,
      if (audioBitRate != null) 'audio_bit_rate': audioBitRate,
      if (audioBuffer != null) 'audio_buffer': audioBuffer,
      if (audioOutputBuffer != null) 'audio_output_buffer': audioOutputBuffer,
      if (audioDup != null) 'audio_dup': audioDup,
      if (requireAudio != null) 'require_audio': requireAudio,
      if (videoSource != null) 'video_source': videoSource,
      if (cameraId != null) 'camera_id': cameraId,
      if (cameraFacing != null) 'camera_facing': cameraFacing,
      if (cameraSize != null) 'camera_size': cameraSize,
      if (cameraAr != null) 'camera_ar': cameraAr,
      if (cameraFps != null) 'camera_fps': cameraFps,
      if (cameraHighSpeed != null) 'camera_high_speed': cameraHighSpeed,
      if (cameraTorch != null) 'camera_torch': cameraTorch,
      if (cameraZoom != null) 'camera_zoom': cameraZoom,
      if (borderless != null) 'borderless': borderless,
      if (windowTitle != null) 'window_title': windowTitle,
      if (windowX != null) 'window_x': windowX,
      if (windowY != null) 'window_y': windowY,
      if (windowWidth != null) 'window_width': windowWidth,
      if (windowHeight != null) 'window_height': windowHeight,
      if (alwaysOnTop != null) 'always_on_top': alwaysOnTop,
      if (fullscreen != null) 'fullscreen': fullscreen,
      if (disableScreensaver != null) 'disable_screensaver': disableScreensaver,
      if (noWindow != null) 'no_window': noWindow,
      if (noWindowAspectRatioLock != null)
        'no_window_aspect_ratio_lock': noWindowAspectRatioLock,
      if (keyboard != null) 'keyboard': keyboard,
      if (mouse != null) 'mouse': mouse,
      if (noControl != null) 'no_control': noControl,
      if (mouseBind != null) 'mouse_bind': mouseBind,
      if (preferText != null) 'prefer_text': preferText,
      if (rawKeyEvents != null) 'raw_key_events': rawKeyEvents,
      if (noKeyRepeat != null) 'no_key_repeat': noKeyRepeat,
      if (noMouseHover != null) 'no_mouse_hover': noMouseHover,
      if (legacyPaste != null) 'legacy_paste': legacyPaste,
      if (noClipboardAutosync != null)
        'no_clipboard_autosync': noClipboardAutosync,
      if (stayAwake != null) 'stay_awake': stayAwake,
      if (turnScreenOff != null) 'turn_screen_off': turnScreenOff,
      if (keepActive != null) 'keep_active': keepActive,
      if (showTouches != null) 'show_touches': showTouches,
      if (powerOffOnClose != null) 'power_off_on_close': powerOffOnClose,
      if (noPowerOn != null) 'no_power_on': noPowerOn,
      if (screenOffTimeout != null) 'screen_off_timeout': screenOffTimeout,
      if (shortcutMod != null) 'shortcut_mod': shortcutMod,
      if (recordEnabled != null) 'record_enabled': recordEnabled,
      if (record != null) 'record': record,
      if (recordFormat != null) 'record_format': recordFormat,
      if (timeLimit != null) 'time_limit': timeLimit,
      if (noPlayback != null) 'no_playback': noPlayback,
      if (noVideoPlayback != null) 'no_video_playback': noVideoPlayback,
      if (pauseOnExit != null) 'pause_on_exit': pauseOnExit,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScrcpyOptions_Companion copyWith(
      {Value<String>? serial,
      Value<int>? maxSize,
      Value<String?>? videoBitRate,
      Value<int>? maxFps,
      Value<String?>? videoCodec,
      Value<String?>? videoEncoder,
      Value<int>? videoBuffer,
      Value<bool>? noMipmaps,
      Value<String?>? captureOrientation,
      Value<String?>? displayOrientation,
      Value<String?>? crop,
      Value<int>? angle,
      Value<int>? displayId,
      Value<String?>? renderFit,
      Value<String?>? backgroundColor,
      Value<int>? minSizeAlignment,
      Value<bool>? noDownsizeOnError,
      Value<bool>? printFps,
      Value<bool>? noAudio,
      Value<bool>? noAudioPlayback,
      Value<String?>? audioSource,
      Value<String?>? audioCodec,
      Value<String?>? audioEncoder,
      Value<String?>? audioBitRate,
      Value<int>? audioBuffer,
      Value<int>? audioOutputBuffer,
      Value<bool>? audioDup,
      Value<bool>? requireAudio,
      Value<String?>? videoSource,
      Value<int>? cameraId,
      Value<String?>? cameraFacing,
      Value<String?>? cameraSize,
      Value<String?>? cameraAr,
      Value<int>? cameraFps,
      Value<bool>? cameraHighSpeed,
      Value<bool>? cameraTorch,
      Value<double>? cameraZoom,
      Value<bool>? borderless,
      Value<String?>? windowTitle,
      Value<int>? windowX,
      Value<int>? windowY,
      Value<int>? windowWidth,
      Value<int>? windowHeight,
      Value<bool>? alwaysOnTop,
      Value<bool>? fullscreen,
      Value<bool>? disableScreensaver,
      Value<bool>? noWindow,
      Value<bool>? noWindowAspectRatioLock,
      Value<String?>? keyboard,
      Value<String?>? mouse,
      Value<bool>? noControl,
      Value<String?>? mouseBind,
      Value<bool>? preferText,
      Value<bool>? rawKeyEvents,
      Value<bool>? noKeyRepeat,
      Value<bool>? noMouseHover,
      Value<bool>? legacyPaste,
      Value<bool>? noClipboardAutosync,
      Value<bool>? stayAwake,
      Value<bool>? turnScreenOff,
      Value<bool>? keepActive,
      Value<bool>? showTouches,
      Value<bool>? powerOffOnClose,
      Value<bool>? noPowerOn,
      Value<int>? screenOffTimeout,
      Value<String?>? shortcutMod,
      Value<bool>? recordEnabled,
      Value<String?>? record,
      Value<String?>? recordFormat,
      Value<int>? timeLimit,
      Value<bool>? noPlayback,
      Value<bool>? noVideoPlayback,
      Value<String?>? pauseOnExit,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return ScrcpyOptions_Companion(
      serial: serial ?? this.serial,
      maxSize: maxSize ?? this.maxSize,
      videoBitRate: videoBitRate ?? this.videoBitRate,
      maxFps: maxFps ?? this.maxFps,
      videoCodec: videoCodec ?? this.videoCodec,
      videoEncoder: videoEncoder ?? this.videoEncoder,
      videoBuffer: videoBuffer ?? this.videoBuffer,
      noMipmaps: noMipmaps ?? this.noMipmaps,
      captureOrientation: captureOrientation ?? this.captureOrientation,
      displayOrientation: displayOrientation ?? this.displayOrientation,
      crop: crop ?? this.crop,
      angle: angle ?? this.angle,
      displayId: displayId ?? this.displayId,
      renderFit: renderFit ?? this.renderFit,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      minSizeAlignment: minSizeAlignment ?? this.minSizeAlignment,
      noDownsizeOnError: noDownsizeOnError ?? this.noDownsizeOnError,
      printFps: printFps ?? this.printFps,
      noAudio: noAudio ?? this.noAudio,
      noAudioPlayback: noAudioPlayback ?? this.noAudioPlayback,
      audioSource: audioSource ?? this.audioSource,
      audioCodec: audioCodec ?? this.audioCodec,
      audioEncoder: audioEncoder ?? this.audioEncoder,
      audioBitRate: audioBitRate ?? this.audioBitRate,
      audioBuffer: audioBuffer ?? this.audioBuffer,
      audioOutputBuffer: audioOutputBuffer ?? this.audioOutputBuffer,
      audioDup: audioDup ?? this.audioDup,
      requireAudio: requireAudio ?? this.requireAudio,
      videoSource: videoSource ?? this.videoSource,
      cameraId: cameraId ?? this.cameraId,
      cameraFacing: cameraFacing ?? this.cameraFacing,
      cameraSize: cameraSize ?? this.cameraSize,
      cameraAr: cameraAr ?? this.cameraAr,
      cameraFps: cameraFps ?? this.cameraFps,
      cameraHighSpeed: cameraHighSpeed ?? this.cameraHighSpeed,
      cameraTorch: cameraTorch ?? this.cameraTorch,
      cameraZoom: cameraZoom ?? this.cameraZoom,
      borderless: borderless ?? this.borderless,
      windowTitle: windowTitle ?? this.windowTitle,
      windowX: windowX ?? this.windowX,
      windowY: windowY ?? this.windowY,
      windowWidth: windowWidth ?? this.windowWidth,
      windowHeight: windowHeight ?? this.windowHeight,
      alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
      fullscreen: fullscreen ?? this.fullscreen,
      disableScreensaver: disableScreensaver ?? this.disableScreensaver,
      noWindow: noWindow ?? this.noWindow,
      noWindowAspectRatioLock:
          noWindowAspectRatioLock ?? this.noWindowAspectRatioLock,
      keyboard: keyboard ?? this.keyboard,
      mouse: mouse ?? this.mouse,
      noControl: noControl ?? this.noControl,
      mouseBind: mouseBind ?? this.mouseBind,
      preferText: preferText ?? this.preferText,
      rawKeyEvents: rawKeyEvents ?? this.rawKeyEvents,
      noKeyRepeat: noKeyRepeat ?? this.noKeyRepeat,
      noMouseHover: noMouseHover ?? this.noMouseHover,
      legacyPaste: legacyPaste ?? this.legacyPaste,
      noClipboardAutosync: noClipboardAutosync ?? this.noClipboardAutosync,
      stayAwake: stayAwake ?? this.stayAwake,
      turnScreenOff: turnScreenOff ?? this.turnScreenOff,
      keepActive: keepActive ?? this.keepActive,
      showTouches: showTouches ?? this.showTouches,
      powerOffOnClose: powerOffOnClose ?? this.powerOffOnClose,
      noPowerOn: noPowerOn ?? this.noPowerOn,
      screenOffTimeout: screenOffTimeout ?? this.screenOffTimeout,
      shortcutMod: shortcutMod ?? this.shortcutMod,
      recordEnabled: recordEnabled ?? this.recordEnabled,
      record: record ?? this.record,
      recordFormat: recordFormat ?? this.recordFormat,
      timeLimit: timeLimit ?? this.timeLimit,
      noPlayback: noPlayback ?? this.noPlayback,
      noVideoPlayback: noVideoPlayback ?? this.noVideoPlayback,
      pauseOnExit: pauseOnExit ?? this.pauseOnExit,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serial.present) {
      map['serial'] = Variable<String>(serial.value);
    }
    if (maxSize.present) {
      map['max_size'] = Variable<int>(maxSize.value);
    }
    if (videoBitRate.present) {
      map['video_bit_rate'] = Variable<String>(videoBitRate.value);
    }
    if (maxFps.present) {
      map['max_fps'] = Variable<int>(maxFps.value);
    }
    if (videoCodec.present) {
      map['video_codec'] = Variable<String>(videoCodec.value);
    }
    if (videoEncoder.present) {
      map['video_encoder'] = Variable<String>(videoEncoder.value);
    }
    if (videoBuffer.present) {
      map['video_buffer'] = Variable<int>(videoBuffer.value);
    }
    if (noMipmaps.present) {
      map['no_mipmaps'] = Variable<bool>(noMipmaps.value);
    }
    if (captureOrientation.present) {
      map['capture_orientation'] = Variable<String>(captureOrientation.value);
    }
    if (displayOrientation.present) {
      map['display_orientation'] = Variable<String>(displayOrientation.value);
    }
    if (crop.present) {
      map['crop'] = Variable<String>(crop.value);
    }
    if (angle.present) {
      map['angle'] = Variable<int>(angle.value);
    }
    if (displayId.present) {
      map['display_id'] = Variable<int>(displayId.value);
    }
    if (renderFit.present) {
      map['render_fit'] = Variable<String>(renderFit.value);
    }
    if (backgroundColor.present) {
      map['background_color'] = Variable<String>(backgroundColor.value);
    }
    if (minSizeAlignment.present) {
      map['min_size_alignment'] = Variable<int>(minSizeAlignment.value);
    }
    if (noDownsizeOnError.present) {
      map['no_downsize_on_error'] = Variable<bool>(noDownsizeOnError.value);
    }
    if (printFps.present) {
      map['print_fps'] = Variable<bool>(printFps.value);
    }
    if (noAudio.present) {
      map['no_audio'] = Variable<bool>(noAudio.value);
    }
    if (noAudioPlayback.present) {
      map['no_audio_playback'] = Variable<bool>(noAudioPlayback.value);
    }
    if (audioSource.present) {
      map['audio_source'] = Variable<String>(audioSource.value);
    }
    if (audioCodec.present) {
      map['audio_codec'] = Variable<String>(audioCodec.value);
    }
    if (audioEncoder.present) {
      map['audio_encoder'] = Variable<String>(audioEncoder.value);
    }
    if (audioBitRate.present) {
      map['audio_bit_rate'] = Variable<String>(audioBitRate.value);
    }
    if (audioBuffer.present) {
      map['audio_buffer'] = Variable<int>(audioBuffer.value);
    }
    if (audioOutputBuffer.present) {
      map['audio_output_buffer'] = Variable<int>(audioOutputBuffer.value);
    }
    if (audioDup.present) {
      map['audio_dup'] = Variable<bool>(audioDup.value);
    }
    if (requireAudio.present) {
      map['require_audio'] = Variable<bool>(requireAudio.value);
    }
    if (videoSource.present) {
      map['video_source'] = Variable<String>(videoSource.value);
    }
    if (cameraId.present) {
      map['camera_id'] = Variable<int>(cameraId.value);
    }
    if (cameraFacing.present) {
      map['camera_facing'] = Variable<String>(cameraFacing.value);
    }
    if (cameraSize.present) {
      map['camera_size'] = Variable<String>(cameraSize.value);
    }
    if (cameraAr.present) {
      map['camera_ar'] = Variable<String>(cameraAr.value);
    }
    if (cameraFps.present) {
      map['camera_fps'] = Variable<int>(cameraFps.value);
    }
    if (cameraHighSpeed.present) {
      map['camera_high_speed'] = Variable<bool>(cameraHighSpeed.value);
    }
    if (cameraTorch.present) {
      map['camera_torch'] = Variable<bool>(cameraTorch.value);
    }
    if (cameraZoom.present) {
      map['camera_zoom'] = Variable<double>(cameraZoom.value);
    }
    if (borderless.present) {
      map['borderless'] = Variable<bool>(borderless.value);
    }
    if (windowTitle.present) {
      map['window_title'] = Variable<String>(windowTitle.value);
    }
    if (windowX.present) {
      map['window_x'] = Variable<int>(windowX.value);
    }
    if (windowY.present) {
      map['window_y'] = Variable<int>(windowY.value);
    }
    if (windowWidth.present) {
      map['window_width'] = Variable<int>(windowWidth.value);
    }
    if (windowHeight.present) {
      map['window_height'] = Variable<int>(windowHeight.value);
    }
    if (alwaysOnTop.present) {
      map['always_on_top'] = Variable<bool>(alwaysOnTop.value);
    }
    if (fullscreen.present) {
      map['fullscreen'] = Variable<bool>(fullscreen.value);
    }
    if (disableScreensaver.present) {
      map['disable_screensaver'] = Variable<bool>(disableScreensaver.value);
    }
    if (noWindow.present) {
      map['no_window'] = Variable<bool>(noWindow.value);
    }
    if (noWindowAspectRatioLock.present) {
      map['no_window_aspect_ratio_lock'] =
          Variable<bool>(noWindowAspectRatioLock.value);
    }
    if (keyboard.present) {
      map['keyboard'] = Variable<String>(keyboard.value);
    }
    if (mouse.present) {
      map['mouse'] = Variable<String>(mouse.value);
    }
    if (noControl.present) {
      map['no_control'] = Variable<bool>(noControl.value);
    }
    if (mouseBind.present) {
      map['mouse_bind'] = Variable<String>(mouseBind.value);
    }
    if (preferText.present) {
      map['prefer_text'] = Variable<bool>(preferText.value);
    }
    if (rawKeyEvents.present) {
      map['raw_key_events'] = Variable<bool>(rawKeyEvents.value);
    }
    if (noKeyRepeat.present) {
      map['no_key_repeat'] = Variable<bool>(noKeyRepeat.value);
    }
    if (noMouseHover.present) {
      map['no_mouse_hover'] = Variable<bool>(noMouseHover.value);
    }
    if (legacyPaste.present) {
      map['legacy_paste'] = Variable<bool>(legacyPaste.value);
    }
    if (noClipboardAutosync.present) {
      map['no_clipboard_autosync'] = Variable<bool>(noClipboardAutosync.value);
    }
    if (stayAwake.present) {
      map['stay_awake'] = Variable<bool>(stayAwake.value);
    }
    if (turnScreenOff.present) {
      map['turn_screen_off'] = Variable<bool>(turnScreenOff.value);
    }
    if (keepActive.present) {
      map['keep_active'] = Variable<bool>(keepActive.value);
    }
    if (showTouches.present) {
      map['show_touches'] = Variable<bool>(showTouches.value);
    }
    if (powerOffOnClose.present) {
      map['power_off_on_close'] = Variable<bool>(powerOffOnClose.value);
    }
    if (noPowerOn.present) {
      map['no_power_on'] = Variable<bool>(noPowerOn.value);
    }
    if (screenOffTimeout.present) {
      map['screen_off_timeout'] = Variable<int>(screenOffTimeout.value);
    }
    if (shortcutMod.present) {
      map['shortcut_mod'] = Variable<String>(shortcutMod.value);
    }
    if (recordEnabled.present) {
      map['record_enabled'] = Variable<bool>(recordEnabled.value);
    }
    if (record.present) {
      map['record'] = Variable<String>(record.value);
    }
    if (recordFormat.present) {
      map['record_format'] = Variable<String>(recordFormat.value);
    }
    if (timeLimit.present) {
      map['time_limit'] = Variable<int>(timeLimit.value);
    }
    if (noPlayback.present) {
      map['no_playback'] = Variable<bool>(noPlayback.value);
    }
    if (noVideoPlayback.present) {
      map['no_video_playback'] = Variable<bool>(noVideoPlayback.value);
    }
    if (pauseOnExit.present) {
      map['pause_on_exit'] = Variable<String>(pauseOnExit.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScrcpyOptions_Companion(')
          ..write('serial: $serial, ')
          ..write('maxSize: $maxSize, ')
          ..write('videoBitRate: $videoBitRate, ')
          ..write('maxFps: $maxFps, ')
          ..write('videoCodec: $videoCodec, ')
          ..write('videoEncoder: $videoEncoder, ')
          ..write('videoBuffer: $videoBuffer, ')
          ..write('noMipmaps: $noMipmaps, ')
          ..write('captureOrientation: $captureOrientation, ')
          ..write('displayOrientation: $displayOrientation, ')
          ..write('crop: $crop, ')
          ..write('angle: $angle, ')
          ..write('displayId: $displayId, ')
          ..write('renderFit: $renderFit, ')
          ..write('backgroundColor: $backgroundColor, ')
          ..write('minSizeAlignment: $minSizeAlignment, ')
          ..write('noDownsizeOnError: $noDownsizeOnError, ')
          ..write('printFps: $printFps, ')
          ..write('noAudio: $noAudio, ')
          ..write('noAudioPlayback: $noAudioPlayback, ')
          ..write('audioSource: $audioSource, ')
          ..write('audioCodec: $audioCodec, ')
          ..write('audioEncoder: $audioEncoder, ')
          ..write('audioBitRate: $audioBitRate, ')
          ..write('audioBuffer: $audioBuffer, ')
          ..write('audioOutputBuffer: $audioOutputBuffer, ')
          ..write('audioDup: $audioDup, ')
          ..write('requireAudio: $requireAudio, ')
          ..write('videoSource: $videoSource, ')
          ..write('cameraId: $cameraId, ')
          ..write('cameraFacing: $cameraFacing, ')
          ..write('cameraSize: $cameraSize, ')
          ..write('cameraAr: $cameraAr, ')
          ..write('cameraFps: $cameraFps, ')
          ..write('cameraHighSpeed: $cameraHighSpeed, ')
          ..write('cameraTorch: $cameraTorch, ')
          ..write('cameraZoom: $cameraZoom, ')
          ..write('borderless: $borderless, ')
          ..write('windowTitle: $windowTitle, ')
          ..write('windowX: $windowX, ')
          ..write('windowY: $windowY, ')
          ..write('windowWidth: $windowWidth, ')
          ..write('windowHeight: $windowHeight, ')
          ..write('alwaysOnTop: $alwaysOnTop, ')
          ..write('fullscreen: $fullscreen, ')
          ..write('disableScreensaver: $disableScreensaver, ')
          ..write('noWindow: $noWindow, ')
          ..write('noWindowAspectRatioLock: $noWindowAspectRatioLock, ')
          ..write('keyboard: $keyboard, ')
          ..write('mouse: $mouse, ')
          ..write('noControl: $noControl, ')
          ..write('mouseBind: $mouseBind, ')
          ..write('preferText: $preferText, ')
          ..write('rawKeyEvents: $rawKeyEvents, ')
          ..write('noKeyRepeat: $noKeyRepeat, ')
          ..write('noMouseHover: $noMouseHover, ')
          ..write('legacyPaste: $legacyPaste, ')
          ..write('noClipboardAutosync: $noClipboardAutosync, ')
          ..write('stayAwake: $stayAwake, ')
          ..write('turnScreenOff: $turnScreenOff, ')
          ..write('keepActive: $keepActive, ')
          ..write('showTouches: $showTouches, ')
          ..write('powerOffOnClose: $powerOffOnClose, ')
          ..write('noPowerOn: $noPowerOn, ')
          ..write('screenOffTimeout: $screenOffTimeout, ')
          ..write('shortcutMod: $shortcutMod, ')
          ..write('recordEnabled: $recordEnabled, ')
          ..write('record: $record, ')
          ..write('recordFormat: $recordFormat, ')
          ..write('timeLimit: $timeLimit, ')
          ..write('noPlayback: $noPlayback, ')
          ..write('noVideoPlayback: $noVideoPlayback, ')
          ..write('pauseOnExit: $pauseOnExit, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SentClipboardEntryTable extends SentClipboardEntry
    with TableInfo<$SentClipboardEntryTable, SentClipboardEntryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SentClipboardEntryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sentAtMeta = const VerificationMeta('sentAt');
  @override
  late final GeneratedColumn<DateTime> sentAt = GeneratedColumn<DateTime>(
      'sent_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _favoriteMeta =
      const VerificationMeta('favorite');
  @override
  late final GeneratedColumn<bool> favorite = GeneratedColumn<bool>(
      'favorite', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("favorite" IN (0, 1))'));
  static const VerificationMeta _sendCountMeta =
      const VerificationMeta('sendCount');
  @override
  late final GeneratedColumn<int> sendCount = GeneratedColumn<int>(
      'send_count', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, content, sentAt, favorite, sendCount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sent_clipboard_entry';
  @override
  VerificationContext validateIntegrity(
      Insertable<SentClipboardEntryData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('sent_at')) {
      context.handle(_sentAtMeta,
          sentAt.isAcceptableOrUnknown(data['sent_at']!, _sentAtMeta));
    } else if (isInserting) {
      context.missing(_sentAtMeta);
    }
    if (data.containsKey('favorite')) {
      context.handle(_favoriteMeta,
          favorite.isAcceptableOrUnknown(data['favorite']!, _favoriteMeta));
    } else if (isInserting) {
      context.missing(_favoriteMeta);
    }
    if (data.containsKey('send_count')) {
      context.handle(_sendCountMeta,
          sendCount.isAcceptableOrUnknown(data['send_count']!, _sendCountMeta));
    } else if (isInserting) {
      context.missing(_sendCountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SentClipboardEntryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SentClipboardEntryData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      sentAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}sent_at'])!,
      favorite: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}favorite'])!,
      sendCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}send_count'])!,
    );
  }

  @override
  $SentClipboardEntryTable createAlias(String alias) {
    return $SentClipboardEntryTable(attachedDatabase, alias);
  }
}

class SentClipboardEntryData extends DataClass
    implements Insertable<SentClipboardEntryData> {
  final int id;
  final String content;
  final DateTime sentAt;
  final bool favorite;
  final int sendCount;
  const SentClipboardEntryData(
      {required this.id,
      required this.content,
      required this.sentAt,
      required this.favorite,
      required this.sendCount});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['content'] = Variable<String>(content);
    map['sent_at'] = Variable<DateTime>(sentAt);
    map['favorite'] = Variable<bool>(favorite);
    map['send_count'] = Variable<int>(sendCount);
    return map;
  }

  SentClipboardEntryCompanion toCompanion(bool nullToAbsent) {
    return SentClipboardEntryCompanion(
      id: Value(id),
      content: Value(content),
      sentAt: Value(sentAt),
      favorite: Value(favorite),
      sendCount: Value(sendCount),
    );
  }

  factory SentClipboardEntryData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SentClipboardEntryData(
      id: serializer.fromJson<int>(json['id']),
      content: serializer.fromJson<String>(json['content']),
      sentAt: serializer.fromJson<DateTime>(json['sentAt']),
      favorite: serializer.fromJson<bool>(json['favorite']),
      sendCount: serializer.fromJson<int>(json['sendCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'content': serializer.toJson<String>(content),
      'sentAt': serializer.toJson<DateTime>(sentAt),
      'favorite': serializer.toJson<bool>(favorite),
      'sendCount': serializer.toJson<int>(sendCount),
    };
  }

  SentClipboardEntryData copyWith(
          {int? id,
          String? content,
          DateTime? sentAt,
          bool? favorite,
          int? sendCount}) =>
      SentClipboardEntryData(
        id: id ?? this.id,
        content: content ?? this.content,
        sentAt: sentAt ?? this.sentAt,
        favorite: favorite ?? this.favorite,
        sendCount: sendCount ?? this.sendCount,
      );
  SentClipboardEntryData copyWithCompanion(SentClipboardEntryCompanion data) {
    return SentClipboardEntryData(
      id: data.id.present ? data.id.value : this.id,
      content: data.content.present ? data.content.value : this.content,
      sentAt: data.sentAt.present ? data.sentAt.value : this.sentAt,
      favorite: data.favorite.present ? data.favorite.value : this.favorite,
      sendCount: data.sendCount.present ? data.sendCount.value : this.sendCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SentClipboardEntryData(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('sentAt: $sentAt, ')
          ..write('favorite: $favorite, ')
          ..write('sendCount: $sendCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, content, sentAt, favorite, sendCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SentClipboardEntryData &&
          other.id == this.id &&
          other.content == this.content &&
          other.sentAt == this.sentAt &&
          other.favorite == this.favorite &&
          other.sendCount == this.sendCount);
}

class SentClipboardEntryCompanion
    extends UpdateCompanion<SentClipboardEntryData> {
  final Value<int> id;
  final Value<String> content;
  final Value<DateTime> sentAt;
  final Value<bool> favorite;
  final Value<int> sendCount;
  const SentClipboardEntryCompanion({
    this.id = const Value.absent(),
    this.content = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.favorite = const Value.absent(),
    this.sendCount = const Value.absent(),
  });
  SentClipboardEntryCompanion.insert({
    this.id = const Value.absent(),
    required String content,
    required DateTime sentAt,
    required bool favorite,
    required int sendCount,
  })  : content = Value(content),
        sentAt = Value(sentAt),
        favorite = Value(favorite),
        sendCount = Value(sendCount);
  static Insertable<SentClipboardEntryData> custom({
    Expression<int>? id,
    Expression<String>? content,
    Expression<DateTime>? sentAt,
    Expression<bool>? favorite,
    Expression<int>? sendCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (content != null) 'content': content,
      if (sentAt != null) 'sent_at': sentAt,
      if (favorite != null) 'favorite': favorite,
      if (sendCount != null) 'send_count': sendCount,
    });
  }

  SentClipboardEntryCompanion copyWith(
      {Value<int>? id,
      Value<String>? content,
      Value<DateTime>? sentAt,
      Value<bool>? favorite,
      Value<int>? sendCount}) {
    return SentClipboardEntryCompanion(
      id: id ?? this.id,
      content: content ?? this.content,
      sentAt: sentAt ?? this.sentAt,
      favorite: favorite ?? this.favorite,
      sendCount: sendCount ?? this.sendCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (sentAt.present) {
      map['sent_at'] = Variable<DateTime>(sentAt.value);
    }
    if (favorite.present) {
      map['favorite'] = Variable<bool>(favorite.value);
    }
    if (sendCount.present) {
      map['send_count'] = Variable<int>(sendCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SentClipboardEntryCompanion(')
          ..write('id: $id, ')
          ..write('content: $content, ')
          ..write('sentAt: $sentAt, ')
          ..write('favorite: $favorite, ')
          ..write('sendCount: $sendCount')
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
  static const VerificationMeta _screenRecordOwnerMeta =
      const VerificationMeta('screenRecordOwner');
  @override
  late final GeneratedColumn<String> screenRecordOwner =
      GeneratedColumn<String>('screen_record_owner', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
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
        note,
        screenRecordOwner
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
    if (data.containsKey('screen_record_owner')) {
      context.handle(
          _screenRecordOwnerMeta,
          screenRecordOwner.isAcceptableOrUnknown(
              data['screen_record_owner']!, _screenRecordOwnerMeta));
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
      screenRecordOwner: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}screen_record_owner']),
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

  /// Who owns the currently-active screen recording for this session.
  /// One of 'file_browser' / 'test_session' / null. Set when a recording
  /// starts, cleared when it ends (success, failure, or session finish).
  final String? screenRecordOwner;
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
      required this.note,
      this.screenRecordOwner});
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
    if (!nullToAbsent || screenRecordOwner != null) {
      map['screen_record_owner'] = Variable<String>(screenRecordOwner);
    }
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
      screenRecordOwner: screenRecordOwner == null && nullToAbsent
          ? const Value.absent()
          : Value(screenRecordOwner),
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
      screenRecordOwner:
          serializer.fromJson<String?>(json['screenRecordOwner']),
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
      'screenRecordOwner': serializer.toJson<String?>(screenRecordOwner),
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
          String? note,
          Value<String?> screenRecordOwner = const Value.absent()}) =>
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
        screenRecordOwner: screenRecordOwner.present
            ? screenRecordOwner.value
            : this.screenRecordOwner,
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
      screenRecordOwner: data.screenRecordOwner.present
          ? data.screenRecordOwner.value
          : this.screenRecordOwner,
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
          ..write('note: $note, ')
          ..write('screenRecordOwner: $screenRecordOwner')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
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
      note,
      screenRecordOwner);
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
          other.note == this.note &&
          other.screenRecordOwner == this.screenRecordOwner);
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
  final Value<String?> screenRecordOwner;
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
    this.screenRecordOwner = const Value.absent(),
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
    this.screenRecordOwner = const Value.absent(),
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
    Expression<String>? screenRecordOwner,
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
      if (screenRecordOwner != null) 'screen_record_owner': screenRecordOwner,
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
      Value<String?>? screenRecordOwner,
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
      screenRecordOwner: screenRecordOwner ?? this.screenRecordOwner,
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
    if (screenRecordOwner.present) {
      map['screen_record_owner'] = Variable<String>(screenRecordOwner.value);
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
          ..write('screenRecordOwner: $screenRecordOwner, ')
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
  late final $ScrcpyOptions_Table scrcpyOptions = $ScrcpyOptions_Table(this);
  late final $SentClipboardEntryTable sentClipboardEntry =
      $SentClipboardEntryTable(this);
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
  late final ScrcpyOptionsDao scrcpyOptionsDao =
      ScrcpyOptionsDao(this as AppDatabase);
  late final SentClipboardEntryDao sentClipboardEntryDao =
      SentClipboardEntryDao(this as AppDatabase);
  late final TestSessionsDao testSessionsDao =
      TestSessionsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        savedDevices,
        appStates,
        scrcpyOptions,
        sentClipboardEntry,
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
  Value<String?> recordingOwner,
  Value<int?> recordingStartedAt,
  Value<bool> recordingIsSaving,
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
  Value<String?> recordingOwner,
  Value<int?> recordingStartedAt,
  Value<bool> recordingIsSaving,
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

  ColumnFilters<String> get recordingOwner => $composableBuilder(
      column: $table.recordingOwner,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get recordingStartedAt => $composableBuilder(
      column: $table.recordingStartedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get recordingIsSaving => $composableBuilder(
      column: $table.recordingIsSaving,
      builder: (column) => ColumnFilters(column));

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

  ColumnOrderings<String> get recordingOwner => $composableBuilder(
      column: $table.recordingOwner,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get recordingStartedAt => $composableBuilder(
      column: $table.recordingStartedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get recordingIsSaving => $composableBuilder(
      column: $table.recordingIsSaving,
      builder: (column) => ColumnOrderings(column));
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

  GeneratedColumn<String> get recordingOwner => $composableBuilder(
      column: $table.recordingOwner, builder: (column) => column);

  GeneratedColumn<int> get recordingStartedAt => $composableBuilder(
      column: $table.recordingStartedAt, builder: (column) => column);

  GeneratedColumn<bool> get recordingIsSaving => $composableBuilder(
      column: $table.recordingIsSaving, builder: (column) => column);

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
            Value<String?> recordingOwner = const Value.absent(),
            Value<int?> recordingStartedAt = const Value.absent(),
            Value<bool> recordingIsSaving = const Value.absent(),
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
            recordingOwner: recordingOwner,
            recordingStartedAt: recordingStartedAt,
            recordingIsSaving: recordingIsSaving,
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
            Value<String?> recordingOwner = const Value.absent(),
            Value<int?> recordingStartedAt = const Value.absent(),
            Value<bool> recordingIsSaving = const Value.absent(),
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
            recordingOwner: recordingOwner,
            recordingStartedAt: recordingStartedAt,
            recordingIsSaving: recordingIsSaving,
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
typedef $$ScrcpyOptions_TableCreateCompanionBuilder = ScrcpyOptions_Companion
    Function({
  required String serial,
  required int maxSize,
  Value<String?> videoBitRate,
  required int maxFps,
  Value<String?> videoCodec,
  Value<String?> videoEncoder,
  required int videoBuffer,
  required bool noMipmaps,
  Value<String?> captureOrientation,
  Value<String?> displayOrientation,
  Value<String?> crop,
  required int angle,
  required int displayId,
  Value<String?> renderFit,
  Value<String?> backgroundColor,
  required int minSizeAlignment,
  required bool noDownsizeOnError,
  required bool printFps,
  required bool noAudio,
  required bool noAudioPlayback,
  Value<String?> audioSource,
  Value<String?> audioCodec,
  Value<String?> audioEncoder,
  Value<String?> audioBitRate,
  required int audioBuffer,
  required int audioOutputBuffer,
  required bool audioDup,
  required bool requireAudio,
  Value<String?> videoSource,
  required int cameraId,
  Value<String?> cameraFacing,
  Value<String?> cameraSize,
  Value<String?> cameraAr,
  required int cameraFps,
  required bool cameraHighSpeed,
  required bool cameraTorch,
  required double cameraZoom,
  required bool borderless,
  Value<String?> windowTitle,
  required int windowX,
  required int windowY,
  required int windowWidth,
  required int windowHeight,
  required bool alwaysOnTop,
  required bool fullscreen,
  required bool disableScreensaver,
  required bool noWindow,
  required bool noWindowAspectRatioLock,
  Value<String?> keyboard,
  Value<String?> mouse,
  required bool noControl,
  Value<String?> mouseBind,
  required bool preferText,
  required bool rawKeyEvents,
  required bool noKeyRepeat,
  required bool noMouseHover,
  required bool legacyPaste,
  required bool noClipboardAutosync,
  required bool stayAwake,
  required bool turnScreenOff,
  required bool keepActive,
  required bool showTouches,
  required bool powerOffOnClose,
  required bool noPowerOn,
  required int screenOffTimeout,
  Value<String?> shortcutMod,
  required bool recordEnabled,
  Value<String?> record,
  Value<String?> recordFormat,
  required int timeLimit,
  required bool noPlayback,
  required bool noVideoPlayback,
  Value<String?> pauseOnExit,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ScrcpyOptions_TableUpdateCompanionBuilder = ScrcpyOptions_Companion
    Function({
  Value<String> serial,
  Value<int> maxSize,
  Value<String?> videoBitRate,
  Value<int> maxFps,
  Value<String?> videoCodec,
  Value<String?> videoEncoder,
  Value<int> videoBuffer,
  Value<bool> noMipmaps,
  Value<String?> captureOrientation,
  Value<String?> displayOrientation,
  Value<String?> crop,
  Value<int> angle,
  Value<int> displayId,
  Value<String?> renderFit,
  Value<String?> backgroundColor,
  Value<int> minSizeAlignment,
  Value<bool> noDownsizeOnError,
  Value<bool> printFps,
  Value<bool> noAudio,
  Value<bool> noAudioPlayback,
  Value<String?> audioSource,
  Value<String?> audioCodec,
  Value<String?> audioEncoder,
  Value<String?> audioBitRate,
  Value<int> audioBuffer,
  Value<int> audioOutputBuffer,
  Value<bool> audioDup,
  Value<bool> requireAudio,
  Value<String?> videoSource,
  Value<int> cameraId,
  Value<String?> cameraFacing,
  Value<String?> cameraSize,
  Value<String?> cameraAr,
  Value<int> cameraFps,
  Value<bool> cameraHighSpeed,
  Value<bool> cameraTorch,
  Value<double> cameraZoom,
  Value<bool> borderless,
  Value<String?> windowTitle,
  Value<int> windowX,
  Value<int> windowY,
  Value<int> windowWidth,
  Value<int> windowHeight,
  Value<bool> alwaysOnTop,
  Value<bool> fullscreen,
  Value<bool> disableScreensaver,
  Value<bool> noWindow,
  Value<bool> noWindowAspectRatioLock,
  Value<String?> keyboard,
  Value<String?> mouse,
  Value<bool> noControl,
  Value<String?> mouseBind,
  Value<bool> preferText,
  Value<bool> rawKeyEvents,
  Value<bool> noKeyRepeat,
  Value<bool> noMouseHover,
  Value<bool> legacyPaste,
  Value<bool> noClipboardAutosync,
  Value<bool> stayAwake,
  Value<bool> turnScreenOff,
  Value<bool> keepActive,
  Value<bool> showTouches,
  Value<bool> powerOffOnClose,
  Value<bool> noPowerOn,
  Value<int> screenOffTimeout,
  Value<String?> shortcutMod,
  Value<bool> recordEnabled,
  Value<String?> record,
  Value<String?> recordFormat,
  Value<int> timeLimit,
  Value<bool> noPlayback,
  Value<bool> noVideoPlayback,
  Value<String?> pauseOnExit,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$ScrcpyOptions_TableFilterComposer
    extends Composer<_$AppDatabase, $ScrcpyOptions_Table> {
  $$ScrcpyOptions_TableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serial => $composableBuilder(
      column: $table.serial, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get maxSize => $composableBuilder(
      column: $table.maxSize, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get videoBitRate => $composableBuilder(
      column: $table.videoBitRate, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get maxFps => $composableBuilder(
      column: $table.maxFps, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get videoCodec => $composableBuilder(
      column: $table.videoCodec, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get videoEncoder => $composableBuilder(
      column: $table.videoEncoder, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get videoBuffer => $composableBuilder(
      column: $table.videoBuffer, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get noMipmaps => $composableBuilder(
      column: $table.noMipmaps, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get captureOrientation => $composableBuilder(
      column: $table.captureOrientation,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayOrientation => $composableBuilder(
      column: $table.displayOrientation,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get crop => $composableBuilder(
      column: $table.crop, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get angle => $composableBuilder(
      column: $table.angle, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get displayId => $composableBuilder(
      column: $table.displayId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get renderFit => $composableBuilder(
      column: $table.renderFit, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get backgroundColor => $composableBuilder(
      column: $table.backgroundColor,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get minSizeAlignment => $composableBuilder(
      column: $table.minSizeAlignment,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get noDownsizeOnError => $composableBuilder(
      column: $table.noDownsizeOnError,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get printFps => $composableBuilder(
      column: $table.printFps, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get noAudio => $composableBuilder(
      column: $table.noAudio, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get noAudioPlayback => $composableBuilder(
      column: $table.noAudioPlayback,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get audioSource => $composableBuilder(
      column: $table.audioSource, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get audioCodec => $composableBuilder(
      column: $table.audioCodec, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get audioEncoder => $composableBuilder(
      column: $table.audioEncoder, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get audioBitRate => $composableBuilder(
      column: $table.audioBitRate, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get audioBuffer => $composableBuilder(
      column: $table.audioBuffer, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get audioOutputBuffer => $composableBuilder(
      column: $table.audioOutputBuffer,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get audioDup => $composableBuilder(
      column: $table.audioDup, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get requireAudio => $composableBuilder(
      column: $table.requireAudio, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get videoSource => $composableBuilder(
      column: $table.videoSource, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cameraId => $composableBuilder(
      column: $table.cameraId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cameraFacing => $composableBuilder(
      column: $table.cameraFacing, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cameraSize => $composableBuilder(
      column: $table.cameraSize, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cameraAr => $composableBuilder(
      column: $table.cameraAr, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cameraFps => $composableBuilder(
      column: $table.cameraFps, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get cameraHighSpeed => $composableBuilder(
      column: $table.cameraHighSpeed,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get cameraTorch => $composableBuilder(
      column: $table.cameraTorch, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get cameraZoom => $composableBuilder(
      column: $table.cameraZoom, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get borderless => $composableBuilder(
      column: $table.borderless, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get windowTitle => $composableBuilder(
      column: $table.windowTitle, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get windowX => $composableBuilder(
      column: $table.windowX, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get windowY => $composableBuilder(
      column: $table.windowY, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get windowWidth => $composableBuilder(
      column: $table.windowWidth, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get windowHeight => $composableBuilder(
      column: $table.windowHeight, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get alwaysOnTop => $composableBuilder(
      column: $table.alwaysOnTop, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get fullscreen => $composableBuilder(
      column: $table.fullscreen, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get disableScreensaver => $composableBuilder(
      column: $table.disableScreensaver,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get noWindow => $composableBuilder(
      column: $table.noWindow, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get noWindowAspectRatioLock => $composableBuilder(
      column: $table.noWindowAspectRatioLock,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get keyboard => $composableBuilder(
      column: $table.keyboard, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mouse => $composableBuilder(
      column: $table.mouse, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get noControl => $composableBuilder(
      column: $table.noControl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mouseBind => $composableBuilder(
      column: $table.mouseBind, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get preferText => $composableBuilder(
      column: $table.preferText, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get rawKeyEvents => $composableBuilder(
      column: $table.rawKeyEvents, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get noKeyRepeat => $composableBuilder(
      column: $table.noKeyRepeat, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get noMouseHover => $composableBuilder(
      column: $table.noMouseHover, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get legacyPaste => $composableBuilder(
      column: $table.legacyPaste, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get noClipboardAutosync => $composableBuilder(
      column: $table.noClipboardAutosync,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get stayAwake => $composableBuilder(
      column: $table.stayAwake, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get turnScreenOff => $composableBuilder(
      column: $table.turnScreenOff, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get keepActive => $composableBuilder(
      column: $table.keepActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get showTouches => $composableBuilder(
      column: $table.showTouches, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get powerOffOnClose => $composableBuilder(
      column: $table.powerOffOnClose,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get noPowerOn => $composableBuilder(
      column: $table.noPowerOn, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get screenOffTimeout => $composableBuilder(
      column: $table.screenOffTimeout,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shortcutMod => $composableBuilder(
      column: $table.shortcutMod, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get recordEnabled => $composableBuilder(
      column: $table.recordEnabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get record => $composableBuilder(
      column: $table.record, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recordFormat => $composableBuilder(
      column: $table.recordFormat, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get timeLimit => $composableBuilder(
      column: $table.timeLimit, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get noPlayback => $composableBuilder(
      column: $table.noPlayback, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get noVideoPlayback => $composableBuilder(
      column: $table.noVideoPlayback,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pauseOnExit => $composableBuilder(
      column: $table.pauseOnExit, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$ScrcpyOptions_TableOrderingComposer
    extends Composer<_$AppDatabase, $ScrcpyOptions_Table> {
  $$ScrcpyOptions_TableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serial => $composableBuilder(
      column: $table.serial, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get maxSize => $composableBuilder(
      column: $table.maxSize, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get videoBitRate => $composableBuilder(
      column: $table.videoBitRate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get maxFps => $composableBuilder(
      column: $table.maxFps, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get videoCodec => $composableBuilder(
      column: $table.videoCodec, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get videoEncoder => $composableBuilder(
      column: $table.videoEncoder,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get videoBuffer => $composableBuilder(
      column: $table.videoBuffer, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get noMipmaps => $composableBuilder(
      column: $table.noMipmaps, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get captureOrientation => $composableBuilder(
      column: $table.captureOrientation,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayOrientation => $composableBuilder(
      column: $table.displayOrientation,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get crop => $composableBuilder(
      column: $table.crop, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get angle => $composableBuilder(
      column: $table.angle, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get displayId => $composableBuilder(
      column: $table.displayId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get renderFit => $composableBuilder(
      column: $table.renderFit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get backgroundColor => $composableBuilder(
      column: $table.backgroundColor,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get minSizeAlignment => $composableBuilder(
      column: $table.minSizeAlignment,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get noDownsizeOnError => $composableBuilder(
      column: $table.noDownsizeOnError,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get printFps => $composableBuilder(
      column: $table.printFps, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get noAudio => $composableBuilder(
      column: $table.noAudio, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get noAudioPlayback => $composableBuilder(
      column: $table.noAudioPlayback,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get audioSource => $composableBuilder(
      column: $table.audioSource, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get audioCodec => $composableBuilder(
      column: $table.audioCodec, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get audioEncoder => $composableBuilder(
      column: $table.audioEncoder,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get audioBitRate => $composableBuilder(
      column: $table.audioBitRate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get audioBuffer => $composableBuilder(
      column: $table.audioBuffer, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get audioOutputBuffer => $composableBuilder(
      column: $table.audioOutputBuffer,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get audioDup => $composableBuilder(
      column: $table.audioDup, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get requireAudio => $composableBuilder(
      column: $table.requireAudio,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get videoSource => $composableBuilder(
      column: $table.videoSource, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cameraId => $composableBuilder(
      column: $table.cameraId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cameraFacing => $composableBuilder(
      column: $table.cameraFacing,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cameraSize => $composableBuilder(
      column: $table.cameraSize, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cameraAr => $composableBuilder(
      column: $table.cameraAr, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cameraFps => $composableBuilder(
      column: $table.cameraFps, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get cameraHighSpeed => $composableBuilder(
      column: $table.cameraHighSpeed,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get cameraTorch => $composableBuilder(
      column: $table.cameraTorch, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get cameraZoom => $composableBuilder(
      column: $table.cameraZoom, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get borderless => $composableBuilder(
      column: $table.borderless, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get windowTitle => $composableBuilder(
      column: $table.windowTitle, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get windowX => $composableBuilder(
      column: $table.windowX, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get windowY => $composableBuilder(
      column: $table.windowY, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get windowWidth => $composableBuilder(
      column: $table.windowWidth, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get windowHeight => $composableBuilder(
      column: $table.windowHeight,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get alwaysOnTop => $composableBuilder(
      column: $table.alwaysOnTop, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get fullscreen => $composableBuilder(
      column: $table.fullscreen, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get disableScreensaver => $composableBuilder(
      column: $table.disableScreensaver,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get noWindow => $composableBuilder(
      column: $table.noWindow, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get noWindowAspectRatioLock => $composableBuilder(
      column: $table.noWindowAspectRatioLock,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get keyboard => $composableBuilder(
      column: $table.keyboard, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mouse => $composableBuilder(
      column: $table.mouse, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get noControl => $composableBuilder(
      column: $table.noControl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mouseBind => $composableBuilder(
      column: $table.mouseBind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get preferText => $composableBuilder(
      column: $table.preferText, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get rawKeyEvents => $composableBuilder(
      column: $table.rawKeyEvents,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get noKeyRepeat => $composableBuilder(
      column: $table.noKeyRepeat, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get noMouseHover => $composableBuilder(
      column: $table.noMouseHover,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get legacyPaste => $composableBuilder(
      column: $table.legacyPaste, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get noClipboardAutosync => $composableBuilder(
      column: $table.noClipboardAutosync,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get stayAwake => $composableBuilder(
      column: $table.stayAwake, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get turnScreenOff => $composableBuilder(
      column: $table.turnScreenOff,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get keepActive => $composableBuilder(
      column: $table.keepActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get showTouches => $composableBuilder(
      column: $table.showTouches, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get powerOffOnClose => $composableBuilder(
      column: $table.powerOffOnClose,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get noPowerOn => $composableBuilder(
      column: $table.noPowerOn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get screenOffTimeout => $composableBuilder(
      column: $table.screenOffTimeout,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shortcutMod => $composableBuilder(
      column: $table.shortcutMod, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get recordEnabled => $composableBuilder(
      column: $table.recordEnabled,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get record => $composableBuilder(
      column: $table.record, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recordFormat => $composableBuilder(
      column: $table.recordFormat,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get timeLimit => $composableBuilder(
      column: $table.timeLimit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get noPlayback => $composableBuilder(
      column: $table.noPlayback, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get noVideoPlayback => $composableBuilder(
      column: $table.noVideoPlayback,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pauseOnExit => $composableBuilder(
      column: $table.pauseOnExit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ScrcpyOptions_TableAnnotationComposer
    extends Composer<_$AppDatabase, $ScrcpyOptions_Table> {
  $$ScrcpyOptions_TableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serial =>
      $composableBuilder(column: $table.serial, builder: (column) => column);

  GeneratedColumn<int> get maxSize =>
      $composableBuilder(column: $table.maxSize, builder: (column) => column);

  GeneratedColumn<String> get videoBitRate => $composableBuilder(
      column: $table.videoBitRate, builder: (column) => column);

  GeneratedColumn<int> get maxFps =>
      $composableBuilder(column: $table.maxFps, builder: (column) => column);

  GeneratedColumn<String> get videoCodec => $composableBuilder(
      column: $table.videoCodec, builder: (column) => column);

  GeneratedColumn<String> get videoEncoder => $composableBuilder(
      column: $table.videoEncoder, builder: (column) => column);

  GeneratedColumn<int> get videoBuffer => $composableBuilder(
      column: $table.videoBuffer, builder: (column) => column);

  GeneratedColumn<bool> get noMipmaps =>
      $composableBuilder(column: $table.noMipmaps, builder: (column) => column);

  GeneratedColumn<String> get captureOrientation => $composableBuilder(
      column: $table.captureOrientation, builder: (column) => column);

  GeneratedColumn<String> get displayOrientation => $composableBuilder(
      column: $table.displayOrientation, builder: (column) => column);

  GeneratedColumn<String> get crop =>
      $composableBuilder(column: $table.crop, builder: (column) => column);

  GeneratedColumn<int> get angle =>
      $composableBuilder(column: $table.angle, builder: (column) => column);

  GeneratedColumn<int> get displayId =>
      $composableBuilder(column: $table.displayId, builder: (column) => column);

  GeneratedColumn<String> get renderFit =>
      $composableBuilder(column: $table.renderFit, builder: (column) => column);

  GeneratedColumn<String> get backgroundColor => $composableBuilder(
      column: $table.backgroundColor, builder: (column) => column);

  GeneratedColumn<int> get minSizeAlignment => $composableBuilder(
      column: $table.minSizeAlignment, builder: (column) => column);

  GeneratedColumn<bool> get noDownsizeOnError => $composableBuilder(
      column: $table.noDownsizeOnError, builder: (column) => column);

  GeneratedColumn<bool> get printFps =>
      $composableBuilder(column: $table.printFps, builder: (column) => column);

  GeneratedColumn<bool> get noAudio =>
      $composableBuilder(column: $table.noAudio, builder: (column) => column);

  GeneratedColumn<bool> get noAudioPlayback => $composableBuilder(
      column: $table.noAudioPlayback, builder: (column) => column);

  GeneratedColumn<String> get audioSource => $composableBuilder(
      column: $table.audioSource, builder: (column) => column);

  GeneratedColumn<String> get audioCodec => $composableBuilder(
      column: $table.audioCodec, builder: (column) => column);

  GeneratedColumn<String> get audioEncoder => $composableBuilder(
      column: $table.audioEncoder, builder: (column) => column);

  GeneratedColumn<String> get audioBitRate => $composableBuilder(
      column: $table.audioBitRate, builder: (column) => column);

  GeneratedColumn<int> get audioBuffer => $composableBuilder(
      column: $table.audioBuffer, builder: (column) => column);

  GeneratedColumn<int> get audioOutputBuffer => $composableBuilder(
      column: $table.audioOutputBuffer, builder: (column) => column);

  GeneratedColumn<bool> get audioDup =>
      $composableBuilder(column: $table.audioDup, builder: (column) => column);

  GeneratedColumn<bool> get requireAudio => $composableBuilder(
      column: $table.requireAudio, builder: (column) => column);

  GeneratedColumn<String> get videoSource => $composableBuilder(
      column: $table.videoSource, builder: (column) => column);

  GeneratedColumn<int> get cameraId =>
      $composableBuilder(column: $table.cameraId, builder: (column) => column);

  GeneratedColumn<String> get cameraFacing => $composableBuilder(
      column: $table.cameraFacing, builder: (column) => column);

  GeneratedColumn<String> get cameraSize => $composableBuilder(
      column: $table.cameraSize, builder: (column) => column);

  GeneratedColumn<String> get cameraAr =>
      $composableBuilder(column: $table.cameraAr, builder: (column) => column);

  GeneratedColumn<int> get cameraFps =>
      $composableBuilder(column: $table.cameraFps, builder: (column) => column);

  GeneratedColumn<bool> get cameraHighSpeed => $composableBuilder(
      column: $table.cameraHighSpeed, builder: (column) => column);

  GeneratedColumn<bool> get cameraTorch => $composableBuilder(
      column: $table.cameraTorch, builder: (column) => column);

  GeneratedColumn<double> get cameraZoom => $composableBuilder(
      column: $table.cameraZoom, builder: (column) => column);

  GeneratedColumn<bool> get borderless => $composableBuilder(
      column: $table.borderless, builder: (column) => column);

  GeneratedColumn<String> get windowTitle => $composableBuilder(
      column: $table.windowTitle, builder: (column) => column);

  GeneratedColumn<int> get windowX =>
      $composableBuilder(column: $table.windowX, builder: (column) => column);

  GeneratedColumn<int> get windowY =>
      $composableBuilder(column: $table.windowY, builder: (column) => column);

  GeneratedColumn<int> get windowWidth => $composableBuilder(
      column: $table.windowWidth, builder: (column) => column);

  GeneratedColumn<int> get windowHeight => $composableBuilder(
      column: $table.windowHeight, builder: (column) => column);

  GeneratedColumn<bool> get alwaysOnTop => $composableBuilder(
      column: $table.alwaysOnTop, builder: (column) => column);

  GeneratedColumn<bool> get fullscreen => $composableBuilder(
      column: $table.fullscreen, builder: (column) => column);

  GeneratedColumn<bool> get disableScreensaver => $composableBuilder(
      column: $table.disableScreensaver, builder: (column) => column);

  GeneratedColumn<bool> get noWindow =>
      $composableBuilder(column: $table.noWindow, builder: (column) => column);

  GeneratedColumn<bool> get noWindowAspectRatioLock => $composableBuilder(
      column: $table.noWindowAspectRatioLock, builder: (column) => column);

  GeneratedColumn<String> get keyboard =>
      $composableBuilder(column: $table.keyboard, builder: (column) => column);

  GeneratedColumn<String> get mouse =>
      $composableBuilder(column: $table.mouse, builder: (column) => column);

  GeneratedColumn<bool> get noControl =>
      $composableBuilder(column: $table.noControl, builder: (column) => column);

  GeneratedColumn<String> get mouseBind =>
      $composableBuilder(column: $table.mouseBind, builder: (column) => column);

  GeneratedColumn<bool> get preferText => $composableBuilder(
      column: $table.preferText, builder: (column) => column);

  GeneratedColumn<bool> get rawKeyEvents => $composableBuilder(
      column: $table.rawKeyEvents, builder: (column) => column);

  GeneratedColumn<bool> get noKeyRepeat => $composableBuilder(
      column: $table.noKeyRepeat, builder: (column) => column);

  GeneratedColumn<bool> get noMouseHover => $composableBuilder(
      column: $table.noMouseHover, builder: (column) => column);

  GeneratedColumn<bool> get legacyPaste => $composableBuilder(
      column: $table.legacyPaste, builder: (column) => column);

  GeneratedColumn<bool> get noClipboardAutosync => $composableBuilder(
      column: $table.noClipboardAutosync, builder: (column) => column);

  GeneratedColumn<bool> get stayAwake =>
      $composableBuilder(column: $table.stayAwake, builder: (column) => column);

  GeneratedColumn<bool> get turnScreenOff => $composableBuilder(
      column: $table.turnScreenOff, builder: (column) => column);

  GeneratedColumn<bool> get keepActive => $composableBuilder(
      column: $table.keepActive, builder: (column) => column);

  GeneratedColumn<bool> get showTouches => $composableBuilder(
      column: $table.showTouches, builder: (column) => column);

  GeneratedColumn<bool> get powerOffOnClose => $composableBuilder(
      column: $table.powerOffOnClose, builder: (column) => column);

  GeneratedColumn<bool> get noPowerOn =>
      $composableBuilder(column: $table.noPowerOn, builder: (column) => column);

  GeneratedColumn<int> get screenOffTimeout => $composableBuilder(
      column: $table.screenOffTimeout, builder: (column) => column);

  GeneratedColumn<String> get shortcutMod => $composableBuilder(
      column: $table.shortcutMod, builder: (column) => column);

  GeneratedColumn<bool> get recordEnabled => $composableBuilder(
      column: $table.recordEnabled, builder: (column) => column);

  GeneratedColumn<String> get record =>
      $composableBuilder(column: $table.record, builder: (column) => column);

  GeneratedColumn<String> get recordFormat => $composableBuilder(
      column: $table.recordFormat, builder: (column) => column);

  GeneratedColumn<int> get timeLimit =>
      $composableBuilder(column: $table.timeLimit, builder: (column) => column);

  GeneratedColumn<bool> get noPlayback => $composableBuilder(
      column: $table.noPlayback, builder: (column) => column);

  GeneratedColumn<bool> get noVideoPlayback => $composableBuilder(
      column: $table.noVideoPlayback, builder: (column) => column);

  GeneratedColumn<String> get pauseOnExit => $composableBuilder(
      column: $table.pauseOnExit, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ScrcpyOptions_TableTableManager extends RootTableManager<
    _$AppDatabase,
    $ScrcpyOptions_Table,
    ScrcpyOptions_Data,
    $$ScrcpyOptions_TableFilterComposer,
    $$ScrcpyOptions_TableOrderingComposer,
    $$ScrcpyOptions_TableAnnotationComposer,
    $$ScrcpyOptions_TableCreateCompanionBuilder,
    $$ScrcpyOptions_TableUpdateCompanionBuilder,
    (
      ScrcpyOptions_Data,
      BaseReferences<_$AppDatabase, $ScrcpyOptions_Table, ScrcpyOptions_Data>
    ),
    ScrcpyOptions_Data,
    PrefetchHooks Function()> {
  $$ScrcpyOptions_TableTableManager(
      _$AppDatabase db, $ScrcpyOptions_Table table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScrcpyOptions_TableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScrcpyOptions_TableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScrcpyOptions_TableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> serial = const Value.absent(),
            Value<int> maxSize = const Value.absent(),
            Value<String?> videoBitRate = const Value.absent(),
            Value<int> maxFps = const Value.absent(),
            Value<String?> videoCodec = const Value.absent(),
            Value<String?> videoEncoder = const Value.absent(),
            Value<int> videoBuffer = const Value.absent(),
            Value<bool> noMipmaps = const Value.absent(),
            Value<String?> captureOrientation = const Value.absent(),
            Value<String?> displayOrientation = const Value.absent(),
            Value<String?> crop = const Value.absent(),
            Value<int> angle = const Value.absent(),
            Value<int> displayId = const Value.absent(),
            Value<String?> renderFit = const Value.absent(),
            Value<String?> backgroundColor = const Value.absent(),
            Value<int> minSizeAlignment = const Value.absent(),
            Value<bool> noDownsizeOnError = const Value.absent(),
            Value<bool> printFps = const Value.absent(),
            Value<bool> noAudio = const Value.absent(),
            Value<bool> noAudioPlayback = const Value.absent(),
            Value<String?> audioSource = const Value.absent(),
            Value<String?> audioCodec = const Value.absent(),
            Value<String?> audioEncoder = const Value.absent(),
            Value<String?> audioBitRate = const Value.absent(),
            Value<int> audioBuffer = const Value.absent(),
            Value<int> audioOutputBuffer = const Value.absent(),
            Value<bool> audioDup = const Value.absent(),
            Value<bool> requireAudio = const Value.absent(),
            Value<String?> videoSource = const Value.absent(),
            Value<int> cameraId = const Value.absent(),
            Value<String?> cameraFacing = const Value.absent(),
            Value<String?> cameraSize = const Value.absent(),
            Value<String?> cameraAr = const Value.absent(),
            Value<int> cameraFps = const Value.absent(),
            Value<bool> cameraHighSpeed = const Value.absent(),
            Value<bool> cameraTorch = const Value.absent(),
            Value<double> cameraZoom = const Value.absent(),
            Value<bool> borderless = const Value.absent(),
            Value<String?> windowTitle = const Value.absent(),
            Value<int> windowX = const Value.absent(),
            Value<int> windowY = const Value.absent(),
            Value<int> windowWidth = const Value.absent(),
            Value<int> windowHeight = const Value.absent(),
            Value<bool> alwaysOnTop = const Value.absent(),
            Value<bool> fullscreen = const Value.absent(),
            Value<bool> disableScreensaver = const Value.absent(),
            Value<bool> noWindow = const Value.absent(),
            Value<bool> noWindowAspectRatioLock = const Value.absent(),
            Value<String?> keyboard = const Value.absent(),
            Value<String?> mouse = const Value.absent(),
            Value<bool> noControl = const Value.absent(),
            Value<String?> mouseBind = const Value.absent(),
            Value<bool> preferText = const Value.absent(),
            Value<bool> rawKeyEvents = const Value.absent(),
            Value<bool> noKeyRepeat = const Value.absent(),
            Value<bool> noMouseHover = const Value.absent(),
            Value<bool> legacyPaste = const Value.absent(),
            Value<bool> noClipboardAutosync = const Value.absent(),
            Value<bool> stayAwake = const Value.absent(),
            Value<bool> turnScreenOff = const Value.absent(),
            Value<bool> keepActive = const Value.absent(),
            Value<bool> showTouches = const Value.absent(),
            Value<bool> powerOffOnClose = const Value.absent(),
            Value<bool> noPowerOn = const Value.absent(),
            Value<int> screenOffTimeout = const Value.absent(),
            Value<String?> shortcutMod = const Value.absent(),
            Value<bool> recordEnabled = const Value.absent(),
            Value<String?> record = const Value.absent(),
            Value<String?> recordFormat = const Value.absent(),
            Value<int> timeLimit = const Value.absent(),
            Value<bool> noPlayback = const Value.absent(),
            Value<bool> noVideoPlayback = const Value.absent(),
            Value<String?> pauseOnExit = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ScrcpyOptions_Companion(
            serial: serial,
            maxSize: maxSize,
            videoBitRate: videoBitRate,
            maxFps: maxFps,
            videoCodec: videoCodec,
            videoEncoder: videoEncoder,
            videoBuffer: videoBuffer,
            noMipmaps: noMipmaps,
            captureOrientation: captureOrientation,
            displayOrientation: displayOrientation,
            crop: crop,
            angle: angle,
            displayId: displayId,
            renderFit: renderFit,
            backgroundColor: backgroundColor,
            minSizeAlignment: minSizeAlignment,
            noDownsizeOnError: noDownsizeOnError,
            printFps: printFps,
            noAudio: noAudio,
            noAudioPlayback: noAudioPlayback,
            audioSource: audioSource,
            audioCodec: audioCodec,
            audioEncoder: audioEncoder,
            audioBitRate: audioBitRate,
            audioBuffer: audioBuffer,
            audioOutputBuffer: audioOutputBuffer,
            audioDup: audioDup,
            requireAudio: requireAudio,
            videoSource: videoSource,
            cameraId: cameraId,
            cameraFacing: cameraFacing,
            cameraSize: cameraSize,
            cameraAr: cameraAr,
            cameraFps: cameraFps,
            cameraHighSpeed: cameraHighSpeed,
            cameraTorch: cameraTorch,
            cameraZoom: cameraZoom,
            borderless: borderless,
            windowTitle: windowTitle,
            windowX: windowX,
            windowY: windowY,
            windowWidth: windowWidth,
            windowHeight: windowHeight,
            alwaysOnTop: alwaysOnTop,
            fullscreen: fullscreen,
            disableScreensaver: disableScreensaver,
            noWindow: noWindow,
            noWindowAspectRatioLock: noWindowAspectRatioLock,
            keyboard: keyboard,
            mouse: mouse,
            noControl: noControl,
            mouseBind: mouseBind,
            preferText: preferText,
            rawKeyEvents: rawKeyEvents,
            noKeyRepeat: noKeyRepeat,
            noMouseHover: noMouseHover,
            legacyPaste: legacyPaste,
            noClipboardAutosync: noClipboardAutosync,
            stayAwake: stayAwake,
            turnScreenOff: turnScreenOff,
            keepActive: keepActive,
            showTouches: showTouches,
            powerOffOnClose: powerOffOnClose,
            noPowerOn: noPowerOn,
            screenOffTimeout: screenOffTimeout,
            shortcutMod: shortcutMod,
            recordEnabled: recordEnabled,
            record: record,
            recordFormat: recordFormat,
            timeLimit: timeLimit,
            noPlayback: noPlayback,
            noVideoPlayback: noVideoPlayback,
            pauseOnExit: pauseOnExit,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String serial,
            required int maxSize,
            Value<String?> videoBitRate = const Value.absent(),
            required int maxFps,
            Value<String?> videoCodec = const Value.absent(),
            Value<String?> videoEncoder = const Value.absent(),
            required int videoBuffer,
            required bool noMipmaps,
            Value<String?> captureOrientation = const Value.absent(),
            Value<String?> displayOrientation = const Value.absent(),
            Value<String?> crop = const Value.absent(),
            required int angle,
            required int displayId,
            Value<String?> renderFit = const Value.absent(),
            Value<String?> backgroundColor = const Value.absent(),
            required int minSizeAlignment,
            required bool noDownsizeOnError,
            required bool printFps,
            required bool noAudio,
            required bool noAudioPlayback,
            Value<String?> audioSource = const Value.absent(),
            Value<String?> audioCodec = const Value.absent(),
            Value<String?> audioEncoder = const Value.absent(),
            Value<String?> audioBitRate = const Value.absent(),
            required int audioBuffer,
            required int audioOutputBuffer,
            required bool audioDup,
            required bool requireAudio,
            Value<String?> videoSource = const Value.absent(),
            required int cameraId,
            Value<String?> cameraFacing = const Value.absent(),
            Value<String?> cameraSize = const Value.absent(),
            Value<String?> cameraAr = const Value.absent(),
            required int cameraFps,
            required bool cameraHighSpeed,
            required bool cameraTorch,
            required double cameraZoom,
            required bool borderless,
            Value<String?> windowTitle = const Value.absent(),
            required int windowX,
            required int windowY,
            required int windowWidth,
            required int windowHeight,
            required bool alwaysOnTop,
            required bool fullscreen,
            required bool disableScreensaver,
            required bool noWindow,
            required bool noWindowAspectRatioLock,
            Value<String?> keyboard = const Value.absent(),
            Value<String?> mouse = const Value.absent(),
            required bool noControl,
            Value<String?> mouseBind = const Value.absent(),
            required bool preferText,
            required bool rawKeyEvents,
            required bool noKeyRepeat,
            required bool noMouseHover,
            required bool legacyPaste,
            required bool noClipboardAutosync,
            required bool stayAwake,
            required bool turnScreenOff,
            required bool keepActive,
            required bool showTouches,
            required bool powerOffOnClose,
            required bool noPowerOn,
            required int screenOffTimeout,
            Value<String?> shortcutMod = const Value.absent(),
            required bool recordEnabled,
            Value<String?> record = const Value.absent(),
            Value<String?> recordFormat = const Value.absent(),
            required int timeLimit,
            required bool noPlayback,
            required bool noVideoPlayback,
            Value<String?> pauseOnExit = const Value.absent(),
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ScrcpyOptions_Companion.insert(
            serial: serial,
            maxSize: maxSize,
            videoBitRate: videoBitRate,
            maxFps: maxFps,
            videoCodec: videoCodec,
            videoEncoder: videoEncoder,
            videoBuffer: videoBuffer,
            noMipmaps: noMipmaps,
            captureOrientation: captureOrientation,
            displayOrientation: displayOrientation,
            crop: crop,
            angle: angle,
            displayId: displayId,
            renderFit: renderFit,
            backgroundColor: backgroundColor,
            minSizeAlignment: minSizeAlignment,
            noDownsizeOnError: noDownsizeOnError,
            printFps: printFps,
            noAudio: noAudio,
            noAudioPlayback: noAudioPlayback,
            audioSource: audioSource,
            audioCodec: audioCodec,
            audioEncoder: audioEncoder,
            audioBitRate: audioBitRate,
            audioBuffer: audioBuffer,
            audioOutputBuffer: audioOutputBuffer,
            audioDup: audioDup,
            requireAudio: requireAudio,
            videoSource: videoSource,
            cameraId: cameraId,
            cameraFacing: cameraFacing,
            cameraSize: cameraSize,
            cameraAr: cameraAr,
            cameraFps: cameraFps,
            cameraHighSpeed: cameraHighSpeed,
            cameraTorch: cameraTorch,
            cameraZoom: cameraZoom,
            borderless: borderless,
            windowTitle: windowTitle,
            windowX: windowX,
            windowY: windowY,
            windowWidth: windowWidth,
            windowHeight: windowHeight,
            alwaysOnTop: alwaysOnTop,
            fullscreen: fullscreen,
            disableScreensaver: disableScreensaver,
            noWindow: noWindow,
            noWindowAspectRatioLock: noWindowAspectRatioLock,
            keyboard: keyboard,
            mouse: mouse,
            noControl: noControl,
            mouseBind: mouseBind,
            preferText: preferText,
            rawKeyEvents: rawKeyEvents,
            noKeyRepeat: noKeyRepeat,
            noMouseHover: noMouseHover,
            legacyPaste: legacyPaste,
            noClipboardAutosync: noClipboardAutosync,
            stayAwake: stayAwake,
            turnScreenOff: turnScreenOff,
            keepActive: keepActive,
            showTouches: showTouches,
            powerOffOnClose: powerOffOnClose,
            noPowerOn: noPowerOn,
            screenOffTimeout: screenOffTimeout,
            shortcutMod: shortcutMod,
            recordEnabled: recordEnabled,
            record: record,
            recordFormat: recordFormat,
            timeLimit: timeLimit,
            noPlayback: noPlayback,
            noVideoPlayback: noVideoPlayback,
            pauseOnExit: pauseOnExit,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ScrcpyOptions_TableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ScrcpyOptions_Table,
    ScrcpyOptions_Data,
    $$ScrcpyOptions_TableFilterComposer,
    $$ScrcpyOptions_TableOrderingComposer,
    $$ScrcpyOptions_TableAnnotationComposer,
    $$ScrcpyOptions_TableCreateCompanionBuilder,
    $$ScrcpyOptions_TableUpdateCompanionBuilder,
    (
      ScrcpyOptions_Data,
      BaseReferences<_$AppDatabase, $ScrcpyOptions_Table, ScrcpyOptions_Data>
    ),
    ScrcpyOptions_Data,
    PrefetchHooks Function()>;
typedef $$SentClipboardEntryTableCreateCompanionBuilder
    = SentClipboardEntryCompanion Function({
  Value<int> id,
  required String content,
  required DateTime sentAt,
  required bool favorite,
  required int sendCount,
});
typedef $$SentClipboardEntryTableUpdateCompanionBuilder
    = SentClipboardEntryCompanion Function({
  Value<int> id,
  Value<String> content,
  Value<DateTime> sentAt,
  Value<bool> favorite,
  Value<int> sendCount,
});

class $$SentClipboardEntryTableFilterComposer
    extends Composer<_$AppDatabase, $SentClipboardEntryTable> {
  $$SentClipboardEntryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get sentAt => $composableBuilder(
      column: $table.sentAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get favorite => $composableBuilder(
      column: $table.favorite, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sendCount => $composableBuilder(
      column: $table.sendCount, builder: (column) => ColumnFilters(column));
}

class $$SentClipboardEntryTableOrderingComposer
    extends Composer<_$AppDatabase, $SentClipboardEntryTable> {
  $$SentClipboardEntryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get sentAt => $composableBuilder(
      column: $table.sentAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get favorite => $composableBuilder(
      column: $table.favorite, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sendCount => $composableBuilder(
      column: $table.sendCount, builder: (column) => ColumnOrderings(column));
}

class $$SentClipboardEntryTableAnnotationComposer
    extends Composer<_$AppDatabase, $SentClipboardEntryTable> {
  $$SentClipboardEntryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => column);

  GeneratedColumn<bool> get favorite =>
      $composableBuilder(column: $table.favorite, builder: (column) => column);

  GeneratedColumn<int> get sendCount =>
      $composableBuilder(column: $table.sendCount, builder: (column) => column);
}

class $$SentClipboardEntryTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SentClipboardEntryTable,
    SentClipboardEntryData,
    $$SentClipboardEntryTableFilterComposer,
    $$SentClipboardEntryTableOrderingComposer,
    $$SentClipboardEntryTableAnnotationComposer,
    $$SentClipboardEntryTableCreateCompanionBuilder,
    $$SentClipboardEntryTableUpdateCompanionBuilder,
    (
      SentClipboardEntryData,
      BaseReferences<_$AppDatabase, $SentClipboardEntryTable,
          SentClipboardEntryData>
    ),
    SentClipboardEntryData,
    PrefetchHooks Function()> {
  $$SentClipboardEntryTableTableManager(
      _$AppDatabase db, $SentClipboardEntryTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SentClipboardEntryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SentClipboardEntryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SentClipboardEntryTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<DateTime> sentAt = const Value.absent(),
            Value<bool> favorite = const Value.absent(),
            Value<int> sendCount = const Value.absent(),
          }) =>
              SentClipboardEntryCompanion(
            id: id,
            content: content,
            sentAt: sentAt,
            favorite: favorite,
            sendCount: sendCount,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String content,
            required DateTime sentAt,
            required bool favorite,
            required int sendCount,
          }) =>
              SentClipboardEntryCompanion.insert(
            id: id,
            content: content,
            sentAt: sentAt,
            favorite: favorite,
            sendCount: sendCount,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SentClipboardEntryTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SentClipboardEntryTable,
    SentClipboardEntryData,
    $$SentClipboardEntryTableFilterComposer,
    $$SentClipboardEntryTableOrderingComposer,
    $$SentClipboardEntryTableAnnotationComposer,
    $$SentClipboardEntryTableCreateCompanionBuilder,
    $$SentClipboardEntryTableUpdateCompanionBuilder,
    (
      SentClipboardEntryData,
      BaseReferences<_$AppDatabase, $SentClipboardEntryTable,
          SentClipboardEntryData>
    ),
    SentClipboardEntryData,
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
  Value<String?> screenRecordOwner,
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
  Value<String?> screenRecordOwner,
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

  ColumnFilters<String> get screenRecordOwner => $composableBuilder(
      column: $table.screenRecordOwner,
      builder: (column) => ColumnFilters(column));

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

  ColumnOrderings<String> get screenRecordOwner => $composableBuilder(
      column: $table.screenRecordOwner,
      builder: (column) => ColumnOrderings(column));

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

  GeneratedColumn<String> get screenRecordOwner => $composableBuilder(
      column: $table.screenRecordOwner, builder: (column) => column);

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
            Value<String?> screenRecordOwner = const Value.absent(),
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
            screenRecordOwner: screenRecordOwner,
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
            Value<String?> screenRecordOwner = const Value.absent(),
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
            screenRecordOwner: screenRecordOwner,
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
  $$ScrcpyOptions_TableTableManager get scrcpyOptions =>
      $$ScrcpyOptions_TableTableManager(_db, _db.scrcpyOptions);
  $$SentClipboardEntryTableTableManager get sentClipboardEntry =>
      $$SentClipboardEntryTableTableManager(_db, _db.sentClipboardEntry);
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
