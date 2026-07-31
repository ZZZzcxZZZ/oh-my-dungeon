import 'package:dnd_table_client/src/features/campaigns/data/sync/campaign_sync_api_client.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_actor.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_actor_audit.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/actors/campaign_actor_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/actors/campaign_actor_directory_page.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/actors/campaign_actor_sheet_launcher.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/actors/campaign_actor_sheet_page.dart';
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_controller.dart';
import 'package:dnd_table_client/src/features/characters/presentation/characters_tab_page.dart';
import 'package:dnd_table_client/src/features/client_mode/domain/client_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_test_support.dart';
import 'support/character_test_support.dart';

void main() {
  Future<void> drainStream() async {
    await Future.microtask(() {});
    await Future.microtask(() {});
  }

  test('campaign actor edit permission follows ownership and DM authority', () {
    final ownActor = testCampaignActor(
      id: 'own',
      ownerUserId: 'user-1',
      sheet: const {'name': 'Own'},
    );
    final otherActor = testCampaignActor(
      id: 'other',
      ownerUserId: 'user-2',
      sheet: const {'name': 'Other'},
    );

    expect(
      canEditCampaignActor(
        actor: ownActor,
        currentUserId: 'user-1',
        canEditAnyActor: false,
      ),
      isTrue,
    );
    expect(
      canEditCampaignActor(
        actor: otherActor,
        currentUserId: 'user-1',
        canEditAnyActor: false,
      ),
      isFalse,
    );
    expect(
      canEditCampaignActor(
        actor: otherActor,
        currentUserId: 'user-1',
        canEditAnyActor: true,
      ),
      isTrue,
    );
  });

  testWidgets('read-only actor sheet hides every editing affordance', (
    tester,
  ) async {
    final controller = CampaignActorController(
      cacheRepository: MemoryCampaignCacheRepository(actors: [_sampleActor]),
      apiClient: MemoryCampaignSyncApiClient(),
      apiBaseUrl: 'https://example.test',
      accessToken: 'access-token',
      currentUserId: 'viewer',
    );
    await controller.selectCampaign('campaign-1');
    await drainStream();

    await tester.pumpWidget(
      MaterialApp(
        home: CampaignActorSheetPage(
          controller: controller,
          actorId: _sampleActor.id,
          canEdit: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('campaign-actor-sheet')), findsOneWidget);
    expect(find.byTooltip('归档'), findsNothing);
    expect(find.byKey(const Key('campaign-actor-avatar-picker')), findsNothing);
    expect(find.byTooltip('受到 1 点伤害'), findsNothing);
    expect(find.byTooltip('恢复 1 点 HP'), findsNothing);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1600));
    await tester.pumpAndSettle();
    expect(find.text('备注'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    controller.dispose();
  });

  test('uses credentials that become available after construction', () async {
    var accessToken = '';
    var userId = '';
    final apiClient = MemoryCampaignSyncApiClient();
    final controller = CampaignActorController(
      cacheRepository: MemoryCampaignCacheRepository(),
      apiClient: apiClient,
      apiBaseUrl: 'https://example.test',
      accessToken: '',
      currentUserId: '',
      accessTokenProvider: () => accessToken,
      currentUserIdProvider: () => userId,
    );
    await controller.selectCampaign('campaign-1');

    accessToken = 'token-after-login';
    userId = 'user-after-login';
    final published = await controller.publishCharacter(_sampleCharacter);

    expect(published, isTrue);
    expect(apiClient.publishCalls.single['accessToken'], 'token-after-login');
    expect(controller.currentUserId, 'user-after-login');
    controller.dispose();
  });

  // Spec compliance: DM must be able to create persistent NPC/monster/companion
  // actors via the DM create endpoint (/actors), not the self-publish endpoint
  // (/actors/publish) which rejects non-player types. See
  // docs/superpowers/plans/2026-07-17-workspace-spec-compliance-fixes.md Task 1.3.
  test(
    'createDmActor creates a persistent NPC via the DM create endpoint',
    () async {
      final apiClient = MemoryCampaignSyncApiClient();
      final controller = CampaignActorController(
        cacheRepository: MemoryCampaignCacheRepository(),
        apiClient: apiClient,
        apiBaseUrl: 'https://example.test',
        accessToken: 'access-token',
        currentUserId: 'dm-1',
      );
      await controller.selectCampaign('campaign-1');

      final created = await controller.createDmActor(
        actorType: 'npc',
        sheet: {'name': '酒馆老板', 'currentHp': 12, 'maxHp': 12},
      );

      expect(created, isTrue);
      expect(apiClient.createActorCalls, hasLength(1));
      expect(apiClient.createActorCalls.single['actorType'], 'npc');
      expect(apiClient.createActorCalls.single['lifecycle'], 'persistent');
      expect(apiClient.publishCalls, isEmpty);
      controller.dispose();
    },
  );

  test(
    'createDmActor creates a persistent monster via the DM create endpoint',
    () async {
      final apiClient = MemoryCampaignSyncApiClient();
      final controller = CampaignActorController(
        cacheRepository: MemoryCampaignCacheRepository(),
        apiClient: apiClient,
        apiBaseUrl: 'https://example.test',
        accessToken: 'access-token',
        currentUserId: 'dm-1',
      );
      await controller.selectCampaign('campaign-1');

      final created = await controller.createDmActor(
        actorType: 'monster',
        sheet: {'name': '哥布林', 'currentHp': 7, 'maxHp': 7},
      );

      expect(created, isTrue);
      expect(apiClient.createActorCalls.single['actorType'], 'monster');
      expect(apiClient.createActorCalls.single['lifecycle'], 'persistent');
      controller.dispose();
    },
  );

  // Spec compliance: error path must surface server-provided message instead
  // of a generic "发布角色失败" string. The previous catch-all discarded the
  // CampaignSyncException and its statusCode, hiding actionable details like
  // "Only player actors can be self-published; use the DM create endpoint".
  test('publishCharacter surfaces server error message on 400', () async {
    final apiClient = MemoryCampaignSyncApiClient();
    apiClient.nextPublishActorException = const CampaignSyncException(
      'Only player actors can be self-published; use the DM create endpoint',
      statusCode: 400,
    );
    final controller = CampaignActorController(
      cacheRepository: MemoryCampaignCacheRepository(),
      apiClient: apiClient,
      apiBaseUrl: 'https://example.test',
      accessToken: 'access-token',
      currentUserId: 'dm-1',
    );
    await controller.selectCampaign('campaign-1');

    final published = await controller.publishCharacter(_sampleCharacter);

    expect(published, isFalse);
    expect(controller.error, isNotNull);
    expect(
      controller.error,
      contains('Only player actors can be self-published'),
    );
    controller.dispose();
  });

  test('publishCharacter surfaces 403 forbidden message', () async {
    final apiClient = MemoryCampaignSyncApiClient();
    apiClient.nextPublishActorException = const CampaignSyncException(
      'Forbidden',
      statusCode: 403,
    );
    final controller = CampaignActorController(
      cacheRepository: MemoryCampaignCacheRepository(),
      apiClient: apiClient,
      apiBaseUrl: 'https://example.test',
      accessToken: 'access-token',
      currentUserId: 'dm-1',
    );
    await controller.selectCampaign('campaign-1');

    final published = await controller.publishCharacter(_sampleCharacter);

    expect(published, isFalse);
    expect(controller.error, contains('Forbidden'));
    controller.dispose();
  });

  // Spec §双向同步 切片 A: 重发布必须用本地缓存的 actor.revision 作
  // baseRevision，否则服务端 applyUpdate 第 446 行 nextRevision =
  // existing.revision + 1 检查 baseRevision 不匹配必然 409。
  test(
    'publishCharacter uses local actor revision as baseRevision when re-publishing',
    () async {
      final cacheRepository = MemoryCampaignCacheRepository(
        actors: [
          testCampaignActor(
            id: 'actor-existing',
            campaignId: 'campaign-1',
            sourceCharacterId: 'char-1',
            revision: 5,
          ),
        ],
      );
      final apiClient = MemoryCampaignSyncApiClient();
      final controller = CampaignActorController(
        cacheRepository: cacheRepository,
        apiClient: apiClient,
        apiBaseUrl: 'https://example.test',
        accessToken: 'access-token',
        currentUserId: 'user-1',
      );
      await controller.selectCampaign('campaign-1');
      await drainStream();

      final published = await controller.publishCharacter(_sampleCharacter);

      expect(published, isTrue);
      expect(apiClient.publishCalls.single['baseRevision'], 5);
      controller.dispose();
    },
  );

  test('publishCharacter uses baseRevision 0 on first publish', () async {
    final apiClient = MemoryCampaignSyncApiClient();
    final controller = CampaignActorController(
      cacheRepository: MemoryCampaignCacheRepository(),
      apiClient: apiClient,
      apiBaseUrl: 'https://example.test',
      accessToken: 'access-token',
      currentUserId: 'user-1',
    );
    await controller.selectCampaign('campaign-1');
    await drainStream();

    final published = await controller.publishCharacter(_sampleCharacter);

    expect(published, isTrue);
    expect(apiClient.publishCalls.single['baseRevision'], 0);
    controller.dispose();
  });

  // Spec §双向同步 切片 A: 发布成功后立即调用 backlink 回调把远端 actor
  // 回写本地角色，避免等下次 pullUntilCurrent 才同步运行时字段。
  test(
    'publishCharacter invokes onActorPublished callback after success',
    () async {
      final apiClient = MemoryCampaignSyncApiClient();
      CampaignActor? publishedActor;
      final controller = CampaignActorController(
        cacheRepository: MemoryCampaignCacheRepository(),
        apiClient: apiClient,
        apiBaseUrl: 'https://example.test',
        accessToken: 'access-token',
        currentUserId: 'user-1',
        onActorPublished: (actor) async {
          publishedActor = actor;
        },
      );
      await controller.selectCampaign('campaign-1');
      await drainStream();

      final published = await controller.publishCharacter(_sampleCharacter);

      expect(published, isTrue);
      expect(publishedActor, isNotNull);
      expect(publishedActor!.sourceCharacterId, 'char-1');
      controller.dispose();
    },
  );

  testWidgets(
    'player and dm modes both show local characters with create FAB',
    (tester) async {
      final characterRepository = MemoryCharacterRepository(
        initial: [_sampleCharacter],
      );
      final characterController = CharacterController(
        repository: characterRepository,
      );
      await drainStream();

      final cacheRepository = MemoryCampaignCacheRepository(
        actors: [_sampleActor, _sampleNpc, _archivedActor],
      );
      final apiClient = MemoryCampaignSyncApiClient();
      final modeController = ClientModeController();
      final actorController = CampaignActorController(
        cacheRepository: cacheRepository,
        apiClient: apiClient,
        apiBaseUrl: 'https://example.test',
        accessToken: 'access-token',
        currentUserId: 'user-1',
      );
      await drainStream();
      await actorController.selectCampaign('campaign-1');
      await drainStream();

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

      // Player mode: publishing lives in the character's expandable summary.
      expect(find.byKey(const Key('player-local-characters')), findsOneWidget);
      expect(find.text('Mira'), findsOneWidget);
      expect(find.text('发布到战役'), findsNothing);
      await tester.tap(find.byKey(const Key('character-expand-char-1')));
      await tester.pumpAndSettle();
      expect(find.text('发布到战役'), findsWidgets);

      // Only the settings flow changes the mode; the role page has no toggle.
      expect(find.byKey(const Key('mode-switch-dm')), findsNothing);
      await modeController.setMode(ClientMode.dungeonMaster);
      await tester.pumpAndSettle();

      // Spec §DM 角色生命周期 / Plan Task 6.2: DM 模式下"角色"tab 仍显示
      // 本地角色列表和"新角色" FAB，不被 CampaignActorDirectoryPage 替代。
      // 战役角色目录作为独立入口在战役中心队伍面板里访问。
      expect(find.byKey(const Key('player-local-characters')), findsOneWidget);
      expect(find.text('Mira'), findsOneWidget);
      expect(find.byKey(const Key('create_character')), findsOneWidget);
      expect(find.byKey(const Key('campaign-actor-directory')), findsNothing);
      expect(find.text('Test Hero'), findsNothing);
      expect(find.text('Goblin Boss'), findsNothing);

      characterController.dispose();
      actorController.dispose();
      modeController.dispose();
    },
  );

  testWidgets('dm mode actor directory supports search and status filters', (
    tester,
  ) async {
    final cacheRepository = MemoryCampaignCacheRepository(
      actors: [_sampleActor, _sampleNpc, _archivedActor],
    );
    final apiClient = MemoryCampaignSyncApiClient();
    final actorController = CampaignActorController(
      cacheRepository: cacheRepository,
      apiClient: apiClient,
      apiBaseUrl: 'https://example.test',
      accessToken: 'access-token',
      currentUserId: 'user-1',
    );
    await drainStream();
    await actorController.selectCampaign('campaign-1');
    await drainStream();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignActorDirectoryPage(
            controller: actorController,
            campaigns: const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Default: player + npc visible, archived hidden.
    expect(find.text('Test Hero'), findsOneWidget);
    expect(find.text('Goblin Boss'), findsOneWidget);
    expect(find.text('Old Villain'), findsNothing);

    // Search narrows by name.
    await tester.enterText(
      find.byKey(const Key('actor-directory-search')),
      'Goblin',
    );
    await tester.pumpAndSettle();
    expect(find.text('Test Hero'), findsNothing);
    expect(find.text('Goblin Boss'), findsOneWidget);

    // Clear search and toggle to archived-only filter.
    await tester.enterText(find.byKey(const Key('actor-directory-search')), '');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter-chip-archived')));
    await tester.pumpAndSettle();
    expect(find.text('Test Hero'), findsNothing);
    expect(find.text('Goblin Boss'), findsNothing);
    expect(find.text('Old Villain'), findsOneWidget);

    actorController.dispose();
  });

  testWidgets('dm opens actor sheet and updates hp with base revision', (
    tester,
  ) async {
    final cacheRepository = MemoryCampaignCacheRepository(
      actors: [_sampleActor],
    );
    final apiClient = MemoryCampaignSyncApiClient();
    final actorController = CampaignActorController(
      cacheRepository: cacheRepository,
      apiClient: apiClient,
      apiBaseUrl: 'https://example.test',
      accessToken: 'access-token',
      currentUserId: 'user-1',
    );
    await drainStream();
    await actorController.selectCampaign('campaign-1');
    await drainStream();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignActorDirectoryPage(
            controller: actorController,
            campaigns: const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test Hero'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('campaign-actor-full-sheet')), findsOneWidget);
    expect(find.textContaining('HP 10/20'), findsWidgets);

    await tester.tap(find.byKey(const Key('runtime-hp-panel')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('hp-quick-value-field')), '1');
    await tester.tap(find.widgetWithText(FilledButton, '受到伤害'));
    await tester.pumpAndSettle();

    expect(apiClient.updateActorCalls, hasLength(1));
    expect(apiClient.updateActorCalls.last['baseRevision'], 1);
    expect(apiClient.updateActorCalls.last['actorId'], 'actor-1');
    final sheet =
        apiClient.updateActorCalls.last['sheet']! as Map<String, Object?>;
    expect(sheet['currentHp'], 9);

    actorController.dispose();
  });

  testWidgets('publish character sheet submits to api with base revision 0', (
    tester,
  ) async {
    final characterRepository = MemoryCharacterRepository(
      initial: [_sampleCharacter],
    );
    final characterController = CharacterController(
      repository: characterRepository,
    );
    await drainStream();

    final cacheRepository = MemoryCampaignCacheRepository();
    final apiClient = MemoryCampaignSyncApiClient();
    final modeController = ClientModeController();
    final actorController = CampaignActorController(
      cacheRepository: cacheRepository,
      apiClient: apiClient,
      apiBaseUrl: 'https://example.test',
      accessToken: 'access-token',
      currentUserId: 'user-1',
    );
    await actorController.selectCampaign('campaign-1');
    await drainStream();

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

    await tester.tap(find.byKey(const Key('character-expand-char-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('publish-character-char-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('publish-character-sheet')), findsOneWidget);
    expect(find.text('NPC'), findsNothing);
    expect(find.text('怪物'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, '发布'));
    await tester.pumpAndSettle();

    expect(apiClient.publishCalls, hasLength(1));
    expect(apiClient.publishCalls.last['sourceCharacterId'], 'char-1');
    expect(apiClient.publishCalls.last['actorType'], 'player');
    expect(apiClient.publishCalls.last['baseRevision'], 0);

    characterController.dispose();
    actorController.dispose();
    modeController.dispose();
  });

  // Spec §双向同步 切片 A: publishCharacter 返回 409 时应显示冲突对话框，
  // 提供"用本地覆盖"（用服务端最新 revision 重试）和"用远端覆盖"（pull）。
  testWidgets(
    'publish conflict shows comparison dialog with override actions',
    (tester) async {
      final characterRepository = MemoryCharacterRepository(
        initial: [_sampleCharacter],
      );
      final characterController = CharacterController(
        repository: characterRepository,
      );
      await drainStream();

      final cacheRepository = MemoryCampaignCacheRepository(
        actors: [
          testCampaignActor(
            id: 'actor-existing',
            campaignId: 'campaign-1',
            sourceCharacterId: 'char-1',
            revision: 3,
          ),
        ],
      );
      final apiClient = MemoryCampaignSyncApiClient();
      apiClient.nextPublishActorException = const CampaignConflictException({
        'id': 'actor-existing',
        'campaignId': 'campaign-1',
        'actorType': 'player',
        'status': 'active',
        'sheet': {'name': 'Mira', 'currentHp': 5, 'maxHp': 20},
        'revision': 7,
        'updatedBy': 'dm-user',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-07-14T00:00:00.000Z',
      });
      final modeController = ClientModeController();
      final actorController = CampaignActorController(
        cacheRepository: cacheRepository,
        apiClient: apiClient,
        apiBaseUrl: 'https://example.test',
        accessToken: 'access-token',
        currentUserId: 'user-1',
      );
      await actorController.selectCampaign('campaign-1');
      await drainStream();

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

      await tester.tap(find.byKey(const Key('character-expand-char-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('publish-character-char-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '发布'));
      await tester.pumpAndSettle();

      // 冲突对话框出现，显示远端版本信息。
      expect(find.byKey(const Key('publish-conflict-dialog')), findsOneWidget);
      expect(find.textContaining('已被其他端修改'), findsOneWidget);
      expect(find.textContaining('版本号 7'), findsOneWidget);

      // "用本地覆盖"：用服务端 revision=7 重试 publishActor。
      await tester.tap(find.widgetWithText(FilledButton, '用本地覆盖'));
      await tester.pumpAndSettle();
      expect(apiClient.publishCalls, hasLength(2));
      expect(apiClient.publishCalls.last['baseRevision'], 7);

      characterController.dispose();
      actorController.dispose();
      modeController.dispose();
    },
  );

  testWidgets('actor update conflict shows comparison and reload action', (
    tester,
  ) async {
    final cacheRepository = MemoryCampaignCacheRepository(
      actors: [_sampleActor],
    );
    final apiClient = MemoryCampaignSyncApiClient();
    apiClient.nextUpdateActorException = const CampaignConflictException({
      'id': 'actor-1',
      'campaignId': 'campaign-1',
      'actorType': 'player',
      'status': 'active',
      'sheet': {'name': 'Test Hero', 'currentHp': 5, 'maxHp': 20},
      'revision': 7,
      'updatedBy': 'dm-user',
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-07-14T00:00:00.000Z',
    });
    final actorController = CampaignActorController(
      cacheRepository: cacheRepository,
      apiClient: apiClient,
      apiBaseUrl: 'https://example.test',
      accessToken: 'access-token',
      currentUserId: 'user-1',
    );
    await drainStream();
    await actorController.selectCampaign('campaign-1');
    await drainStream();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignActorDirectoryPage(
            controller: actorController,
            campaigns: const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test Hero'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('runtime-hp-panel')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('hp-quick-value-field')), '1');
    await tester.tap(find.widgetWithText(FilledButton, '受到伤害'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('actor-conflict-dialog')), findsOneWidget);
    expect(find.textContaining('已被其他主持人修改'), findsOneWidget);
    expect(find.textContaining('当前 HP 5'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '重新加载'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('actor-conflict-dialog')), findsNothing);

    actorController.dispose();
  });

  testWidgets('dm actor sheet shows runtime ledger and edit history', (
    tester,
  ) async {
    final actor = testCampaignActor(
      id: 'actor-audit',
      campaignId: 'campaign-1',
      sheet: const {
        'name': 'Audit Hero',
        'currentHp': 8,
        'maxHp': 12,
        'armorClass': 14,
        'speed': 30,
        'data': {
          'runtime': {
            'temporaryHp': 4,
            'conditions': ['中毒'],
            'classResourcesUsed': {'second-wind': 1},
          },
          'resolvedGrants': [
            {
              'id': 'second-wind',
              'kind': 'feature',
              'label': '第二气息',
              'entryId': 'guide:feature/second-wind',
              'sourceLevel': 1,
            },
          ],
        },
      },
      revision: 2,
    );
    final apiClient = MemoryCampaignSyncApiClient(
      actorAudits: const [
        CampaignActorAudit(
          id: 'audit-1',
          campaignActorId: 'actor-audit',
          campaignId: 'campaign-1',
          actorUserId: 'dm-user',
          baseRevision: 1,
          resultRevision: 2,
          changedPaths: ['currentHp', 'data.runtime.conditions'],
          beforeSheet: {'currentHp': 12},
          afterSheet: {'currentHp': 8},
          createdAt: '2026-07-15T01:00:00.000Z',
        ),
      ],
    );
    final controller = CampaignActorController(
      cacheRepository: MemoryCampaignCacheRepository(actors: [actor]),
      apiClient: apiClient,
      apiBaseUrl: 'https://example.test',
      accessToken: 'access-token',
      currentUserId: 'dm-user',
    );
    await controller.selectCampaign('campaign-1');
    await drainStream();

    await tester.pumpWidget(
      MaterialApp(
        home: CampaignActorSheetPage(
          controller: controller,
          actorId: actor.id,
          canEdit: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('运行时状态'), findsOneWidget);
    expect(find.textContaining('临时 HP 4'), findsOneWidget);
    expect(find.textContaining('中毒'), findsOneWidget);
    expect(find.text('规则账本'), findsOneWidget);
    expect(find.text('第二气息'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('编辑历史'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('编辑历史'), findsOneWidget);
    expect(find.textContaining('1 → 2'), findsOneWidget);
    expect(find.textContaining('currentHp'), findsOneWidget);
    expect(apiClient.listActorAuditCalls, ['actor-audit']);

    controller.dispose();
  });
}

const _sampleCharacter = CharacterSheet(
  id: 'char-1',
  ownerUserId: 'user-1',
  name: 'Mira',
  avatarUrl: null,
  system: 'dnd5e',
  level: 2,
  classSummary: '法师',
  raceSummary: '人类',
  currentHp: 12,
  maxHp: 12,
  armorClass: 12,
  speed: 30,
  initiativeBonus: 1,
  abilities: {'str': 8, 'dex': 14, 'con': 12, 'int': 16, 'wis': 10, 'cha': 10},
  saves: {'int': true, 'wis': true},
  skills: {'奥秘': true},
  inventory: [],
  currency: {'gp': 15},
  notes: '',
  data: null,
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
);

final CampaignActor _sampleActor = testCampaignActor(
  id: 'actor-1',
  campaignId: 'campaign-1',
  ownerUserId: 'user-1',
  sourceCharacterId: 'char-1',
  actorType: 'player',
  status: 'active',
  sheet: const {
    'name': 'Test Hero',
    'currentHp': 10,
    'maxHp': 20,
    'armorClass': 15,
    'speed': 30,
  },
  revision: 1,
);

final CampaignActor _sampleNpc = testCampaignActor(
  id: 'actor-2',
  campaignId: 'campaign-1',
  ownerUserId: null,
  sourceCharacterId: null,
  actorType: 'npc',
  status: 'active',
  sheet: const {
    'name': 'Goblin Boss',
    'currentHp': 15,
    'maxHp': 15,
    'armorClass': 13,
    'speed': 30,
  },
  revision: 1,
);

final CampaignActor _archivedActor = testCampaignActor(
  id: 'actor-3',
  campaignId: 'campaign-1',
  ownerUserId: null,
  sourceCharacterId: null,
  actorType: 'npc',
  status: 'archived',
  sheet: const {
    'name': 'Old Villain',
    'currentHp': 0,
    'maxHp': 30,
    'armorClass': 12,
    'speed': 30,
  },
  revision: 2,
);
