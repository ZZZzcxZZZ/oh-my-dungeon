import 'package:dnd_table_client/src/features/campaigns/presentation/actors/campaign_actor_controller.dart';
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_controller.dart';
import 'package:dnd_table_client/src/features/characters/presentation/characters_tab_page.dart';
import 'package:dnd_table_client/src/features/client_mode/domain/client_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_test_support.dart';
import 'support/character_test_support.dart';

/// Spec §DM 角色生命周期: DM 模式下角色栏 FAB 应弹出菜单提供:
/// 1. 快速创建 NPC (常驻)
/// 2. 快速创建一次性角色 (临时)
/// 3. 完整创建角色
void main() {
  const apiBaseUrl = 'http://localhost:3000/api';

  Future<CampaignActorController> buildActorController() async {
    final controller = CampaignActorController(
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
    CampaignActorController? actorController,
  }) async {
    final characterController = CharacterController(
      repository: MemoryCharacterRepository(
        initial: [CharacterSheet.local(id: 'char-1', name: 'Hero', level: 1)],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharactersTabPage(
          controller: characterController,
          modeController: modeController,
          actorController: actorController,
        ),
      ),
    );
    await tester.pumpAndSettle();
    characterController.dispose();
  }

  testWidgets(
    'DM mode with selected campaign shows popup menu with three create options',
    (tester) async {
      final modeController = ClientModeController(
        initialMode: ClientMode.dungeonMaster,
      );
      final actorController = await buildActorController();
      await pumpPage(
        tester,
        modeController: modeController,
        actorController: actorController,
      );

      await tester.tap(find.byKey(const Key('create_character')));
      await tester.pumpAndSettle();

      expect(find.text('创建角色'), findsOneWidget);
      expect(find.byKey(const Key('dm-create-quick-npc')), findsOneWidget);
      expect(find.text('快速创建 NPC'), findsOneWidget);
      expect(
        find.byKey(const Key('dm-create-quick-temporary')),
        findsOneWidget,
      );
      expect(find.text('快速创建一次性角色'), findsOneWidget);
      expect(find.byKey(const Key('dm-create-full')), findsOneWidget);
      expect(find.text('完整创建角色'), findsOneWidget);

      actorController.dispose();
      modeController.dispose();
    },
  );

  testWidgets(
    'player mode does not show the DM create menu, FAB opens editor directly',
    (tester) async {
      final modeController = ClientModeController(initialMode: ClientMode.player);
      final actorController = await buildActorController();
      await pumpPage(
        tester,
        modeController: modeController,
        actorController: actorController,
      );

      await tester.tap(find.byKey(const Key('create_character')));
      await tester.pumpAndSettle();

      // No DM popup menu.
      expect(find.text('创建角色'), findsNothing);
      expect(find.byKey(const Key('dm-create-quick-npc')), findsNothing);

      actorController.dispose();
      modeController.dispose();
    },
  );

  testWidgets(
    'DM mode without selected campaign does not show the DM create menu',
    (tester) async {
      final modeController = ClientModeController(
        initialMode: ClientMode.dungeonMaster,
      );
      // actorController without selectCampaign → selectedCampaignId is null.
      final actorController = CampaignActorController(
        cacheRepository: MemoryCampaignCacheRepository(),
        apiClient: MemoryCampaignSyncApiClient(),
        apiBaseUrl: apiBaseUrl,
        accessToken: 'access-token',
        currentUserId: 'user-1',
      );
      await pumpPage(
        tester,
        modeController: modeController,
        actorController: actorController,
      );

      await tester.tap(find.byKey(const Key('create_character')));
      await tester.pumpAndSettle();

      // No DM popup menu — falls back to full editor path.
      expect(find.text('创建角色'), findsNothing);
      expect(find.byKey(const Key('dm-create-quick-npc')), findsNothing);

      actorController.dispose();
      modeController.dispose();
    },
  );

  testWidgets(
    'DM quick NPC option opens the quick NPC form',
    (tester) async {
      final modeController = ClientModeController(
        initialMode: ClientMode.dungeonMaster,
      );
      final actorController = await buildActorController();
      await pumpPage(
        tester,
        modeController: modeController,
        actorController: actorController,
      );

      await tester.tap(find.byKey(const Key('create_character')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dm-create-quick-npc')));
      await tester.pumpAndSettle();

      expect(find.text('快速创建 NPC'), findsOneWidget);
      expect(find.byKey(const Key('quick-npc-name')), findsOneWidget);
      expect(find.byKey(const Key('quick-npc-hp')), findsOneWidget);
      expect(find.byKey(const Key('quick-npc-confirm')), findsOneWidget);

      actorController.dispose();
      modeController.dispose();
    },
  );

  testWidgets(
    'DM quick temporary option opens the quick temporary form',
    (tester) async {
      final modeController = ClientModeController(
        initialMode: ClientMode.dungeonMaster,
      );
      final actorController = await buildActorController();
      await pumpPage(
        tester,
        modeController: modeController,
        actorController: actorController,
      );

      await tester.tap(find.byKey(const Key('create_character')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dm-create-quick-temporary')));
      await tester.pumpAndSettle();

      expect(find.text('快速创建一次性角色'), findsOneWidget);
      expect(find.byKey(const Key('quick-temporary-name')), findsOneWidget);
      expect(find.byKey(const Key('quick-temporary-confirm')), findsOneWidget);

      actorController.dispose();
      modeController.dispose();
    },
  );
}
