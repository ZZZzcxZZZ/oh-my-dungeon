import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:dnd_table_client/src/core/sync/sync_repository.dart';
import 'package:dnd_table_client/src/features/characters/data/character_markdown_mirror_store_base.dart';
import 'package:dnd_table_client/src/features/characters/data/local/drift_character_repository.dart';
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/domain/character_content_reference.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/character_test_support.dart';

void main() {
  test(
    'creates a character and keeps a content snapshot after package removal',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = DriftCharacterRepository(database);
      final character = CharacterSheet.local(
        id: 'character-1',
        name: 'Arannis',
        level: 2,
        contentReferences: const [
          CharacterContentReference(
            slot: 'class',
            entryKey: 'example:class/fighter',
            sourceRevision: 1,
            snapshot: {'name': '战士', 'hitDie': 'd10'},
          ),
        ],
      );

      await repository.save(character);
      final loaded = await repository.getById('character-1');
      expect(loaded!.name, 'Arannis');
      expect(loaded.contentReferences.single.snapshot['name'], '战士');
      final row = await database.select(database.characters).getSingle();
      expect(row.markdownMirror, contains('# Arannis'));
      expect(row.markdownMirror, contains('format: dnd-table-character/v2'));
      await database.close();
    },
  );

  test('watches owned characters as a stream', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = DriftCharacterRepository(database);
    final emit = repository.watchOwnedCharacters().first;
    await repository.save(
      CharacterSheet.local(id: 'c1', name: 'Hero', level: 1),
    );
    final characters = await emit.timeout(const Duration(seconds: 1));
    expect(characters, hasLength(1));
    expect(characters.single.name, 'Hero');
    await database.close();
  });

  test('regenerates the readable Markdown mirror after every save', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = DriftCharacterRepository(database);
    final character = CharacterSheet.local(
      id: 'c1',
      name: 'Old Name',
      level: 1,
    );

    await repository.save(character);
    await repository.save(character.copyWith(name: 'New Name', notes: '新笔记'));

    final row = await database.select(database.characters).getSingle();
    expect(row.markdownMirror, contains('# New Name'));
    expect(row.markdownMirror, contains('新笔记'));
    expect(row.markdownMirror, isNot(contains('# Old Name')));
    await database.close();
  });

  test(
    'writes the latest Markdown to the workspace mirror after saving',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final mirror = _FakeMarkdownMirrorStore();
      final repository = DriftCharacterRepository(
        database,
        markdownMirrorStore: mirror,
      );
      final character = CharacterSheet.local(
        id: 'c1',
        name: 'Old Name',
        level: 1,
      );

      await repository.save(character);
      await repository.save(character.copyWith(name: 'New Name'));

      expect(mirror.values['c1'], contains('# New Name'));
      expect(mirror.values['c1'], contains('revision: 2'));
      final row = await database.select(database.characters).getSingle();
      expect(row.markdownDirty, isFalse);

      mirror.values['c1'] = mirror.values['c1']!.replaceAll(
        'New Name',
        'External Name',
      );
      final externalChanges = await repository.detectExternalMarkdownChanges();
      expect(externalChanges, hasLength(1));
      expect(externalChanges.single.existing.name, 'New Name');
      expect(externalChanges.single.imported.name, 'External Name');
      await database.close();
    },
  );

  test('keeps the character and marks a failed file mirror as dirty', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final mirror = _FakeMarkdownMirrorStore(shouldFail: true);
    final repository = DriftCharacterRepository(
      database,
      markdownMirrorStore: mirror,
    );

    await repository.save(
      CharacterSheet.local(id: 'c1', name: 'Hero', level: 1),
    );

    expect(await repository.getById('c1'), isNotNull);
    final row = await database.select(database.characters).getSingle();
    expect(row.markdownDirty, isTrue);

    mirror.shouldFail = false;
    await repository.repairMarkdownMirrors();
    final repaired = await database.select(database.characters).getSingle();
    expect(repaired.markdownDirty, isFalse);
    expect(mirror.values['c1'], contains('# Hero'));
    await database.close();
  });

  test('archives and deletes a character', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = DriftCharacterRepository(database);
    await repository.save(
      CharacterSheet.local(id: 'c1', name: 'Hero', level: 1),
    );
    await repository.archive('c1');
    var characters = await repository.watchOwnedCharacters().first;
    // Archived characters are excluded from watchOwnedCharacters
    expect(characters, isEmpty);
    await repository.delete('c1');
    expect(await repository.getById('c1'), isNull);
    await database.close();
  });

  test('upserts content references atomically on save', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = DriftCharacterRepository(database);
    await repository.save(
      CharacterSheet.local(
        id: 'c1',
        name: 'Hero',
        level: 1,
        contentReferences: const [
          CharacterContentReference(
            slot: 'class',
            entryKey: 'pkg:class/fighter',
            sourceRevision: 1,
            snapshot: {},
          ),
          CharacterContentReference(
            slot: 'race',
            entryKey: 'pkg:species/elf',
            sourceRevision: 1,
            snapshot: {},
          ),
        ],
      ),
    );
    // Save again with different references — old ones must be replaced
    await repository.save(
      CharacterSheet.local(
        id: 'c1',
        name: 'Hero',
        level: 1,
        contentReferences: const [
          CharacterContentReference(
            slot: 'class',
            entryKey: 'pkg:class/wizard',
            sourceRevision: 2,
            snapshot: {},
          ),
        ],
      ),
    );
    final loaded = await repository.getById('c1');
    expect(loaded!.contentReferences, hasLength(1));
    expect(loaded.contentReferences.single.entryKey, 'pkg:class/wizard');
    await database.close();
  });

  test(
    'saving a character writes the character and vault operation atomically',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = DriftCharacterRepository(database);
      final arannis = testCharacter(
        id: 'character-1',
        name: 'Arannis',
        notes: 'Local notes',
      );
      await repository.save(arannis);
      final pending = await DriftSyncRepository(
        database,
      ).pending(scope: 'vault');
      expect(pending, hasLength(1));
      expect(pending.single.entityType, 'character');
      expect(pending.single.entityId, arannis.id);
      await database.close();
    },
  );

  test(
    'uses the last remote revision and coalesces pending character edits',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = DriftCharacterRepository(database);
      final remote = testCharacter(id: 'character-1', notes: 'remote');
      await repository.saveRemote(remote, 7);

      await repository.save(remote.copyWith(notes: 'first local edit'));
      await repository.save(remote.copyWith(notes: 'latest local edit'));

      final pending = await DriftSyncRepository(
        database,
      ).pending(scope: 'vault');
      expect(pending, hasLength(1));
      expect(pending.single.baseRevision, 7);
      expect(pending.single.payloadJson, contains('latest local edit'));
      await database.close();
    },
  );
}

final class _FakeMarkdownMirrorStore implements CharacterMarkdownMirrorStore {
  _FakeMarkdownMirrorStore({this.shouldFail = false});

  bool shouldFail;
  final Map<String, String> values = {};

  @override
  Future<String?> read(String characterId) async => values[characterId];

  @override
  Future<void> write({
    required String characterId,
    required String markdown,
  }) async {
    if (shouldFail) throw StateError('disk unavailable');
    values[characterId] = markdown;
  }
}
