import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:dnd_table_client/src/core/workspace/legacy_workspace_migrator.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('merges legacy private data into local exactly once', () async {
    final legacy = AppDatabase.forTesting(NativeDatabase.memory());
    final local = AppDatabase.forTesting(NativeDatabase.memory());

    await legacy
        .into(legacy.serverProfiles)
        .insert(
          ServerProfilesCompanion.insert(
            id: 'server-1',
            name: 'Table Server',
            baseUrl: 'https://table.example',
            apiBaseUrl: 'https://table.example/api',
            websocketUrl: 'wss://table.example',
          ),
        );
    await legacy
        .into(legacy.localContentPackages)
        .insert(
          LocalContentPackagesCompanion.insert(
            id: 'legacy-pack',
            formatVersion: 2,
            name: 'Legacy Pack',
            version: '1.0.0',
            locale: 'zh-CN',
            system: 'dnd5e-2024',
            entryCount: 0,
            contentHash: 'legacy-hash',
            installedAt: DateTime.utc(2026, 7, 29),
          ),
        );
    await legacy
        .into(legacy.characters)
        .insert(
          CharactersCompanion.insert(
            id: 'legacy-character',
            sheetJson: '{"id":"legacy-character","name":"Aria"}',
          ),
        );
    await local
        .into(local.characters)
        .insert(
          CharactersCompanion.insert(
            id: 'local-character',
            sheetJson: '{"id":"local-character","name":"Local"}',
          ),
        );

    final migrator = LegacyWorkspaceMigrator(source: legacy, target: local);
    expect(await migrator.run(), isTrue);
    expect(await migrator.run(), isFalse);

    final characterIds = (await local.select(local.characters).get())
        .map((row) => row.id)
        .toSet();
    expect(characterIds, {'legacy-character', 'local-character'});
    expect(await local.select(local.localContentPackages).get(), hasLength(1));
    expect(await local.select(local.serverProfiles).get(), isEmpty);
    expect(await legacy.select(legacy.characters).get(), hasLength(1));
    expect(
      await (local.select(local.migrationMarkers)
            ..where((row) => row.key.equals(LegacyWorkspaceMigrator.markerKey)))
          .getSingleOrNull(),
      isNotNull,
    );

    await legacy.close();
    await local.close();
  });

  test('writes no marker when copying fails', () async {
    final legacy = AppDatabase.forTesting(NativeDatabase.memory());
    final local = AppDatabase.forTesting(NativeDatabase.memory());
    await legacy
        .into(legacy.characters)
        .insert(
          CharactersCompanion.insert(
            id: 'duplicate',
            sheetJson: '{"id":"duplicate","name":"Legacy"}',
          ),
        );
    await local
        .into(local.characters)
        .insert(
          CharactersCompanion.insert(
            id: 'duplicate',
            sheetJson: '{"id":"duplicate","name":"Local"}',
          ),
        );

    final migrator = LegacyWorkspaceMigrator(
      source: legacy,
      target: local,
      failAfterCopyForTesting: true,
    );
    await expectLater(migrator.run(), throwsStateError);
    expect(await local.select(local.migrationMarkers).get(), isEmpty);
    expect(
      (await local.select(local.characters).getSingle()).sheetJson,
      contains('"Local"'),
    );

    await legacy.close();
    await local.close();
  });
}
