import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:meta/meta.dart';

import '../../features/campaigns/data/local/campaign_cache_tables.dart';
import '../../features/characters/data/local/character_tables.dart';
import '../../features/content/data/local/content_tables.dart';
import 'tables/core_tables.dart';

part 'app_database.g.dart';

/// 客户端本地数据库。本地数据是离线优先应用的事实来源，网络同步只把远端变化
/// 合并到本地表，UI 永远只读本地。
@DriftDatabase(
  tables: [
    ServerProfiles,
    SyncOutbox,
    SyncCursors,
    MigrationMarkers,
    VaultEntityRevisions,
    LocalContentPackages,
    LocalContentEntries,
    LocalContentAssets,
    ContentLinks,
    ContentFavorites,
    ContentNotes,
    ContentReadHistory,
    Characters,
    CharacterContentRefs,
    CampaignCharactersCache,
    CampaignCharacterBacklinks,
    CampaignContentCache,
    CampaignSyncCursors,
    CharacterSyncConflicts,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection('app.db'));

  AppDatabase.named(String databaseName) : super(_openConnection(databaseName));

  /// 测试与内存数据库构造器。
  @visibleForTesting
  AppDatabase.forTesting(super.executor) {
    // Widget suites intentionally create isolated in-memory databases in one
    // process. They never share an executor, so Drift's production warning is
    // noise in this constructor only.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }

  @override
  int get schemaVersion => 14;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(localContentPackages);
        await m.createTable(localContentEntries);
        await m.createTable(localContentAssets);
        await m.createTable(contentLinks);
        await m.createTable(contentFavorites);
        await m.createTable(contentNotes);
        await m.createTable(contentReadHistory);
      }
      if (from < 3) {
        await m.createTable(characters);
        await m.createTable(characterContentRefs);
      }
      if (from < 4) {
        await m.createTable(campaignCharactersCache);
        await m.createTable(campaignCharacterBacklinks);
        await m.createTable(campaignContentCache);
        await m.createTable(campaignSyncCursors);
        await m.createTable(characterSyncConflicts);
      }
      if (from < 5) {
        await m.createTable(vaultEntityRevisions);
      }
      // `from >= 2` 是必需的：`from < 2` 已按**当前** schema 建
      // `local_content_entries`（含 rules_json / relations_json），再加一次会重复列。
      // 同一原因，所有"补列"分支都必须以"建表分支"的 `from >=` 为守卫。
      if (from >= 2 && from < 6) {
        await m.addColumn(localContentEntries, localContentEntries.rulesJson);
      }
      if (from >= 2 && from < 7) {
        await m.addColumn(
          localContentEntries,
          localContentEntries.relationsJson,
        );
      }
      if (from < 8) {
        // Schema v8: characterContentRefs 主键从 {characterId, slot} 改为
        // {characterId, entryKey}。旧主键导致同 kind 的多个 grant (如多个
        // feature) 主键冲突 (SqliteException 1555)。重建表以应用新主键;
        // 旧 refs 数据丢弃, 角色会在下次打开时重新解析 contentReferences。
        await m.alterTable(TableMigration(characterContentRefs));
      }
      if (from < 9) {
        await m.addColumn(serverProfiles, serverProfiles.localAlias);
      }
      if (from >= 3 && from < 10) {
        await m.addColumn(characters, characters.markdownMirror);
      }
      if (from >= 3 && from < 11) {
        await m.addColumn(characters, characters.markdownDirty);
      }
      if (from >= 4 && from < 12) {
        await customStatement(
          'ALTER TABLE campaign_actors_cache '
          'RENAME TO campaign_characters_cache',
        );
        await customStatement(
          'ALTER TABLE campaign_characters_cache '
          'RENAME COLUMN actor_type TO character_type',
        );
        await customStatement(
          'ALTER TABLE campaign_actor_backlinks '
          'RENAME TO campaign_character_backlinks',
        );
        await customStatement(
          'ALTER TABLE campaign_character_backlinks '
          'RENAME COLUMN campaign_actor_id TO campaign_character_id',
        );
        await customStatement(
          'ALTER TABLE campaign_character_backlinks '
          'RENAME COLUMN last_applied_actor_revision '
          'TO last_applied_character_revision',
        );
        await customStatement(
          'ALTER TABLE character_sync_conflicts '
          'RENAME COLUMN campaign_actor_id TO campaign_character_id',
        );
        await customStatement(
          'DROP INDEX IF EXISTS idx_campaign_actors_campaign_status',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_campaign_characters_campaign_status '
          'ON campaign_characters_cache (campaign_id, status)',
        );
      }
      if (from >= 4 && from < 13) {
        await m.addColumn(
          campaignCharactersCache,
          campaignCharactersCache.visibleToPlayers,
        );
      }
      if (from >= 2 && from < 14) {
        // Schema v14: local_content_packages.priority（S3 规则覆盖优先级）。
        // 默认 0，老包升级后 tier 仍是 100，任何角色数值都不变。
        // `from >= 2` 是必需的：`from < 2` 时上面的 createTable 已经按**当前**
        // schema 建表（含 priority），再加一次会重复列。
        await m.addColumn(
          localContentPackages,
          localContentPackages.priority,
        );
      }
    },
  );

  static QueryExecutor _openConnection(String databaseName) {
    return driftDatabase(
      name: databaseName,
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.dart.js'),
      ),
    );
  }
}
