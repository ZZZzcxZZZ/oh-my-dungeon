import 'package:dnd_table_client/src/features/characters/data/legacy_character_importer.dart';
import 'package:dnd_table_client/src/features/vault/domain/vault_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/character_test_support.dart';

void main() {
  const session = VaultSession(
    remoteUserId: 'user-1',
    deviceId: 'device-1',
    baseUrl: 'https://table.example',
    accessToken: 'token',
  );

  test('imports legacy remote characters once and preserves local conflicts',
      () async {
    final localArannis = testCharacter(
      id: 'character-1',
      name: 'Arannis',
      notes: 'Keep local notes',
    );
    final remoteArannis = testCharacter(
      id: 'character-1',
      name: 'Arannis',
      notes: 'Remote notes',
    );
    final remoteBorin = testCharacter(
      id: 'character-2',
      name: 'Borin',
      notes: '',
    );
    final local = MemoryCharacterRepository(initial: [localArannis]);
    final legacy = MemoryLegacyCharacterClient(
      characters: [remoteArannis, remoteBorin],
    );
    final markers = MemoryMigrationMarkers();
    final importer = LegacyCharacterImporter(local, legacy, markers);

    await importer.run(session);
    await importer.run(session);

    expect((await local.getById(localArannis.id))!.notes, localArannis.notes);
    expect(await local.getById(remoteBorin.id), isNotNull);
    expect(markers.completed, contains('legacy-characters:table.example:user-1'));
  });

  test('copies conflicting remote character with new id and suffix', () async {
    final localCharacter = testCharacter(
      id: 'character-1',
      name: 'Arannis',
      notes: 'Local',
    );
    final remoteCharacter = testCharacter(
      id: 'character-1',
      name: 'Arannis',
      notes: 'Different remote content',
    );
    final local = MemoryCharacterRepository(initial: [localCharacter]);
    final legacy = MemoryLegacyCharacterClient(characters: [remoteCharacter]);
    final markers = MemoryMigrationMarkers();
    final importer = LegacyCharacterImporter(local, legacy, markers);

    await importer.run(session);

    final all = await local.watchOwnedCharacters().first;
    // Should have 2 characters: the original local + the copied remote
    expect(all, hasLength(2));
    final copied = all.firstWhere((c) => c.id != 'character-1');
    expect(copied.name, contains('（服务器导入）'));
    expect(copied.notes, 'Different remote content');
  });

  test('does not write marker on failure', () async {
    final legacy = MemoryLegacyCharacterClient(throwOnList: true);
    final local = MemoryCharacterRepository();
    final markers = MemoryMigrationMarkers();
    final importer = LegacyCharacterImporter(local, legacy, markers);

    expect(() => importer.run(session), throwsA(isA<Exception>()));
    // Wait for the throw to propagate
    await Future.delayed(const Duration(milliseconds: 100));
    expect(markers.completed, isEmpty);
  });
}
