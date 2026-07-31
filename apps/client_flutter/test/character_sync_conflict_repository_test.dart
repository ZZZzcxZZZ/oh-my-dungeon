import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:dnd_table_client/src/features/characters/data/local/character_sync_conflict_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late CharacterSyncConflictRepository repository;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftCharacterSyncConflictRepository(database);
    // 插入 3 条冲突：2 个未解决（不同角色），1 个已解决。
    await _seedConflict(
      database,
      id: 'conflict-1',
      characterId: 'char-1',
      campaignCharacterId: 'character-1',
      resolvedAt: null,
    );
    await _seedConflict(
      database,
      id: 'conflict-2',
      characterId: 'char-1',
      campaignCharacterId: 'character-2',
      resolvedAt: null,
    );
    await _seedConflict(
      database,
      id: 'conflict-3',
      characterId: 'char-2',
      campaignCharacterId: 'character-3',
      resolvedAt: DateTime(2026, 7, 1),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'watchUnresolved emits only unresolved conflicts for the character',
    () async {
      final stream = repository.watchUnresolved('char-1');
      final first = await stream.first;

      expect(first, hasLength(2));
      expect(first.map((c) => c.id).toSet(), {'conflict-1', 'conflict-2'});
      for (final conflict in first) {
        expect(conflict.isResolved, isFalse);
      }
    },
  );

  test('watchAllUnresolved emits all unresolved across characters', () async {
    final stream = repository.watchAllUnresolved();
    final first = await stream.first;

    // char-2 的 conflict-3 已解决，应被过滤掉。
    expect(first, hasLength(2));
    expect(first.map((c) => c.characterId).toSet(), {'char-1'});
  });

  test('markResolved hides conflict from subsequent emissions', () async {
    final stream = repository.watchUnresolved('char-1');
    final first = await stream.first;
    expect(first, hasLength(2));

    await repository.markResolved('conflict-1');

    final second = await stream.first;
    expect(second, hasLength(1));
    expect(second.single.id, 'conflict-2');
  });

  test('clearForCharacter removes all conflicts for the character', () async {
    final stream = repository.watchUnresolved('char-1');
    expect((await stream.first), hasLength(2));

    await repository.clearForCharacter('char-1');

    final second = await stream.first;
    expect(second, isEmpty);
  });

  test('conflict fields map correctly from row to domain', () async {
    final stream = repository.watchUnresolved('char-1');
    final first = await stream.first;
    final conflict = first.singleWhere((c) => c.id == 'conflict-1');

    expect(conflict.characterId, 'char-1');
    expect(conflict.campaignCharacterId, 'character-1');
    expect(conflict.fieldPath, 'build');
    expect(conflict.localValueJson, contains('localSheet'));
    expect(conflict.remoteValueJson, contains('remoteSheet'));
    expect(conflict.createdAt, isNotNull);
    expect(conflict.resolvedAt, isNull);
  });
}

Future<void> _seedConflict(
  AppDatabase database, {
  required String id,
  required String characterId,
  required String campaignCharacterId,
  required DateTime? resolvedAt,
}) async {
  await database
      .into(database.characterSyncConflicts)
      .insert(
        CharacterSyncConflictsCompanion.insert(
          id: id,
          characterId: characterId,
          campaignCharacterId: campaignCharacterId,
          fieldPath: 'build',
          localValueJson: Value('{"localSheet": true}'),
          remoteValueJson: Value('{"remoteSheet": true}'),
          resolvedAt: Value(resolvedAt),
          createdAt: DateTime(2026, 7, 15),
        ),
      );
}
