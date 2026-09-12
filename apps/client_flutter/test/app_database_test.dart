import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('opens an empty schema at version fourteen', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    expect(database.schemaVersion, 14);
    expect(await database.select(database.serverProfiles).get(), isEmpty);
    expect(await database.select(database.syncOutbox).get(), isEmpty);
    expect(await database.select(database.localContentPackages).get(), isEmpty);
    expect(await database.select(database.localContentEntries).get(), isEmpty);
    expect(await database.select(database.characters).get(), isEmpty);
    expect(await database.select(database.characterContentRefs).get(), isEmpty);
    expect(
      await database.select(database.campaignCharactersCache).get(),
      isEmpty,
    );
    expect(await database.select(database.campaignContentCache).get(), isEmpty);
    expect(await database.select(database.campaignSyncCursors).get(), isEmpty);
    expect(
      await database.select(database.characterSyncConflicts).get(),
      isEmpty,
    );
    expect(await database.select(database.vaultEntityRevisions).get(), isEmpty);
    await database.close();
  });

  test('migrates a v1 database without duplicating columns', () async {
    // v1 只有 serverProfiles（没有任何迁移分支 createTable 它；from < 9 会给它
    // 加 local_alias）。从 v1 升到 v14 会依次经过 `from < 2`（建内容表）与
    // `from < 3`（建 characters）——这两处的 `createTable` 用的是**当前** schema，
    // 因此后面所有 `addColumn` 都必须有 `from >=` 守卫，否则重复列。
    final sqlite = sqlite3.openInMemory();
    sqlite
      ..execute('''
        CREATE TABLE server_profiles (
          id TEXT PRIMARY KEY NOT NULL,
          name TEXT NOT NULL,
          base_url TEXT NOT NULL,
          api_base_url TEXT NOT NULL,
          websocket_url TEXT NOT NULL,
          last_known_version TEXT NOT NULL DEFAULT '',
          is_default INTEGER NOT NULL DEFAULT 0,
          last_connected_at INTEGER
        )
      ''')
      ..execute(
        "INSERT INTO server_profiles VALUES "
        "('localhost', 'Local', 'http://localhost:3000', "
        "'http://localhost:3000/api', 'ws://localhost:3000', '', 1, NULL)",
      )
      ..execute('PRAGMA user_version = 1');

    final database = AppDatabase.forTesting(NativeDatabase.opened(sqlite));

    // v1 → v14 全链路必须成功（任何 duplicate column 都会在首次查询时抛错）。
    final profiles = await database.select(database.serverProfiles).get();
    expect(profiles.single.id, 'localhost');
    expect(profiles.single.localAlias, isNull);

    // `from < 2` 按当前 schema 建的 local_content_packages 已经带 priority，
    // `from >= 2 && from < 14` 因此跳过 addColumn：建表与迁移不冲突。
    await database
        .into(database.localContentPackages)
        .insert(
          LocalContentPackagesCompanion.insert(
            id: 'fresh',
            formatVersion: 3,
            name: 'Fresh',
            version: '1.0.0',
            locale: 'zh-CN',
            system: 'dnd5e-2024',
            entryCount: 0,
            contentHash: 'hash',
            installedAt: DateTime.utc(2026, 9, 12),
          ),
        );
    final packages = await database.select(database.localContentPackages).get();
    expect(packages.single.priority, 0);

    await database.close();
  });

  test('migrates legacy actor cache names without losing rows', () async {
    final sqlite = sqlite3.openInMemory();
    sqlite
      ..execute('''
        CREATE TABLE campaign_actors_cache (
          id TEXT PRIMARY KEY NOT NULL,
          campaign_id TEXT NOT NULL,
          owner_user_id TEXT,
          source_character_id TEXT,
          actor_type TEXT NOT NULL,
          status TEXT NOT NULL,
          sheet_json TEXT NOT NULL,
          revision INTEGER NOT NULL,
          updated_by TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''')
      ..execute('''
        CREATE INDEX idx_campaign_actors_campaign_status
        ON campaign_actors_cache (campaign_id, status)
      ''')
      ..execute('''
        CREATE TABLE campaign_actor_backlinks (
          campaign_actor_id TEXT PRIMARY KEY NOT NULL,
          source_character_id TEXT NOT NULL,
          last_published_local_revision INTEGER NOT NULL DEFAULT 0,
          last_applied_actor_revision INTEGER NOT NULL DEFAULT 0
        )
      ''')
      ..execute('''
        CREATE TABLE character_sync_conflicts (
          id TEXT PRIMARY KEY NOT NULL,
          character_id TEXT NOT NULL,
          campaign_actor_id TEXT NOT NULL,
          field_path TEXT NOT NULL,
          local_value_json TEXT NOT NULL DEFAULT '{}',
          remote_value_json TEXT NOT NULL DEFAULT '{}',
          resolved_at INTEGER,
          created_at INTEGER NOT NULL
        )
      ''')
      ..execute('''
        CREATE TABLE characters (
          id TEXT PRIMARY KEY NOT NULL,
          owner_local_id TEXT NOT NULL DEFAULT 'local',
          sheet_json TEXT NOT NULL,
          markdown_mirror TEXT,
          revision INTEGER NOT NULL DEFAULT 1,
          sync_revision INTEGER,
          archived_at INTEGER,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''')
      // v11 的真实存档一定有 local_content_packages（v2 引入）；迁移链里
      // `from < 14` 会 ADD COLUMN priority，因此这份最小 fixture 也必须带上它，
      // 否则测的是"表不存在"而不是迁移本身。
      ..execute('''
        CREATE TABLE local_content_packages (
          id TEXT PRIMARY KEY NOT NULL,
          format_version INTEGER NOT NULL,
          name TEXT NOT NULL,
          version TEXT NOT NULL,
          locale TEXT NOT NULL,
          system TEXT NOT NULL,
          entry_count INTEGER NOT NULL,
          content_hash TEXT NOT NULL,
          enabled INTEGER NOT NULL DEFAULT 1,
          installed_at INTEGER NOT NULL
        )
      ''')
      ..execute(
        "INSERT INTO local_content_packages VALUES "
        "('legacy-pack', 3, 'Legacy', '1.0.0', 'zh-CN', 'dnd5e-2024', 1, "
        "'hash', 1, 0)",
      )
      ..execute(
        "INSERT INTO campaign_actors_cache VALUES "
        "('character-1', 'campaign-1', NULL, NULL, 'npc', 'active', '{}', "
        "1, 'user-1', 0, 0)",
      )
      ..execute('PRAGMA user_version = 11');

    final database = AppDatabase.forTesting(NativeDatabase.opened(sqlite));
    final rows = await database.select(database.campaignCharactersCache).get();

    expect(rows.single.id, 'character-1');
    expect(rows.single.characterType, 'npc');
    // v11 → v14 迁移后老包的 priority 取默认 0（tier 仍为 100，数值不变）。
    final packages = await database.select(database.localContentPackages).get();
    expect(packages.single.priority, 0);
    await database.close();
  });
}
