import 'package:drift/drift.dart';

/// 服务器 Profile 本地持久化。迁自 SharedPreferences，离线主壳不再要求先添加服务器。
@DataClassName('ServerProfileRow')
class ServerProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get baseUrl => text()();
  TextColumn get apiBaseUrl => text()();
  TextColumn get websocketUrl => text()();
  TextColumn get lastKnownVersion => text().withDefault(const Constant(''))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastConnectedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 同步 Outbox：个人实体本地写操作待推送到 Vault 或战役。
class SyncOutbox extends Table {
  TextColumn get id => text()();
  TextColumn get scope => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  IntColumn get baseRevision => integer().withDefault(const Constant(0))();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 每个同步 scope + 远端 ID 的游标。
class SyncCursors extends Table {
  TextColumn get scope => text()();
  TextColumn get remoteId => text()();
  TextColumn get cursor => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {scope, remoteId};
}

/// 一次性迁移标记，避免重复迁移 SharedPreferences 等历史数据。
class MigrationMarkers extends Table {
  TextColumn get key => text()();
  DateTimeColumn get completedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Last server revision observed for a personal Vault entity.
class VaultEntityRevisions extends Table {
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  IntColumn get revision => integer()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {entityType, entityId};
}
