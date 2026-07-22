import 'package:dnd_table_client/src/features/campaigns/data/sync/campaign_sync_api_client.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/actors/campaign_actor_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/actors/publish_character_sheet.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/widgets/avatar_picker.dart';
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_test_support.dart';

/// Spec §头像来源: 战役角色头像由本地角色绑定战役后自动上传，发布对话框
/// 不再暴露手动头像选择入口。头像 URL 直接随 sheet 提交，无需用户干预。
void main() {
  final sampleCharacter = CharacterSheet.local(
    id: 'char-1',
    name: 'Mira',
    level: 2,
    classSummary: '法师',
    raceSummary: '人类',
  );

  Future<CampaignActorController> buildController({
    MemoryCampaignSyncApiClient? apiClient,
    String currentUserId = 'user-1',
  }) async {
    final client = apiClient ?? MemoryCampaignSyncApiClient();
    final controller = CampaignActorController(
      cacheRepository: MemoryCampaignCacheRepository(),
      apiClient: client,
      apiBaseUrl: 'https://example.test',
      accessToken: 'access-token',
      currentUserId: currentUserId,
    );
    await controller.selectCampaign('campaign-1');
    return controller;
  }

  Future<void> pumpSheet(
    WidgetTester tester,
    CampaignActorController controller, {
    CharacterSheet? character,
    bool allowDmActorTypes = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PublishCharacterSheet(
            controller: controller,
            character: character ?? sampleCharacter,
            allowDmActorTypes: allowDmActorTypes,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Spec §头像来源: 发布对话框不再包含手动头像选择入口。
  testWidgets('publish dialog does not expose avatar picker', (tester) async {
    final controller = await buildController();
    await pumpSheet(tester, controller);

    expect(find.byType(AvatarPicker), findsNothing);
    expect(find.text('选择图片'), findsNothing);

    controller.dispose();
  });

  // Spec §头像来源: 本地角色头像随发布自动上传到战役，无需用户干预。
  testWidgets(
    'automatically uploads character avatar URL when publishing',
    (tester) async {
      final apiClient = MemoryCampaignSyncApiClient();
      final controller = await buildController(apiClient: apiClient);
      const avatarUrl = 'data:image/png;base64,SGVsbG8=';
      final characterWithAvatar = sampleCharacter.copyWith(
        avatarUrl: avatarUrl,
      );

      await pumpSheet(tester, controller, character: characterWithAvatar);
      await tester.tap(find.widgetWithText(FilledButton, '发布'));
      await tester.pumpAndSettle();

      expect(apiClient.publishCalls, hasLength(1));
      final sheet =
          apiClient.publishCalls.single['sheet']! as Map<String, Object?>;
      expect(sheet['avatarUrl'], avatarUrl);

      controller.dispose();
    },
  );

  // Spec §头像来源: 本地角色未设置头像时，sheet 不携带 avatarUrl 字段。
  testWidgets('publishes without avatarUrl when character has none',
      (tester) async {
    final apiClient = MemoryCampaignSyncApiClient();
    final controller = await buildController(apiClient: apiClient);

    await pumpSheet(tester, controller);
    await tester.tap(find.widgetWithText(FilledButton, '发布'));
    await tester.pumpAndSettle();

    expect(apiClient.publishCalls, hasLength(1));
    final sheet =
        apiClient.publishCalls.single['sheet']! as Map<String, Object?>;
    expect(sheet['avatarUrl'], isNull);

    controller.dispose();
  });

  // Spec compliance: DM must be able to create persistent NPC/monster/companion
  // actors. The previous sheet routed ALL actor types through the player-only
  // /actors/publish endpoint, which rejects non-player types with HTTP 400.
  // Now selecting NPC/companion/monster routes through /actors (DM create).
  testWidgets(
    'selecting NPC routes through createActor (DM endpoint), not publishActor',
    (tester) async {
      final apiClient = MemoryCampaignSyncApiClient();
      final controller = await buildController(
        apiClient: apiClient,
        currentUserId: 'dm-1',
      );

      await pumpSheet(tester, controller, allowDmActorTypes: true);

      await tester.tap(find.text('NPC'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '发布'));
      await tester.pumpAndSettle();

      expect(apiClient.publishCalls, isEmpty,
          reason: 'NPC creation must go through the DM create endpoint');
      expect(apiClient.createActorCalls, hasLength(1));
      expect(apiClient.createActorCalls.single['actorType'], 'npc');
      expect(
        apiClient.createActorCalls.single['lifecycle'],
        'persistent',
        reason: 'DM-created actors are persistent by spec §DM角色生命周期',
      );

      controller.dispose();
    },
  );

  testWidgets(
    'selecting monster routes through createActor with persistent lifecycle',
    (tester) async {
      final apiClient = MemoryCampaignSyncApiClient();
      final controller = await buildController(
        apiClient: apiClient,
        currentUserId: 'dm-1',
      );

      await pumpSheet(tester, controller, allowDmActorTypes: true);

      await tester.tap(find.text('怪物'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '发布'));
      await tester.pumpAndSettle();

      expect(apiClient.publishCalls, isEmpty);
      expect(apiClient.createActorCalls.single['actorType'], 'monster');
      expect(apiClient.createActorCalls.single['lifecycle'], 'persistent');

      controller.dispose();
    },
  );

  // Spec compliance: error path must surface server-provided message.
  testWidgets(
    'surfaces server error message in SnackBar instead of generic failure',
    (tester) async {
      final apiClient = MemoryCampaignSyncApiClient();
      apiClient.nextPublishActorException = const CampaignSyncException(
        'sourceCharacterId is required',
        statusCode: 400,
      );
      final controller = await buildController(apiClient: apiClient);

      await pumpSheet(tester, controller);

      await tester.tap(find.widgetWithText(FilledButton, '发布'));
      await tester.pumpAndSettle();

      expect(find.textContaining('sourceCharacterId is required'), findsOneWidget);

      controller.dispose();
    },
  );
}
