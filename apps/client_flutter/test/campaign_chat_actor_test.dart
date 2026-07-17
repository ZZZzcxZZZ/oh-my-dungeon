import 'package:dnd_table_client/src/features/auth/data/auth_api_client.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:dnd_table_client/src/features/auth/domain/auth_session.dart';
import 'package:dnd_table_client/src/features/auth/presentation/auth_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/data/campaign_api_client.dart';
import 'package:dnd_table_client/src/features/campaigns/data/campaign_socket_service.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_archive_entry.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/actors/campaign_actor_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/campaign_chat_page.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/campaign_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/chat/campaign_chat_bubble.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/chat/chat_avatar.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/widgets/campaign_actor_quick_sheet.dart';
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_controller.dart';
import 'package:dnd_table_client/src/features/content/data/local/content_repository.dart';
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

  testWidgets('chat avatars expose a health ring only when the server shares a state', (tester) async {
    campaignClient.messages = const [
      CampaignChatMessage(
        id: 'health-1',
        campaignId: 'camp-1',
        senderId: 'user-2',
        campaignActorId: 'actor-player',
        displayName: 'Arannis',
        avatarUrl: null,
        publicHealthState: 'injured',
        kind: 'say',
        content: 'Still standing.',
        createdAt: '2026-07-09T00:00:00.000Z',
      ),
    ];

    await pumpChatPage(tester);

    expect(find.byKey(const Key('campaign-avatar-ring-injured')), findsOneWidget);
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

  testWidgets('campaign chat stays focused and does not expose the retired swipe hub', (
    tester,
  ) async {
    await pumpChatPage(tester, isDm: true);

    expect(find.byKey(const Key('campaign-chat-page')), findsOneWidget);
    expect(find.byKey(const Key('campaign-hub-page')), findsNothing);
    expect(find.byKey(const Key('campaign-workspace')), findsNothing);
  });

  testWidgets('member sheet joins campaign membership with actor status', (
    tester,
  ) async {
    await pumpChatPage(tester, isDm: true);

    await tester.tap(find.byKey(const Key('campaign-open-center')));
    await tester.pumpAndSettle();
    // Center now uses NavigationBar; tap the 队伍 destination label.
    await tester.tap(find.text('队伍').last);
    await tester.pumpAndSettle();

    expect(find.text('Dungeon Master'), findsOneWidget);
    expect(find.text('Player Two'), findsOneWidget);
    expect(find.textContaining('Arannis'), findsWidgets);
  });

  testWidgets('dm requests a player skill check directly from chat tools', (
    tester,
  ) async {
    await pumpChatPage(tester, isDm: true);

    await tester.tap(find.byKey(const Key('campaign-chat-identity')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('技能检定'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('campaign-actor-actor-player')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('check-type-skill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('send-check-request')));
    await tester.pumpAndSettle();

    final call = campaignClient.sendMessageCalls.single;
    expect(call.kind, 'checkRequest');
    expect(call.eventData, {
      'targetActorId': 'actor-player',
      'checkType': 'skill',
      'checkKey': '杂技',
      'label': '杂技技能检定',
      'rollMode': 'normal',
    });
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
    'tapping a chat bubble avatar opens the CampaignActorQuickSheet',
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
        matching: find.byType(ChatAvatar),
      );
      expect(bubbleAvatar, findsOneWidget);
      await tester.tap(bubbleAvatar);
      await tester.pumpAndSettle();

      expect(find.byType(CampaignActorQuickSheet), findsOneWidget);
      expect(find.text('Arannis'), findsWidgets);
      expect(find.text('打开角色卡'), findsOneWidget);
    },
  );

  testWidgets(
    'avatar without a resolvable actor stays silent on tap',
    (tester) async {
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
        matching: find.byType(ChatAvatar),
      );
      expect(bubbleAvatar, findsOneWidget);
      await tester.tap(bubbleAvatar);
      await tester.pumpAndSettle();

      expect(find.byType(CampaignActorQuickSheet), findsNothing);
    },
  );

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
      expect(find.byKey(const Key('identity-temporary-entry')), findsNothing);
      expect(find.byKey(const Key('campaign-dm-control-entry')), findsNothing);
      expect(
        find.byKey(const Key('tool-dm-identity-switch')),
        findsNothing,
      );
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
          ownerUserId: 'user-1',
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
      expect(
        find.byKey(const Key('tool-dm-identity-switch')),
        findsNothing,
      );

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
      expect(find.byKey(const Key('tool-open-character-sheet')), findsOneWidget);
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
      expect(find.byKey(const Key('tool-open-character-sheet')), findsOneWidget);
      expect(find.byKey(const Key('tool-roll-dice')), findsOneWidget);
      expect(find.byKey(const Key('tool-skill-check')), findsOneWidget);
      expect(find.byKey(const Key('tool-hp-status')), findsOneWidget);
      expect(find.byKey(const Key('tool-content-entries')), findsOneWidget);
      expect(find.byKey(const Key('tool-record-clue')), findsOneWidget);
      expect(find.byKey(const Key('tool-share-location')), findsOneWidget);
      expect(find.byKey(const Key('tool-group-files')), findsOneWidget);

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

  // Spec §顶部: 聊天顶部只显示返回、战役名称+在线状态、搜索、战役中心。
  testWidgets(
    'chat AppBar only exposes search and campaign center actions',
    (tester) async {
      await pumpChatPage(tester);

      // Must have search and campaign center entries.
      expect(find.byTooltip('搜索'), findsOneWidget);
      expect(find.byKey(const Key('campaign-open-center')), findsOneWidget);

      // Must NOT expose 战役资料 or 成员 as direct AppBar buttons.
      expect(find.byTooltip('战役资料'), findsNothing);
      expect(find.byTooltip('成员'), findsNothing);
    },
  );

  // Spec §全局设置: 右上角更多菜单只有战役名称/封面/简介、所有权转移、
  // 战役归档、离开战役四项。
  testWidgets(
    'chat AppBar more menu contains only the four global settings',
    (tester) async {
      await pumpChatPage(tester);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('战役名称、封面和简介'), findsOneWidget);
      expect(find.text('所有权转移'), findsOneWidget);
      expect(find.text('战役归档'), findsOneWidget);
      expect(find.text('离开战役'), findsOneWidget);
    },
  );

  // Spec §输入栏: 战役资料入口迁移到头像快捷面板第 6 项"资料条目"，
  // 不在 AppBar 单独入口。
  testWidgets(
    'tool panel content entry opens CampaignContentPage when controller is available',
    (tester) async {
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

      // Tap "资料条目" — should navigate to CampaignContentPage.
      await tester.tap(find.byKey(const Key('tool-content-entries')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('campaign-content-page')), findsOneWidget);

      contentController.dispose();
    },
  );
}

class _RecordingCampaignClient implements CampaignClient {
  @override
  Future<void> markCampaignRead({required String apiBaseUrl, required String accessToken, required String campaignId}) async {}
  @override
  Future<CampaignMembership> updateSpeaker({required String apiBaseUrl, required String accessToken, required String campaignId, required String speakerMode, String? actorId}) => throw UnimplementedError();
  @override
  Future<List<CampaignArchiveEntry>> listArchives({required String apiBaseUrl, required String accessToken, required String campaignId, String? kind}) async => const [];
  @override
  Future<CampaignArchiveEntry> createArchiveEntry({required String apiBaseUrl, required String accessToken, required String campaignId, required String kind, required String title, String? summary, Map<String, Object?>? payload}) => throw UnimplementedError();
  @override
  Future<CampaignArchiveEntry> updateArchiveEntry({required String apiBaseUrl, required String accessToken, required String campaignId, required String entryId, String? kind, String? title, String? summary, Map<String, Object?>? payload, bool? pinned}) => throw UnimplementedError();
  @override
  Future<void> archiveEntry({required String apiBaseUrl, required String accessToken, required String campaignId, required String entryId}) => throw UnimplementedError();
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
      membership: workspaceMembership ??
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
