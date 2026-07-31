import 'package:dnd_table_client/src/features/auth/data/auth_api_client.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:dnd_table_client/src/features/auth/domain/auth_session.dart';
import 'package:dnd_table_client/src/features/auth/presentation/auth_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/data/campaign_api_client.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_conversation.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/conversation_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'silent refresh preserves selection and never exposes loading state',
    () async {
      final tokenStore = InMemoryAuthTokenStore();
      await tokenStore.saveTokens(
        'server',
        const StoredAuthTokens(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        ),
      );
      final auth = AuthController(
        tokenStore: tokenStore,
        authClient: _AuthClient(),
        serverProfileId: 'server',
        apiBaseUrl: 'http://localhost:3000/api',
      );
      await auth.initialize();
      final client = _ConversationClient();
      final controller = ConversationController(
        apiBaseUrl: 'http://localhost:3000/api',
        authController: auth,
        campaignClient: client,
      );
      await controller.loadConversations('campaign-1');
      controller.setActiveConversation('group-1');
      final loadingStates = <bool>[];
      controller.addListener(() => loadingStates.add(controller.isLoading));

      client.title = '更新后的小群';
      await controller.refreshConversations('campaign-1');

      expect(controller.activeConversationId, 'group-1');
      expect(controller.activeConversation?.title, '更新后的小群');
      expect(loadingStates, isNot(contains(true)));
      controller.dispose();
      auth.dispose();
    },
  );
}

class _ConversationClient implements CampaignClient {
  String title = '小群';

  @override
  Future<List<CampaignConversation>> listConversations({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async => [
    CampaignConversation(
      id: 'main-1',
      campaignId: campaignId,
      kind: 'main',
      title: '主聊天室',
      participantIds: const [],
      createdBy: 'user-1',
      createdAt: '2026-07-30T00:00:00.000Z',
      updatedAt: '2026-07-30T00:00:00.000Z',
    ),
    CampaignConversation(
      id: 'group-1',
      campaignId: campaignId,
      kind: 'group',
      title: title,
      participantIds: const ['user-1'],
      createdBy: 'user-1',
      createdAt: '2026-07-30T00:00:00.000Z',
      updatedAt: '2026-07-30T00:01:00.000Z',
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthClient implements AuthClient {
  @override
  Future<AuthUser> me({
    required String apiBaseUrl,
    required String accessToken,
  }) async =>
      const AuthUser(id: 'user-1', username: 'user', email: 'user@example.com');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
