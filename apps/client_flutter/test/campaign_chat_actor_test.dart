import 'package:dnd_table_client/src/features/auth/data/auth_api_client.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:dnd_table_client/src/features/auth/domain/auth_session.dart';
import 'package:dnd_table_client/src/features/auth/presentation/auth_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/data/campaign_api_client.dart';
import 'package:dnd_table_client/src/features/campaigns/data/campaign_socket_service.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_archive_entry.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/actors/campaign_actor_controller.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_detail_page.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/campaign_chat_page.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/campaign_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/chat/campaign_chat_bubble.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/chat/campaign_chat_composer.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/chat/campaign_chat_timeline.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/widgets/campaign_avatar.dart';
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_controller.dart';
import 'package:dnd_table_client/src/features/content/data/local/content_repository.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_detail_page.dart';
import 'package:dnd_table_client/src/core/dice/dice_roller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/character_test_support.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/content/campaign_content_controller.dart';

import 'support/campaign_test_support.dart';
import 'support/content_test_support.dart';

const _apiBaseUrl = 'http://localhost:3000/api';

const _campaign = Campaign(
  id: 'camp-1',
  name: 'Test Campaign',
  description: '',
  system: 'dnd5e',
  ownerId: 'user-1',
  status: 'active',
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
  memberPreview: [
    CampaignMemberPreview(
      userId: 'user-1',
      displayName: 'Dungeon Master',
      role: 'owner',
    ),
    CampaignMemberPreview(
      userId: 'user-2',
      displayName: 'Player Two',
      role: 'player',
    ),
  ],
);

final _character = CharacterSheet.fromJson({
  ...CharacterSheet.local(id: 'char-1', name: 'Arannis', level: 3).toJson(),
  'currentHp': 7,
  'maxHp': 10,
  'data': {
    'actions': [
      {
        'id': 'action-surge',
        'name': '动作如潮',
        'entryId': 'guide:feature/action-surge',
        'formula': '1/use',
      },
    ],
  },
});

void main() {
  late AuthController authController;
  late CampaignController campaignController;
  late CharacterController characterController;
  late ContentRepository contentRepository;
  late _RecordingCampaignClient campaignClient;
  late CampaignActorController actorController;

  setUp(() async {
    final tokenStore = InMemoryAuthTokenStore();
    await tokenStore.saveTokens(
      'localhost',
      const StoredAuthTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    );
    authController = AuthController(
      tokenStore: tokenStore,
      authClient: _FakeAuthClient(),
      serverProfileId: 'localhost',
      apiBaseUrl: _apiBaseUrl,
    );
    await authController.initialize();

    campaignClient = _RecordingCampaignClient();
    campaignController = CampaignController(
      apiBaseUrl: _apiBaseUrl,
      authController: authController,
      campaignClient: campaignClient,
      campaignSocketService: NoopCampaignSocketService(),
    );

    characterController = CharacterController(
      repository: MemoryCharacterRepository(initial: [_character]),
    );

    contentRepository = MemoryContentRepository(
      initialEntries: [testFighterEntry()],
    );
    actorController = CampaignActorController(
      cacheRepository: MemoryCampaignCacheRepository(
        actors: [
          testCampaignActor(
            id: 'actor-player',
            campaignId: _campaign.id,
            ownerUserId: 'user-2',
            sourceCharacterId: _character.id,
            sheet: _character.toJson(),
          ),
        ],
      ),
      apiClient: MemoryCampaignSyncApiClient(),
      apiBaseUrl: _apiBaseUrl,
      accessToken: 'access-token',
      currentUserId: 'user-1',
    );
    await actorController.selectCampaign(_campaign.id);
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() {
    campaignController.dispose();
    characterController.dispose();
    actorController.dispose();
    authController.dispose();
  });

  Future<void> pumpChatPage(
    WidgetTester tester, {
    String? campaignActorId,
    bool isDm = false,
    DiceRoller? diceRoller,
    CampaignContentController? campaignContentController,
  }) async {
    // Per spec §客户端工作模式: client mode must not grant campaign rights.
    // canManageCampaign is the only authority for DM UI; isDm is the app
    // preference and must NOT affect chat page behavior.
    campaignClient.canManageCampaign = isDm;
    await tester.pumpWidget(
      MaterialApp(
        home: CampaignChatPage(
          campaign: _campaign,
          character: _character,
          campaignActorId: campaignActorId,
          campaignController: campaignController,
          contentRepository: contentRepository,
          actorController: actorController,
          diceRoller: diceRoller,
          campaignContentController: campaignContentController,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('action mode sends an italic action message', (tester) async {
    await pumpChatPage(tester, campaignActorId: 'actor-1');

    await tester.tap(find.byKey(const Key('chat-mode-action')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('campaign-chat-input')),
      '拔出长剑',
    );
    await tester.tap(find.byKey(const Key('campaign-chat-send')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('action-message')), findsOneWidget);
    final actionText = tester.widget<Text>(find.text('拔出长剑'));
    expect(actionText.style?.fontStyle, FontStyle.italic);
    expect(find.text('Arannis'), findsWidgets);
  });

  testWidgets('system messages use emphasized event styling', (tester) async {
    campaignClient.messages = const [
      CampaignChatMessage(
        id: 'system-1',
        campaignId: 'camp-1',
        senderId: 'user-1',
        campaignActorId: null,
        displayName: 'ranger',
        avatarUrl: null,
        kind: 'system',
        content: 'Arannis 获得长剑',
        createdAt: '2026-07-09T00:00:00.000Z',
      ),
    ];

    await pumpChatPage(tester, isDm: true);

    final text = tester.widget<Text>(find.text('Arannis 获得长剑'));
    expect(text.style?.fontWeight, FontWeight.bold);
  });

  testWidgets('narrator messages use a dedicated centered presentation', (
    tester,
  ) async {
    campaignClient.messages = const [
      CampaignChatMessage(
        id: 'narrator-1',
        campaignId: 'camp-1',
        senderId: 'user-1',
        campaignActorId: null,
        displayName: '旁白 / DM',
        avatarUrl: null,
        speakerMode: 'narrator',
        kind: 'say',
        content: '门在你们身后缓缓关闭。',
        createdAt: '2026-07-09T00:00:00.000Z',
      ),
    ];

    await pumpChatPage(tester, isDm: true);

    expect(find.byKey(const Key('narrator-message')), findsOneWidget);
    expect(find.byKey(const Key('say-message')), findsNothing);
    expect(find.text('门在你们身后缓缓关闭。'), findsOneWidget);
  });
  testWidgets(
    'chat avatars preserve the health state captured when the message was sent',
    (tester) async {
      campaignClient.messages = const [
        CampaignChatMessage(
          id: 'health-1',
          campaignId: 'camp-1',
          senderId: 'user-2',
          campaignActorId: 'actor-player',
          displayName: 'Arannis',
          avatarUrl: null,
          publicHealthState: 'injured',
          publicHealthFraction: 0.42,
          kind: 'say',
          content: 'Still standing.',
          createdAt: '2026-07-09T00:00:00.000Z',
        ),
      ];

      await pumpChatPage(tester);

      final message = find.byKey(const Key('say-message'));
      final messageAvatar = find.descendant(
        of: message,
        matching: find.byType(CampaignAvatar),
      );
      expect(messageAvatar, findsOneWidget);
      var avatar = tester.widget<CampaignAvatar>(messageAvatar);
      expect(avatar.health, CampaignAvatarHealth.injured);
      expect(avatar.healthFraction, 0.42);

      final actor = actorController.actors.singleWhere(
        (candidate) => candidate.id == 'actor-player',
      );
      expect(
        await actorController.updateActor(actor, {
          ...actor.sheet,
          'currentHp': 2,
          'maxHp': 10,
        }),
        isTrue,
      );
      await tester.pumpAndSettle();

      final updatedActor = actorController.actors.singleWhere(
        (candidate) => candidate.id == 'actor-player',
      );
      expect(updatedActor.sheet['currentHp'], 2);
      expect(updatedActor.sheet['maxHp'], 10);
      avatar = tester.widget<CampaignAvatar>(messageAvatar);
      expect(avatar.health, CampaignAvatarHealth.injured);
      expect(avatar.healthFraction, 0.42);
    },
  );

  testWidgets(
    'tool panel current identity uses the actor current HP fraction',
    (tester) async {
      await pumpChatPage(tester, campaignActorId: 'actor-player');

      await tester.tap(find.byKey(const Key('campaign-chat-identity')));
      await tester.pumpAndSettle();

      final avatarFinder = find.descendant(
        of: find.byKey(const Key('tool-current-identity')),
        matching: find.byType(CampaignAvatar),
      );
      final avatar = tester.widget<CampaignAvatar>(avatarFinder);
      expect(avatar.health, CampaignAvatarHealth.healthy);
      expect(avatar.healthFraction, 0.7);
    },
  );

  testWidgets('identity switch uses current actor HP over workspace grade', (
    tester,
  ) async {
    campaignClient.canManageCampaign = true;
    campaignClient.workspaceActors = const [
      CampaignWorkspaceActor(
        id: 'actor-player',
        ownerUserId: 'user-2',
        actorType: 'player',
        status: 'active',
        lifecycle: 'persistent',
        displayName: 'Arannis',
        avatarAssetId: null,
        publicHealthState: 'critical',
      ),
    ];
    await pumpChatPage(tester, isDm: true, campaignActorId: 'actor-player');

    await tester.tap(find.byKey(const Key('campaign-chat-identity')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tool-dm-identity-switch')));
    await tester.pumpAndSettle();

    final avatarFinder = find.descendant(
      of: find.byKey(const Key('identity-actor-actor-player')),
      matching: find.byType(CampaignAvatar),
    );
    final avatar = tester.widget<CampaignAvatar>(avatarFinder);
    expect(avatar.health, CampaignAvatarHealth.healthy);
    expect(avatar.healthFraction, 0.7);
  });

  testWidgets('content tool reads the offline campaign-aware repository', (
    tester,
  ) async {
    await pumpChatPage(tester);

    await tester.tap(find.byKey(const Key('campaign-chat-identity')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('资料条目'));
    await tester.pumpAndSettle();

    expect(find.text('战士'), findsOneWidget);
  });

  testWidgets('say mode sends a bubble message', (tester) async {
    await pumpChatPage(tester, campaignActorId: 'actor-1');

    await tester.tap(find.byKey(const Key('chat-mode-say')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('campaign-chat-input')),
      '向酒馆老板打听消息',
    );
    await tester.tap(find.byKey(const Key('campaign-chat-send')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('say-message')), findsOneWidget);
    expect(find.text('向酒馆老板打听消息'), findsOneWidget);
  });

  testWidgets('character action tool sends a stable action id', (tester) async {
    await pumpChatPage(tester, campaignActorId: 'actor-1');

    await tester.tap(find.byKey(const Key('campaign-chat-identity')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('角色动作'));
    await tester.pumpAndSettle();

    expect(find.text('动作如潮'), findsOneWidget);
    await tester.tap(find.byKey(const Key('character-action-action-surge')));
    await tester.pumpAndSettle();

    expect(campaignClient.sendMessageCalls, hasLength(1));
    final call = campaignClient.sendMessageCalls.single;
    expect(call.kind, 'action');
    expect(call.content, '动作如潮');
    expect(call.campaignActorId, 'actor-1');
    expect(call.actionId, 'action-surge');
    expect(find.byKey(const Key('rules-action-message')), findsOneWidget);
    expect(find.textContaining('guide:feature/action-surge'), findsOneWidget);
  });

  testWidgets(
    'sendMessage uses campaignActorId not characterId or displayName',
    (tester) async {
      await pumpChatPage(tester, campaignActorId: 'actor-1');

      await tester.tap(find.byKey(const Key('chat-mode-action')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('campaign-chat-input')),
        '推开大门',
      );
      await tester.tap(find.byKey(const Key('campaign-chat-send')));
      await tester.pumpAndSettle();

      expect(campaignClient.sendMessageCalls, hasLength(1));
      final call = campaignClient.sendMessageCalls.single;
      expect(call.campaignActorId, 'actor-1');
      expect(call.kind, 'action');
      expect(call.content, '推开大门');
    },
  );

  testWidgets('sendMessage sends null campaignActorId when no actor is bound', (
    tester,
  ) async {
    await pumpChatPage(tester);

    await tester.enterText(find.byKey(const Key('campaign-chat-input')), '你好');
    await tester.tap(find.byKey(const Key('campaign-chat-send')));
    await tester.pumpAndSettle();

    expect(campaignClient.sendMessageCalls, hasLength(1));
    expect(campaignClient.sendMessageCalls.single.campaignActorId, isNull);
  });

  testWidgets('opens character information from the composer identity button', (
    tester,
  ) async {
    await pumpChatPage(tester, campaignActorId: 'actor-1');

    await tester.tap(find.byKey(const Key('campaign-chat-identity')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Arannis'), findsWidgets);
  });

  testWidgets('keeps identity in the composer instead of a tall chat header', (
    tester,
  ) async {
    await pumpChatPage(tester, campaignActorId: 'actor-1');

    expect(find.byKey(const Key('campaign-chat-identity')), findsOneWidget);
    expect(find.byKey(const Key('campaign-chat-identity-bar')), findsNothing);
  });

  testWidgets(
    'campaign chat stays focused and does not expose the retired swipe hub',
    (tester) async {
      await pumpChatPage(tester, isDm: true);

      expect(find.byKey(const Key('campaign-chat-page')), findsOneWidget);
      expect(find.byKey(const Key('campaign-hub-page')), findsNothing);
      expect(find.byKey(const Key('campaign-workspace')), findsNothing);
    },
  );

  testWidgets('member sheet joins campaign membership with actor status', (
    tester,
  ) async {
    await pumpChatPage(tester, isDm: true);

    await tester.tap(find.byKey(const Key('campaign-open-center')));
    await tester.pumpAndSettle();

    expect(find.text('Dungeon Master'), findsOneWidget);
    expect(find.text('Player Two'), findsOneWidget);
    expect(find.textContaining('Arannis'), findsWidgets);
  });

  testWidgets('dm directly rolls a player skill check from chat tools', (
    tester,
  ) async {
    await pumpChatPage(
      tester,
      isDm: true,
      diceRoller: DiceRoller(nextInt: (_) => 14),
    );

    await tester.tap(find.byKey(const Key('campaign-chat-identity')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('代掷检定'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('campaign-actor-actor-player')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('check-type-skill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('roll-check-now')));
    await tester.pumpAndSettle();

    final call = campaignClient.sendMessageCalls.single;
    expect(call.kind, 'roll');
    expect(call.campaignActorId, 'actor-player');
    expect(call.eventData, containsPair('targetActorId', 'actor-player'));
    expect(call.eventData, containsPair('checkType', 'skill'));
    expect(call.eventData, containsPair('checkKey', '杂技'));
    expect(call.eventData, containsPair('dmRolled', true));
    expect(call.eventData, containsPair('total', 15));
  });

  testWidgets('target player answers a check request with a linked roll', (
    tester,
  ) async {
    campaignClient.messages = const [
      CampaignChatMessage(
        id: 'request-1',
        campaignId: 'camp-1',
        senderId: 'user-1',
        campaignActorId: null,
        displayName: 'DM',
        avatarUrl: null,
        kind: 'checkRequest',
        content: '要求 Arannis 进行杂技技能检定',
        createdAt: '2026-07-09T00:00:00.000Z',
        eventData: {
          'targetActorId': 'actor-1',
          'checkType': 'skill',
          'checkKey': '杂技',
          'label': '杂技技能检定',
          'rollMode': 'normal',
        },
      ),
    ];

    await pumpChatPage(
      tester,
      campaignActorId: 'actor-1',
      diceRoller: DiceRoller(nextInt: (_) => 9),
    );
    await tester.tap(find.byKey(const Key('respond-check-request')));
    await tester.pumpAndSettle();

    final call = campaignClient.sendMessageCalls.single;
    expect(call.kind, 'roll');
    expect(call.campaignActorId, 'actor-1');
    expect(call.eventData, {
      'requestId': 'request-1',
      'notation': 'd20',
      'label': '杂技技能检定',
      'total': 10,
    });
  });

  testWidgets(
    'tapping a chat bubble avatar opens the full read-only actor sheet',
    (tester) async {
      campaignClient.messages = const [
        CampaignChatMessage(
          id: 'avatar-1',
          campaignId: 'camp-1',
          senderId: 'user-2',
          campaignActorId: 'actor-player',
          displayName: 'Arannis',
          avatarUrl: null,
          kind: 'say',
          content: 'Hello',
          createdAt: '2026-07-09T00:00:00.000Z',
        ),
      ];

      await pumpChatPage(tester);

      final bubbleAvatar = find.descendant(
        of: find.byType(CampaignChatBubble),
        matching: find.byType(CampaignAvatar),
      );
      expect(bubbleAvatar, findsOneWidget);
      await tester.tap(bubbleAvatar);
      await tester.pumpAndSettle();

      expect(find.byType(CharacterDetailPage), findsOneWidget);
      expect(find.text('Arannis'), findsWidgets);
      final sheet = tester.widget<CharacterDetailPage>(
        find.byType(CharacterDetailPage),
      );
      expect(sheet.onUpdateRuntime, isNull);
      expect(sheet.onSaveCharacter, isNull);
      expect(sheet.contentEntries, isNotEmpty);
    },
  );

  testWidgets('DM opens another player full sheet with editing authority', (
    tester,
  ) async {
    campaignClient.messages = const [
      CampaignChatMessage(
        id: 'avatar-dm-1',
        campaignId: 'camp-1',
        senderId: 'user-2',
        campaignActorId: 'actor-player',
        displayName: 'Arannis',
        avatarUrl: null,
        kind: 'say',
        content: 'Hello',
        createdAt: '2026-07-09T00:00:00.000Z',
      ),
    ];

    await pumpChatPage(tester, isDm: true);
    await tester.tap(
      find.descendant(
        of: find.byType(CampaignChatBubble),
        matching: find.byType(CampaignAvatar),
      ),
    );
    await tester.pumpAndSettle();

    final sheet = tester.widget<CharacterDetailPage>(
      find.byType(CharacterDetailPage),
    );
    expect(sheet.onUpdateRuntime, isNotNull);
    expect(sheet.onUpdateInventory, isNotNull);
    expect(sheet.onSaveCharacter, isNotNull);
  });
  testWidgets('avatar without a resolvable actor stays silent on tap', (
    tester,
  ) async {
    campaignClient.messages = const [
      CampaignChatMessage(
        id: 'avatar-2',
        campaignId: 'camp-1',
        senderId: 'user-2',
        campaignActorId: null,
        displayName: 'Stranger',
        avatarUrl: null,
        kind: 'say',
        content: 'Hello',
        createdAt: '2026-07-09T00:00:00.000Z',
      ),
    ];

    await pumpChatPage(tester);

    final bubbleAvatar = find.descendant(
      of: find.byType(CampaignChatBubble),
      matching: find.byType(CampaignAvatar),
    );
    expect(bubbleAvatar, findsOneWidget);
    await tester.tap(bubbleAvatar);
    await tester.pumpAndSettle();

    expect(find.byType(CharacterDetailPage), findsNothing);
  });

  testWidgets(
    'DM creates a temporary identity draft and sends the first message atomically',
    (tester) async {
      await pumpChatPage(tester, isDm: true);

      await tester.tap(find.byKey(const Key('campaign-chat-identity')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('identity-temporary-entry')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('draft-identity-name')),
        '旅店老板',
      );
      await tester.tap(find.byKey(const Key('draft-identity-confirm')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('campaign-chat-input')),
        '欢迎光临',
      );
      await tester.tap(find.byKey(const Key('campaign-chat-send')));
      await tester.pumpAndSettle();

      expect(campaignClient.sendMessageCalls, hasLength(1));
      final call = campaignClient.sendMessageCalls.single;
      expect(call.draftActor, isNotNull);
      expect(call.draftActor!['displayName'], '旅店老板');
      expect(call.campaignActorId, isNull);
      expect(call.kind, anyOf('say', 'action'));
      expect(call.content, '欢迎光临');
    },
  );

  testWidgets(
    'failed draft send keeps the draft and shows the spec error string',
    (tester) async {
      campaignClient.sendMessageException = const CampaignApiException(
        '临时角色创建失败',
        statusCode: 500,
      );

      await pumpChatPage(tester, isDm: true);

      await tester.tap(find.byKey(const Key('campaign-chat-identity')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('identity-temporary-entry')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('draft-identity-name')),
        '神秘人',
      );
      await tester.tap(find.byKey(const Key('draft-identity-confirm')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('campaign-chat-input')),
        '你好',
      );
      await tester.tap(find.byKey(const Key('campaign-chat-send')));
      await tester.pumpAndSettle();

      expect(find.text('临时角色创建失败，消息尚未发送。'), findsOneWidget);
      expect(campaignClient.sendMessageCalls, hasLength(1));
      expect(
        campaignClient.sendMessageCalls.single.draftActor?['displayName'],
        '神秘人',
      );
    },
  );

  // Spec §客户端工作模式: 普通玩家切换全局 DM 模式后仍不出现战役 DM 功能。
  // CampaignChatPage 必须不接收 isDm 入参；所有 DM UI 一律依据
  // workspaceContext.capabilities.canManageCampaign。
  testWidgets(
    'player with DM app preference still sees no DM-only tools when capabilities say player',
    (tester) async {
      // App preference is DM mode, but server capabilities say player.
      campaignClient.canManageCampaign = false;
      await tester.pumpWidget(
        MaterialApp(
          home: CampaignChatPage(
            campaign: _campaign,
            character: _character,
            campaignActorId: 'actor-1',
            campaignController: campaignController,
            contentRepository: contentRepository,
            actorController: actorController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Merged tool panel opens on avatar tap (spec §输入栏).
      await tester.tap(find.byKey(const Key('campaign-chat-identity')));
      await tester.pumpAndSettle();

      // DM-only entries must NOT appear for a player.
      // Per spec: interface does not show disabled DM features.
      // Note: campaign-dm-control-entry has been migrated to 战役中心 → 概览
      // per spec §概览, so it must not appear in chat for anyone.
      expect(find.byKey(const Key('identity-temporary-entry')), findsNothing);
      expect(find.byKey(const Key('campaign-dm-control-entry')), findsNothing);
      expect(find.byKey(const Key('tool-dm-identity-switch')), findsNothing);
    },
  );

  // Spec §发言身份 DM: DM uses 旁白/DM, 场外, 常驻 NPC/怪物/同伴, 临时角色,
  // 代管玩家角色. DM must NOT be asked to "绑定角色" — that path is for players.
  testWidgets(
    'DM identity panel shows narrator/ooc/persistent actors/temp/proxy sections and no bound-character entry',
    (tester) async {
      campaignClient.canManageCampaign = true;
      campaignClient.workspaceActors = [
        const CampaignWorkspaceActor(
          id: 'actor-npc-1',
          ownerUserId: null,
          actorType: 'npc',
          status: 'active',
          lifecycle: 'persistent',
          displayName: '酒馆老板',
          avatarAssetId: null,
          publicHealthState: 'unknown',
        ),
        const CampaignWorkspaceActor(
          id: 'actor-monster-1',
          ownerUserId: 'user-1',
          actorType: 'monster',
          status: 'active',
          lifecycle: 'persistent',
          displayName: '哥布林',
          avatarAssetId: null,
          publicHealthState: 'unknown',
        ),
        const CampaignWorkspaceActor(
          id: 'actor-temp-1',
          ownerUserId: null,
          actorType: 'npc',
          status: 'active',
          lifecycle: 'temporary',
          displayName: '临时守卫',
          avatarAssetId: null,
          publicHealthState: 'healthy',
        ),
        const CampaignWorkspaceActor(
          id: 'actor-player-2',
          ownerUserId: 'user-2',
          actorType: 'player',
          status: 'active',
          lifecycle: 'persistent',
          displayName: 'Arannis',
          avatarAssetId: null,
          publicHealthState: 'injured',
        ),
      ];

      await pumpChatPage(tester, isDm: true);
      await tester.tap(find.byKey(const Key('campaign-chat-identity')));
      await tester.pumpAndSettle();

      // 快速临时身份 lives in the merged tool panel per spec §输入栏.
      expect(find.byKey(const Key('identity-temporary-entry')), findsOneWidget);

      // Open the DM identity sub-panel via the "DM 身份切换" entry.
      await tester.tap(find.byKey(const Key('tool-dm-identity-switch')));
      await tester.pumpAndSettle();

      // DM-only entries — all required by spec §发言身份 DM.
      expect(find.byKey(const Key('identity-narrator-entry')), findsOneWidget);
      expect(find.byKey(const Key('identity-ooc-entry')), findsOneWidget);
      expect(
        find.byKey(const Key('identity-actor-actor-npc-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('identity-actor-actor-monster-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('identity-actor-actor-temp-1')),
        findsOneWidget,
      );
      // Proxy entry for player-owned actor (ownerUserId != current user).
      expect(
        find.byKey(const Key('identity-actor-actor-player-2')),
        findsOneWidget,
      );

      // The "绑定角色" entry is player-only and must NOT appear for DM.
      expect(
        find.byKey(const Key('identity-bound-character-entry')),
        findsNothing,
      );
    },
  );

  // Spec §快速临时身份: DM identity switch panel must retain a 快速临时身份
  // entry so DMs can start a one-off speaker without leaving the identity
  // sheet. The entry is shared with the merged tool panel via the same
  // _draftIdentity state.
  testWidgets('DM identity panel exposes the quick temporary identity entry', (
    tester,
  ) async {
    campaignClient.canManageCampaign = true;
    campaignClient.workspaceActors = const [];

    await pumpChatPage(tester, isDm: true);
    await tester.tap(find.byKey(const Key('campaign-chat-identity')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tool-dm-identity-switch')));
    await tester.pumpAndSettle();

    // The quick temporary identity entry is part of the DM identity panel.
    expect(
      find.byKey(const Key('identity-quick-temporary-entry')),
      findsOneWidget,
    );
    expect(find.text('快速临时身份'), findsOneWidget);

    // Tapping the entry opens the draft form sheet on top.
    await tester.tap(find.byKey(const Key('identity-quick-temporary-entry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('draft-identity-name')), findsOneWidget);
  });

  testWidgets('say and action modes show text labels with semantic icons', (
    tester,
  ) async {
    await pumpChatPage(tester, campaignActorId: 'actor-1');

    // Task 1.2: 滑块切换动画改为带文字标签（说/做），不再仅显示图标。
    expect(find.text('说'), findsWidgets);
    expect(find.text('做'), findsWidgets);
    expect(find.byKey(const Key('chat-mode-say')), findsOneWidget);
    expect(find.byKey(const Key('chat-mode-action')), findsOneWidget);
  });

  testWidgets(
    'player identity panel does not expose the quick temporary identity entry',
    (tester) async {
      campaignClient.canManageCampaign = false;
      campaignClient.workspaceActors = const [];

      await pumpChatPage(tester, isDm: false);
      await tester.tap(find.byKey(const Key('campaign-chat-identity')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tool-player-identity-switch')));
      await tester.pumpAndSettle();

      // The quick temporary identity entry is DM-only.
      expect(
        find.byKey(const Key('identity-quick-temporary-entry')),
        findsNothing,
      );
    },
  );

  // Spec §发言身份 玩家: player can switch between 绑定角色 and 场外 only.
  // Player must NOT see DM-only entries (narrator, temporary, NPC list, proxy).
  testWidgets(
    'unbound player identity panel shows only bound-character and ooc entries',
    (tester) async {
      campaignClient.canManageCampaign = false;
      campaignClient.workspaceActors = const [];
      // Membership has no boundActorId — simulates unbound player.
      campaignClient.workspaceMembership = const CampaignMembership(
        id: 'member-1',
        campaignId: 'camp-1',
        userId: 'user-1',
        role: 'player',
        displayName: 'Player One',
        joinedAt: '2026-07-09T00:00:00.000Z',
      );

      await pumpChatPage(tester, isDm: false);
      await tester.tap(find.byKey(const Key('campaign-chat-identity')));
      await tester.pumpAndSettle();

      // DM-only entries must NOT appear for player in the merged tool panel.
      expect(find.byKey(const Key('identity-temporary-entry')), findsNothing);
      expect(find.byKey(const Key('tool-dm-identity-switch')), findsNothing);

      // Open the player identity sub-panel via "切换发言身份".
      await tester.tap(find.byKey(const Key('tool-player-identity-switch')));
      await tester.pumpAndSettle();

      // Player-only entries — required by spec §发言身份 玩家.
      expect(
        find.byKey(const Key('identity-bound-character-entry')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('identity-ooc-entry')), findsOneWidget);

      // DM-only entries must NOT appear for player.
      expect(find.byKey(const Key('identity-narrator-entry')), findsNothing);
    },
  );

  // Spec §输入栏: 当前身份头像取代原有独立 `+` 按钮. The separate `+` button
  // must be removed from the composer; the avatar tap opens the merged panel
  // with 11 spec-defined tools.
  testWidgets(
    'merged tool panel shows 11 spec entries and removes the + button',
    (tester) async {
      campaignClient.canManageCampaign = true;
      campaignClient.workspaceActors = const [];
      await pumpChatPage(tester, isDm: true, campaignActorId: 'actor-1');

      // The separate `+` button (tooltip 更多跑团功能) must NOT exist.
      expect(find.byTooltip('更多跑团功能'), findsNothing);

      // Avatar tap opens the merged tool panel.
      await tester.tap(find.byKey(const Key('campaign-chat-identity')));
      await tester.pumpAndSettle();

      // Spec §输入栏 11 tools (DM sees all):
      // 1. 当前身份精确信息 (header)
      expect(find.byKey(const Key('tool-current-identity')), findsOneWidget);
      // 2. 打开角色卡
      expect(
        find.byKey(const Key('tool-open-character-sheet')),
        findsOneWidget,
      );
      // 3. 掷骰
      expect(find.byKey(const Key('tool-roll-dice')), findsOneWidget);
      // 4. 技能检定
      expect(find.byKey(const Key('tool-skill-check')), findsOneWidget);
      // 5. HP 与状态
      expect(find.byKey(const Key('tool-hp-status')), findsOneWidget);
      // 6. 资料条目
      expect(find.byKey(const Key('tool-content-entries')), findsOneWidget);
      // 7. 记录线索
      expect(find.byKey(const Key('tool-record-clue')), findsOneWidget);
      // 8. 分享地点
      expect(find.byKey(const Key('tool-share-location')), findsOneWidget);
      // 9. 群文件
      expect(find.byKey(const Key('tool-group-files')), findsOneWidget);
      // 10. DM 身份切换 (DM only)
      expect(find.byKey(const Key('tool-dm-identity-switch')), findsOneWidget);
      // 11. 快速临时身份 (DM only)
      expect(find.byKey(const Key('identity-temporary-entry')), findsOneWidget);

      // Player-only entry must NOT appear for DM.
      expect(
        find.byKey(const Key('tool-player-identity-switch')),
        findsNothing,
      );
    },
  );

  // Spec §输入栏: 界面不显示不可用的 DM 工具. Player must see only the
  // player-applicable tools, with DM-only entries hidden.
  testWidgets(
    'player merged tool panel hides DM-only entries and shows player identity switch',
    (tester) async {
      campaignClient.canManageCampaign = false;
      campaignClient.workspaceActors = const [];
      await pumpChatPage(tester, isDm: false, campaignActorId: 'actor-1');

      expect(find.byTooltip('更多跑团功能'), findsNothing);

      await tester.tap(find.byKey(const Key('campaign-chat-identity')));
      await tester.pumpAndSettle();

      // Player-visible tools (spec §输入栏):
      expect(find.byKey(const Key('tool-current-identity')), findsOneWidget);
      expect(
        find.byKey(const Key('tool-open-character-sheet')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('tool-roll-dice')), findsOneWidget);
      expect(find.byKey(const Key('tool-hp-status')), findsOneWidget);
      expect(find.byKey(const Key('tool-content-entries')), findsOneWidget);

      // These actions write manager-owned campaign state. The server rejects
      // them for players, so the UI must not advertise dead controls.
      expect(find.byKey(const Key('tool-skill-check')), findsNothing);
      expect(find.byKey(const Key('tool-record-clue')), findsNothing);
      expect(find.byKey(const Key('tool-share-location')), findsNothing);
      expect(find.byKey(const Key('tool-group-files')), findsNothing);

      // Player gets "切换发言身份" instead of "DM 身份切换".
      expect(
        find.byKey(const Key('tool-player-identity-switch')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('tool-dm-identity-switch')), findsNothing);

      // DM-only entries must NOT appear for player.
      expect(find.byKey(const Key('identity-temporary-entry')), findsNothing);
      expect(find.byKey(const Key('campaign-dm-control-entry')), findsNothing);
    },
  );

  testWidgets(
    'composer follows the active NPC speaker instead of the local character',
    (tester) async {
      campaignClient.workspaceMembership = const CampaignMembership(
        id: 'member-1',
        campaignId: 'camp-1',
        userId: 'user-1',
        role: 'owner',
        displayName: 'Dungeon Master',
        joinedAt: '2026-07-09T00:00:00.000Z',
        activeSpeakerActorId: 'actor-npc-1',
        speakerMode: 'actor',
      );
      campaignClient.workspaceActors = const [
        CampaignWorkspaceActor(
          id: 'actor-npc-1',
          ownerUserId: 'user-1',
          actorType: 'npc',
          status: 'active',
          lifecycle: 'persistent',
          displayName: '酒馆老板',
          avatarAssetId: null,
          publicHealthState: 'healthy',
        ),
      ];

      await pumpChatPage(tester, isDm: true);
      await tester.tap(find.byKey(const Key('campaign-chat-identity')));
      await tester.pumpAndSettle();

      expect(find.text('酒馆老板'), findsOneWidget);
      expect(find.text('Arannis'), findsNothing);
    },
  );

  testWidgets('OOC speaker uses a compact composer without say/action modes', (
    tester,
  ) async {
    campaignClient.workspaceMembership = const CampaignMembership(
      id: 'member-1',
      campaignId: 'camp-1',
      userId: 'user-1',
      role: 'player',
      displayName: 'Player One',
      joinedAt: '2026-07-09T00:00:00.000Z',
      speakerMode: 'ooc',
    );

    await pumpChatPage(tester);

    expect(find.byKey(const Key('chat-mode-say')), findsNothing);
    expect(find.byKey(const Key('chat-mode-action')), findsNothing);
    final input = tester.widget<TextField>(
      find.byKey(const Key('campaign-chat-input')),
    );
    expect(input.decoration?.hintText, contains('场外'));
  });

  testWidgets(
    'active campaign actor exposes character actions without legacy actor id',
    (tester) async {
      campaignClient.workspaceMembership = const CampaignMembership(
        id: 'member-1',
        campaignId: 'camp-1',
        userId: 'user-1',
        role: 'owner',
        displayName: 'Dungeon Master',
        joinedAt: '2026-07-09T00:00:00.000Z',
        activeSpeakerActorId: 'actor-player',
        speakerMode: 'actor',
      );
      campaignClient.workspaceActors = const [
        CampaignWorkspaceActor(
          id: 'actor-player',
          ownerUserId: 'user-2',
          actorType: 'player',
          status: 'active',
          lifecycle: 'persistent',
          displayName: 'Arannis',
          avatarAssetId: null,
          publicHealthState: 'healthy',
        ),
      ];

      await pumpChatPage(tester, isDm: true);
      await tester.tap(find.byKey(const Key('campaign-chat-identity')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tool-character-actions')), findsOneWidget);
    },
  );

  testWidgets('tool sheet stays usable on a narrow phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpChatPage(tester, isDm: true, campaignActorId: 'actor-1');
    await tester.tap(find.byKey(const Key('campaign-chat-identity')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('tool-dm-identity-switch')), findsOneWidget);
    expect(find.byKey(const Key('identity-temporary-entry')), findsOneWidget);
  });

  testWidgets('tool sheet groups actions by frequency', (tester) async {
    await pumpChatPage(tester, isDm: true, campaignActorId: 'actor-1');
    await tester.tap(find.byKey(const Key('campaign-chat-identity')));
    await tester.pumpAndSettle();

    final primary = find.byKey(const Key('tool-primary-actions'));
    final campaign = find.byKey(const Key('tool-campaign-actions'));
    expect(find.text('Arannis'), findsWidgets);
    expect(primary, findsOneWidget);
    expect(campaign, findsOneWidget);
    expect(
      tester.getTopLeft(primary).dy,
      lessThan(tester.getTopLeft(campaign).dy),
    );
  });

  // Spec §档案: 资料、地点、线索和文件统一属于战役档案, 可从聊天跳转。
  // The 3 previously-disabled toolbar items (记录线索/分享地点/群文件) must
  // now be enabled and route to the archive creation form pre-filled with the
  // corresponding kind.
  testWidgets('record clue tool opens archive creation form with kind=clue', (
    tester,
  ) async {
    await pumpChatPage(tester, isDm: true);

    await tester.tap(find.byKey(const Key('campaign-chat-identity')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tool-record-clue')));
    await tester.pumpAndSettle();

    expect(find.text('新建战役条目'), findsOneWidget);
    // Initial kind should be 线索.
    expect(find.text('线索'), findsWidgets);

    await tester.enterText(find.byType(TextFormField).first, '神秘符文');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(campaignClient.createArchiveEntryCalls, hasLength(1));
    final call = campaignClient.createArchiveEntryCalls.single;
    expect(call.campaignId, _campaign.id);
    expect(call.kind, 'clue');
    expect(call.title, '神秘符文');
  });

  testWidgets(
    'share location tool opens archive creation form with kind=location',
    (tester) async {
      await pumpChatPage(tester, isDm: true);

      await tester.tap(find.byKey(const Key('campaign-chat-identity')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tool-share-location')));
      await tester.pumpAndSettle();

      expect(find.text('新建战役条目'), findsOneWidget);
      expect(find.text('地点'), findsWidgets);

      await tester.enterText(find.byType(TextFormField).first, '老橡树酒馆');
      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      expect(campaignClient.createArchiveEntryCalls, hasLength(1));
      final call = campaignClient.createArchiveEntryCalls.single;
      expect(call.kind, 'location');
      expect(call.title, '老橡树酒馆');
    },
  );

  testWidgets('group files tool opens archive creation form with kind=file', (
    tester,
  ) async {
    await pumpChatPage(tester, isDm: true);

    await tester.tap(find.byKey(const Key('campaign-chat-identity')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tool-group-files')));
    await tester.pumpAndSettle();

    expect(find.text('新建战役条目'), findsOneWidget);
    expect(find.text('文件'), findsWidgets);

    await tester.enterText(find.byType(TextFormField).first, 'NPC关系图');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(campaignClient.createArchiveEntryCalls, hasLength(1));
    final call = campaignClient.createArchiveEntryCalls.single;
    expect(call.kind, 'file');
    expect(call.title, 'NPC关系图');
  });

  testWidgets('chat shell only exposes campaign navigation', (tester) async {
    campaignClient.messages = const [
      CampaignChatMessage(
        id: 'shell-message',
        campaignId: 'camp-1',
        senderId: 'user-2',
        campaignActorId: null,
        displayName: 'Player Two',
        avatarUrl: null,
        kind: 'say',
        content: '准备出发',
        createdAt: '2026-07-09T00:00:00.000Z',
      ),
    ];
    await pumpChatPage(tester);

    expect(find.byKey(const Key('campaign-open-center')), findsOneWidget);
    expect(find.byKey(const Key('campaign-chat-search')), findsNothing);
    expect(find.byKey(const Key('campaign-chat-subtitle')), findsNothing);
    expect(find.byTooltip('战役资料'), findsNothing);
    expect(find.byTooltip('成员'), findsNothing);
    expect(find.byType(CampaignChatTimeline), findsOneWidget);
    expect(find.byType(CampaignChatComposer), findsOneWidget);
  });

  // Spec §输入栏: 战役资料入口迁移到头像快捷面板第 6 项"资料条目"，
  // 不在 AppBar 单独入口。
  testWidgets('tool panel content entry opens the quick content library', (
    tester,
  ) async {
    final contentController = CampaignContentController(
      cacheRepository: MemoryCampaignCacheRepository(),
      apiClient: MemoryCampaignSyncApiClient(),
      apiBaseUrl: _apiBaseUrl,
      accessToken: 'access-token',
      currentUserId: 'user-1',
    );
    await pumpChatPage(tester, campaignContentController: contentController);

    // Open the tool panel by tapping the identity avatar.
    await tester.tap(find.byKey(const Key('campaign-chat-identity')));
    await tester.pumpAndSettle();

    // The composer is for quick lookup; package management stays in campaign center.
    await tester.tap(find.byKey(const Key('tool-content-entries')));
    await tester.pumpAndSettle();

    expect(find.text('战役资料库'), findsOneWidget);
    await tester.tap(find.text('战士'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(ContentDetailPage), findsOneWidget);

    contentController.dispose();
  });

  // Spec §输入栏: 工具面板条目点击后只关闭工具面板, 不应 double-pop
  // 把聊天页弹走。Helper 方法不应自行 Navigator.pop, 关闭 sheet 是调用方职责。
  testWidgets(
    'tool panel roll dice keeps chat page on stage after sheet closes',
    (tester) async {
      await pumpChatPage(tester, isDm: true);

      await tester.tap(find.byKey(const Key('campaign-chat-identity')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tool-roll-dice')));
      await tester.pumpAndSettle();

      // 掷骰 sheet 应当出现, 聊天页仍应保留在栈中 (输入框可见)。
      expect(find.text('快速掷骰'), findsOneWidget);
      expect(find.byKey(const Key('campaign-chat-input')), findsOneWidget);

      // 关闭掷骰 sheet 后, 聊天页应仍然可见。
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('campaign-chat-input')), findsOneWidget);
    },
  );

  testWidgets('tool panel character actions keeps chat page on stage', (
    tester,
  ) async {
    // 角色动作条目仅在 _characterActions 非空且 campaignActorId 非空时出现。
    await pumpChatPage(tester, isDm: true, campaignActorId: 'actor-1');

    await tester.tap(find.byKey(const Key('campaign-chat-identity')));
    await tester.pumpAndSettle();

    final actionsEntry = find.byKey(const Key('tool-character-actions'));
    if (actionsEntry.evaluate().isNotEmpty) {
      await tester.tap(actionsEntry);
      await tester.pumpAndSettle();

      // 角色动作 sheet 出现时聊天页输入框仍在。
      expect(find.byKey(const Key('campaign-chat-input')), findsOneWidget);
    }
  });

  testWidgets('tool panel open character sheet keeps chat page on stage', (
    tester,
  ) async {
    await pumpChatPage(tester, isDm: true, campaignActorId: 'actor-player');

    await tester.tap(find.byKey(const Key('campaign-chat-identity')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tool-open-character-sheet')));
    await tester.pumpAndSettle();

    // 角色详情页应通过 push 进入, 聊天页仍应在栈中 (返回后会回到聊天)。
    expect(find.byType(BackButton), findsOneWidget);
    // 角色详情页应可见。
    expect(find.text('Arannis'), findsWidgets);
    final sheet = tester.widget<CharacterDetailPage>(
      find.byType(CharacterDetailPage),
    );
    expect(sheet.onUpdateRuntime, isNotNull);
    expect(sheet.onSaveCharacter, isNotNull);
  });

  testWidgets('tool panel content library fallback keeps chat page on stage', (
    tester,
  ) async {
    // 不传 campaignContentController, 走 _showContentLibrary 回退分支。
    await pumpChatPage(tester, isDm: true);

    await tester.tap(find.byKey(const Key('campaign-chat-identity')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tool-content-entries')));
    await tester.pumpAndSettle();

    // 资料库 sheet 出现时聊天页输入框仍应在栈中。
    expect(find.byKey(const Key('campaign-chat-input')), findsOneWidget);
  });

  // Spec §全局设置: 战役名称/所有权转移/战役归档/离开战役四项低频操作
  // 已从聊天页右上角三点菜单迁移到战役中心 → 概览面板的"战役设置"区块。
  // 聊天页 AppBar 不再保留三点菜单 (campaign-chat-more-menu 已删除)。
  testWidgets(
    'chat page no longer has the more-menu (migrated to center overview)',
    (tester) async {
      await pumpChatPage(tester, isDm: true);

      expect(find.byKey(const Key('campaign-chat-more-menu')), findsNothing);
    },
  );

  testWidgets('player chat page also has no more-menu', (tester) async {
    await pumpChatPage(tester, isDm: false);

    expect(find.byKey(const Key('campaign-chat-more-menu')), findsNothing);
  });
}

class _RecordingCampaignClient implements CampaignClient {
  @override
  Future<void> markCampaignRead({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async {}
  @override
  Future<CampaignMembership> updateSpeaker({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String speakerMode,
    String? actorId,
  }) => throw UnimplementedError();
  @override
  Future<List<CampaignArchiveEntry>> listArchives({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    String? kind,
    String? query,
    List<String>? tags,
  }) async => const [];
  final List<_CreatedArchiveCall> createArchiveEntryCalls = [];
  @override
  Future<CampaignArchiveEntry> createArchiveEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String kind,
    required String title,
    String? summary,
    Map<String, Object?>? payload,
    List<Map<String, Object?>>? bodyBlocks,
    List<String>? tags,
    List<Map<String, Object?>>? links,
    List<Map<String, Object?>>? attachmentRefs,
  }) async {
    createArchiveEntryCalls.add(
      _CreatedArchiveCall(
        campaignId: campaignId,
        kind: kind,
        title: title,
        summary: summary,
        payload: payload,
      ),
    );
    return CampaignArchiveEntry(
      id: 'archive-${createArchiveEntryCalls.length}',
      campaignId: campaignId,
      kind: kind,
      title: title,
      summary: summary ?? '',
      payload: payload ?? const {},
      pinned: false,
      updatedAt: '2026-07-17T00:00:00.000Z',
    );
  }

  @override
  Future<CampaignArchiveEntry> updateArchiveEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String entryId,
    String? kind,
    String? title,
    String? summary,
    Map<String, Object?>? payload,
    bool? pinned,
    List<Map<String, Object?>>? bodyBlocks,
    List<String>? tags,
    List<Map<String, Object?>>? links,
    List<Map<String, Object?>>? attachmentRefs,
  }) => throw UnimplementedError();
  @override
  Future<void> archiveEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String entryId,
  }) => throw UnimplementedError();
  final List<_SentMessageCall> sendMessageCalls = [];
  List<CampaignChatMessage> messages = [];
  bool canManageCampaign = false;
  CampaignApiException? sendMessageException;

  /// Test-only injection: workspace actors returned by getWorkspaceContext.
  /// Used by spec compliance tests for DM identity switching panel.
  List<CampaignWorkspaceActor> workspaceActors = const [];

  /// Test-only injection: membership returned by getWorkspaceContext.
  /// Allows tests to vary speakerMode / boundActorId per scenario.
  CampaignMembership? workspaceMembership;

  @override
  Future<CampaignWorkspaceContext> getWorkspaceContext({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async {
    return CampaignWorkspaceContext(
      campaign: _campaign,
      membership:
          workspaceMembership ??
          const CampaignMembership(
            id: 'member-1',
            campaignId: 'camp-1',
            userId: 'user-1',
            role: 'player',
            displayName: 'Dungeon Master',
            joinedAt: '2026-07-09T00:00:00.000Z',
          ),
      members: _campaign.memberPreview,
      actors: workspaceActors,
      capabilities: CampaignCapabilities(
        canManageCampaign: canManageCampaign,
        canManageMembers: canManageCampaign,
        canCreateActors: canManageCampaign,
        canSpeakAsNarrator: canManageCampaign,
      ),
    );
  }

  @override
  Future<Campaign> createCampaign({
    required String apiBaseUrl,
    required String accessToken,
    required String name,
    String? description,
    String? system,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Campaign> getCampaign({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<Campaign>> listCampaigns({
    required String apiBaseUrl,
    required String accessToken,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CampaignInvite> createInvite({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    int? maxUses,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<CampaignInvite>> listInvites({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CampaignMembership> joinCampaign({
    required String apiBaseUrl,
    required String accessToken,
    required String code,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<CampaignChatMessage>> listMessages({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    String? query,
  }) async => messages;

  @override
  Future<CampaignChatMessage> sendMessage({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String kind,
    required String content,
    String? campaignActorId,
    String? actionId,
    Map<String, Object?>? eventData,
    Map<String, Object?>? draftActor,
  }) async {
    sendMessageCalls.add(
      _SentMessageCall(
        kind: kind,
        content: content,
        campaignActorId: campaignActorId,
        actionId: actionId,
        eventData: eventData,
        draftActor: draftActor,
      ),
    );
    final exception = sendMessageException;
    if (exception != null) {
      throw exception;
    }
    return CampaignChatMessage(
      id: 'msg-${sendMessageCalls.length}',
      campaignId: campaignId,
      senderId: 'user-1',
      campaignActorId: campaignActorId,
      displayName: 'Arannis',
      avatarUrl: null,
      kind: kind,
      content: content,
      createdAt: '2026-07-09T00:00:00.000Z',
      actionSnapshot: actionId == null
          ? null
          : {
              'id': actionId,
              'name': content,
              'entryId': 'guide:feature/action-surge',
              'formula': '1/use',
              'actorRevision': 3,
            },
      eventData: eventData,
    );
  }
}

class _SentMessageCall {
  const _SentMessageCall({
    required this.kind,
    required this.content,
    required this.campaignActorId,
    required this.actionId,
    required this.eventData,
    required this.draftActor,
  });

  final String kind;
  final String content;
  final String? campaignActorId;
  final String? actionId;
  final Map<String, Object?>? eventData;
  final Map<String, Object?>? draftActor;
}

class _CreatedArchiveCall {
  const _CreatedArchiveCall({
    required this.campaignId,
    required this.kind,
    required this.title,
    required this.summary,
    required this.payload,
  });

  final String campaignId;
  final String kind;
  final String title;
  final String? summary;
  final Map<String, Object?>? payload;
}

class _FakeAuthClient implements AuthClient {
  @override
  Future<AuthSession> login({
    required String apiBaseUrl,
    required String identifier,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout({
    required String apiBaseUrl,
    required String refreshToken,
  }) async {}

  @override
  Future<AuthUser> me({
    required String apiBaseUrl,
    required String accessToken,
  }) async {
    return const AuthUser(
      id: 'user-1',
      username: 'ranger',
      email: 'ranger@example.com',
    );
  }

  @override
  Future<String> refresh({
    required String apiBaseUrl,
    required String refreshToken,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<RegisterResult> register({
    required String apiBaseUrl,
    required String username,
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }
}
