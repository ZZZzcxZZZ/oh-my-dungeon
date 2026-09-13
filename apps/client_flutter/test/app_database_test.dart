import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// 打开一个"**当前** schema 建表、再退化成某个旧版本形状"的内存库。
///
/// 做法：先用当前 schema 建全库，再按版本删掉"该版本之后才引入"的表 / 列，并把
/// v12 之前的 actor 命名还原回去，最后 `PRAGMA user_version = version`。这样迁移
/// 链看到的形状与真实旧存档一致，而不必手写 14 张表的完整 DDL。
///
/// [dropTables]：v 版本还不存在的表（迁移链会 `createTable`，存在会重复建表）。
/// [dropColumns]：`table.column`（迁移链会 `addColumn`，存在会重复列）。
/// [oldCampaignNames]：`from >= 4 && from < 12` 的真实旧存档是 actor 命名。
Future<AppDatabase> openLegacyDatabase(
  int version, {
  List<String> dropTables = const <String>[],
  List<String> dropColumns = const <String>[],
  bool oldCampaignNames = false,
}) async {
  final sqlite = sqlite3.openInMemory();
  final bootstrap = AppDatabase.forTesting(
    NativeDatabase.opened(sqlite, closeUnderlyingOnClose: false),
  );
  // 触发 `onCreate`（当前 schema 建表）。
  await bootstrap.customSelect('SELECT 1').get();
  await bootstrap.close();

  for (final table in dropTables) {
    sqlite.execute('DROP TABLE IF EXISTS $table');
  }
  // 先按**当前**表名删列（旧命名还原会让 `campaign_characters_cache` 改名）。
  for (final column in dropColumns) {
    final split = column.lastIndexOf('.');
    sqlite.execute(
      'ALTER TABLE ${column.substring(0, split)} '
      'DROP COLUMN ${column.substring(split + 1)}',
    );
  }
  if (oldCampaignNames) {
    sqlite
      ..execute(
        'DROP INDEX IF EXISTS idx_campaign_characters_campaign_status',
      )
      ..execute('DROP INDEX IF EXISTS idx_campaign_actors_campaign_status')
      ..execute(
        'ALTER TABLE campaign_characters_cache RENAME TO campaign_actors_cache',
      )
      ..execute(
        'ALTER TABLE campaign_actors_cache '
        'RENAME COLUMN character_type TO actor_type',
      )
      ..execute(
        'ALTER TABLE campaign_character_backlinks '
        'RENAME TO campaign_actor_backlinks',
      )
      ..execute(
        'ALTER TABLE campaign_actor_backlinks '
        'RENAME COLUMN campaign_character_id TO campaign_actor_id',
      )
      ..execute(
        'ALTER TABLE campaign_actor_backlinks '
        'RENAME COLUMN last_applied_character_revision '
        'TO last_applied_actor_revision',
      )
      ..execute(
        'ALTER TABLE character_sync_conflicts '
        'RENAME COLUMN campaign_character_id TO campaign_actor_id',
      );
  }
  sqlite.execute('PRAGMA user_version = $version');
  return AppDatabase.forTesting(NativeDatabase.opened(sqlite));
}

/// 版本 < 12 的真实旧存档里，五张战役缓存的表还没改名。
const _legacyCampaignTables = <String>[
  'campaign_characters_cache',
  'campaign_character_backlinks',
  'campaign_content_cache',
  'campaign_sync_cursors',
  'character_sync_conflicts',
];

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
          markdown_dirty INTEGER NOT NULL DEFAULT 0,
          revision INTEGER NOT NULL DEFAULT 1,
          sync_revision INTEGER,
          archived_at INTEGER,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''')
      ..execute(
        "INSERT INTO characters VALUES "
        "('char-1', 'local', '{}', NULL, 1, 1, NULL, NULL, 0, 0)",
      )
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
    // v11 夹具带上 `markdown_dirty`（v11 实有），迁移必须原样保留它的值。
    final characters = await database.select(database.characters).get();
    expect(characters.single.markdownDirty, isTrue);
    expect(characters.single.markdownMirror, isNull);
    await database.close();
  });

  // ── 迁移链边界（0.4 审查项：补 2/3/5/6/9/10 → 14 的正向路径） ──

  test('migrates a v2 database: entries 补列 + characters 建表（守卫边界）', () async {
    final database = await openLegacyDatabase(
      2,
      dropTables: <String>[
        'characters',
        'character_content_refs',
        ..._legacyCampaignTables,
        'vault_entity_revisions',
      ],
      dropColumns: <String>[
        'local_content_packages.priority',
        'local_content_entries.rules_json',
        'local_content_entries.relations_json',
        'server_profiles.local_alias',
      ],
    );

    expect(database.schemaVersion, 14);
    // `from < 2` 不成立：内容表必须已存在，且 `from >= 2` 守卫下补两列。
    await database
        .into(database.localContentEntries)
        .insert(
          LocalContentEntriesCompanion.insert(
            entryKey: 'legacy:spell/fireball',
            packageId: 'legacy',
            type: 'spell',
            slug: 'fireball',
            name: '火球术',
            revision: 1,
          ),
        );
    final entry = (await database.select(
      database.localContentEntries,
    ).get()).single;
    expect(entry.rulesJson, '{}');
    expect(entry.relationsJson, '[]');
    // `from < 3` 建了 characters（当前 schema）。
    await database
        .into(database.characters)
        .insert(CharactersCompanion.insert(id: 'char-1', sheetJson: '{}'));
    expect(
      (await database.select(database.characters).get()).single.markdownDirty,
      isFalse,
    );
    await database.close();
  });

  test('migrates a v3 database: characters 补 markdown_mirror 与 markdown_dirty', () async {
    final database = await openLegacyDatabase(
      3,
      dropTables: <String>[..._legacyCampaignTables, 'vault_entity_revisions'],
      dropColumns: <String>[
        'local_content_packages.priority',
        'local_content_entries.rules_json',
        'local_content_entries.relations_json',
        'server_profiles.local_alias',
        'characters.markdown_mirror',
        'characters.markdown_dirty',
      ],
    );

    // v3 已有 characters；`from >= 3 && from < 10/11` 补齐两个补列。
    await database
        .into(database.characters)
        .insert(CharactersCompanion.insert(id: 'char-1', sheetJson: '{}'));
    final character = (await database.select(database.characters).get()).single;
    expect(character.markdownMirror, isNull);
    expect(character.markdownDirty, isFalse, reason: '补列默认 false');
    await database.close();
  });

  test('migrates a v10 database: 只缺 markdown_dirty / priority / visible_to_players', () async {
    final database = await openLegacyDatabase(
      10,
      dropColumns: <String>[
        'local_content_packages.priority',
        'characters.markdown_dirty',
        'campaign_characters_cache.visible_to_players',
      ],
      oldCampaignNames: true,
    );

    // v10 已有 markdown_mirror，只补 markdown_dirty（`from >= 3 && from < 11`）。
    await database
        .into(database.characters)
        .insert(
          CharactersCompanion.insert(
            id: 'char-1',
            sheetJson: '{}',
            markdownMirror: const Value('老镜像'),
          ),
        );
    final character = (await database.select(database.characters).get()).single;
    expect(character.markdownMirror, '老镜像', reason: '已有列原样保留');
    expect(character.markdownDirty, isFalse);
    // `from >= 4 && from < 13` 补 visible_to_players（查询会引用该列）。
    expect(
      await database.select(database.campaignCharactersCache).get(),
      isEmpty,
    );
    await database.close();
  });

  test('migrates a v5 database: entries 补 rules_json 与 relations_json', () async {
    final database = await openLegacyDatabase(
      5,
      dropColumns: <String>[
        'local_content_packages.priority',
        'local_content_entries.rules_json',
        'local_content_entries.relations_json',
        'server_profiles.local_alias',
        'characters.markdown_mirror',
        'characters.markdown_dirty',
        'campaign_characters_cache.visible_to_players',
      ],
      oldCampaignNames: true,
    );

    await database
        .into(database.localContentEntries)
        .insert(
          LocalContentEntriesCompanion.insert(
            entryKey: 'legacy:class/fighter',
            packageId: 'legacy',
            type: 'class',
            slug: 'fighter',
            name: '战士',
            revision: 1,
          ),
        );
    final entry = (await database.select(
      database.localContentEntries,
    ).get()).single;
    expect(entry.rulesJson, '{}', reason: '`from >= 2 && from < 6` 补列');
    expect(entry.relationsJson, '[]', reason: '`from >= 2 && from < 7` 补列');
    await database.close();
  });

  test('migrates a v6 database: entries 只缺 relations_json', () async {
    final database = await openLegacyDatabase(
      6,
      dropColumns: <String>[
        'local_content_packages.priority',
        'local_content_entries.relations_json',
        'server_profiles.local_alias',
        'characters.markdown_mirror',
        'characters.markdown_dirty',
        'campaign_characters_cache.visible_to_players',
      ],
      oldCampaignNames: true,
    );

    // v6 已有 rules_json：`from >= 2 && from < 7` 只补 relations_json。
    await database
        .into(database.localContentEntries)
        .insert(
          LocalContentEntriesCompanion.insert(
            entryKey: 'legacy:class/fighter',
            packageId: 'legacy',
            type: 'class',
            slug: 'fighter',
            name: '战士',
            revision: 1,
            rulesJson: const Value('{"hitDie":10}'),
          ),
        );
    final entry = (await database.select(
      database.localContentEntries,
    ).get()).single;
    expect(entry.rulesJson, '{"hitDie":10}', reason: '已有列原样保留');
    expect(entry.relationsJson, '[]');
    await database.close();
  });

  test('migrates a v9 database: local_alias 已在，补 priority 与 visible_to_players', () async {
    final database = await openLegacyDatabase(
      9,
      dropColumns: <String>[
        'local_content_packages.priority',
        'characters.markdown_mirror',
        'characters.markdown_dirty',
        'campaign_characters_cache.visible_to_players',
      ],
      oldCampaignNames: true,
    );

    await database
        .into(database.serverProfiles)
        .insert(
          ServerProfilesCompanion.insert(
            id: 'localhost',
            name: 'Local',
            baseUrl: 'http://localhost:3000',
            apiBaseUrl: 'http://localhost:3000/api',
            websocketUrl: 'ws://localhost:3000',
          ),
        );
    final profile = (await database.select(
      database.serverProfiles,
    ).get()).single;
    expect(profile.localAlias, isNull, reason: 'v9 已有该列（`from < 9` 才补）');
    // `from >= 4 && from < 13` 补 visible_to_players（查询会引用该列）。
    expect(
      await database.select(database.campaignCharactersCache).get(),
      isEmpty,
    );
    await database.close();
  });
}
