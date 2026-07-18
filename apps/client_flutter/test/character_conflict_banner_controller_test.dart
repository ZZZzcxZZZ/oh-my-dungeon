import 'dart:async';

import 'package:dnd_table_client/src/features/characters/data/local/character_sync_conflict_repository.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_conflict_banner_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _MemoryConflictRepository repository;
  late CharacterConflictBannerController controller;

  setUp(() {
    repository = _MemoryConflictRepository();
    controller = CharacterConflictBannerController(repository: repository);
  });

  tearDown(() {
    controller.dispose();
  });

  test('emits unresolved count from repository stream', () async {
    repository.emit([
      _conflict('c1', 'char-1'),
      _conflict('c2', 'char-1'),
      _conflict('c3', 'char-2'),
    ]);
    await Future.microtask(() {});
    await Future.microtask(() {});

    expect(controller.unresolvedCount, 3);
    expect(controller.hasUnresolved, isTrue);
  });

  test('updates when repository emits new state', () async {
    repository.emit([_conflict('c1', 'char-1')]);
    await Future.microtask(() {});
    await Future.microtask(() {});
    expect(controller.unresolvedCount, 1);

    repository.emit([_conflict('c1', 'char-1'), _conflict('c2', 'char-2')]);
    await Future.microtask(() {});
    await Future.microtask(() {});
    expect(controller.unresolvedCount, 2);
  });

  test('markResolved delegates to repository', () async {
    repository.emit([_conflict('c1', 'char-1')]);
    await Future.microtask(() {});
    await Future.microtask(() {});

    await controller.markResolved('c1');

    expect(repository.markResolvedCalls, ['c1']);
  });

  test('hasUnresolved is false when empty', () async {
    repository.emit(const []);
    await Future.microtask(() {});
    await Future.microtask(() {});

    expect(controller.hasUnresolved, isFalse);
    expect(controller.unresolvedCount, 0);
  });
}

CharacterSyncConflict _conflict(String id, String characterId) {
  return CharacterSyncConflict(
    id: id,
    characterId: characterId,
    campaignActorId: 'actor-$id',
    fieldPath: 'build',
    localValueJson: '{}',
    remoteValueJson: '{}',
    createdAt: DateTime(2026, 7, 15),
  );
}

class _MemoryConflictRepository implements CharacterSyncConflictRepository {
  final StreamController<List<CharacterSyncConflict>> _controller =
      StreamController<List<CharacterSyncConflict>>.broadcast();
  final List<String> markResolvedCalls = [];

  void emit(List<CharacterSyncConflict> conflicts) {
    _controller.add(conflicts);
  }

  @override
  Stream<List<CharacterSyncConflict>> watchUnresolved(String characterId) {
    throw UnimplementedError();
  }

  @override
  Stream<List<CharacterSyncConflict>> watchAllUnresolved() =>
      _controller.stream;

  @override
  Future<void> markResolved(String conflictId) async {
    markResolvedCalls.add(conflictId);
  }

  @override
  Future<void> clearForCharacter(String characterId) async {}
}
