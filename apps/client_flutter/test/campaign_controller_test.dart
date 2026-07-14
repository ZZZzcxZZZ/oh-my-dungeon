import 'dart:async';

import 'package:dnd_table_client/src/features/auth/data/auth_api_client.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:dnd_table_client/src/features/auth/domain/auth_session.dart';
import 'package:dnd_table_client/src/features/auth/presentation/auth_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/data/campaign_api_client.dart';
import 'package:dnd_table_client/src/features/campaigns/data/campaign_socket_service.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/campaign_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const apiBaseUrl = 'http://localhost:3000/api';

  Future<AuthController> buildLoggedInAuthController() async {
    final tokenStore = InMemoryAuthTokenStore();
    await tokenStore.saveTokens(
      'localhost',
      const StoredAuthTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    );
    final controller = AuthController(
      tokenStore: tokenStore,
      authClient: _FakeAuthClient(),
      serverProfileId: 'localhost',
      apiBaseUrl: apiBaseUrl,
    );
    await controller.initialize();
    return controller;
  }

  test('connects campaign realtime and appends remote messages once', () async {
    final authController = await buildLoggedInAuthController();
    final socket = _FakeCampaignSocketService();
    final controller = CampaignController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      campaignClient: _FakeCampaignClient(),
      campaignSocketService: socket,
    );

    await controller.connectCampaignChat('camp-1');
    socket.emitMessage(_remoteMessage);
    await Future<void>.delayed(Duration.zero);
    socket.emitMessage(_remoteMessage);
    await Future<void>.delayed(Duration.zero);

    expect(socket.connectCalls.single.serverOrigin, 'http://localhost:3000');
    expect(socket.connectCalls.single.accessToken, 'access-token');
    expect(socket.connectCalls.single.campaignId, 'camp-1');
    expect(controller.messages, [_remoteMessage]);

    await controller.disconnectCampaignChat();
    expect(socket.disconnectCount, 1);

    controller.dispose();
    authController.dispose();
  });
}

const _remoteMessage = CampaignChatMessage(
  id: 'msg-remote',
  campaignId: 'camp-1',
  senderId: 'user-2',
  campaignActorId: 'actor-2',
  displayName: 'Mira',
  avatarUrl: null,
  kind: 'say',
  content: '火把亮了起来',
  createdAt: '2026-07-09T00:00:00.000Z',
);

class _FakeCampaignSocketService implements CampaignSocketService {
  final _messageController = StreamController<CampaignChatMessage>.broadcast();
  final List<
    ({
      String serverOrigin,
      String accessToken,
      String campaignId,
    })
  >
  connectCalls = [];
  int disconnectCount = 0;

  @override
  bool get isConnected => connectCalls.isNotEmpty && disconnectCount == 0;

  @override
  Future<void> connect({
    required String serverOrigin,
    required String accessToken,
    required String campaignId,
  }) async {
    connectCalls.add((
      serverOrigin: serverOrigin,
      accessToken: accessToken,
      campaignId: campaignId,
    ));
  }

  @override
  Future<void> disconnect() async {
    disconnectCount += 1;
  }

  @override
  Stream<CampaignChatMessage> get messageStream => _messageController.stream;

  void emitMessage(CampaignChatMessage message) {
    _messageController.add(message);
  }
}

class _FakeCampaignClient implements CampaignClient {
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
  }) {
    throw UnimplementedError();
  }
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
