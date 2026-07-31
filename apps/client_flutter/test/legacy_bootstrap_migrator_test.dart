import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:dnd_table_client/src/core/workspace/legacy_bootstrap_migrator.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('copies only legacy server profiles into bootstrap storage', () async {
    final legacy = AppDatabase.forTesting(NativeDatabase.memory());
    final bootstrap = AppDatabase.forTesting(NativeDatabase.memory());
    await legacy
        .into(legacy.serverProfiles)
        .insert(
          ServerProfilesCompanion.insert(
            id: 'server-1',
            name: 'Friday Table',
            baseUrl: 'https://table.example',
            apiBaseUrl: 'https://table.example/api',
            websocketUrl: 'wss://table.example',
            isDefault: const Value(true),
          ),
        );
    await legacy
        .into(legacy.characters)
        .insert(
          CharactersCompanion.insert(
            id: 'character-1',
            sheetJson: '{"id":"character-1"}',
          ),
        );

    final migrator = LegacyBootstrapMigrator(source: legacy, target: bootstrap);
    expect(await migrator.run(), isTrue);
    expect(await migrator.run(), isFalse);

    expect(
      await bootstrap.select(bootstrap.serverProfiles).get(),
      hasLength(1),
    );
    expect(await bootstrap.select(bootstrap.characters).get(), isEmpty);
    expect(await legacy.select(legacy.serverProfiles).get(), hasLength(1));

    await legacy.close();
    await bootstrap.close();
  });
}
