import 'package:dnd_table_client/src/features/auth/data/auth_api_client.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:dnd_table_client/src/features/auth/domain/auth_session.dart';
import 'package:dnd_table_client/src/features/auth/presentation/auth_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/data/campaign_api_client.dart';
import 'package:dnd_table_client/src/features/campaigns/data/campaign_socket_service.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/campaign_chat_page.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/campaign_controller.dart';
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_controller.dart';
import 'package:dnd_table_client/src/features/content/data/content_api_client.dart';
import 'package:dnd_table_client/src/features/content/domain/content.dart';
import 'package:dnd_table_client/src/features/content/presentation/content_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/character_test_support.dart';

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
);

final _character = CharacterSheet.local(
  id: 'char-1',
  name: 'Arannis',
  level: 3,
);

void main() {
  late AuthController authController;
  late CampaignController campaignController;
  late CharacterController characterController;
  late ContentController contentController;
  late _RecordingCampaignClient campaignClient;

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

    contentController = ContentController(
      apiBaseUrl: _apiBaseUrl,
      authController: authController,
      contentClient: _FakeContentClient(),
    );
  });

  tearDown(() {
    campaignController.dispose();
    characterController.dispose();
    contentController.dispose();
    authController.dispose();
  });

  Future<void> pumpChatPage(
    WidgetTester tester, {
    String? campaignActorId,
    bool isDm = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CampaignChatPage(
          campaign: _campaign,
          character: _character,
          campaignActorId: campaignActorId,
          campaignController: campaignController,
          characterController: characterController,
          contentController: contentController,
          isDm: isDm,
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

  testWidgets('sendMessage uses campaignActorId not characterId or displayName',
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
  });

  testWidgets('sendMessage sends null campaignActorId when no actor is bound',
      (tester) async {
    await pumpChatPage(tester);

    await tester.enterText(
      find.byKey(const Key('campaign-chat-input')),
      '你好',
    );
    await tester.tap(find.byKey(const Key('campaign-chat-send')));
    await tester.pumpAndSettle();

    expect(campaignClient.sendMessageCalls, hasLength(1));
    expect(campaignClient.sendMessageCalls.single.campaignActorId, isNull);
  });

  testWidgets('shows identity bar with character info', (tester) async {
    await pumpChatPage(tester, campaignActorId: 'actor-1');

    expect(find.textContaining('Arannis'), findsWidgets);
  });
}

class _RecordingCampaignClient implements CampaignClient {
  final List<_SentMessageCall> sendMessageCalls = [];

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
    String? roleOnJoin,
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
  }) async {
    return const [];
  }

  @override
  Future<CampaignChatMessage> sendMessage({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String kind,
    required String content,
    String? campaignActorId,
  }) async {
    sendMessageCalls.add(
      _SentMessageCall(
        kind: kind,
        content: content,
        campaignActorId: campaignActorId,
      ),
    );
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
    );
  }
}

class _SentMessageCall {
  const _SentMessageCall({
    required this.kind,
    required this.content,
    required this.campaignActorId,
  });

  final String kind;
  final String content;
  final String? campaignActorId;
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

class _FakeContentClient implements ContentClient {
  @override
  Future<ImportContentPackageResult> importCampaignPackage({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required Object package,
    bool dryRun = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ImportContentPackageResult> importPackage({
    required String apiBaseUrl,
    required String accessToken,
    required Object package,
    bool dryRun = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<ContentPackage>> listPackages({
    required String apiBaseUrl,
    required String accessToken,
  }) async {
    return const [];
  }

  @override
  Future<Map<String, Object?>> exportPackage({
    required String apiBaseUrl,
    required String accessToken,
    required String packageId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<ContentItem>> listItems({
    required String apiBaseUrl,
    required String accessToken,
    String? type,
    String? query,
    String? packageId,
  }) async {
    return const [];
  }

  @override
  Future<List<ContentItem>> listAvailableCampaignItems({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    String? type,
    String? query,
    bool favoriteOnly = false,
  }) async {
    return const [];
  }

  @override
  Future<void> setCampaignPackage({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String packageId,
    required bool enabled,
  }) async {}

  @override
  Future<void> disableCampaignItem({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String itemId,
    String? reason,
  }) async {}

  @override
  Future<void> setCampaignItemFavorite({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String itemId,
    required bool favorite,
  }) async {}

  @override
  Future<ContentItemDetail> getCampaignItem({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String itemId,
  }) {
    throw UnimplementedError();
  }
}
