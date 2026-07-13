// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ServerProfilesTable extends ServerProfiles
    with TableInfo<$ServerProfilesTable, ServerProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServerProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _apiBaseUrlMeta = const VerificationMeta(
    'apiBaseUrl',
  );
  @override
  late final GeneratedColumn<String> apiBaseUrl = GeneratedColumn<String>(
    'api_base_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _websocketUrlMeta = const VerificationMeta(
    'websocketUrl',
  );
  @override
  late final GeneratedColumn<String> websocketUrl = GeneratedColumn<String>(
    'websocket_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastKnownVersionMeta = const VerificationMeta(
    'lastKnownVersion',
  );
  @override
  late final GeneratedColumn<String> lastKnownVersion = GeneratedColumn<String>(
    'last_known_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastConnectedAtMeta = const VerificationMeta(
    'lastConnectedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastConnectedAt =
      GeneratedColumn<DateTime>(
        'last_connected_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    baseUrl,
    apiBaseUrl,
    websocketUrl,
    lastKnownVersion,
    isDefault,
    lastConnectedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'server_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ServerProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_baseUrlMeta);
    }
    if (data.containsKey('api_base_url')) {
      context.handle(
        _apiBaseUrlMeta,
        apiBaseUrl.isAcceptableOrUnknown(
          data['api_base_url']!,
          _apiBaseUrlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_apiBaseUrlMeta);
    }
    if (data.containsKey('websocket_url')) {
      context.handle(
        _websocketUrlMeta,
        websocketUrl.isAcceptableOrUnknown(
          data['websocket_url']!,
          _websocketUrlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_websocketUrlMeta);
    }
    if (data.containsKey('last_known_version')) {
      context.handle(
        _lastKnownVersionMeta,
        lastKnownVersion.isAcceptableOrUnknown(
          data['last_known_version']!,
          _lastKnownVersionMeta,
        ),
      );
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('last_connected_at')) {
      context.handle(
        _lastConnectedAtMeta,
        lastConnectedAt.isAcceptableOrUnknown(
          data['last_connected_at']!,
          _lastConnectedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ServerProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServerProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      )!,
      apiBaseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}api_base_url'],
      )!,
      websocketUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}websocket_url'],
      )!,
      lastKnownVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_known_version'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      lastConnectedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_connected_at'],
      ),
    );
  }

  @override
  $ServerProfilesTable createAlias(String alias) {
    return $ServerProfilesTable(attachedDatabase, alias);
  }
}

class ServerProfileRow extends DataClass
    implements Insertable<ServerProfileRow> {
  final String id;
  final String name;
  final String baseUrl;
  final String apiBaseUrl;
  final String websocketUrl;
  final String lastKnownVersion;
  final bool isDefault;
  final DateTime? lastConnectedAt;
  const ServerProfileRow({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.apiBaseUrl,
    required this.websocketUrl,
    required this.lastKnownVersion,
    required this.isDefault,
    this.lastConnectedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['base_url'] = Variable<String>(baseUrl);
    map['api_base_url'] = Variable<String>(apiBaseUrl);
    map['websocket_url'] = Variable<String>(websocketUrl);
    map['last_known_version'] = Variable<String>(lastKnownVersion);
    map['is_default'] = Variable<bool>(isDefault);
    if (!nullToAbsent || lastConnectedAt != null) {
      map['last_connected_at'] = Variable<DateTime>(lastConnectedAt);
    }
    return map;
  }

  ServerProfilesCompanion toCompanion(bool nullToAbsent) {
    return ServerProfilesCompanion(
      id: Value(id),
      name: Value(name),
      baseUrl: Value(baseUrl),
      apiBaseUrl: Value(apiBaseUrl),
      websocketUrl: Value(websocketUrl),
      lastKnownVersion: Value(lastKnownVersion),
      isDefault: Value(isDefault),
      lastConnectedAt: lastConnectedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastConnectedAt),
    );
  }

  factory ServerProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServerProfileRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
      apiBaseUrl: serializer.fromJson<String>(json['apiBaseUrl']),
      websocketUrl: serializer.fromJson<String>(json['websocketUrl']),
      lastKnownVersion: serializer.fromJson<String>(json['lastKnownVersion']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      lastConnectedAt: serializer.fromJson<DateTime?>(json['lastConnectedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'baseUrl': serializer.toJson<String>(baseUrl),
      'apiBaseUrl': serializer.toJson<String>(apiBaseUrl),
      'websocketUrl': serializer.toJson<String>(websocketUrl),
      'lastKnownVersion': serializer.toJson<String>(lastKnownVersion),
      'isDefault': serializer.toJson<bool>(isDefault),
      'lastConnectedAt': serializer.toJson<DateTime?>(lastConnectedAt),
    };
  }

  ServerProfileRow copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? apiBaseUrl,
    String? websocketUrl,
    String? lastKnownVersion,
    bool? isDefault,
    Value<DateTime?> lastConnectedAt = const Value.absent(),
  }) => ServerProfileRow(
    id: id ?? this.id,
    name: name ?? this.name,
    baseUrl: baseUrl ?? this.baseUrl,
    apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
    websocketUrl: websocketUrl ?? this.websocketUrl,
    lastKnownVersion: lastKnownVersion ?? this.lastKnownVersion,
    isDefault: isDefault ?? this.isDefault,
    lastConnectedAt: lastConnectedAt.present
        ? lastConnectedAt.value
        : this.lastConnectedAt,
  );
  ServerProfileRow copyWithCompanion(ServerProfilesCompanion data) {
    return ServerProfileRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      apiBaseUrl: data.apiBaseUrl.present
          ? data.apiBaseUrl.value
          : this.apiBaseUrl,
      websocketUrl: data.websocketUrl.present
          ? data.websocketUrl.value
          : this.websocketUrl,
      lastKnownVersion: data.lastKnownVersion.present
          ? data.lastKnownVersion.value
          : this.lastKnownVersion,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      lastConnectedAt: data.lastConnectedAt.present
          ? data.lastConnectedAt.value
          : this.lastConnectedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServerProfileRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('apiBaseUrl: $apiBaseUrl, ')
          ..write('websocketUrl: $websocketUrl, ')
          ..write('lastKnownVersion: $lastKnownVersion, ')
          ..write('isDefault: $isDefault, ')
          ..write('lastConnectedAt: $lastConnectedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    baseUrl,
    apiBaseUrl,
    websocketUrl,
    lastKnownVersion,
    isDefault,
    lastConnectedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServerProfileRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.baseUrl == this.baseUrl &&
          other.apiBaseUrl == this.apiBaseUrl &&
          other.websocketUrl == this.websocketUrl &&
          other.lastKnownVersion == this.lastKnownVersion &&
          other.isDefault == this.isDefault &&
          other.lastConnectedAt == this.lastConnectedAt);
}

class ServerProfilesCompanion extends UpdateCompanion<ServerProfileRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> baseUrl;
  final Value<String> apiBaseUrl;
  final Value<String> websocketUrl;
  final Value<String> lastKnownVersion;
  final Value<bool> isDefault;
  final Value<DateTime?> lastConnectedAt;
  final Value<int> rowid;
  const ServerProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.apiBaseUrl = const Value.absent(),
    this.websocketUrl = const Value.absent(),
    this.lastKnownVersion = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.lastConnectedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ServerProfilesCompanion.insert({
    required String id,
    required String name,
    required String baseUrl,
    required String apiBaseUrl,
    required String websocketUrl,
    this.lastKnownVersion = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.lastConnectedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       baseUrl = Value(baseUrl),
       apiBaseUrl = Value(apiBaseUrl),
       websocketUrl = Value(websocketUrl);
  static Insertable<ServerProfileRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? baseUrl,
    Expression<String>? apiBaseUrl,
    Expression<String>? websocketUrl,
    Expression<String>? lastKnownVersion,
    Expression<bool>? isDefault,
    Expression<DateTime>? lastConnectedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (baseUrl != null) 'base_url': baseUrl,
      if (apiBaseUrl != null) 'api_base_url': apiBaseUrl,
      if (websocketUrl != null) 'websocket_url': websocketUrl,
      if (lastKnownVersion != null) 'last_known_version': lastKnownVersion,
      if (isDefault != null) 'is_default': isDefault,
      if (lastConnectedAt != null) 'last_connected_at': lastConnectedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ServerProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? baseUrl,
    Value<String>? apiBaseUrl,
    Value<String>? websocketUrl,
    Value<String>? lastKnownVersion,
    Value<bool>? isDefault,
    Value<DateTime?>? lastConnectedAt,
    Value<int>? rowid,
  }) {
    return ServerProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      websocketUrl: websocketUrl ?? this.websocketUrl,
      lastKnownVersion: lastKnownVersion ?? this.lastKnownVersion,
      isDefault: isDefault ?? this.isDefault,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
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
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (apiBaseUrl.present) {
      map['api_base_url'] = Variable<String>(apiBaseUrl.value);
    }
    if (websocketUrl.present) {
      map['websocket_url'] = Variable<String>(websocketUrl.value);
    }
    if (lastKnownVersion.present) {
      map['last_known_version'] = Variable<String>(lastKnownVersion.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (lastConnectedAt.present) {
      map['last_connected_at'] = Variable<DateTime>(lastConnectedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServerProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('apiBaseUrl: $apiBaseUrl, ')
          ..write('websocketUrl: $websocketUrl, ')
          ..write('lastKnownVersion: $lastKnownVersion, ')
          ..write('isDefault: $isDefault, ')
          ..write('lastConnectedAt: $lastConnectedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxTable extends SyncOutbox
    with TableInfo<$SyncOutboxTable, SyncOutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseRevisionMeta = const VerificationMeta(
    'baseRevision',
  );
  @override
  late final GeneratedColumn<int> baseRevision = GeneratedColumn<int>(
    'base_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    scope,
    entityType,
    entityId,
    baseRevision,
    payloadJson,
    createdAt,
    attempts,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncOutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('base_revision')) {
      context.handle(
        _baseRevisionMeta,
        baseRevision.isAcceptableOrUnknown(
          data['base_revision']!,
          _baseRevisionMeta,
        ),
      );
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncOutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      baseRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_revision'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
    );
  }

  @override
  $SyncOutboxTable createAlias(String alias) {
    return $SyncOutboxTable(attachedDatabase, alias);
  }
}

class SyncOutboxData extends DataClass implements Insertable<SyncOutboxData> {
  final String id;
  final String scope;
  final String entityType;
  final String entityId;
  final int baseRevision;
  final String payloadJson;
  final DateTime createdAt;
  final int attempts;
  const SyncOutboxData({
    required this.id,
    required this.scope,
    required this.entityType,
    required this.entityId,
    required this.baseRevision,
    required this.payloadJson,
    required this.createdAt,
    required this.attempts,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['scope'] = Variable<String>(scope);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['base_revision'] = Variable<int>(baseRevision);
    map['payload_json'] = Variable<String>(payloadJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['attempts'] = Variable<int>(attempts);
    return map;
  }

  SyncOutboxCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxCompanion(
      id: Value(id),
      scope: Value(scope),
      entityType: Value(entityType),
      entityId: Value(entityId),
      baseRevision: Value(baseRevision),
      payloadJson: Value(payloadJson),
      createdAt: Value(createdAt),
      attempts: Value(attempts),
    );
  }

  factory SyncOutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxData(
      id: serializer.fromJson<String>(json['id']),
      scope: serializer.fromJson<String>(json['scope']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      baseRevision: serializer.fromJson<int>(json['baseRevision']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'scope': serializer.toJson<String>(scope),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'baseRevision': serializer.toJson<int>(baseRevision),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'attempts': serializer.toJson<int>(attempts),
    };
  }

  SyncOutboxData copyWith({
    String? id,
    String? scope,
    String? entityType,
    String? entityId,
    int? baseRevision,
    String? payloadJson,
    DateTime? createdAt,
    int? attempts,
  }) => SyncOutboxData(
    id: id ?? this.id,
    scope: scope ?? this.scope,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    baseRevision: baseRevision ?? this.baseRevision,
    payloadJson: payloadJson ?? this.payloadJson,
    createdAt: createdAt ?? this.createdAt,
    attempts: attempts ?? this.attempts,
  );
  SyncOutboxData copyWithCompanion(SyncOutboxCompanion data) {
    return SyncOutboxData(
      id: data.id.present ? data.id.value : this.id,
      scope: data.scope.present ? data.scope.value : this.scope,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      baseRevision: data.baseRevision.present
          ? data.baseRevision.value
          : this.baseRevision,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxData(')
          ..write('id: $id, ')
          ..write('scope: $scope, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('baseRevision: $baseRevision, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    scope,
    entityType,
    entityId,
    baseRevision,
    payloadJson,
    createdAt,
    attempts,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxData &&
          other.id == this.id &&
          other.scope == this.scope &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.baseRevision == this.baseRevision &&
          other.payloadJson == this.payloadJson &&
          other.createdAt == this.createdAt &&
          other.attempts == this.attempts);
}

class SyncOutboxCompanion extends UpdateCompanion<SyncOutboxData> {
  final Value<String> id;
  final Value<String> scope;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<int> baseRevision;
  final Value<String> payloadJson;
  final Value<DateTime> createdAt;
  final Value<int> attempts;
  final Value<int> rowid;
  const SyncOutboxCompanion({
    this.id = const Value.absent(),
    this.scope = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.baseRevision = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncOutboxCompanion.insert({
    required String id,
    required String scope,
    required String entityType,
    required String entityId,
    this.baseRevision = const Value.absent(),
    required String payloadJson,
    required DateTime createdAt,
    this.attempts = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       scope = Value(scope),
       entityType = Value(entityType),
       entityId = Value(entityId),
       payloadJson = Value(payloadJson),
       createdAt = Value(createdAt);
  static Insertable<SyncOutboxData> custom({
    Expression<String>? id,
    Expression<String>? scope,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<int>? baseRevision,
    Expression<String>? payloadJson,
    Expression<DateTime>? createdAt,
    Expression<int>? attempts,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scope != null) 'scope': scope,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (baseRevision != null) 'base_revision': baseRevision,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (createdAt != null) 'created_at': createdAt,
      if (attempts != null) 'attempts': attempts,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncOutboxCompanion copyWith({
    Value<String>? id,
    Value<String>? scope,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<int>? baseRevision,
    Value<String>? payloadJson,
    Value<DateTime>? createdAt,
    Value<int>? attempts,
    Value<int>? rowid,
  }) {
    return SyncOutboxCompanion(
      id: id ?? this.id,
      scope: scope ?? this.scope,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      baseRevision: baseRevision ?? this.baseRevision,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (baseRevision.present) {
      map['base_revision'] = Variable<int>(baseRevision.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxCompanion(')
          ..write('id: $id, ')
          ..write('scope: $scope, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('baseRevision: $baseRevision, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncCursorsTable extends SyncCursors
    with TableInfo<$SyncCursorsTable, SyncCursor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
    'remote_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cursorMeta = const VerificationMeta('cursor');
  @override
  late final GeneratedColumn<String> cursor = GeneratedColumn<String>(
    'cursor',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [scope, remoteId, cursor, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncCursor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteIdMeta);
    }
    if (data.containsKey('cursor')) {
      context.handle(
        _cursorMeta,
        cursor.isAcceptableOrUnknown(data['cursor']!, _cursorMeta),
      );
    } else if (isInserting) {
      context.missing(_cursorMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scope, remoteId};
  @override
  SyncCursor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursor(
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_id'],
      )!,
      cursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cursor'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SyncCursorsTable createAlias(String alias) {
    return $SyncCursorsTable(attachedDatabase, alias);
  }
}

class SyncCursor extends DataClass implements Insertable<SyncCursor> {
  final String scope;
  final String remoteId;
  final String cursor;
  final DateTime updatedAt;
  const SyncCursor({
    required this.scope,
    required this.remoteId,
    required this.cursor,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope'] = Variable<String>(scope);
    map['remote_id'] = Variable<String>(remoteId);
    map['cursor'] = Variable<String>(cursor);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SyncCursorsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorsCompanion(
      scope: Value(scope),
      remoteId: Value(remoteId),
      cursor: Value(cursor),
      updatedAt: Value(updatedAt),
    );
  }

  factory SyncCursor.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursor(
      scope: serializer.fromJson<String>(json['scope']),
      remoteId: serializer.fromJson<String>(json['remoteId']),
      cursor: serializer.fromJson<String>(json['cursor']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scope': serializer.toJson<String>(scope),
      'remoteId': serializer.toJson<String>(remoteId),
      'cursor': serializer.toJson<String>(cursor),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SyncCursor copyWith({
    String? scope,
    String? remoteId,
    String? cursor,
    DateTime? updatedAt,
  }) => SyncCursor(
    scope: scope ?? this.scope,
    remoteId: remoteId ?? this.remoteId,
    cursor: cursor ?? this.cursor,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SyncCursor copyWithCompanion(SyncCursorsCompanion data) {
    return SyncCursor(
      scope: data.scope.present ? data.scope.value : this.scope,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursor(')
          ..write('scope: $scope, ')
          ..write('remoteId: $remoteId, ')
          ..write('cursor: $cursor, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(scope, remoteId, cursor, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursor &&
          other.scope == this.scope &&
          other.remoteId == this.remoteId &&
          other.cursor == this.cursor &&
          other.updatedAt == this.updatedAt);
}

class SyncCursorsCompanion extends UpdateCompanion<SyncCursor> {
  final Value<String> scope;
  final Value<String> remoteId;
  final Value<String> cursor;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SyncCursorsCompanion({
    this.scope = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.cursor = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCursorsCompanion.insert({
    required String scope,
    required String remoteId,
    required String cursor,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : scope = Value(scope),
       remoteId = Value(remoteId),
       cursor = Value(cursor),
       updatedAt = Value(updatedAt);
  static Insertable<SyncCursor> custom({
    Expression<String>? scope,
    Expression<String>? remoteId,
    Expression<String>? cursor,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scope != null) 'scope': scope,
      if (remoteId != null) 'remote_id': remoteId,
      if (cursor != null) 'cursor': cursor,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCursorsCompanion copyWith({
    Value<String>? scope,
    Value<String>? remoteId,
    Value<String>? cursor,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SyncCursorsCompanion(
      scope: scope ?? this.scope,
      remoteId: remoteId ?? this.remoteId,
      cursor: cursor ?? this.cursor,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (cursor.present) {
      map['cursor'] = Variable<String>(cursor.value);
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
    return (StringBuffer('SyncCursorsCompanion(')
          ..write('scope: $scope, ')
          ..write('remoteId: $remoteId, ')
          ..write('cursor: $cursor, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MigrationMarkersTable extends MigrationMarkers
    with TableInfo<$MigrationMarkersTable, MigrationMarker> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MigrationMarkersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, completedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'migration_markers';
  @override
  VerificationContext validateIntegrity(
    Insertable<MigrationMarker> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MigrationMarker map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MigrationMarker(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      )!,
    );
  }

  @override
  $MigrationMarkersTable createAlias(String alias) {
    return $MigrationMarkersTable(attachedDatabase, alias);
  }
}

class MigrationMarker extends DataClass implements Insertable<MigrationMarker> {
  final String key;
  final DateTime completedAt;
  const MigrationMarker({required this.key, required this.completedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['completed_at'] = Variable<DateTime>(completedAt);
    return map;
  }

  MigrationMarkersCompanion toCompanion(bool nullToAbsent) {
    return MigrationMarkersCompanion(
      key: Value(key),
      completedAt: Value(completedAt),
    );
  }

  factory MigrationMarker.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MigrationMarker(
      key: serializer.fromJson<String>(json['key']),
      completedAt: serializer.fromJson<DateTime>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'completedAt': serializer.toJson<DateTime>(completedAt),
    };
  }

  MigrationMarker copyWith({String? key, DateTime? completedAt}) =>
      MigrationMarker(
        key: key ?? this.key,
        completedAt: completedAt ?? this.completedAt,
      );
  MigrationMarker copyWithCompanion(MigrationMarkersCompanion data) {
    return MigrationMarker(
      key: data.key.present ? data.key.value : this.key,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MigrationMarker(')
          ..write('key: $key, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, completedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MigrationMarker &&
          other.key == this.key &&
          other.completedAt == this.completedAt);
}

class MigrationMarkersCompanion extends UpdateCompanion<MigrationMarker> {
  final Value<String> key;
  final Value<DateTime> completedAt;
  final Value<int> rowid;
  const MigrationMarkersCompanion({
    this.key = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MigrationMarkersCompanion.insert({
    required String key,
    required DateTime completedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       completedAt = Value(completedAt);
  static Insertable<MigrationMarker> custom({
    Expression<String>? key,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MigrationMarkersCompanion copyWith({
    Value<String>? key,
    Value<DateTime>? completedAt,
    Value<int>? rowid,
  }) {
    return MigrationMarkersCompanion(
      key: key ?? this.key,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MigrationMarkersCompanion(')
          ..write('key: $key, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalContentPackagesTable extends LocalContentPackages
    with TableInfo<$LocalContentPackagesTable, LocalContentPackageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalContentPackagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatVersionMeta = const VerificationMeta(
    'formatVersion',
  );
  @override
  late final GeneratedColumn<int> formatVersion = GeneratedColumn<int>(
    'format_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localeMeta = const VerificationMeta('locale');
  @override
  late final GeneratedColumn<String> locale = GeneratedColumn<String>(
    'locale',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _systemMeta = const VerificationMeta('system');
  @override
  late final GeneratedColumn<String> system = GeneratedColumn<String>(
    'system',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryCountMeta = const VerificationMeta(
    'entryCount',
  );
  @override
  late final GeneratedColumn<int> entryCount = GeneratedColumn<int>(
    'entry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _installedAtMeta = const VerificationMeta(
    'installedAt',
  );
  @override
  late final GeneratedColumn<DateTime> installedAt = GeneratedColumn<DateTime>(
    'installed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    formatVersion,
    name,
    version,
    locale,
    system,
    entryCount,
    contentHash,
    enabled,
    installedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_content_packages';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalContentPackageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('format_version')) {
      context.handle(
        _formatVersionMeta,
        formatVersion.isAcceptableOrUnknown(
          data['format_version']!,
          _formatVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_formatVersionMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('locale')) {
      context.handle(
        _localeMeta,
        locale.isAcceptableOrUnknown(data['locale']!, _localeMeta),
      );
    } else if (isInserting) {
      context.missing(_localeMeta);
    }
    if (data.containsKey('system')) {
      context.handle(
        _systemMeta,
        system.isAcceptableOrUnknown(data['system']!, _systemMeta),
      );
    } else if (isInserting) {
      context.missing(_systemMeta);
    }
    if (data.containsKey('entry_count')) {
      context.handle(
        _entryCountMeta,
        entryCount.isAcceptableOrUnknown(data['entry_count']!, _entryCountMeta),
      );
    } else if (isInserting) {
      context.missing(_entryCountMeta);
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('installed_at')) {
      context.handle(
        _installedAtMeta,
        installedAt.isAcceptableOrUnknown(
          data['installed_at']!,
          _installedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_installedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalContentPackageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalContentPackageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      formatVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}format_version'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      locale: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locale'],
      )!,
      system: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}system'],
      )!,
      entryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}entry_count'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      installedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}installed_at'],
      )!,
    );
  }

  @override
  $LocalContentPackagesTable createAlias(String alias) {
    return $LocalContentPackagesTable(attachedDatabase, alias);
  }
}

class LocalContentPackageRow extends DataClass
    implements Insertable<LocalContentPackageRow> {
  final String id;
  final int formatVersion;
  final String name;
  final String version;
  final String locale;
  final String system;
  final int entryCount;
  final String contentHash;
  final bool enabled;
  final DateTime installedAt;
  const LocalContentPackageRow({
    required this.id,
    required this.formatVersion,
    required this.name,
    required this.version,
    required this.locale,
    required this.system,
    required this.entryCount,
    required this.contentHash,
    required this.enabled,
    required this.installedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['format_version'] = Variable<int>(formatVersion);
    map['name'] = Variable<String>(name);
    map['version'] = Variable<String>(version);
    map['locale'] = Variable<String>(locale);
    map['system'] = Variable<String>(system);
    map['entry_count'] = Variable<int>(entryCount);
    map['content_hash'] = Variable<String>(contentHash);
    map['enabled'] = Variable<bool>(enabled);
    map['installed_at'] = Variable<DateTime>(installedAt);
    return map;
  }

  LocalContentPackagesCompanion toCompanion(bool nullToAbsent) {
    return LocalContentPackagesCompanion(
      id: Value(id),
      formatVersion: Value(formatVersion),
      name: Value(name),
      version: Value(version),
      locale: Value(locale),
      system: Value(system),
      entryCount: Value(entryCount),
      contentHash: Value(contentHash),
      enabled: Value(enabled),
      installedAt: Value(installedAt),
    );
  }

  factory LocalContentPackageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalContentPackageRow(
      id: serializer.fromJson<String>(json['id']),
      formatVersion: serializer.fromJson<int>(json['formatVersion']),
      name: serializer.fromJson<String>(json['name']),
      version: serializer.fromJson<String>(json['version']),
      locale: serializer.fromJson<String>(json['locale']),
      system: serializer.fromJson<String>(json['system']),
      entryCount: serializer.fromJson<int>(json['entryCount']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      installedAt: serializer.fromJson<DateTime>(json['installedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'formatVersion': serializer.toJson<int>(formatVersion),
      'name': serializer.toJson<String>(name),
      'version': serializer.toJson<String>(version),
      'locale': serializer.toJson<String>(locale),
      'system': serializer.toJson<String>(system),
      'entryCount': serializer.toJson<int>(entryCount),
      'contentHash': serializer.toJson<String>(contentHash),
      'enabled': serializer.toJson<bool>(enabled),
      'installedAt': serializer.toJson<DateTime>(installedAt),
    };
  }

  LocalContentPackageRow copyWith({
    String? id,
    int? formatVersion,
    String? name,
    String? version,
    String? locale,
    String? system,
    int? entryCount,
    String? contentHash,
    bool? enabled,
    DateTime? installedAt,
  }) => LocalContentPackageRow(
    id: id ?? this.id,
    formatVersion: formatVersion ?? this.formatVersion,
    name: name ?? this.name,
    version: version ?? this.version,
    locale: locale ?? this.locale,
    system: system ?? this.system,
    entryCount: entryCount ?? this.entryCount,
    contentHash: contentHash ?? this.contentHash,
    enabled: enabled ?? this.enabled,
    installedAt: installedAt ?? this.installedAt,
  );
  LocalContentPackageRow copyWithCompanion(LocalContentPackagesCompanion data) {
    return LocalContentPackageRow(
      id: data.id.present ? data.id.value : this.id,
      formatVersion: data.formatVersion.present
          ? data.formatVersion.value
          : this.formatVersion,
      name: data.name.present ? data.name.value : this.name,
      version: data.version.present ? data.version.value : this.version,
      locale: data.locale.present ? data.locale.value : this.locale,
      system: data.system.present ? data.system.value : this.system,
      entryCount: data.entryCount.present
          ? data.entryCount.value
          : this.entryCount,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      installedAt: data.installedAt.present
          ? data.installedAt.value
          : this.installedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalContentPackageRow(')
          ..write('id: $id, ')
          ..write('formatVersion: $formatVersion, ')
          ..write('name: $name, ')
          ..write('version: $version, ')
          ..write('locale: $locale, ')
          ..write('system: $system, ')
          ..write('entryCount: $entryCount, ')
          ..write('contentHash: $contentHash, ')
          ..write('enabled: $enabled, ')
          ..write('installedAt: $installedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    formatVersion,
    name,
    version,
    locale,
    system,
    entryCount,
    contentHash,
    enabled,
    installedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalContentPackageRow &&
          other.id == this.id &&
          other.formatVersion == this.formatVersion &&
          other.name == this.name &&
          other.version == this.version &&
          other.locale == this.locale &&
          other.system == this.system &&
          other.entryCount == this.entryCount &&
          other.contentHash == this.contentHash &&
          other.enabled == this.enabled &&
          other.installedAt == this.installedAt);
}

class LocalContentPackagesCompanion
    extends UpdateCompanion<LocalContentPackageRow> {
  final Value<String> id;
  final Value<int> formatVersion;
  final Value<String> name;
  final Value<String> version;
  final Value<String> locale;
  final Value<String> system;
  final Value<int> entryCount;
  final Value<String> contentHash;
  final Value<bool> enabled;
  final Value<DateTime> installedAt;
  final Value<int> rowid;
  const LocalContentPackagesCompanion({
    this.id = const Value.absent(),
    this.formatVersion = const Value.absent(),
    this.name = const Value.absent(),
    this.version = const Value.absent(),
    this.locale = const Value.absent(),
    this.system = const Value.absent(),
    this.entryCount = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.enabled = const Value.absent(),
    this.installedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalContentPackagesCompanion.insert({
    required String id,
    required int formatVersion,
    required String name,
    required String version,
    required String locale,
    required String system,
    required int entryCount,
    required String contentHash,
    this.enabled = const Value.absent(),
    required DateTime installedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       formatVersion = Value(formatVersion),
       name = Value(name),
       version = Value(version),
       locale = Value(locale),
       system = Value(system),
       entryCount = Value(entryCount),
       contentHash = Value(contentHash),
       installedAt = Value(installedAt);
  static Insertable<LocalContentPackageRow> custom({
    Expression<String>? id,
    Expression<int>? formatVersion,
    Expression<String>? name,
    Expression<String>? version,
    Expression<String>? locale,
    Expression<String>? system,
    Expression<int>? entryCount,
    Expression<String>? contentHash,
    Expression<bool>? enabled,
    Expression<DateTime>? installedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (formatVersion != null) 'format_version': formatVersion,
      if (name != null) 'name': name,
      if (version != null) 'version': version,
      if (locale != null) 'locale': locale,
      if (system != null) 'system': system,
      if (entryCount != null) 'entry_count': entryCount,
      if (contentHash != null) 'content_hash': contentHash,
      if (enabled != null) 'enabled': enabled,
      if (installedAt != null) 'installed_at': installedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalContentPackagesCompanion copyWith({
    Value<String>? id,
    Value<int>? formatVersion,
    Value<String>? name,
    Value<String>? version,
    Value<String>? locale,
    Value<String>? system,
    Value<int>? entryCount,
    Value<String>? contentHash,
    Value<bool>? enabled,
    Value<DateTime>? installedAt,
    Value<int>? rowid,
  }) {
    return LocalContentPackagesCompanion(
      id: id ?? this.id,
      formatVersion: formatVersion ?? this.formatVersion,
      name: name ?? this.name,
      version: version ?? this.version,
      locale: locale ?? this.locale,
      system: system ?? this.system,
      entryCount: entryCount ?? this.entryCount,
      contentHash: contentHash ?? this.contentHash,
      enabled: enabled ?? this.enabled,
      installedAt: installedAt ?? this.installedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (formatVersion.present) {
      map['format_version'] = Variable<int>(formatVersion.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (locale.present) {
      map['locale'] = Variable<String>(locale.value);
    }
    if (system.present) {
      map['system'] = Variable<String>(system.value);
    }
    if (entryCount.present) {
      map['entry_count'] = Variable<int>(entryCount.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (installedAt.present) {
      map['installed_at'] = Variable<DateTime>(installedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalContentPackagesCompanion(')
          ..write('id: $id, ')
          ..write('formatVersion: $formatVersion, ')
          ..write('name: $name, ')
          ..write('version: $version, ')
          ..write('locale: $locale, ')
          ..write('system: $system, ')
          ..write('entryCount: $entryCount, ')
          ..write('contentHash: $contentHash, ')
          ..write('enabled: $enabled, ')
          ..write('installedAt: $installedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalContentEntriesTable extends LocalContentEntries
    with TableInfo<$LocalContentEntriesTable, LocalContentEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalContentEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entryKeyMeta = const VerificationMeta(
    'entryKey',
  );
  @override
  late final GeneratedColumn<String> entryKey = GeneratedColumn<String>(
    'entry_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _packageIdMeta = const VerificationMeta(
    'packageId',
  );
  @override
  late final GeneratedColumn<String> packageId = GeneratedColumn<String>(
    'package_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _slugMeta = const VerificationMeta('slug');
  @override
  late final GeneratedColumn<String> slug = GeneratedColumn<String>(
    'slug',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aliasesJsonMeta = const VerificationMeta(
    'aliasesJson',
  );
  @override
  late final GeneratedColumn<String> aliasesJson = GeneratedColumn<String>(
    'aliases_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _bodyJsonMeta = const VerificationMeta(
    'bodyJson',
  );
  @override
  late final GeneratedColumn<String> bodyJson = GeneratedColumn<String>(
    'body_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _structuredJsonMeta = const VerificationMeta(
    'structuredJson',
  );
  @override
  late final GeneratedColumn<String> structuredJson = GeneratedColumn<String>(
    'structured_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _tagsJsonMeta = const VerificationMeta(
    'tagsJson',
  );
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
    'tags_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _sourceLabelMeta = const VerificationMeta(
    'sourceLabel',
  );
  @override
  late final GeneratedColumn<String> sourceLabel = GeneratedColumn<String>(
    'source_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    entryKey,
    packageId,
    type,
    slug,
    name,
    aliasesJson,
    summary,
    bodyJson,
    structuredJson,
    tagsJson,
    sourceLabel,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_content_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalContentEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entry_key')) {
      context.handle(
        _entryKeyMeta,
        entryKey.isAcceptableOrUnknown(data['entry_key']!, _entryKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_entryKeyMeta);
    }
    if (data.containsKey('package_id')) {
      context.handle(
        _packageIdMeta,
        packageId.isAcceptableOrUnknown(data['package_id']!, _packageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_packageIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('slug')) {
      context.handle(
        _slugMeta,
        slug.isAcceptableOrUnknown(data['slug']!, _slugMeta),
      );
    } else if (isInserting) {
      context.missing(_slugMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('aliases_json')) {
      context.handle(
        _aliasesJsonMeta,
        aliasesJson.isAcceptableOrUnknown(
          data['aliases_json']!,
          _aliasesJsonMeta,
        ),
      );
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('body_json')) {
      context.handle(
        _bodyJsonMeta,
        bodyJson.isAcceptableOrUnknown(data['body_json']!, _bodyJsonMeta),
      );
    }
    if (data.containsKey('structured_json')) {
      context.handle(
        _structuredJsonMeta,
        structuredJson.isAcceptableOrUnknown(
          data['structured_json']!,
          _structuredJsonMeta,
        ),
      );
    }
    if (data.containsKey('tags_json')) {
      context.handle(
        _tagsJsonMeta,
        tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta),
      );
    }
    if (data.containsKey('source_label')) {
      context.handle(
        _sourceLabelMeta,
        sourceLabel.isAcceptableOrUnknown(
          data['source_label']!,
          _sourceLabelMeta,
        ),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryKey};
  @override
  LocalContentEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalContentEntryRow(
      entryKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_key'],
      )!,
      packageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      slug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slug'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      aliasesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aliases_json'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      )!,
      bodyJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_json'],
      )!,
      structuredJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}structured_json'],
      )!,
      tagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_json'],
      )!,
      sourceLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_label'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $LocalContentEntriesTable createAlias(String alias) {
    return $LocalContentEntriesTable(attachedDatabase, alias);
  }
}

class LocalContentEntryRow extends DataClass
    implements Insertable<LocalContentEntryRow> {
  final String entryKey;
  final String packageId;
  final String type;
  final String slug;
  final String name;
  final String aliasesJson;
  final String summary;
  final String bodyJson;
  final String structuredJson;
  final String tagsJson;
  final String sourceLabel;
  final int revision;
  const LocalContentEntryRow({
    required this.entryKey,
    required this.packageId,
    required this.type,
    required this.slug,
    required this.name,
    required this.aliasesJson,
    required this.summary,
    required this.bodyJson,
    required this.structuredJson,
    required this.tagsJson,
    required this.sourceLabel,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_key'] = Variable<String>(entryKey);
    map['package_id'] = Variable<String>(packageId);
    map['type'] = Variable<String>(type);
    map['slug'] = Variable<String>(slug);
    map['name'] = Variable<String>(name);
    map['aliases_json'] = Variable<String>(aliasesJson);
    map['summary'] = Variable<String>(summary);
    map['body_json'] = Variable<String>(bodyJson);
    map['structured_json'] = Variable<String>(structuredJson);
    map['tags_json'] = Variable<String>(tagsJson);
    map['source_label'] = Variable<String>(sourceLabel);
    map['revision'] = Variable<int>(revision);
    return map;
  }

  LocalContentEntriesCompanion toCompanion(bool nullToAbsent) {
    return LocalContentEntriesCompanion(
      entryKey: Value(entryKey),
      packageId: Value(packageId),
      type: Value(type),
      slug: Value(slug),
      name: Value(name),
      aliasesJson: Value(aliasesJson),
      summary: Value(summary),
      bodyJson: Value(bodyJson),
      structuredJson: Value(structuredJson),
      tagsJson: Value(tagsJson),
      sourceLabel: Value(sourceLabel),
      revision: Value(revision),
    );
  }

  factory LocalContentEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalContentEntryRow(
      entryKey: serializer.fromJson<String>(json['entryKey']),
      packageId: serializer.fromJson<String>(json['packageId']),
      type: serializer.fromJson<String>(json['type']),
      slug: serializer.fromJson<String>(json['slug']),
      name: serializer.fromJson<String>(json['name']),
      aliasesJson: serializer.fromJson<String>(json['aliasesJson']),
      summary: serializer.fromJson<String>(json['summary']),
      bodyJson: serializer.fromJson<String>(json['bodyJson']),
      structuredJson: serializer.fromJson<String>(json['structuredJson']),
      tagsJson: serializer.fromJson<String>(json['tagsJson']),
      sourceLabel: serializer.fromJson<String>(json['sourceLabel']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entryKey': serializer.toJson<String>(entryKey),
      'packageId': serializer.toJson<String>(packageId),
      'type': serializer.toJson<String>(type),
      'slug': serializer.toJson<String>(slug),
      'name': serializer.toJson<String>(name),
      'aliasesJson': serializer.toJson<String>(aliasesJson),
      'summary': serializer.toJson<String>(summary),
      'bodyJson': serializer.toJson<String>(bodyJson),
      'structuredJson': serializer.toJson<String>(structuredJson),
      'tagsJson': serializer.toJson<String>(tagsJson),
      'sourceLabel': serializer.toJson<String>(sourceLabel),
      'revision': serializer.toJson<int>(revision),
    };
  }

  LocalContentEntryRow copyWith({
    String? entryKey,
    String? packageId,
    String? type,
    String? slug,
    String? name,
    String? aliasesJson,
    String? summary,
    String? bodyJson,
    String? structuredJson,
    String? tagsJson,
    String? sourceLabel,
    int? revision,
  }) => LocalContentEntryRow(
    entryKey: entryKey ?? this.entryKey,
    packageId: packageId ?? this.packageId,
    type: type ?? this.type,
    slug: slug ?? this.slug,
    name: name ?? this.name,
    aliasesJson: aliasesJson ?? this.aliasesJson,
    summary: summary ?? this.summary,
    bodyJson: bodyJson ?? this.bodyJson,
    structuredJson: structuredJson ?? this.structuredJson,
    tagsJson: tagsJson ?? this.tagsJson,
    sourceLabel: sourceLabel ?? this.sourceLabel,
    revision: revision ?? this.revision,
  );
  LocalContentEntryRow copyWithCompanion(LocalContentEntriesCompanion data) {
    return LocalContentEntryRow(
      entryKey: data.entryKey.present ? data.entryKey.value : this.entryKey,
      packageId: data.packageId.present ? data.packageId.value : this.packageId,
      type: data.type.present ? data.type.value : this.type,
      slug: data.slug.present ? data.slug.value : this.slug,
      name: data.name.present ? data.name.value : this.name,
      aliasesJson: data.aliasesJson.present
          ? data.aliasesJson.value
          : this.aliasesJson,
      summary: data.summary.present ? data.summary.value : this.summary,
      bodyJson: data.bodyJson.present ? data.bodyJson.value : this.bodyJson,
      structuredJson: data.structuredJson.present
          ? data.structuredJson.value
          : this.structuredJson,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      sourceLabel: data.sourceLabel.present
          ? data.sourceLabel.value
          : this.sourceLabel,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalContentEntryRow(')
          ..write('entryKey: $entryKey, ')
          ..write('packageId: $packageId, ')
          ..write('type: $type, ')
          ..write('slug: $slug, ')
          ..write('name: $name, ')
          ..write('aliasesJson: $aliasesJson, ')
          ..write('summary: $summary, ')
          ..write('bodyJson: $bodyJson, ')
          ..write('structuredJson: $structuredJson, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('sourceLabel: $sourceLabel, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    entryKey,
    packageId,
    type,
    slug,
    name,
    aliasesJson,
    summary,
    bodyJson,
    structuredJson,
    tagsJson,
    sourceLabel,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalContentEntryRow &&
          other.entryKey == this.entryKey &&
          other.packageId == this.packageId &&
          other.type == this.type &&
          other.slug == this.slug &&
          other.name == this.name &&
          other.aliasesJson == this.aliasesJson &&
          other.summary == this.summary &&
          other.bodyJson == this.bodyJson &&
          other.structuredJson == this.structuredJson &&
          other.tagsJson == this.tagsJson &&
          other.sourceLabel == this.sourceLabel &&
          other.revision == this.revision);
}

class LocalContentEntriesCompanion
    extends UpdateCompanion<LocalContentEntryRow> {
  final Value<String> entryKey;
  final Value<String> packageId;
  final Value<String> type;
  final Value<String> slug;
  final Value<String> name;
  final Value<String> aliasesJson;
  final Value<String> summary;
  final Value<String> bodyJson;
  final Value<String> structuredJson;
  final Value<String> tagsJson;
  final Value<String> sourceLabel;
  final Value<int> revision;
  final Value<int> rowid;
  const LocalContentEntriesCompanion({
    this.entryKey = const Value.absent(),
    this.packageId = const Value.absent(),
    this.type = const Value.absent(),
    this.slug = const Value.absent(),
    this.name = const Value.absent(),
    this.aliasesJson = const Value.absent(),
    this.summary = const Value.absent(),
    this.bodyJson = const Value.absent(),
    this.structuredJson = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.sourceLabel = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalContentEntriesCompanion.insert({
    required String entryKey,
    required String packageId,
    required String type,
    required String slug,
    required String name,
    this.aliasesJson = const Value.absent(),
    this.summary = const Value.absent(),
    this.bodyJson = const Value.absent(),
    this.structuredJson = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.sourceLabel = const Value.absent(),
    required int revision,
    this.rowid = const Value.absent(),
  }) : entryKey = Value(entryKey),
       packageId = Value(packageId),
       type = Value(type),
       slug = Value(slug),
       name = Value(name),
       revision = Value(revision);
  static Insertable<LocalContentEntryRow> custom({
    Expression<String>? entryKey,
    Expression<String>? packageId,
    Expression<String>? type,
    Expression<String>? slug,
    Expression<String>? name,
    Expression<String>? aliasesJson,
    Expression<String>? summary,
    Expression<String>? bodyJson,
    Expression<String>? structuredJson,
    Expression<String>? tagsJson,
    Expression<String>? sourceLabel,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryKey != null) 'entry_key': entryKey,
      if (packageId != null) 'package_id': packageId,
      if (type != null) 'type': type,
      if (slug != null) 'slug': slug,
      if (name != null) 'name': name,
      if (aliasesJson != null) 'aliases_json': aliasesJson,
      if (summary != null) 'summary': summary,
      if (bodyJson != null) 'body_json': bodyJson,
      if (structuredJson != null) 'structured_json': structuredJson,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (sourceLabel != null) 'source_label': sourceLabel,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalContentEntriesCompanion copyWith({
    Value<String>? entryKey,
    Value<String>? packageId,
    Value<String>? type,
    Value<String>? slug,
    Value<String>? name,
    Value<String>? aliasesJson,
    Value<String>? summary,
    Value<String>? bodyJson,
    Value<String>? structuredJson,
    Value<String>? tagsJson,
    Value<String>? sourceLabel,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return LocalContentEntriesCompanion(
      entryKey: entryKey ?? this.entryKey,
      packageId: packageId ?? this.packageId,
      type: type ?? this.type,
      slug: slug ?? this.slug,
      name: name ?? this.name,
      aliasesJson: aliasesJson ?? this.aliasesJson,
      summary: summary ?? this.summary,
      bodyJson: bodyJson ?? this.bodyJson,
      structuredJson: structuredJson ?? this.structuredJson,
      tagsJson: tagsJson ?? this.tagsJson,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryKey.present) {
      map['entry_key'] = Variable<String>(entryKey.value);
    }
    if (packageId.present) {
      map['package_id'] = Variable<String>(packageId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (slug.present) {
      map['slug'] = Variable<String>(slug.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (aliasesJson.present) {
      map['aliases_json'] = Variable<String>(aliasesJson.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (bodyJson.present) {
      map['body_json'] = Variable<String>(bodyJson.value);
    }
    if (structuredJson.present) {
      map['structured_json'] = Variable<String>(structuredJson.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (sourceLabel.present) {
      map['source_label'] = Variable<String>(sourceLabel.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalContentEntriesCompanion(')
          ..write('entryKey: $entryKey, ')
          ..write('packageId: $packageId, ')
          ..write('type: $type, ')
          ..write('slug: $slug, ')
          ..write('name: $name, ')
          ..write('aliasesJson: $aliasesJson, ')
          ..write('summary: $summary, ')
          ..write('bodyJson: $bodyJson, ')
          ..write('structuredJson: $structuredJson, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('sourceLabel: $sourceLabel, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalContentAssetsTable extends LocalContentAssets
    with TableInfo<$LocalContentAssetsTable, LocalContentAssetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalContentAssetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _packageIdMeta = const VerificationMeta(
    'packageId',
  );
  @override
  late final GeneratedColumn<String> packageId = GeneratedColumn<String>(
    'package_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<Uint8List> bytes = GeneratedColumn<Uint8List>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaTypeMeta = const VerificationMeta(
    'mediaType',
  );
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
    'media_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    packageId,
    relativePath,
    bytes,
    mediaType,
    contentHash,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_content_assets';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalContentAssetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('package_id')) {
      context.handle(
        _packageIdMeta,
        packageId.isAcceptableOrUnknown(data['package_id']!, _packageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_packageIdMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('media_type')) {
      context.handle(
        _mediaTypeMeta,
        mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta),
      );
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {packageId, relativePath};
  @override
  LocalContentAssetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalContentAssetRow(
      packageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_id'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}bytes'],
      )!,
      mediaType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_type'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
    );
  }

  @override
  $LocalContentAssetsTable createAlias(String alias) {
    return $LocalContentAssetsTable(attachedDatabase, alias);
  }
}

class LocalContentAssetRow extends DataClass
    implements Insertable<LocalContentAssetRow> {
  final String packageId;
  final String relativePath;
  final Uint8List bytes;
  final String mediaType;
  final String contentHash;
  const LocalContentAssetRow({
    required this.packageId,
    required this.relativePath,
    required this.bytes,
    required this.mediaType,
    required this.contentHash,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['package_id'] = Variable<String>(packageId);
    map['relative_path'] = Variable<String>(relativePath);
    map['bytes'] = Variable<Uint8List>(bytes);
    map['media_type'] = Variable<String>(mediaType);
    map['content_hash'] = Variable<String>(contentHash);
    return map;
  }

  LocalContentAssetsCompanion toCompanion(bool nullToAbsent) {
    return LocalContentAssetsCompanion(
      packageId: Value(packageId),
      relativePath: Value(relativePath),
      bytes: Value(bytes),
      mediaType: Value(mediaType),
      contentHash: Value(contentHash),
    );
  }

  factory LocalContentAssetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalContentAssetRow(
      packageId: serializer.fromJson<String>(json['packageId']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      bytes: serializer.fromJson<Uint8List>(json['bytes']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'packageId': serializer.toJson<String>(packageId),
      'relativePath': serializer.toJson<String>(relativePath),
      'bytes': serializer.toJson<Uint8List>(bytes),
      'mediaType': serializer.toJson<String>(mediaType),
      'contentHash': serializer.toJson<String>(contentHash),
    };
  }

  LocalContentAssetRow copyWith({
    String? packageId,
    String? relativePath,
    Uint8List? bytes,
    String? mediaType,
    String? contentHash,
  }) => LocalContentAssetRow(
    packageId: packageId ?? this.packageId,
    relativePath: relativePath ?? this.relativePath,
    bytes: bytes ?? this.bytes,
    mediaType: mediaType ?? this.mediaType,
    contentHash: contentHash ?? this.contentHash,
  );
  LocalContentAssetRow copyWithCompanion(LocalContentAssetsCompanion data) {
    return LocalContentAssetRow(
      packageId: data.packageId.present ? data.packageId.value : this.packageId,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalContentAssetRow(')
          ..write('packageId: $packageId, ')
          ..write('relativePath: $relativePath, ')
          ..write('bytes: $bytes, ')
          ..write('mediaType: $mediaType, ')
          ..write('contentHash: $contentHash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    packageId,
    relativePath,
    $driftBlobEquality.hash(bytes),
    mediaType,
    contentHash,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalContentAssetRow &&
          other.packageId == this.packageId &&
          other.relativePath == this.relativePath &&
          $driftBlobEquality.equals(other.bytes, this.bytes) &&
          other.mediaType == this.mediaType &&
          other.contentHash == this.contentHash);
}

class LocalContentAssetsCompanion
    extends UpdateCompanion<LocalContentAssetRow> {
  final Value<String> packageId;
  final Value<String> relativePath;
  final Value<Uint8List> bytes;
  final Value<String> mediaType;
  final Value<String> contentHash;
  final Value<int> rowid;
  const LocalContentAssetsCompanion({
    this.packageId = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.bytes = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalContentAssetsCompanion.insert({
    required String packageId,
    required String relativePath,
    required Uint8List bytes,
    this.mediaType = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : packageId = Value(packageId),
       relativePath = Value(relativePath),
       bytes = Value(bytes);
  static Insertable<LocalContentAssetRow> custom({
    Expression<String>? packageId,
    Expression<String>? relativePath,
    Expression<Uint8List>? bytes,
    Expression<String>? mediaType,
    Expression<String>? contentHash,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (packageId != null) 'package_id': packageId,
      if (relativePath != null) 'relative_path': relativePath,
      if (bytes != null) 'bytes': bytes,
      if (mediaType != null) 'media_type': mediaType,
      if (contentHash != null) 'content_hash': contentHash,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalContentAssetsCompanion copyWith({
    Value<String>? packageId,
    Value<String>? relativePath,
    Value<Uint8List>? bytes,
    Value<String>? mediaType,
    Value<String>? contentHash,
    Value<int>? rowid,
  }) {
    return LocalContentAssetsCompanion(
      packageId: packageId ?? this.packageId,
      relativePath: relativePath ?? this.relativePath,
      bytes: bytes ?? this.bytes,
      mediaType: mediaType ?? this.mediaType,
      contentHash: contentHash ?? this.contentHash,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (packageId.present) {
      map['package_id'] = Variable<String>(packageId.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<Uint8List>(bytes.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalContentAssetsCompanion(')
          ..write('packageId: $packageId, ')
          ..write('relativePath: $relativePath, ')
          ..write('bytes: $bytes, ')
          ..write('mediaType: $mediaType, ')
          ..write('contentHash: $contentHash, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContentLinksTable extends ContentLinks
    with TableInfo<$ContentLinksTable, ContentLinkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentLinksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _linkTextMeta = const VerificationMeta(
    'linkText',
  );
  @override
  late final GeneratedColumn<String> linkText = GeneratedColumn<String>(
    'link_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [id, sourceId, targetId, linkText];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContentLinkRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    if (data.containsKey('link_text')) {
      context.handle(
        _linkTextMeta,
        linkText.isAcceptableOrUnknown(data['link_text']!, _linkTextMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ContentLinkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentLinkRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      )!,
      linkText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}link_text'],
      )!,
    );
  }

  @override
  $ContentLinksTable createAlias(String alias) {
    return $ContentLinksTable(attachedDatabase, alias);
  }
}

class ContentLinkRow extends DataClass implements Insertable<ContentLinkRow> {
  final String id;
  final String sourceId;
  final String targetId;
  final String linkText;
  const ContentLinkRow({
    required this.id,
    required this.sourceId,
    required this.targetId,
    required this.linkText,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_id'] = Variable<String>(sourceId);
    map['target_id'] = Variable<String>(targetId);
    map['link_text'] = Variable<String>(linkText);
    return map;
  }

  ContentLinksCompanion toCompanion(bool nullToAbsent) {
    return ContentLinksCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      targetId: Value(targetId),
      linkText: Value(linkText),
    );
  }

  factory ContentLinkRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentLinkRow(
      id: serializer.fromJson<String>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      targetId: serializer.fromJson<String>(json['targetId']),
      linkText: serializer.fromJson<String>(json['linkText']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'targetId': serializer.toJson<String>(targetId),
      'linkText': serializer.toJson<String>(linkText),
    };
  }

  ContentLinkRow copyWith({
    String? id,
    String? sourceId,
    String? targetId,
    String? linkText,
  }) => ContentLinkRow(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    targetId: targetId ?? this.targetId,
    linkText: linkText ?? this.linkText,
  );
  ContentLinkRow copyWithCompanion(ContentLinksCompanion data) {
    return ContentLinkRow(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      linkText: data.linkText.present ? data.linkText.value : this.linkText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentLinkRow(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('targetId: $targetId, ')
          ..write('linkText: $linkText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sourceId, targetId, linkText);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentLinkRow &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.targetId == this.targetId &&
          other.linkText == this.linkText);
}

class ContentLinksCompanion extends UpdateCompanion<ContentLinkRow> {
  final Value<String> id;
  final Value<String> sourceId;
  final Value<String> targetId;
  final Value<String> linkText;
  final Value<int> rowid;
  const ContentLinksCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.targetId = const Value.absent(),
    this.linkText = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentLinksCompanion.insert({
    required String id,
    required String sourceId,
    required String targetId,
    this.linkText = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceId = Value(sourceId),
       targetId = Value(targetId);
  static Insertable<ContentLinkRow> custom({
    Expression<String>? id,
    Expression<String>? sourceId,
    Expression<String>? targetId,
    Expression<String>? linkText,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (targetId != null) 'target_id': targetId,
      if (linkText != null) 'link_text': linkText,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentLinksCompanion copyWith({
    Value<String>? id,
    Value<String>? sourceId,
    Value<String>? targetId,
    Value<String>? linkText,
    Value<int>? rowid,
  }) {
    return ContentLinksCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      targetId: targetId ?? this.targetId,
      linkText: linkText ?? this.linkText,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (linkText.present) {
      map['link_text'] = Variable<String>(linkText.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentLinksCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('targetId: $targetId, ')
          ..write('linkText: $linkText, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContentFavoritesTable extends ContentFavorites
    with TableInfo<$ContentFavoritesTable, ContentFavoriteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentFavoritesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entryKeyMeta = const VerificationMeta(
    'entryKey',
  );
  @override
  late final GeneratedColumn<String> entryKey = GeneratedColumn<String>(
    'entry_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [entryKey, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_favorites';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContentFavoriteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entry_key')) {
      context.handle(
        _entryKeyMeta,
        entryKey.isAcceptableOrUnknown(data['entry_key']!, _entryKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_entryKeyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryKey};
  @override
  ContentFavoriteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentFavoriteRow(
      entryKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_key'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ContentFavoritesTable createAlias(String alias) {
    return $ContentFavoritesTable(attachedDatabase, alias);
  }
}

class ContentFavoriteRow extends DataClass
    implements Insertable<ContentFavoriteRow> {
  final String entryKey;
  final DateTime createdAt;
  const ContentFavoriteRow({required this.entryKey, required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_key'] = Variable<String>(entryKey);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ContentFavoritesCompanion toCompanion(bool nullToAbsent) {
    return ContentFavoritesCompanion(
      entryKey: Value(entryKey),
      createdAt: Value(createdAt),
    );
  }

  factory ContentFavoriteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentFavoriteRow(
      entryKey: serializer.fromJson<String>(json['entryKey']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entryKey': serializer.toJson<String>(entryKey),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ContentFavoriteRow copyWith({String? entryKey, DateTime? createdAt}) =>
      ContentFavoriteRow(
        entryKey: entryKey ?? this.entryKey,
        createdAt: createdAt ?? this.createdAt,
      );
  ContentFavoriteRow copyWithCompanion(ContentFavoritesCompanion data) {
    return ContentFavoriteRow(
      entryKey: data.entryKey.present ? data.entryKey.value : this.entryKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentFavoriteRow(')
          ..write('entryKey: $entryKey, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entryKey, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentFavoriteRow &&
          other.entryKey == this.entryKey &&
          other.createdAt == this.createdAt);
}

class ContentFavoritesCompanion extends UpdateCompanion<ContentFavoriteRow> {
  final Value<String> entryKey;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ContentFavoritesCompanion({
    this.entryKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentFavoritesCompanion.insert({
    required String entryKey,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : entryKey = Value(entryKey),
       createdAt = Value(createdAt);
  static Insertable<ContentFavoriteRow> custom({
    Expression<String>? entryKey,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryKey != null) 'entry_key': entryKey,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentFavoritesCompanion copyWith({
    Value<String>? entryKey,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ContentFavoritesCompanion(
      entryKey: entryKey ?? this.entryKey,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryKey.present) {
      map['entry_key'] = Variable<String>(entryKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentFavoritesCompanion(')
          ..write('entryKey: $entryKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContentNotesTable extends ContentNotes
    with TableInfo<$ContentNotesTable, ContentNoteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entryKeyMeta = const VerificationMeta(
    'entryKey',
  );
  @override
  late final GeneratedColumn<String> entryKey = GeneratedColumn<String>(
    'entry_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _markdownMeta = const VerificationMeta(
    'markdown',
  );
  @override
  late final GeneratedColumn<String> markdown = GeneratedColumn<String>(
    'markdown',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [entryKey, markdown, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContentNoteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entry_key')) {
      context.handle(
        _entryKeyMeta,
        entryKey.isAcceptableOrUnknown(data['entry_key']!, _entryKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_entryKeyMeta);
    }
    if (data.containsKey('markdown')) {
      context.handle(
        _markdownMeta,
        markdown.isAcceptableOrUnknown(data['markdown']!, _markdownMeta),
      );
    } else if (isInserting) {
      context.missing(_markdownMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryKey};
  @override
  ContentNoteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentNoteRow(
      entryKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_key'],
      )!,
      markdown: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}markdown'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ContentNotesTable createAlias(String alias) {
    return $ContentNotesTable(attachedDatabase, alias);
  }
}

class ContentNoteRow extends DataClass implements Insertable<ContentNoteRow> {
  final String entryKey;
  final String markdown;
  final DateTime updatedAt;
  const ContentNoteRow({
    required this.entryKey,
    required this.markdown,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_key'] = Variable<String>(entryKey);
    map['markdown'] = Variable<String>(markdown);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ContentNotesCompanion toCompanion(bool nullToAbsent) {
    return ContentNotesCompanion(
      entryKey: Value(entryKey),
      markdown: Value(markdown),
      updatedAt: Value(updatedAt),
    );
  }

  factory ContentNoteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentNoteRow(
      entryKey: serializer.fromJson<String>(json['entryKey']),
      markdown: serializer.fromJson<String>(json['markdown']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entryKey': serializer.toJson<String>(entryKey),
      'markdown': serializer.toJson<String>(markdown),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ContentNoteRow copyWith({
    String? entryKey,
    String? markdown,
    DateTime? updatedAt,
  }) => ContentNoteRow(
    entryKey: entryKey ?? this.entryKey,
    markdown: markdown ?? this.markdown,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ContentNoteRow copyWithCompanion(ContentNotesCompanion data) {
    return ContentNoteRow(
      entryKey: data.entryKey.present ? data.entryKey.value : this.entryKey,
      markdown: data.markdown.present ? data.markdown.value : this.markdown,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentNoteRow(')
          ..write('entryKey: $entryKey, ')
          ..write('markdown: $markdown, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entryKey, markdown, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentNoteRow &&
          other.entryKey == this.entryKey &&
          other.markdown == this.markdown &&
          other.updatedAt == this.updatedAt);
}

class ContentNotesCompanion extends UpdateCompanion<ContentNoteRow> {
  final Value<String> entryKey;
  final Value<String> markdown;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ContentNotesCompanion({
    this.entryKey = const Value.absent(),
    this.markdown = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentNotesCompanion.insert({
    required String entryKey,
    required String markdown,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : entryKey = Value(entryKey),
       markdown = Value(markdown),
       updatedAt = Value(updatedAt);
  static Insertable<ContentNoteRow> custom({
    Expression<String>? entryKey,
    Expression<String>? markdown,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryKey != null) 'entry_key': entryKey,
      if (markdown != null) 'markdown': markdown,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentNotesCompanion copyWith({
    Value<String>? entryKey,
    Value<String>? markdown,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ContentNotesCompanion(
      entryKey: entryKey ?? this.entryKey,
      markdown: markdown ?? this.markdown,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryKey.present) {
      map['entry_key'] = Variable<String>(entryKey.value);
    }
    if (markdown.present) {
      map['markdown'] = Variable<String>(markdown.value);
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
    return (StringBuffer('ContentNotesCompanion(')
          ..write('entryKey: $entryKey, ')
          ..write('markdown: $markdown, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContentReadHistoryTable extends ContentReadHistory
    with TableInfo<$ContentReadHistoryTable, ContentReadHistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentReadHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entryKeyMeta = const VerificationMeta(
    'entryKey',
  );
  @override
  late final GeneratedColumn<String> entryKey = GeneratedColumn<String>(
    'entry_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readAtMeta = const VerificationMeta('readAt');
  @override
  late final GeneratedColumn<DateTime> readAt = GeneratedColumn<DateTime>(
    'read_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [entryKey, readAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_read_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContentReadHistoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entry_key')) {
      context.handle(
        _entryKeyMeta,
        entryKey.isAcceptableOrUnknown(data['entry_key']!, _entryKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_entryKeyMeta);
    }
    if (data.containsKey('read_at')) {
      context.handle(
        _readAtMeta,
        readAt.isAcceptableOrUnknown(data['read_at']!, _readAtMeta),
      );
    } else if (isInserting) {
      context.missing(_readAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryKey};
  @override
  ContentReadHistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentReadHistoryRow(
      entryKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_key'],
      )!,
      readAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}read_at'],
      )!,
    );
  }

  @override
  $ContentReadHistoryTable createAlias(String alias) {
    return $ContentReadHistoryTable(attachedDatabase, alias);
  }
}

class ContentReadHistoryRow extends DataClass
    implements Insertable<ContentReadHistoryRow> {
  final String entryKey;
  final DateTime readAt;
  const ContentReadHistoryRow({required this.entryKey, required this.readAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_key'] = Variable<String>(entryKey);
    map['read_at'] = Variable<DateTime>(readAt);
    return map;
  }

  ContentReadHistoryCompanion toCompanion(bool nullToAbsent) {
    return ContentReadHistoryCompanion(
      entryKey: Value(entryKey),
      readAt: Value(readAt),
    );
  }

  factory ContentReadHistoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentReadHistoryRow(
      entryKey: serializer.fromJson<String>(json['entryKey']),
      readAt: serializer.fromJson<DateTime>(json['readAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entryKey': serializer.toJson<String>(entryKey),
      'readAt': serializer.toJson<DateTime>(readAt),
    };
  }

  ContentReadHistoryRow copyWith({String? entryKey, DateTime? readAt}) =>
      ContentReadHistoryRow(
        entryKey: entryKey ?? this.entryKey,
        readAt: readAt ?? this.readAt,
      );
  ContentReadHistoryRow copyWithCompanion(ContentReadHistoryCompanion data) {
    return ContentReadHistoryRow(
      entryKey: data.entryKey.present ? data.entryKey.value : this.entryKey,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentReadHistoryRow(')
          ..write('entryKey: $entryKey, ')
          ..write('readAt: $readAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entryKey, readAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentReadHistoryRow &&
          other.entryKey == this.entryKey &&
          other.readAt == this.readAt);
}

class ContentReadHistoryCompanion
    extends UpdateCompanion<ContentReadHistoryRow> {
  final Value<String> entryKey;
  final Value<DateTime> readAt;
  final Value<int> rowid;
  const ContentReadHistoryCompanion({
    this.entryKey = const Value.absent(),
    this.readAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentReadHistoryCompanion.insert({
    required String entryKey,
    required DateTime readAt,
    this.rowid = const Value.absent(),
  }) : entryKey = Value(entryKey),
       readAt = Value(readAt);
  static Insertable<ContentReadHistoryRow> custom({
    Expression<String>? entryKey,
    Expression<DateTime>? readAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryKey != null) 'entry_key': entryKey,
      if (readAt != null) 'read_at': readAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentReadHistoryCompanion copyWith({
    Value<String>? entryKey,
    Value<DateTime>? readAt,
    Value<int>? rowid,
  }) {
    return ContentReadHistoryCompanion(
      entryKey: entryKey ?? this.entryKey,
      readAt: readAt ?? this.readAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryKey.present) {
      map['entry_key'] = Variable<String>(entryKey.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<DateTime>(readAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentReadHistoryCompanion(')
          ..write('entryKey: $entryKey, ')
          ..write('readAt: $readAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CharactersTable extends Characters
    with TableInfo<$CharactersTable, CharacterRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CharactersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerLocalIdMeta = const VerificationMeta(
    'ownerLocalId',
  );
  @override
  late final GeneratedColumn<String> ownerLocalId = GeneratedColumn<String>(
    'owner_local_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  static const VerificationMeta _sheetJsonMeta = const VerificationMeta(
    'sheetJson',
  );
  @override
  late final GeneratedColumn<String> sheetJson = GeneratedColumn<String>(
    'sheet_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _syncRevisionMeta = const VerificationMeta(
    'syncRevision',
  );
  @override
  late final GeneratedColumn<int> syncRevision = GeneratedColumn<int>(
    'sync_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerLocalId,
    sheetJson,
    revision,
    syncRevision,
    archivedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'characters';
  @override
  VerificationContext validateIntegrity(
    Insertable<CharacterRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_local_id')) {
      context.handle(
        _ownerLocalIdMeta,
        ownerLocalId.isAcceptableOrUnknown(
          data['owner_local_id']!,
          _ownerLocalIdMeta,
        ),
      );
    }
    if (data.containsKey('sheet_json')) {
      context.handle(
        _sheetJsonMeta,
        sheetJson.isAcceptableOrUnknown(data['sheet_json']!, _sheetJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_sheetJsonMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('sync_revision')) {
      context.handle(
        _syncRevisionMeta,
        syncRevision.isAcceptableOrUnknown(
          data['sync_revision']!,
          _syncRevisionMeta,
        ),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CharacterRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CharacterRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerLocalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_local_id'],
      )!,
      sheetJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sheet_json'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      syncRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_revision'],
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CharactersTable createAlias(String alias) {
    return $CharactersTable(attachedDatabase, alias);
  }
}

class CharacterRow extends DataClass implements Insertable<CharacterRow> {
  final String id;
  final String ownerLocalId;
  final String sheetJson;
  final int revision;
  final int? syncRevision;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const CharacterRow({
    required this.id,
    required this.ownerLocalId,
    required this.sheetJson,
    required this.revision,
    this.syncRevision,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_local_id'] = Variable<String>(ownerLocalId);
    map['sheet_json'] = Variable<String>(sheetJson);
    map['revision'] = Variable<int>(revision);
    if (!nullToAbsent || syncRevision != null) {
      map['sync_revision'] = Variable<int>(syncRevision);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CharactersCompanion toCompanion(bool nullToAbsent) {
    return CharactersCompanion(
      id: Value(id),
      ownerLocalId: Value(ownerLocalId),
      sheetJson: Value(sheetJson),
      revision: Value(revision),
      syncRevision: syncRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(syncRevision),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CharacterRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CharacterRow(
      id: serializer.fromJson<String>(json['id']),
      ownerLocalId: serializer.fromJson<String>(json['ownerLocalId']),
      sheetJson: serializer.fromJson<String>(json['sheetJson']),
      revision: serializer.fromJson<int>(json['revision']),
      syncRevision: serializer.fromJson<int?>(json['syncRevision']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerLocalId': serializer.toJson<String>(ownerLocalId),
      'sheetJson': serializer.toJson<String>(sheetJson),
      'revision': serializer.toJson<int>(revision),
      'syncRevision': serializer.toJson<int?>(syncRevision),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CharacterRow copyWith({
    String? id,
    String? ownerLocalId,
    String? sheetJson,
    int? revision,
    Value<int?> syncRevision = const Value.absent(),
    Value<DateTime?> archivedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CharacterRow(
    id: id ?? this.id,
    ownerLocalId: ownerLocalId ?? this.ownerLocalId,
    sheetJson: sheetJson ?? this.sheetJson,
    revision: revision ?? this.revision,
    syncRevision: syncRevision.present ? syncRevision.value : this.syncRevision,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CharacterRow copyWithCompanion(CharactersCompanion data) {
    return CharacterRow(
      id: data.id.present ? data.id.value : this.id,
      ownerLocalId: data.ownerLocalId.present
          ? data.ownerLocalId.value
          : this.ownerLocalId,
      sheetJson: data.sheetJson.present ? data.sheetJson.value : this.sheetJson,
      revision: data.revision.present ? data.revision.value : this.revision,
      syncRevision: data.syncRevision.present
          ? data.syncRevision.value
          : this.syncRevision,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CharacterRow(')
          ..write('id: $id, ')
          ..write('ownerLocalId: $ownerLocalId, ')
          ..write('sheetJson: $sheetJson, ')
          ..write('revision: $revision, ')
          ..write('syncRevision: $syncRevision, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerLocalId,
    sheetJson,
    revision,
    syncRevision,
    archivedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CharacterRow &&
          other.id == this.id &&
          other.ownerLocalId == this.ownerLocalId &&
          other.sheetJson == this.sheetJson &&
          other.revision == this.revision &&
          other.syncRevision == this.syncRevision &&
          other.archivedAt == this.archivedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CharactersCompanion extends UpdateCompanion<CharacterRow> {
  final Value<String> id;
  final Value<String> ownerLocalId;
  final Value<String> sheetJson;
  final Value<int> revision;
  final Value<int?> syncRevision;
  final Value<DateTime?> archivedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CharactersCompanion({
    this.id = const Value.absent(),
    this.ownerLocalId = const Value.absent(),
    this.sheetJson = const Value.absent(),
    this.revision = const Value.absent(),
    this.syncRevision = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CharactersCompanion.insert({
    required String id,
    this.ownerLocalId = const Value.absent(),
    required String sheetJson,
    this.revision = const Value.absent(),
    this.syncRevision = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sheetJson = Value(sheetJson);
  static Insertable<CharacterRow> custom({
    Expression<String>? id,
    Expression<String>? ownerLocalId,
    Expression<String>? sheetJson,
    Expression<int>? revision,
    Expression<int>? syncRevision,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerLocalId != null) 'owner_local_id': ownerLocalId,
      if (sheetJson != null) 'sheet_json': sheetJson,
      if (revision != null) 'revision': revision,
      if (syncRevision != null) 'sync_revision': syncRevision,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CharactersCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerLocalId,
    Value<String>? sheetJson,
    Value<int>? revision,
    Value<int?>? syncRevision,
    Value<DateTime?>? archivedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CharactersCompanion(
      id: id ?? this.id,
      ownerLocalId: ownerLocalId ?? this.ownerLocalId,
      sheetJson: sheetJson ?? this.sheetJson,
      revision: revision ?? this.revision,
      syncRevision: syncRevision ?? this.syncRevision,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerLocalId.present) {
      map['owner_local_id'] = Variable<String>(ownerLocalId.value);
    }
    if (sheetJson.present) {
      map['sheet_json'] = Variable<String>(sheetJson.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (syncRevision.present) {
      map['sync_revision'] = Variable<int>(syncRevision.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('CharactersCompanion(')
          ..write('id: $id, ')
          ..write('ownerLocalId: $ownerLocalId, ')
          ..write('sheetJson: $sheetJson, ')
          ..write('revision: $revision, ')
          ..write('syncRevision: $syncRevision, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CharacterContentRefsTable extends CharacterContentRefs
    with TableInfo<$CharacterContentRefsTable, CharacterContentRefRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CharacterContentRefsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _characterIdMeta = const VerificationMeta(
    'characterId',
  );
  @override
  late final GeneratedColumn<String> characterId = GeneratedColumn<String>(
    'character_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<String> slot = GeneratedColumn<String>(
    'slot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryKeyMeta = const VerificationMeta(
    'entryKey',
  );
  @override
  late final GeneratedColumn<String> entryKey = GeneratedColumn<String>(
    'entry_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceRevisionMeta = const VerificationMeta(
    'sourceRevision',
  );
  @override
  late final GeneratedColumn<int> sourceRevision = GeneratedColumn<int>(
    'source_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _snapshotJsonMeta = const VerificationMeta(
    'snapshotJson',
  );
  @override
  late final GeneratedColumn<String> snapshotJson = GeneratedColumn<String>(
    'snapshot_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    characterId,
    slot,
    entryKey,
    sourceRevision,
    snapshotJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'character_content_refs';
  @override
  VerificationContext validateIntegrity(
    Insertable<CharacterContentRefRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('character_id')) {
      context.handle(
        _characterIdMeta,
        characterId.isAcceptableOrUnknown(
          data['character_id']!,
          _characterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_characterIdMeta);
    }
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    } else if (isInserting) {
      context.missing(_slotMeta);
    }
    if (data.containsKey('entry_key')) {
      context.handle(
        _entryKeyMeta,
        entryKey.isAcceptableOrUnknown(data['entry_key']!, _entryKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_entryKeyMeta);
    }
    if (data.containsKey('source_revision')) {
      context.handle(
        _sourceRevisionMeta,
        sourceRevision.isAcceptableOrUnknown(
          data['source_revision']!,
          _sourceRevisionMeta,
        ),
      );
    }
    if (data.containsKey('snapshot_json')) {
      context.handle(
        _snapshotJsonMeta,
        snapshotJson.isAcceptableOrUnknown(
          data['snapshot_json']!,
          _snapshotJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {characterId, slot};
  @override
  CharacterContentRefRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CharacterContentRefRow(
      characterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}character_id'],
      )!,
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slot'],
      )!,
      entryKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_key'],
      )!,
      sourceRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_revision'],
      )!,
      snapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_json'],
      )!,
    );
  }

  @override
  $CharacterContentRefsTable createAlias(String alias) {
    return $CharacterContentRefsTable(attachedDatabase, alias);
  }
}

class CharacterContentRefRow extends DataClass
    implements Insertable<CharacterContentRefRow> {
  final String characterId;
  final String slot;
  final String entryKey;
  final int sourceRevision;
  final String snapshotJson;
  const CharacterContentRefRow({
    required this.characterId,
    required this.slot,
    required this.entryKey,
    required this.sourceRevision,
    required this.snapshotJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['character_id'] = Variable<String>(characterId);
    map['slot'] = Variable<String>(slot);
    map['entry_key'] = Variable<String>(entryKey);
    map['source_revision'] = Variable<int>(sourceRevision);
    map['snapshot_json'] = Variable<String>(snapshotJson);
    return map;
  }

  CharacterContentRefsCompanion toCompanion(bool nullToAbsent) {
    return CharacterContentRefsCompanion(
      characterId: Value(characterId),
      slot: Value(slot),
      entryKey: Value(entryKey),
      sourceRevision: Value(sourceRevision),
      snapshotJson: Value(snapshotJson),
    );
  }

  factory CharacterContentRefRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CharacterContentRefRow(
      characterId: serializer.fromJson<String>(json['characterId']),
      slot: serializer.fromJson<String>(json['slot']),
      entryKey: serializer.fromJson<String>(json['entryKey']),
      sourceRevision: serializer.fromJson<int>(json['sourceRevision']),
      snapshotJson: serializer.fromJson<String>(json['snapshotJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'characterId': serializer.toJson<String>(characterId),
      'slot': serializer.toJson<String>(slot),
      'entryKey': serializer.toJson<String>(entryKey),
      'sourceRevision': serializer.toJson<int>(sourceRevision),
      'snapshotJson': serializer.toJson<String>(snapshotJson),
    };
  }

  CharacterContentRefRow copyWith({
    String? characterId,
    String? slot,
    String? entryKey,
    int? sourceRevision,
    String? snapshotJson,
  }) => CharacterContentRefRow(
    characterId: characterId ?? this.characterId,
    slot: slot ?? this.slot,
    entryKey: entryKey ?? this.entryKey,
    sourceRevision: sourceRevision ?? this.sourceRevision,
    snapshotJson: snapshotJson ?? this.snapshotJson,
  );
  CharacterContentRefRow copyWithCompanion(CharacterContentRefsCompanion data) {
    return CharacterContentRefRow(
      characterId: data.characterId.present
          ? data.characterId.value
          : this.characterId,
      slot: data.slot.present ? data.slot.value : this.slot,
      entryKey: data.entryKey.present ? data.entryKey.value : this.entryKey,
      sourceRevision: data.sourceRevision.present
          ? data.sourceRevision.value
          : this.sourceRevision,
      snapshotJson: data.snapshotJson.present
          ? data.snapshotJson.value
          : this.snapshotJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CharacterContentRefRow(')
          ..write('characterId: $characterId, ')
          ..write('slot: $slot, ')
          ..write('entryKey: $entryKey, ')
          ..write('sourceRevision: $sourceRevision, ')
          ..write('snapshotJson: $snapshotJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(characterId, slot, entryKey, sourceRevision, snapshotJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CharacterContentRefRow &&
          other.characterId == this.characterId &&
          other.slot == this.slot &&
          other.entryKey == this.entryKey &&
          other.sourceRevision == this.sourceRevision &&
          other.snapshotJson == this.snapshotJson);
}

class CharacterContentRefsCompanion
    extends UpdateCompanion<CharacterContentRefRow> {
  final Value<String> characterId;
  final Value<String> slot;
  final Value<String> entryKey;
  final Value<int> sourceRevision;
  final Value<String> snapshotJson;
  final Value<int> rowid;
  const CharacterContentRefsCompanion({
    this.characterId = const Value.absent(),
    this.slot = const Value.absent(),
    this.entryKey = const Value.absent(),
    this.sourceRevision = const Value.absent(),
    this.snapshotJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CharacterContentRefsCompanion.insert({
    required String characterId,
    required String slot,
    required String entryKey,
    this.sourceRevision = const Value.absent(),
    this.snapshotJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : characterId = Value(characterId),
       slot = Value(slot),
       entryKey = Value(entryKey);
  static Insertable<CharacterContentRefRow> custom({
    Expression<String>? characterId,
    Expression<String>? slot,
    Expression<String>? entryKey,
    Expression<int>? sourceRevision,
    Expression<String>? snapshotJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (characterId != null) 'character_id': characterId,
      if (slot != null) 'slot': slot,
      if (entryKey != null) 'entry_key': entryKey,
      if (sourceRevision != null) 'source_revision': sourceRevision,
      if (snapshotJson != null) 'snapshot_json': snapshotJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CharacterContentRefsCompanion copyWith({
    Value<String>? characterId,
    Value<String>? slot,
    Value<String>? entryKey,
    Value<int>? sourceRevision,
    Value<String>? snapshotJson,
    Value<int>? rowid,
  }) {
    return CharacterContentRefsCompanion(
      characterId: characterId ?? this.characterId,
      slot: slot ?? this.slot,
      entryKey: entryKey ?? this.entryKey,
      sourceRevision: sourceRevision ?? this.sourceRevision,
      snapshotJson: snapshotJson ?? this.snapshotJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (characterId.present) {
      map['character_id'] = Variable<String>(characterId.value);
    }
    if (slot.present) {
      map['slot'] = Variable<String>(slot.value);
    }
    if (entryKey.present) {
      map['entry_key'] = Variable<String>(entryKey.value);
    }
    if (sourceRevision.present) {
      map['source_revision'] = Variable<int>(sourceRevision.value);
    }
    if (snapshotJson.present) {
      map['snapshot_json'] = Variable<String>(snapshotJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CharacterContentRefsCompanion(')
          ..write('characterId: $characterId, ')
          ..write('slot: $slot, ')
          ..write('entryKey: $entryKey, ')
          ..write('sourceRevision: $sourceRevision, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ServerProfilesTable serverProfiles = $ServerProfilesTable(this);
  late final $SyncOutboxTable syncOutbox = $SyncOutboxTable(this);
  late final $SyncCursorsTable syncCursors = $SyncCursorsTable(this);
  late final $MigrationMarkersTable migrationMarkers = $MigrationMarkersTable(
    this,
  );
  late final $LocalContentPackagesTable localContentPackages =
      $LocalContentPackagesTable(this);
  late final $LocalContentEntriesTable localContentEntries =
      $LocalContentEntriesTable(this);
  late final $LocalContentAssetsTable localContentAssets =
      $LocalContentAssetsTable(this);
  late final $ContentLinksTable contentLinks = $ContentLinksTable(this);
  late final $ContentFavoritesTable contentFavorites = $ContentFavoritesTable(
    this,
  );
  late final $ContentNotesTable contentNotes = $ContentNotesTable(this);
  late final $ContentReadHistoryTable contentReadHistory =
      $ContentReadHistoryTable(this);
  late final $CharactersTable characters = $CharactersTable(this);
  late final $CharacterContentRefsTable characterContentRefs =
      $CharacterContentRefsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    serverProfiles,
    syncOutbox,
    syncCursors,
    migrationMarkers,
    localContentPackages,
    localContentEntries,
    localContentAssets,
    contentLinks,
    contentFavorites,
    contentNotes,
    contentReadHistory,
    characters,
    characterContentRefs,
  ];
}

typedef $$ServerProfilesTableCreateCompanionBuilder =
    ServerProfilesCompanion Function({
      required String id,
      required String name,
      required String baseUrl,
      required String apiBaseUrl,
      required String websocketUrl,
      Value<String> lastKnownVersion,
      Value<bool> isDefault,
      Value<DateTime?> lastConnectedAt,
      Value<int> rowid,
    });
typedef $$ServerProfilesTableUpdateCompanionBuilder =
    ServerProfilesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> baseUrl,
      Value<String> apiBaseUrl,
      Value<String> websocketUrl,
      Value<String> lastKnownVersion,
      Value<bool> isDefault,
      Value<DateTime?> lastConnectedAt,
      Value<int> rowid,
    });

class $$ServerProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ServerProfilesTable> {
  $$ServerProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get apiBaseUrl => $composableBuilder(
    column: $table.apiBaseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get websocketUrl => $composableBuilder(
    column: $table.websocketUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastKnownVersion => $composableBuilder(
    column: $table.lastKnownVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastConnectedAt => $composableBuilder(
    column: $table.lastConnectedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ServerProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ServerProfilesTable> {
  $$ServerProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get apiBaseUrl => $composableBuilder(
    column: $table.apiBaseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get websocketUrl => $composableBuilder(
    column: $table.websocketUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastKnownVersion => $composableBuilder(
    column: $table.lastKnownVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastConnectedAt => $composableBuilder(
    column: $table.lastConnectedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ServerProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ServerProfilesTable> {
  $$ServerProfilesTableAnnotationComposer({
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

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<String> get apiBaseUrl => $composableBuilder(
    column: $table.apiBaseUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get websocketUrl => $composableBuilder(
    column: $table.websocketUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastKnownVersion => $composableBuilder(
    column: $table.lastKnownVersion,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<DateTime> get lastConnectedAt => $composableBuilder(
    column: $table.lastConnectedAt,
    builder: (column) => column,
  );
}

class $$ServerProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ServerProfilesTable,
          ServerProfileRow,
          $$ServerProfilesTableFilterComposer,
          $$ServerProfilesTableOrderingComposer,
          $$ServerProfilesTableAnnotationComposer,
          $$ServerProfilesTableCreateCompanionBuilder,
          $$ServerProfilesTableUpdateCompanionBuilder,
          (
            ServerProfileRow,
            BaseReferences<
              _$AppDatabase,
              $ServerProfilesTable,
              ServerProfileRow
            >,
          ),
          ServerProfileRow,
          PrefetchHooks Function()
        > {
  $$ServerProfilesTableTableManager(
    _$AppDatabase db,
    $ServerProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServerProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServerProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServerProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> baseUrl = const Value.absent(),
                Value<String> apiBaseUrl = const Value.absent(),
                Value<String> websocketUrl = const Value.absent(),
                Value<String> lastKnownVersion = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<DateTime?> lastConnectedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ServerProfilesCompanion(
                id: id,
                name: name,
                baseUrl: baseUrl,
                apiBaseUrl: apiBaseUrl,
                websocketUrl: websocketUrl,
                lastKnownVersion: lastKnownVersion,
                isDefault: isDefault,
                lastConnectedAt: lastConnectedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String baseUrl,
                required String apiBaseUrl,
                required String websocketUrl,
                Value<String> lastKnownVersion = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<DateTime?> lastConnectedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ServerProfilesCompanion.insert(
                id: id,
                name: name,
                baseUrl: baseUrl,
                apiBaseUrl: apiBaseUrl,
                websocketUrl: websocketUrl,
                lastKnownVersion: lastKnownVersion,
                isDefault: isDefault,
                lastConnectedAt: lastConnectedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ServerProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ServerProfilesTable,
      ServerProfileRow,
      $$ServerProfilesTableFilterComposer,
      $$ServerProfilesTableOrderingComposer,
      $$ServerProfilesTableAnnotationComposer,
      $$ServerProfilesTableCreateCompanionBuilder,
      $$ServerProfilesTableUpdateCompanionBuilder,
      (
        ServerProfileRow,
        BaseReferences<_$AppDatabase, $ServerProfilesTable, ServerProfileRow>,
      ),
      ServerProfileRow,
      PrefetchHooks Function()
    >;
typedef $$SyncOutboxTableCreateCompanionBuilder =
    SyncOutboxCompanion Function({
      required String id,
      required String scope,
      required String entityType,
      required String entityId,
      Value<int> baseRevision,
      required String payloadJson,
      required DateTime createdAt,
      Value<int> attempts,
      Value<int> rowid,
    });
typedef $$SyncOutboxTableUpdateCompanionBuilder =
    SyncOutboxCompanion Function({
      Value<String> id,
      Value<String> scope,
      Value<String> entityType,
      Value<String> entityId,
      Value<int> baseRevision,
      Value<String> payloadJson,
      Value<DateTime> createdAt,
      Value<int> attempts,
      Value<int> rowid,
    });

class $$SyncOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<int> get baseRevision => $composableBuilder(
    column: $table.baseRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);
}

class $$SyncOutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncOutboxTable,
          SyncOutboxData,
          $$SyncOutboxTableFilterComposer,
          $$SyncOutboxTableOrderingComposer,
          $$SyncOutboxTableAnnotationComposer,
          $$SyncOutboxTableCreateCompanionBuilder,
          $$SyncOutboxTableUpdateCompanionBuilder,
          (
            SyncOutboxData,
            BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxData>,
          ),
          SyncOutboxData,
          PrefetchHooks Function()
        > {
  $$SyncOutboxTableTableManager(_$AppDatabase db, $SyncOutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<int> baseRevision = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxCompanion(
                id: id,
                scope: scope,
                entityType: entityType,
                entityId: entityId,
                baseRevision: baseRevision,
                payloadJson: payloadJson,
                createdAt: createdAt,
                attempts: attempts,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String scope,
                required String entityType,
                required String entityId,
                Value<int> baseRevision = const Value.absent(),
                required String payloadJson,
                required DateTime createdAt,
                Value<int> attempts = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxCompanion.insert(
                id: id,
                scope: scope,
                entityType: entityType,
                entityId: entityId,
                baseRevision: baseRevision,
                payloadJson: payloadJson,
                createdAt: createdAt,
                attempts: attempts,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncOutboxTable,
      SyncOutboxData,
      $$SyncOutboxTableFilterComposer,
      $$SyncOutboxTableOrderingComposer,
      $$SyncOutboxTableAnnotationComposer,
      $$SyncOutboxTableCreateCompanionBuilder,
      $$SyncOutboxTableUpdateCompanionBuilder,
      (
        SyncOutboxData,
        BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxData>,
      ),
      SyncOutboxData,
      PrefetchHooks Function()
    >;
typedef $$SyncCursorsTableCreateCompanionBuilder =
    SyncCursorsCompanion Function({
      required String scope,
      required String remoteId,
      required String cursor,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SyncCursorsTableUpdateCompanionBuilder =
    SyncCursorsCompanion Function({
      Value<String> scope,
      Value<String> remoteId,
      Value<String> cursor,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SyncCursorsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncCursorsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncCursorsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get cursor =>
      $composableBuilder(column: $table.cursor, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SyncCursorsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncCursorsTable,
          SyncCursor,
          $$SyncCursorsTableFilterComposer,
          $$SyncCursorsTableOrderingComposer,
          $$SyncCursorsTableAnnotationComposer,
          $$SyncCursorsTableCreateCompanionBuilder,
          $$SyncCursorsTableUpdateCompanionBuilder,
          (
            SyncCursor,
            BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>,
          ),
          SyncCursor,
          PrefetchHooks Function()
        > {
  $$SyncCursorsTableTableManager(_$AppDatabase db, $SyncCursorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> scope = const Value.absent(),
                Value<String> remoteId = const Value.absent(),
                Value<String> cursor = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion(
                scope: scope,
                remoteId: remoteId,
                cursor: cursor,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String scope,
                required String remoteId,
                required String cursor,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion.insert(
                scope: scope,
                remoteId: remoteId,
                cursor: cursor,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncCursorsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncCursorsTable,
      SyncCursor,
      $$SyncCursorsTableFilterComposer,
      $$SyncCursorsTableOrderingComposer,
      $$SyncCursorsTableAnnotationComposer,
      $$SyncCursorsTableCreateCompanionBuilder,
      $$SyncCursorsTableUpdateCompanionBuilder,
      (
        SyncCursor,
        BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>,
      ),
      SyncCursor,
      PrefetchHooks Function()
    >;
typedef $$MigrationMarkersTableCreateCompanionBuilder =
    MigrationMarkersCompanion Function({
      required String key,
      required DateTime completedAt,
      Value<int> rowid,
    });
typedef $$MigrationMarkersTableUpdateCompanionBuilder =
    MigrationMarkersCompanion Function({
      Value<String> key,
      Value<DateTime> completedAt,
      Value<int> rowid,
    });

class $$MigrationMarkersTableFilterComposer
    extends Composer<_$AppDatabase, $MigrationMarkersTable> {
  $$MigrationMarkersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MigrationMarkersTableOrderingComposer
    extends Composer<_$AppDatabase, $MigrationMarkersTable> {
  $$MigrationMarkersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MigrationMarkersTableAnnotationComposer
    extends Composer<_$AppDatabase, $MigrationMarkersTable> {
  $$MigrationMarkersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$MigrationMarkersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MigrationMarkersTable,
          MigrationMarker,
          $$MigrationMarkersTableFilterComposer,
          $$MigrationMarkersTableOrderingComposer,
          $$MigrationMarkersTableAnnotationComposer,
          $$MigrationMarkersTableCreateCompanionBuilder,
          $$MigrationMarkersTableUpdateCompanionBuilder,
          (
            MigrationMarker,
            BaseReferences<
              _$AppDatabase,
              $MigrationMarkersTable,
              MigrationMarker
            >,
          ),
          MigrationMarker,
          PrefetchHooks Function()
        > {
  $$MigrationMarkersTableTableManager(
    _$AppDatabase db,
    $MigrationMarkersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MigrationMarkersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MigrationMarkersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MigrationMarkersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<DateTime> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MigrationMarkersCompanion(
                key: key,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required DateTime completedAt,
                Value<int> rowid = const Value.absent(),
              }) => MigrationMarkersCompanion.insert(
                key: key,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MigrationMarkersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MigrationMarkersTable,
      MigrationMarker,
      $$MigrationMarkersTableFilterComposer,
      $$MigrationMarkersTableOrderingComposer,
      $$MigrationMarkersTableAnnotationComposer,
      $$MigrationMarkersTableCreateCompanionBuilder,
      $$MigrationMarkersTableUpdateCompanionBuilder,
      (
        MigrationMarker,
        BaseReferences<_$AppDatabase, $MigrationMarkersTable, MigrationMarker>,
      ),
      MigrationMarker,
      PrefetchHooks Function()
    >;
typedef $$LocalContentPackagesTableCreateCompanionBuilder =
    LocalContentPackagesCompanion Function({
      required String id,
      required int formatVersion,
      required String name,
      required String version,
      required String locale,
      required String system,
      required int entryCount,
      required String contentHash,
      Value<bool> enabled,
      required DateTime installedAt,
      Value<int> rowid,
    });
typedef $$LocalContentPackagesTableUpdateCompanionBuilder =
    LocalContentPackagesCompanion Function({
      Value<String> id,
      Value<int> formatVersion,
      Value<String> name,
      Value<String> version,
      Value<String> locale,
      Value<String> system,
      Value<int> entryCount,
      Value<String> contentHash,
      Value<bool> enabled,
      Value<DateTime> installedAt,
      Value<int> rowid,
    });

class $$LocalContentPackagesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalContentPackagesTable> {
  $$LocalContentPackagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locale => $composableBuilder(
    column: $table.locale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get system => $composableBuilder(
    column: $table.system,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get entryCount => $composableBuilder(
    column: $table.entryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalContentPackagesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalContentPackagesTable> {
  $$LocalContentPackagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locale => $composableBuilder(
    column: $table.locale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get system => $composableBuilder(
    column: $table.system,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get entryCount => $composableBuilder(
    column: $table.entryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalContentPackagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalContentPackagesTable> {
  $$LocalContentPackagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get locale =>
      $composableBuilder(column: $table.locale, builder: (column) => column);

  GeneratedColumn<String> get system =>
      $composableBuilder(column: $table.system, builder: (column) => column);

  GeneratedColumn<int> get entryCount => $composableBuilder(
    column: $table.entryCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => column,
  );
}

class $$LocalContentPackagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalContentPackagesTable,
          LocalContentPackageRow,
          $$LocalContentPackagesTableFilterComposer,
          $$LocalContentPackagesTableOrderingComposer,
          $$LocalContentPackagesTableAnnotationComposer,
          $$LocalContentPackagesTableCreateCompanionBuilder,
          $$LocalContentPackagesTableUpdateCompanionBuilder,
          (
            LocalContentPackageRow,
            BaseReferences<
              _$AppDatabase,
              $LocalContentPackagesTable,
              LocalContentPackageRow
            >,
          ),
          LocalContentPackageRow,
          PrefetchHooks Function()
        > {
  $$LocalContentPackagesTableTableManager(
    _$AppDatabase db,
    $LocalContentPackagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalContentPackagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalContentPackagesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalContentPackagesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> formatVersion = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<String> locale = const Value.absent(),
                Value<String> system = const Value.absent(),
                Value<int> entryCount = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<DateTime> installedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalContentPackagesCompanion(
                id: id,
                formatVersion: formatVersion,
                name: name,
                version: version,
                locale: locale,
                system: system,
                entryCount: entryCount,
                contentHash: contentHash,
                enabled: enabled,
                installedAt: installedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int formatVersion,
                required String name,
                required String version,
                required String locale,
                required String system,
                required int entryCount,
                required String contentHash,
                Value<bool> enabled = const Value.absent(),
                required DateTime installedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalContentPackagesCompanion.insert(
                id: id,
                formatVersion: formatVersion,
                name: name,
                version: version,
                locale: locale,
                system: system,
                entryCount: entryCount,
                contentHash: contentHash,
                enabled: enabled,
                installedAt: installedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalContentPackagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalContentPackagesTable,
      LocalContentPackageRow,
      $$LocalContentPackagesTableFilterComposer,
      $$LocalContentPackagesTableOrderingComposer,
      $$LocalContentPackagesTableAnnotationComposer,
      $$LocalContentPackagesTableCreateCompanionBuilder,
      $$LocalContentPackagesTableUpdateCompanionBuilder,
      (
        LocalContentPackageRow,
        BaseReferences<
          _$AppDatabase,
          $LocalContentPackagesTable,
          LocalContentPackageRow
        >,
      ),
      LocalContentPackageRow,
      PrefetchHooks Function()
    >;
typedef $$LocalContentEntriesTableCreateCompanionBuilder =
    LocalContentEntriesCompanion Function({
      required String entryKey,
      required String packageId,
      required String type,
      required String slug,
      required String name,
      Value<String> aliasesJson,
      Value<String> summary,
      Value<String> bodyJson,
      Value<String> structuredJson,
      Value<String> tagsJson,
      Value<String> sourceLabel,
      required int revision,
      Value<int> rowid,
    });
typedef $$LocalContentEntriesTableUpdateCompanionBuilder =
    LocalContentEntriesCompanion Function({
      Value<String> entryKey,
      Value<String> packageId,
      Value<String> type,
      Value<String> slug,
      Value<String> name,
      Value<String> aliasesJson,
      Value<String> summary,
      Value<String> bodyJson,
      Value<String> structuredJson,
      Value<String> tagsJson,
      Value<String> sourceLabel,
      Value<int> revision,
      Value<int> rowid,
    });

class $$LocalContentEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalContentEntriesTable> {
  $$LocalContentEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entryKey => $composableBuilder(
    column: $table.entryKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aliasesJson => $composableBuilder(
    column: $table.aliasesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyJson => $composableBuilder(
    column: $table.bodyJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get structuredJson => $composableBuilder(
    column: $table.structuredJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceLabel => $composableBuilder(
    column: $table.sourceLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalContentEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalContentEntriesTable> {
  $$LocalContentEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entryKey => $composableBuilder(
    column: $table.entryKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aliasesJson => $composableBuilder(
    column: $table.aliasesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyJson => $composableBuilder(
    column: $table.bodyJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get structuredJson => $composableBuilder(
    column: $table.structuredJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceLabel => $composableBuilder(
    column: $table.sourceLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalContentEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalContentEntriesTable> {
  $$LocalContentEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entryKey =>
      $composableBuilder(column: $table.entryKey, builder: (column) => column);

  GeneratedColumn<String> get packageId =>
      $composableBuilder(column: $table.packageId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get slug =>
      $composableBuilder(column: $table.slug, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get aliasesJson => $composableBuilder(
    column: $table.aliasesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get bodyJson =>
      $composableBuilder(column: $table.bodyJson, builder: (column) => column);

  GeneratedColumn<String> get structuredJson => $composableBuilder(
    column: $table.structuredJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<String> get sourceLabel => $composableBuilder(
    column: $table.sourceLabel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);
}

class $$LocalContentEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalContentEntriesTable,
          LocalContentEntryRow,
          $$LocalContentEntriesTableFilterComposer,
          $$LocalContentEntriesTableOrderingComposer,
          $$LocalContentEntriesTableAnnotationComposer,
          $$LocalContentEntriesTableCreateCompanionBuilder,
          $$LocalContentEntriesTableUpdateCompanionBuilder,
          (
            LocalContentEntryRow,
            BaseReferences<
              _$AppDatabase,
              $LocalContentEntriesTable,
              LocalContentEntryRow
            >,
          ),
          LocalContentEntryRow,
          PrefetchHooks Function()
        > {
  $$LocalContentEntriesTableTableManager(
    _$AppDatabase db,
    $LocalContentEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalContentEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalContentEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalContentEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> entryKey = const Value.absent(),
                Value<String> packageId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> slug = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> aliasesJson = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<String> bodyJson = const Value.absent(),
                Value<String> structuredJson = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<String> sourceLabel = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalContentEntriesCompanion(
                entryKey: entryKey,
                packageId: packageId,
                type: type,
                slug: slug,
                name: name,
                aliasesJson: aliasesJson,
                summary: summary,
                bodyJson: bodyJson,
                structuredJson: structuredJson,
                tagsJson: tagsJson,
                sourceLabel: sourceLabel,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entryKey,
                required String packageId,
                required String type,
                required String slug,
                required String name,
                Value<String> aliasesJson = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<String> bodyJson = const Value.absent(),
                Value<String> structuredJson = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<String> sourceLabel = const Value.absent(),
                required int revision,
                Value<int> rowid = const Value.absent(),
              }) => LocalContentEntriesCompanion.insert(
                entryKey: entryKey,
                packageId: packageId,
                type: type,
                slug: slug,
                name: name,
                aliasesJson: aliasesJson,
                summary: summary,
                bodyJson: bodyJson,
                structuredJson: structuredJson,
                tagsJson: tagsJson,
                sourceLabel: sourceLabel,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalContentEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalContentEntriesTable,
      LocalContentEntryRow,
      $$LocalContentEntriesTableFilterComposer,
      $$LocalContentEntriesTableOrderingComposer,
      $$LocalContentEntriesTableAnnotationComposer,
      $$LocalContentEntriesTableCreateCompanionBuilder,
      $$LocalContentEntriesTableUpdateCompanionBuilder,
      (
        LocalContentEntryRow,
        BaseReferences<
          _$AppDatabase,
          $LocalContentEntriesTable,
          LocalContentEntryRow
        >,
      ),
      LocalContentEntryRow,
      PrefetchHooks Function()
    >;
typedef $$LocalContentAssetsTableCreateCompanionBuilder =
    LocalContentAssetsCompanion Function({
      required String packageId,
      required String relativePath,
      required Uint8List bytes,
      Value<String> mediaType,
      Value<String> contentHash,
      Value<int> rowid,
    });
typedef $$LocalContentAssetsTableUpdateCompanionBuilder =
    LocalContentAssetsCompanion Function({
      Value<String> packageId,
      Value<String> relativePath,
      Value<Uint8List> bytes,
      Value<String> mediaType,
      Value<String> contentHash,
      Value<int> rowid,
    });

class $$LocalContentAssetsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalContentAssetsTable> {
  $$LocalContentAssetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalContentAssetsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalContentAssetsTable> {
  $$LocalContentAssetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalContentAssetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalContentAssetsTable> {
  $$LocalContentAssetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get packageId =>
      $composableBuilder(column: $table.packageId, builder: (column) => column);

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );
}

class $$LocalContentAssetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalContentAssetsTable,
          LocalContentAssetRow,
          $$LocalContentAssetsTableFilterComposer,
          $$LocalContentAssetsTableOrderingComposer,
          $$LocalContentAssetsTableAnnotationComposer,
          $$LocalContentAssetsTableCreateCompanionBuilder,
          $$LocalContentAssetsTableUpdateCompanionBuilder,
          (
            LocalContentAssetRow,
            BaseReferences<
              _$AppDatabase,
              $LocalContentAssetsTable,
              LocalContentAssetRow
            >,
          ),
          LocalContentAssetRow,
          PrefetchHooks Function()
        > {
  $$LocalContentAssetsTableTableManager(
    _$AppDatabase db,
    $LocalContentAssetsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalContentAssetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalContentAssetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalContentAssetsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> packageId = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<Uint8List> bytes = const Value.absent(),
                Value<String> mediaType = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalContentAssetsCompanion(
                packageId: packageId,
                relativePath: relativePath,
                bytes: bytes,
                mediaType: mediaType,
                contentHash: contentHash,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String packageId,
                required String relativePath,
                required Uint8List bytes,
                Value<String> mediaType = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalContentAssetsCompanion.insert(
                packageId: packageId,
                relativePath: relativePath,
                bytes: bytes,
                mediaType: mediaType,
                contentHash: contentHash,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalContentAssetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalContentAssetsTable,
      LocalContentAssetRow,
      $$LocalContentAssetsTableFilterComposer,
      $$LocalContentAssetsTableOrderingComposer,
      $$LocalContentAssetsTableAnnotationComposer,
      $$LocalContentAssetsTableCreateCompanionBuilder,
      $$LocalContentAssetsTableUpdateCompanionBuilder,
      (
        LocalContentAssetRow,
        BaseReferences<
          _$AppDatabase,
          $LocalContentAssetsTable,
          LocalContentAssetRow
        >,
      ),
      LocalContentAssetRow,
      PrefetchHooks Function()
    >;
typedef $$ContentLinksTableCreateCompanionBuilder =
    ContentLinksCompanion Function({
      required String id,
      required String sourceId,
      required String targetId,
      Value<String> linkText,
      Value<int> rowid,
    });
typedef $$ContentLinksTableUpdateCompanionBuilder =
    ContentLinksCompanion Function({
      Value<String> id,
      Value<String> sourceId,
      Value<String> targetId,
      Value<String> linkText,
      Value<int> rowid,
    });

class $$ContentLinksTableFilterComposer
    extends Composer<_$AppDatabase, $ContentLinksTable> {
  $$ContentLinksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkText => $composableBuilder(
    column: $table.linkText,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContentLinksTableOrderingComposer
    extends Composer<_$AppDatabase, $ContentLinksTable> {
  $$ContentLinksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkText => $composableBuilder(
    column: $table.linkText,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContentLinksTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContentLinksTable> {
  $$ContentLinksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);

  GeneratedColumn<String> get linkText =>
      $composableBuilder(column: $table.linkText, builder: (column) => column);
}

class $$ContentLinksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContentLinksTable,
          ContentLinkRow,
          $$ContentLinksTableFilterComposer,
          $$ContentLinksTableOrderingComposer,
          $$ContentLinksTableAnnotationComposer,
          $$ContentLinksTableCreateCompanionBuilder,
          $$ContentLinksTableUpdateCompanionBuilder,
          (
            ContentLinkRow,
            BaseReferences<_$AppDatabase, $ContentLinksTable, ContentLinkRow>,
          ),
          ContentLinkRow,
          PrefetchHooks Function()
        > {
  $$ContentLinksTableTableManager(_$AppDatabase db, $ContentLinksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentLinksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContentLinksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContentLinksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> targetId = const Value.absent(),
                Value<String> linkText = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentLinksCompanion(
                id: id,
                sourceId: sourceId,
                targetId: targetId,
                linkText: linkText,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourceId,
                required String targetId,
                Value<String> linkText = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentLinksCompanion.insert(
                id: id,
                sourceId: sourceId,
                targetId: targetId,
                linkText: linkText,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContentLinksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContentLinksTable,
      ContentLinkRow,
      $$ContentLinksTableFilterComposer,
      $$ContentLinksTableOrderingComposer,
      $$ContentLinksTableAnnotationComposer,
      $$ContentLinksTableCreateCompanionBuilder,
      $$ContentLinksTableUpdateCompanionBuilder,
      (
        ContentLinkRow,
        BaseReferences<_$AppDatabase, $ContentLinksTable, ContentLinkRow>,
      ),
      ContentLinkRow,
      PrefetchHooks Function()
    >;
typedef $$ContentFavoritesTableCreateCompanionBuilder =
    ContentFavoritesCompanion Function({
      required String entryKey,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ContentFavoritesTableUpdateCompanionBuilder =
    ContentFavoritesCompanion Function({
      Value<String> entryKey,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$ContentFavoritesTableFilterComposer
    extends Composer<_$AppDatabase, $ContentFavoritesTable> {
  $$ContentFavoritesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entryKey => $composableBuilder(
    column: $table.entryKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContentFavoritesTableOrderingComposer
    extends Composer<_$AppDatabase, $ContentFavoritesTable> {
  $$ContentFavoritesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entryKey => $composableBuilder(
    column: $table.entryKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContentFavoritesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContentFavoritesTable> {
  $$ContentFavoritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entryKey =>
      $composableBuilder(column: $table.entryKey, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ContentFavoritesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContentFavoritesTable,
          ContentFavoriteRow,
          $$ContentFavoritesTableFilterComposer,
          $$ContentFavoritesTableOrderingComposer,
          $$ContentFavoritesTableAnnotationComposer,
          $$ContentFavoritesTableCreateCompanionBuilder,
          $$ContentFavoritesTableUpdateCompanionBuilder,
          (
            ContentFavoriteRow,
            BaseReferences<
              _$AppDatabase,
              $ContentFavoritesTable,
              ContentFavoriteRow
            >,
          ),
          ContentFavoriteRow,
          PrefetchHooks Function()
        > {
  $$ContentFavoritesTableTableManager(
    _$AppDatabase db,
    $ContentFavoritesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentFavoritesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContentFavoritesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContentFavoritesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entryKey = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentFavoritesCompanion(
                entryKey: entryKey,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entryKey,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ContentFavoritesCompanion.insert(
                entryKey: entryKey,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContentFavoritesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContentFavoritesTable,
      ContentFavoriteRow,
      $$ContentFavoritesTableFilterComposer,
      $$ContentFavoritesTableOrderingComposer,
      $$ContentFavoritesTableAnnotationComposer,
      $$ContentFavoritesTableCreateCompanionBuilder,
      $$ContentFavoritesTableUpdateCompanionBuilder,
      (
        ContentFavoriteRow,
        BaseReferences<
          _$AppDatabase,
          $ContentFavoritesTable,
          ContentFavoriteRow
        >,
      ),
      ContentFavoriteRow,
      PrefetchHooks Function()
    >;
typedef $$ContentNotesTableCreateCompanionBuilder =
    ContentNotesCompanion Function({
      required String entryKey,
      required String markdown,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ContentNotesTableUpdateCompanionBuilder =
    ContentNotesCompanion Function({
      Value<String> entryKey,
      Value<String> markdown,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ContentNotesTableFilterComposer
    extends Composer<_$AppDatabase, $ContentNotesTable> {
  $$ContentNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entryKey => $composableBuilder(
    column: $table.entryKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get markdown => $composableBuilder(
    column: $table.markdown,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContentNotesTableOrderingComposer
    extends Composer<_$AppDatabase, $ContentNotesTable> {
  $$ContentNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entryKey => $composableBuilder(
    column: $table.entryKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get markdown => $composableBuilder(
    column: $table.markdown,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContentNotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContentNotesTable> {
  $$ContentNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entryKey =>
      $composableBuilder(column: $table.entryKey, builder: (column) => column);

  GeneratedColumn<String> get markdown =>
      $composableBuilder(column: $table.markdown, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ContentNotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContentNotesTable,
          ContentNoteRow,
          $$ContentNotesTableFilterComposer,
          $$ContentNotesTableOrderingComposer,
          $$ContentNotesTableAnnotationComposer,
          $$ContentNotesTableCreateCompanionBuilder,
          $$ContentNotesTableUpdateCompanionBuilder,
          (
            ContentNoteRow,
            BaseReferences<_$AppDatabase, $ContentNotesTable, ContentNoteRow>,
          ),
          ContentNoteRow,
          PrefetchHooks Function()
        > {
  $$ContentNotesTableTableManager(_$AppDatabase db, $ContentNotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContentNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContentNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entryKey = const Value.absent(),
                Value<String> markdown = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentNotesCompanion(
                entryKey: entryKey,
                markdown: markdown,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entryKey,
                required String markdown,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ContentNotesCompanion.insert(
                entryKey: entryKey,
                markdown: markdown,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContentNotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContentNotesTable,
      ContentNoteRow,
      $$ContentNotesTableFilterComposer,
      $$ContentNotesTableOrderingComposer,
      $$ContentNotesTableAnnotationComposer,
      $$ContentNotesTableCreateCompanionBuilder,
      $$ContentNotesTableUpdateCompanionBuilder,
      (
        ContentNoteRow,
        BaseReferences<_$AppDatabase, $ContentNotesTable, ContentNoteRow>,
      ),
      ContentNoteRow,
      PrefetchHooks Function()
    >;
typedef $$ContentReadHistoryTableCreateCompanionBuilder =
    ContentReadHistoryCompanion Function({
      required String entryKey,
      required DateTime readAt,
      Value<int> rowid,
    });
typedef $$ContentReadHistoryTableUpdateCompanionBuilder =
    ContentReadHistoryCompanion Function({
      Value<String> entryKey,
      Value<DateTime> readAt,
      Value<int> rowid,
    });

class $$ContentReadHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $ContentReadHistoryTable> {
  $$ContentReadHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entryKey => $composableBuilder(
    column: $table.entryKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContentReadHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $ContentReadHistoryTable> {
  $$ContentReadHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entryKey => $composableBuilder(
    column: $table.entryKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContentReadHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContentReadHistoryTable> {
  $$ContentReadHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entryKey =>
      $composableBuilder(column: $table.entryKey, builder: (column) => column);

  GeneratedColumn<DateTime> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);
}

class $$ContentReadHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContentReadHistoryTable,
          ContentReadHistoryRow,
          $$ContentReadHistoryTableFilterComposer,
          $$ContentReadHistoryTableOrderingComposer,
          $$ContentReadHistoryTableAnnotationComposer,
          $$ContentReadHistoryTableCreateCompanionBuilder,
          $$ContentReadHistoryTableUpdateCompanionBuilder,
          (
            ContentReadHistoryRow,
            BaseReferences<
              _$AppDatabase,
              $ContentReadHistoryTable,
              ContentReadHistoryRow
            >,
          ),
          ContentReadHistoryRow,
          PrefetchHooks Function()
        > {
  $$ContentReadHistoryTableTableManager(
    _$AppDatabase db,
    $ContentReadHistoryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentReadHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContentReadHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContentReadHistoryTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> entryKey = const Value.absent(),
                Value<DateTime> readAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentReadHistoryCompanion(
                entryKey: entryKey,
                readAt: readAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entryKey,
                required DateTime readAt,
                Value<int> rowid = const Value.absent(),
              }) => ContentReadHistoryCompanion.insert(
                entryKey: entryKey,
                readAt: readAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContentReadHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContentReadHistoryTable,
      ContentReadHistoryRow,
      $$ContentReadHistoryTableFilterComposer,
      $$ContentReadHistoryTableOrderingComposer,
      $$ContentReadHistoryTableAnnotationComposer,
      $$ContentReadHistoryTableCreateCompanionBuilder,
      $$ContentReadHistoryTableUpdateCompanionBuilder,
      (
        ContentReadHistoryRow,
        BaseReferences<
          _$AppDatabase,
          $ContentReadHistoryTable,
          ContentReadHistoryRow
        >,
      ),
      ContentReadHistoryRow,
      PrefetchHooks Function()
    >;
typedef $$CharactersTableCreateCompanionBuilder =
    CharactersCompanion Function({
      required String id,
      Value<String> ownerLocalId,
      required String sheetJson,
      Value<int> revision,
      Value<int?> syncRevision,
      Value<DateTime?> archivedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$CharactersTableUpdateCompanionBuilder =
    CharactersCompanion Function({
      Value<String> id,
      Value<String> ownerLocalId,
      Value<String> sheetJson,
      Value<int> revision,
      Value<int?> syncRevision,
      Value<DateTime?> archivedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CharactersTableFilterComposer
    extends Composer<_$AppDatabase, $CharactersTable> {
  $$CharactersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerLocalId => $composableBuilder(
    column: $table.ownerLocalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sheetJson => $composableBuilder(
    column: $table.sheetJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncRevision => $composableBuilder(
    column: $table.syncRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CharactersTableOrderingComposer
    extends Composer<_$AppDatabase, $CharactersTable> {
  $$CharactersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerLocalId => $composableBuilder(
    column: $table.ownerLocalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sheetJson => $composableBuilder(
    column: $table.sheetJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncRevision => $composableBuilder(
    column: $table.syncRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CharactersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CharactersTable> {
  $$CharactersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerLocalId => $composableBuilder(
    column: $table.ownerLocalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sheetJson =>
      $composableBuilder(column: $table.sheetJson, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<int> get syncRevision => $composableBuilder(
    column: $table.syncRevision,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CharactersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CharactersTable,
          CharacterRow,
          $$CharactersTableFilterComposer,
          $$CharactersTableOrderingComposer,
          $$CharactersTableAnnotationComposer,
          $$CharactersTableCreateCompanionBuilder,
          $$CharactersTableUpdateCompanionBuilder,
          (
            CharacterRow,
            BaseReferences<_$AppDatabase, $CharactersTable, CharacterRow>,
          ),
          CharacterRow,
          PrefetchHooks Function()
        > {
  $$CharactersTableTableManager(_$AppDatabase db, $CharactersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CharactersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CharactersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CharactersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerLocalId = const Value.absent(),
                Value<String> sheetJson = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int?> syncRevision = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CharactersCompanion(
                id: id,
                ownerLocalId: ownerLocalId,
                sheetJson: sheetJson,
                revision: revision,
                syncRevision: syncRevision,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> ownerLocalId = const Value.absent(),
                required String sheetJson,
                Value<int> revision = const Value.absent(),
                Value<int?> syncRevision = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CharactersCompanion.insert(
                id: id,
                ownerLocalId: ownerLocalId,
                sheetJson: sheetJson,
                revision: revision,
                syncRevision: syncRevision,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CharactersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CharactersTable,
      CharacterRow,
      $$CharactersTableFilterComposer,
      $$CharactersTableOrderingComposer,
      $$CharactersTableAnnotationComposer,
      $$CharactersTableCreateCompanionBuilder,
      $$CharactersTableUpdateCompanionBuilder,
      (
        CharacterRow,
        BaseReferences<_$AppDatabase, $CharactersTable, CharacterRow>,
      ),
      CharacterRow,
      PrefetchHooks Function()
    >;
typedef $$CharacterContentRefsTableCreateCompanionBuilder =
    CharacterContentRefsCompanion Function({
      required String characterId,
      required String slot,
      required String entryKey,
      Value<int> sourceRevision,
      Value<String> snapshotJson,
      Value<int> rowid,
    });
typedef $$CharacterContentRefsTableUpdateCompanionBuilder =
    CharacterContentRefsCompanion Function({
      Value<String> characterId,
      Value<String> slot,
      Value<String> entryKey,
      Value<int> sourceRevision,
      Value<String> snapshotJson,
      Value<int> rowid,
    });

class $$CharacterContentRefsTableFilterComposer
    extends Composer<_$AppDatabase, $CharacterContentRefsTable> {
  $$CharacterContentRefsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryKey => $composableBuilder(
    column: $table.entryKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceRevision => $composableBuilder(
    column: $table.sourceRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CharacterContentRefsTableOrderingComposer
    extends Composer<_$AppDatabase, $CharacterContentRefsTable> {
  $$CharacterContentRefsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryKey => $composableBuilder(
    column: $table.entryKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceRevision => $composableBuilder(
    column: $table.sourceRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CharacterContentRefsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CharacterContentRefsTable> {
  $$CharacterContentRefsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  GeneratedColumn<String> get entryKey =>
      $composableBuilder(column: $table.entryKey, builder: (column) => column);

  GeneratedColumn<int> get sourceRevision => $composableBuilder(
    column: $table.sourceRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => column,
  );
}

class $$CharacterContentRefsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CharacterContentRefsTable,
          CharacterContentRefRow,
          $$CharacterContentRefsTableFilterComposer,
          $$CharacterContentRefsTableOrderingComposer,
          $$CharacterContentRefsTableAnnotationComposer,
          $$CharacterContentRefsTableCreateCompanionBuilder,
          $$CharacterContentRefsTableUpdateCompanionBuilder,
          (
            CharacterContentRefRow,
            BaseReferences<
              _$AppDatabase,
              $CharacterContentRefsTable,
              CharacterContentRefRow
            >,
          ),
          CharacterContentRefRow,
          PrefetchHooks Function()
        > {
  $$CharacterContentRefsTableTableManager(
    _$AppDatabase db,
    $CharacterContentRefsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CharacterContentRefsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CharacterContentRefsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CharacterContentRefsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> characterId = const Value.absent(),
                Value<String> slot = const Value.absent(),
                Value<String> entryKey = const Value.absent(),
                Value<int> sourceRevision = const Value.absent(),
                Value<String> snapshotJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CharacterContentRefsCompanion(
                characterId: characterId,
                slot: slot,
                entryKey: entryKey,
                sourceRevision: sourceRevision,
                snapshotJson: snapshotJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String characterId,
                required String slot,
                required String entryKey,
                Value<int> sourceRevision = const Value.absent(),
                Value<String> snapshotJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CharacterContentRefsCompanion.insert(
                characterId: characterId,
                slot: slot,
                entryKey: entryKey,
                sourceRevision: sourceRevision,
                snapshotJson: snapshotJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CharacterContentRefsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CharacterContentRefsTable,
      CharacterContentRefRow,
      $$CharacterContentRefsTableFilterComposer,
      $$CharacterContentRefsTableOrderingComposer,
      $$CharacterContentRefsTableAnnotationComposer,
      $$CharacterContentRefsTableCreateCompanionBuilder,
      $$CharacterContentRefsTableUpdateCompanionBuilder,
      (
        CharacterContentRefRow,
        BaseReferences<
          _$AppDatabase,
          $CharacterContentRefsTable,
          CharacterContentRefRow
        >,
      ),
      CharacterContentRefRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ServerProfilesTableTableManager get serverProfiles =>
      $$ServerProfilesTableTableManager(_db, _db.serverProfiles);
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db, _db.syncOutbox);
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db, _db.syncCursors);
  $$MigrationMarkersTableTableManager get migrationMarkers =>
      $$MigrationMarkersTableTableManager(_db, _db.migrationMarkers);
  $$LocalContentPackagesTableTableManager get localContentPackages =>
      $$LocalContentPackagesTableTableManager(_db, _db.localContentPackages);
  $$LocalContentEntriesTableTableManager get localContentEntries =>
      $$LocalContentEntriesTableTableManager(_db, _db.localContentEntries);
  $$LocalContentAssetsTableTableManager get localContentAssets =>
      $$LocalContentAssetsTableTableManager(_db, _db.localContentAssets);
  $$ContentLinksTableTableManager get contentLinks =>
      $$ContentLinksTableTableManager(_db, _db.contentLinks);
  $$ContentFavoritesTableTableManager get contentFavorites =>
      $$ContentFavoritesTableTableManager(_db, _db.contentFavorites);
  $$ContentNotesTableTableManager get contentNotes =>
      $$ContentNotesTableTableManager(_db, _db.contentNotes);
  $$ContentReadHistoryTableTableManager get contentReadHistory =>
      $$ContentReadHistoryTableTableManager(_db, _db.contentReadHistory);
  $$CharactersTableTableManager get characters =>
      $$CharactersTableTableManager(_db, _db.characters);
  $$CharacterContentRefsTableTableManager get characterContentRefs =>
      $$CharacterContentRefsTableTableManager(_db, _db.characterContentRefs);
}
