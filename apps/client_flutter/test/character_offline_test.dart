import 'dart:convert';

import 'package:dnd_table_client/src/features/characters/data/character_repository.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_controller.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_editor_page.dart';
import 'package:dnd_table_client/src/features/characters/presentation/characters_tab_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/character_test_support.dart';

Widget buildOfflineCharacterApp(CharacterRepository repository) {
  return MaterialApp(
    home: CharactersTabPage(
      controller: CharacterController(repository: repository),
    ),
  );
}

void main() {
  testWidgets('creates and edits a character without an auth session', (tester) async {
    final repository = MemoryCharacterRepository();
    final controller = CharacterController(repository: repository);
    // Task 1.3: 编辑器现在默认进入"选择创建方式"页面, 此处直接构造
    // CharacterEditorPage 并指定 fullSheet 流程, 以保持测试聚焦于离线创建/编辑能力。
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterEditorPage(
          defaultCreationMethod: 'fullSheet',
          onSubmit: (draft) async {
            final success = await controller.createCharacter(draft);
            return success;
          },
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('character-name')), 'Arannis');
    await tester.tap(find.widgetWithText(FilledButton, '保存角色'));
    await tester.pumpAndSettle();
    expect(find.text('Arannis'), findsOneWidget);
    expect(await repository.getById('character-1'), isNotNull);
    controller.dispose();
  });

  testWidgets('shows existing local characters without login', (tester) async {
    final repository = MemoryCharacterRepository(
      initial: [testCharacter(id: 'c1', name: 'Existing Hero')],
    );
    await tester.pumpWidget(buildOfflineCharacterApp(repository));
    await tester.pumpAndSettle();
    expect(find.text('Existing Hero'), findsOneWidget);
  });

  // Spec §头像来源: 角色列表卡片应优先显示头像图片，无头像时退回首字母。
  testWidgets(
    'character list card shows avatar image when avatarUrl is set',
    (tester) async {
      final avatarUrl = Uri.dataFromBytes(
        base64Decode(_validPngBase64),
        mimeType: 'image/png',
      ).toString();
      final repository = MemoryCharacterRepository(
        initial: [
          testCharacter(id: 'c1', name: 'Hero').copyWith(avatarUrl: avatarUrl),
        ],
      );
      await tester.pumpWidget(buildOfflineCharacterApp(repository));
      await tester.pumpAndSettle();

      final avatar = tester.widget<CircleAvatar>(
        find.byKey(const Key('character-list-avatar-c1')),
      );
      expect(avatar.backgroundImage, isNotNull);
      expect(avatar.child, isNull);
    },
  );

  testWidgets(
    'character list card falls back to initial when no avatar',
    (tester) async {
      final repository = MemoryCharacterRepository(
        initial: [testCharacter(id: 'c1', name: 'Hero')],
      );
      await tester.pumpWidget(buildOfflineCharacterApp(repository));
      await tester.pumpAndSettle();

      final avatar = tester.widget<CircleAvatar>(
        find.byKey(const Key('character-list-avatar-c1')),
      );
      expect(avatar.backgroundImage, isNull);
      expect(avatar.child, isNotNull);
    },
  );
}

const _validPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8A'
    'AQUBAScY42YAAAAASUVORK5CYII=';
