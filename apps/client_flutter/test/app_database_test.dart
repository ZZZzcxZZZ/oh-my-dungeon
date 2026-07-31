import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('opens an empty schema at version thirteen', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    expect(database.schemaVersion, 13);
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
    await database.close();
  });
}
