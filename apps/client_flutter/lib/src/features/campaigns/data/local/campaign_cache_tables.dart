import 'package:drift/drift.dart';

/// 战役角色本地缓存。来源是远端战役变更流的 upsert。
@DataClassName('CampaignCharactersCacheRow')
@TableIndex(
  name: 'idx_campaign_characters_campaign_status',
  columns: {#campaignId, #status},
)
class CampaignCharactersCache extends Table {
  @override
  String get tableName => 'campaign_characters_cache';

  TextColumn get id => text()();
  TextColumn get campaignId => text()();
  TextColumn get ownerUserId => text().nullable()();
  TextColumn get sourceCharacterId => text().nullable()();
  TextColumn get characterType => text().named('character_type')();
  TextColumn get status => text()();
  BoolColumn get visibleToPlayers =>
      boolean().withDefault(const Constant(true))();
  TextColumn get sheetJson => text()();
  IntColumn get revision => integer()();
  TextColumn get updatedBy => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 角色与战役 Character 双向同步基线。campaignCharacterId 为主键。
@DataClassName('CampaignCharacterBacklinkRow')
class CampaignCharacterBacklinks extends Table {
  @override
  String get tableName => 'campaign_character_backlinks';

  TextColumn get campaignCharacterId => text().named('campaign_character_id')();
  TextColumn get sourceCharacterId => text()();
  IntColumn get lastPublishedLocalRevision =>
      integer().withDefault(const Constant(0))();
  IntColumn get lastAppliedCharacterRevision => integer()
      .named('last_applied_character_revision')
      .withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {campaignCharacterId};
}

/// 战役内容条目本地缓存。
@DataClassName('CampaignContentCacheRow')
@TableIndex(
  name: 'idx_campaign_content_campaign_type_deleted',
  columns: {#campaignId, #type, #deletedAt},
)
class CampaignContentCache extends Table {
  TextColumn get id => text()();
  TextColumn get campaignId => text()();
  TextColumn get type => text()();
  TextColumn get slug => text()();
  TextColumn get name => text()();
  TextColumn get entryJson => text().withDefault(const Constant('{}'))();
  IntColumn get revision => integer()();
  TextColumn get createdBy => text()();
  TextColumn get updatedBy => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 每个战役的变更流游标。
@DataClassName('CampaignSyncCursorRow')
class CampaignSyncCursors extends Table {
  TextColumn get campaignId => text()();
  TextColumn get cursor => text().withDefault(const Constant('0'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {campaignId};
}

/// 角色与 Character 双向同步冲突记录，由角色页比较解决。
@DataClassName('CharacterSyncConflictRow')
@TableIndex(
  name: 'idx_character_sync_conflicts_character',
  columns: {#characterId},
)
class CharacterSyncConflicts extends Table {
  TextColumn get id => text()();
  TextColumn get characterId => text()();
  TextColumn get campaignCharacterId => text().named('campaign_character_id')();
  TextColumn get fieldPath => text()();
  TextColumn get localValueJson => text().withDefault(const Constant('{}'))();
  TextColumn get remoteValueJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
