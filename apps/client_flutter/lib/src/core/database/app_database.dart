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
    CampaignActorsCache,
    CampaignActorBacklinks,
    CampaignContentCache,
    CampaignSyncCursors,
    CharacterSyncConflicts,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// 测试与内存数据库构造器。
  @visibleForTesting
  AppDatabase.forTesting(super.executor) {
    // Widget suites intentionally create isolated in-memory databases in one
    // process. They never share an executor, so Drift's production warning is
    // noise in this constructor only.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }

  @override
  int get schemaVersion => 8;

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
        await m.createTable(campaignActorsCache);
        await m.createTable(campaignActorBacklinks);
        await m.createTable(campaignContentCache);
        await m.createTable(campaignSyncCursors);
        await m.createTable(characterSyncConflicts);
      }
      if (from < 5) {
        await m.createTable(vaultEntityRevisions);
      }
      if (from < 6) {
        await m.addColumn(localContentEntries, localContentEntries.rulesJson);
      }
      if (from < 7) {
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
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'app.db',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.dart.js'),
      ),
    );
  }
}
