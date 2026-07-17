import 'dart:convert';
import 'dart:typed_data';

import 'package:dnd_table_client/src/features/campaigns/data/sync/campaign_sync_api_client.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/actors/campaign_actor_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/actors/publish_character_sheet.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/widgets/avatar_picker.dart';
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_test_support.dart';

/// Plan 2 task 5 follow-up: wire the AvatarPicker widget into the publish
/// dialog so players can attach an avatar when publishing a local character
/// to a campaign. The file_picker platform call is abstracted behind
/// [PublishCharacterSheet.onPickImage] so tests can drive the flow without
/// touching native plugins.
void main() {
  final sampleCharacter = CharacterSheet.local(
    id: 'char-1',
    name: 'Mira',
    level: 2,
    classSummary: '法师',
    raceSummary: '人类',
  );

  // 1x1 transparent PNG.
  final pngBytes = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
    ),
  );

  Future<CampaignActorController> buildController() async {
    final apiClient = MemoryCampaignSyncApiClient();
    final controller = CampaignActorController(
      cacheRepository: MemoryCampaignCacheRepository(),
      apiClient: apiClient,
      apiBaseUrl: 'https://example.test',
      accessToken: 'access-token',
      currentUserId: 'user-1',
    );
    await controller.selectCampaign('campaign-1');
    return controller;
  }

  Future<void> pumpSheet(
    WidgetTester tester,
    CampaignActorController controller, {
    required Future<({Uint8List bytes, String mimeType})?> Function() onPickImage,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PublishCharacterSheet(
            controller: controller,
            character: sampleCharacter,
            onPickImage: onPickImage,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows AvatarPicker in the publish dialog', (tester) async {
    final controller = await buildController();
    await pumpSheet(
      tester,
      controller,
      onPickImage: () async => null,
    );

    expect(find.byType(AvatarPicker), findsOneWidget);
    expect(find.text('选择图片'), findsOneWidget);

    controller.dispose();
  });

  testWidgets(
      'picking an image attaches the avatar data URI when publishing',
      (tester) async {
    final apiClient = MemoryCampaignSyncApiClient();
    final controller = CampaignActorController(
      cacheRepository: MemoryCampaignCacheRepository(),
      apiClient: apiClient,
      apiBaseUrl: 'https://example.test',
      accessToken: 'access-token',
      currentUserId: 'user-1',
    );
    await controller.selectCampaign('campaign-1');

    await pumpSheet(
      tester,
      controller,
      onPickImage: () async => (bytes: pngBytes, mimeType: 'image/png'),
    );

    // Pick the image — this should populate the preview.
    await tester.tap(find.text('选择图片'));
    await tester.pumpAndSettle();

    // Publish — the avatar data URI should be merged into the sheet.
    await tester.tap(find.widgetWithText(FilledButton, '发布'));
    await tester.pumpAndSettle();

    expect(apiClient.publishCalls, hasLength(1));
    final sheet =
        apiClient.publishCalls.single['sheet']! as Map<String, Object?>;
    expect(sheet['avatarUrl'] as String?, startsWith('data:image/png;base64,'));

    controller.dispose();
  });

  testWidgets('publishes without avatar when no image is picked',
      (tester) async {
    final apiClient = MemoryCampaignSyncApiClient();
    final controller = CampaignActorController(
      cacheRepository: MemoryCampaignCacheRepository(),
      apiClient: apiClient,
      apiBaseUrl: 'https://example.test',
      accessToken: 'access-token',
      currentUserId: 'user-1',
    );
    await controller.selectCampaign('campaign-1');

    await pumpSheet(
      tester,
      controller,
      onPickImage: () async => null,
    );

    await tester.tap(find.widgetWithText(FilledButton, '发布'));
    await tester.pumpAndSettle();

    expect(apiClient.publishCalls, hasLength(1));
    final sheet =
        apiClient.publishCalls.single['sheet']! as Map<String, Object?>;
    expect(sheet.containsKey('avatarUrl'), isFalse);

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
      final controller = CampaignActorController(
        cacheRepository: MemoryCampaignCacheRepository(),
        apiClient: apiClient,
        apiBaseUrl: 'https://example.test',
        accessToken: 'access-token',
        currentUserId: 'dm-1',
      );
      await controller.selectCampaign('campaign-1');

      await pumpSheet(
        tester,
        controller,
        onPickImage: () async => null,
      );

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
      final controller = CampaignActorController(
        cacheRepository: MemoryCampaignCacheRepository(),
        apiClient: apiClient,
        apiBaseUrl: 'https://example.test',
        accessToken: 'access-token',
        currentUserId: 'dm-1',
      );
      await controller.selectCampaign('campaign-1');

      await pumpSheet(
        tester,
        controller,
        onPickImage: () async => null,
      );

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
      final controller = CampaignActorController(
        cacheRepository: MemoryCampaignCacheRepository(),
        apiClient: apiClient,
        apiBaseUrl: 'https://example.test',
        accessToken: 'access-token',
        currentUserId: 'user-1',
      );
      await controller.selectCampaign('campaign-1');

      await pumpSheet(
        tester,
        controller,
        onPickImage: () async => null,
      );

      await tester.tap(find.widgetWithText(FilledButton, '发布'));
      await tester.pumpAndSettle();

      expect(find.textContaining('sourceCharacterId is required'), findsOneWidget);

      controller.dispose();
    },
  );
}
