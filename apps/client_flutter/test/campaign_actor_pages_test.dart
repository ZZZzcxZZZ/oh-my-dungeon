import 'package:dnd_table_client/src/features/campaigns/data/sync/campaign_sync_api_client.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_actor.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/actors/campaign_actor_controller.dart';
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

  testWidgets(
    'player mode shows local characters and dm mode shows actor directory',
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
          _sampleActor,
          _sampleNpc,
          _archivedActor,
        ],
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

      // Player mode: shows local characters list with publish action.
      expect(find.byKey(const Key('player-local-characters')), findsOneWidget);
      expect(find.text('Mira'), findsOneWidget);
      expect(find.text('发布到战役'), findsWidgets);

      // Switch to DM mode via the dedicated switch.
      await tester.tap(find.byKey(const Key('mode-switch-dm')));
      await tester.pumpAndSettle();

      // DM mode: shows campaign actor directory; publish action is hidden.
      expect(find.byKey(const Key('campaign-actor-directory')), findsOneWidget);
      expect(find.text('发布到战役'), findsNothing);
      expect(find.text('Test Hero'), findsOneWidget);
      expect(find.text('Goblin Boss'), findsOneWidget);
      // Archived actor is hidden by default.
      expect(find.text('Old Villain'), findsNothing);

      characterController.dispose();
      actorController.dispose();
      modeController.dispose();
    },
  );

  testWidgets(
    'dm mode actor directory supports search and status filters',
    (tester) async {
      final cacheRepository = MemoryCampaignCacheRepository(
        actors: [
          _sampleActor,
          _sampleNpc,
          _archivedActor,
        ],
      );
      final apiClient = MemoryCampaignSyncApiClient();
      final modeController = ClientModeController(
        initialMode: ClientMode.dungeonMaster,
      );
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
            controller: CharacterController(
              repository: MemoryCharacterRepository(),
            ),
            modeController: modeController,
            actorController: actorController,
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
      await tester.enterText(
        find.byKey(const Key('actor-directory-search')),
        '',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('filter-chip-archived')));
      await tester.pumpAndSettle();
      expect(find.text('Test Hero'), findsNothing);
      expect(find.text('Goblin Boss'), findsNothing);
      expect(find.text('Old Villain'), findsOneWidget);

      actorController.dispose();
      modeController.dispose();
    },
  );

  testWidgets(
    'dm opens actor sheet and updates hp with base revision',
    (tester) async {
      final cacheRepository = MemoryCampaignCacheRepository(
        actors: [_sampleActor],
      );
      final apiClient = MemoryCampaignSyncApiClient();
      final modeController = ClientModeController(
        initialMode: ClientMode.dungeonMaster,
      );
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
            controller: CharacterController(
              repository: MemoryCharacterRepository(),
            ),
            modeController: modeController,
            actorController: actorController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Test Hero'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('campaign-actor-sheet')), findsOneWidget);
      expect(find.textContaining('HP 10/20'), findsOneWidget);

      await tester.tap(find.byTooltip('受到 1 点伤害'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      expect(apiClient.updateActorCalls, hasLength(1));
      expect(apiClient.updateActorCalls.last['baseRevision'], 1);
      expect(apiClient.updateActorCalls.last['actorId'], 'actor-1');
      final sheet = apiClient.updateActorCalls.last['sheet']!
          as Map<String, Object?>;
      expect(sheet['currentHp'], 9);

      actorController.dispose();
      modeController.dispose();
    },
  );

  testWidgets(
    'publish character sheet submits to api with base revision 0',
    (tester) async {
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

      await tester.tap(find.byKey(const Key('publish-character-char-1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('publish-character-sheet')), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '发布'));
      await tester.pumpAndSettle();

      expect(apiClient.publishCalls, hasLength(1));
      expect(apiClient.publishCalls.last['sourceCharacterId'], 'char-1');
      expect(apiClient.publishCalls.last['actorType'], 'player');
      expect(apiClient.publishCalls.last['baseRevision'], 0);

      characterController.dispose();
      actorController.dispose();
      modeController.dispose();
    },
  );

  testWidgets(
    'actor update conflict shows comparison and reload action',
    (tester) async {
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
      final modeController = ClientModeController(
        initialMode: ClientMode.dungeonMaster,
      );
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
            controller: CharacterController(
              repository: MemoryCharacterRepository(),
            ),
            modeController: modeController,
            actorController: actorController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Test Hero'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('受到 1 点伤害'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('actor-conflict-dialog')), findsOneWidget);
      expect(find.textContaining('已被其他主持人修改'), findsOneWidget);
      expect(find.textContaining('当前 HP 5'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '重新加载'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('actor-conflict-dialog')), findsNothing);

      actorController.dispose();
      modeController.dispose();
    },
  );
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
