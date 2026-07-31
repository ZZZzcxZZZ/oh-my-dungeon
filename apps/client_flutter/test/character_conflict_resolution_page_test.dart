import 'dart:async';
import 'dart:convert';

import 'package:dnd_table_client/src/features/characters/data/local/character_sync_conflict_repository.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_conflict_banner_controller.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_conflict_resolution_page.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/character_test_support.dart';

void main() {
  testWidgets('shows empty state when no unresolved conflicts exist', (
    tester,
  ) async {
    final repository = _MemoryConflictRepository();
    final banner = CharacterConflictBannerController(repository: repository);
    await Future.microtask(() {});
    await Future.microtask(() {});

    repository.emit(const []);
    await Future.microtask(() {});
    await Future.microtask(() {});

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterConflictResolutionPage(
          controller: banner,
          characterController: _emptyController(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('没有未解决的同步冲突'), findsOneWidget);
    banner.dispose();
  });

  testWidgets('lists each conflict with local and remote HP', (tester) async {
    final repository = _MemoryConflictRepository();
    final banner = CharacterConflictBannerController(repository: repository);
    // 让 stream subscription 注册
    await Future.microtask(() {});
    await Future.microtask(() {});

    repository.emit([
      _conflict(
        id: 'c1',
        characterId: 'char-1',
        localSheet: {'name': 'Mira', 'currentHp': 18, 'maxHp': 20},
        remoteSheet: {'name': 'Mira', 'currentHp': 5, 'maxHp': 20},
      ),
    ]);
    await Future.microtask(() {});
    await Future.microtask(() {});

    final characterController = CharacterController(
      repository: MemoryCharacterRepository(
        initial: [testCharacter(id: 'char-1', name: 'Mira')],
      ),
    );
    await Future.microtask(() {});
    await Future.microtask(() {});

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterConflictResolutionPage(
          controller: banner,
          characterController: characterController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('conflict-card-c1')), findsOneWidget);
    expect(find.text('Mira'), findsNWidgets(3));
    expect(find.text('HP 18/20'), findsOneWidget);
    expect(find.text('HP 5/20'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '用本地覆盖'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '用远端覆盖'), findsOneWidget);

    characterController.dispose();
    banner.dispose();
  });

  testWidgets('use local button calls markResolved after publish success', (
    tester,
  ) async {
    final repository = _MemoryConflictRepository();
    final banner = CharacterConflictBannerController(repository: repository);
    await Future.microtask(() {});
    await Future.microtask(() {});

    repository.emit([
      _conflict(
        id: 'c1',
        characterId: 'char-1',
        localSheet: {'name': 'Mira', 'currentHp': 18, 'maxHp': 20},
        remoteSheet: {
          'name': 'Mira',
          'revision': 3,
          'currentHp': 5,
          'maxHp': 20,
        },
      ),
    ]);
    await Future.microtask(() {});
    await Future.microtask(() {});

    final characterController = CharacterController(
      repository: MemoryCharacterRepository(
        initial: [testCharacter(id: 'char-1', name: 'Mira')],
      ),
    );
    await Future.microtask(() {});
    await Future.microtask(() {});

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterConflictResolutionPage(
          controller: banner,
          characterController: characterController,
          campaignCharacterController: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '用本地覆盖'));
    await tester.pumpAndSettle();

    // characterController 为空时提示 "未连接到战役，无法覆盖"，不应 markResolved。
    expect(repository.markResolvedCalls, isEmpty);
    expect(find.text('未连接到战役，无法覆盖'), findsOneWidget);

    characterController.dispose();
    banner.dispose();
  });

  testWidgets('use remote marks resolved only after applying remote data', (
    tester,
  ) async {
    final repository = _MemoryConflictRepository();
    final banner = CharacterConflictBannerController(repository: repository);
    await Future.microtask(() {});
    await Future.microtask(() {});

    repository.emit([
      _conflict(
        id: 'c1',
        characterId: 'char-1',
        localSheet: {'name': 'Mira', 'currentHp': 18, 'maxHp': 20},
        remoteSheet: {'name': 'Mira', 'currentHp': 5, 'maxHp': 20},
      ),
    ]);
    await Future.microtask(() {});
    await Future.microtask(() {});

    final characterController = CharacterController(
      repository: MemoryCharacterRepository(
        initial: [testCharacter(id: 'char-1', name: 'Mira')],
      ),
    );
    await Future.microtask(() {});
    await Future.microtask(() {});

    await tester.pumpWidget(
      MaterialApp(
        home: CharacterConflictResolutionPage(
          controller: banner,
          characterController: characterController,
          onUseRemote: (conflict) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '用远端覆盖'));
    await tester.pumpAndSettle();

    expect(repository.markResolvedCalls, ['c1']);
    expect(find.text('已用远端版本覆盖'), findsOneWidget);

    characterController.dispose();
    banner.dispose();
  });
}

CharacterController _emptyController() {
  return CharacterController(repository: MemoryCharacterRepository());
}

CharacterSyncConflict _conflict({
  required String id,
  required String characterId,
  required Map<String, Object?> localSheet,
  required Map<String, Object?> remoteSheet,
}) {
  return CharacterSyncConflict(
    id: id,
    characterId: characterId,
    campaignCharacterId: 'character-$id',
    fieldPath: 'build',
    localValueJson: jsonEncode(localSheet),
    remoteValueJson: jsonEncode(remoteSheet),
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
