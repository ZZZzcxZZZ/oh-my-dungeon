import 'package:dnd_table_client/src/features/campaigns/presentation/characters/campaign_character_controller.dart';
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_controller.dart';
import 'package:dnd_table_client/src/features/characters/presentation/characters_tab_page.dart';
import 'package:dnd_table_client/src/features/client_mode/domain/client_mode.dart';
import 'package:dnd_table_client/src/features/content/data/local/content_repository.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_test_support.dart';
import 'support/character_test_support.dart';
import 'support/content_test_support.dart';

/// Spec §DM 角色生命周期: DM 模式下角色栏 FAB 应弹出菜单提供:
/// 1. 快速创建 NPC (常驻)
/// 2. 完整创建角色
/// 3. 从怪物模板创建可编辑角色
/// 一次性发言身份改用 speakerSnapshot 直接写入消息（Task 5.2），不再创建 Character。
void main() {
  const apiBaseUrl = 'http://localhost:3000/api';

  Future<CampaignCharacterController> buildCharacterController() async {
    final controller = CampaignCharacterController(
      cacheRepository: MemoryCampaignCacheRepository(),
      apiClient: MemoryCampaignSyncApiClient(),
      apiBaseUrl: apiBaseUrl,
      accessToken: 'access-token',
      currentUserId: 'user-1',
    );
    await controller.selectCampaign('camp-1');
    return controller;
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    required ClientModeController modeController,
    CampaignCharacterController? campaignCharacterController,
    ContentRepository? contentRepository,
  }) async {
    final localCharacterController = CharacterController(
      repository: MemoryCharacterRepository(
        initial: [CharacterSheet.local(id: 'char-1', name: 'Hero', level: 1)],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharactersTabPage(
          controller: localCharacterController,
          modeController: modeController,
          campaignCharacterController: campaignCharacterController,
          localContentRepository: contentRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    localCharacterController.dispose();
  }

  testWidgets(
    'DM mode with selected campaign shows the three supported create options',
    (tester) async {
      final modeController = ClientModeController(
        initialMode: ClientMode.dungeonMaster,
      );
      final characterController = await buildCharacterController();
      await pumpPage(
        tester,
        modeController: modeController,
        campaignCharacterController: characterController,
      );

      await tester.tap(find.byKey(const Key('create_character')));
      await tester.pumpAndSettle();

      expect(find.text('创建角色'), findsOneWidget);
      expect(find.byKey(const Key('dm-create-quick-npc')), findsOneWidget);
      expect(find.text('快速创建 NPC'), findsOneWidget);
      expect(find.byKey(const Key('dm-create-full')), findsOneWidget);
      expect(find.text('完整创建角色'), findsOneWidget);
      expect(find.byKey(const Key('dm-create-from-monster')), findsOneWidget);
      expect(find.text('从怪物资料创建'), findsOneWidget);
      // Task 5.2: 一次性发言身份改用 speaker snapshot, 不再在此菜单创建临时角色.
      expect(find.byKey(const Key('dm-create-quick-temporary')), findsNothing);
      expect(find.text('快速创建一次性角色'), findsNothing);

      characterController.dispose();
      modeController.dispose();
    },
  );

  testWidgets(
    'player mode does not show the DM create menu, FAB opens editor directly',
    (tester) async {
      final modeController = ClientModeController(
        initialMode: ClientMode.player,
      );
      final characterController = await buildCharacterController();
      await pumpPage(
        tester,
        modeController: modeController,
        campaignCharacterController: characterController,
      );

      await tester.tap(find.byKey(const Key('create_character')));
      await tester.pumpAndSettle();

      // Player creation goes straight into the guided standard flow.
      expect(find.byKey(const Key('dm-create-quick-npc')), findsNothing);
      expect(find.text('标准创建角色'), findsOneWidget);
      expect(find.text('选择创建方式'), findsNothing);

      characterController.dispose();
      modeController.dispose();
    },
  );

  testWidgets('player character cards do not expose a publish action', (
    tester,
  ) async {
    final modeController = ClientModeController(initialMode: ClientMode.player);
    final characterController = await buildCharacterController();
    await pumpPage(
      tester,
      modeController: modeController,
      campaignCharacterController: characterController,
    );

    await tester.tap(find.byKey(const Key('character-expand-char-1')));
    await tester.pumpAndSettle();

    expect(find.text('发布到战役'), findsNothing);

    characterController.dispose();
    modeController.dispose();
  });

  testWidgets('DM mode does not expose private player characters', (
    tester,
  ) async {
    final modeController = ClientModeController(
      initialMode: ClientMode.dungeonMaster,
    );
    final characterController = await buildCharacterController();

    await pumpPage(
      tester,
      modeController: modeController,
      campaignCharacterController: characterController,
    );

    expect(find.text('Hero'), findsNothing);
    expect(
      find.byKey(const Key('dm-campaign-character-directory')),
      findsOneWidget,
    );

    characterController.dispose();
    modeController.dispose();
  });

  testWidgets(
    'DM mode without selected campaign still offers local and monster creation',
    (tester) async {
      final modeController = ClientModeController(
        initialMode: ClientMode.dungeonMaster,
      );
      // characterController without selectCampaign → selectedCampaignId is null.
      final characterController = CampaignCharacterController(
        cacheRepository: MemoryCampaignCacheRepository(),
        apiClient: MemoryCampaignSyncApiClient(),
        apiBaseUrl: apiBaseUrl,
        accessToken: 'access-token',
        currentUserId: 'user-1',
      );
      await pumpPage(
        tester,
        modeController: modeController,
        campaignCharacterController: characterController,
      );

      await tester.tap(find.byKey(const Key('create_character')));
      await tester.pumpAndSettle();

      // Campaign-only quick NPC creation stays hidden, while ordinary local
      // characters and monster-template characters remain available.
      expect(find.byKey(const Key('dm-create-quick-npc')), findsNothing);
      expect(find.byKey(const Key('dm-create-full')), findsOneWidget);
      expect(find.byKey(const Key('dm-create-from-monster')), findsOneWidget);

      characterController.dispose();
      modeController.dispose();
    },
  );

  testWidgets('DM quick NPC option opens the quick NPC form', (tester) async {
    final modeController = ClientModeController(
      initialMode: ClientMode.dungeonMaster,
    );
    final characterController = await buildCharacterController();
    await pumpPage(
      tester,
      modeController: modeController,
      campaignCharacterController: characterController,
    );

    await tester.tap(find.byKey(const Key('create_character')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dm-create-quick-npc')));
    await tester.pumpAndSettle();

    expect(find.text('快速创建 NPC'), findsOneWidget);
    expect(find.byKey(const Key('quick-npc-name')), findsOneWidget);
    expect(find.byKey(const Key('quick-npc-hp')), findsOneWidget);
    expect(find.byKey(const Key('quick-npc-confirm')), findsOneWidget);

    characterController.dispose();
    modeController.dispose();
  });

  testWidgets('DM can open a monster template in the full character editor', (
    tester,
  ) async {
    final modeController = ClientModeController(
      initialMode: ClientMode.dungeonMaster,
    );
    final characterController = await buildCharacterController();
    final repository = MemoryContentRepository(
      initialEntries: [
        ContentEntry.fromJson({
          'id': 'private-mm:monster/zombie',
          'type': 'monster',
          'slug': 'zombie',
          'name': '丧尸',
          'summary': 'medium 亡灵，中立邪恶',
          'revision': 1,
          'body': const <Object?>[],
          'structured': {
            'characterTemplate': {
              'kind': 'monster',
              'armorClass': 8,
              'hitPoints': {'maximum': 15, 'formula': '2d8+6'},
              'speed': {'walk': 20},
              'abilities': {
                'str': 13,
                'dex': 6,
                'con': 16,
                'int': 3,
                'wis': 6,
                'cha': 5,
              },
              'sections': {'动作': '### 猛击\n\n造成钝击伤害。'},
            },
          },
        }),
      ],
    );
    await pumpPage(
      tester,
      modeController: modeController,
      campaignCharacterController: characterController,
      contentRepository: repository,
    );

    await tester.tap(find.byKey(const Key('create_character')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dm-create-from-monster')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('monster-template-search')), findsOneWidget);
    expect(find.text('丧尸'), findsOneWidget);

    await tester.tap(find.text('丧尸'));
    await tester.pumpAndSettle();

    final nameField = tester.widget<TextField>(
      find.byKey(const Key('character-name')),
    );
    expect(nameField.controller!.text, '丧尸');
    expect(find.text('怪物与 NPC 资料'), findsOneWidget);
    expect(find.byKey(const Key('character-section-actions')), findsOneWidget);

    characterController.dispose();
    modeController.dispose();
  });

  testWidgets('offers one clear Markdown import and export entry', (
    tester,
  ) async {
    final modeController = ClientModeController(initialMode: ClientMode.player);
    await pumpPage(tester, modeController: modeController);

    expect(find.byKey(const Key('import-character-markdown')), findsOneWidget);

    await tester.tap(find.byKey(const Key('character-expand-char-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多角色操作'));
    await tester.pumpAndSettle();

    expect(find.text('导出 Markdown'), findsOneWidget);
    expect(find.text('删除角色'), findsOneWidget);
    expect(find.text('内容引用'), findsNothing);
    modeController.dispose();
  });
}
