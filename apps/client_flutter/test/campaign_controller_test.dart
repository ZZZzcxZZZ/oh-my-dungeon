import 'dart:async';

import 'package:dnd_table_client/src/features/auth/data/auth_api_client.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:dnd_table_client/src/features/auth/domain/auth_session.dart';
import 'package:dnd_table_client/src/features/auth/presentation/auth_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/data/campaign_api_client.dart';
import 'package:dnd_table_client/src/features/campaigns/data/campaign_socket_service.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_conversation.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_archive_entry.dart';
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

  test('loads workspace capabilities from the server context', () async {
    final authController = await buildLoggedInAuthController();
    final controller = CampaignController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      campaignClient: _FakeCampaignClient(),
    );

    await controller.loadWorkspaceContext('camp-1');

    expect(controller.workspaceContext?.membership.boundActorId, 'actor-1');
    expect(
      controller.workspaceContext?.capabilities.canManageCampaign,
      isFalse,
    );

    controller.dispose();
    authController.dispose();
  });

  test('loads campaign archives independently from the chat stream', () async {
    final authController = await buildLoggedInAuthController();
    final controller = CampaignController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      campaignClient: _FakeCampaignClient(),
    );

    await controller.loadArchives('camp-1');

    expect(controller.archives, hasLength(1));
    expect(controller.archives.single.kind, 'clue');
    expect(controller.archives.single.title, 'The silver key');

    controller.dispose();
    authController.dispose();
  });

  test('searches campaign records through the server without replacing chat', () async {
    final authController = await buildLoggedInAuthController();
    final client = _FakeCampaignClient();
    final controller = CampaignController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      campaignClient: client,
    );

    final results = await controller.searchMessages('camp-1', query: 'chapel');

    expect(client.lastMessageQuery, 'chapel');
    expect(results, [_remoteMessage]);
    expect(controller.messages, isEmpty);

    controller.dispose();
    authController.dispose();
  });

  // Spec §双向同步 切片 A: socket 收到 campaign:changed 信号后应触发
  // onCampaignChanged 回调，由调用方接入 actorController.pullUntilCurrent。
  test(
    'connectCampaignChat subscribes to changeStream and invokes onCampaignChanged',
    () async {
      final authController = await buildLoggedInAuthController();
      final socket = _FakeCampaignSocketService();
      int changeCallCount = 0;
      final controller = CampaignController(
        apiBaseUrl: apiBaseUrl,
        authController: authController,
        campaignClient: _FakeCampaignClient(),
        campaignSocketService: socket,
        onCampaignChanged: () async {
          changeCallCount += 1;
        },
      );

      await controller.connectCampaignChat('camp-1');
      socket.emitChange();
      await Future<void>.delayed(Duration.zero);

      expect(changeCallCount, 1);

      // 多次信号都应触发。
      socket.emitChange();
      socket.emitChange();
      await Future<void>.delayed(Duration.zero);
      expect(changeCallCount, 3);

      // 断开后不再触发。
      await controller.disconnectCampaignChat();
      socket.emitChange();
      await Future<void>.delayed(Duration.zero);
      expect(changeCallCount, 3);

      controller.dispose();
      authController.dispose();
    },
  );
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
  final _changeController = StreamController<void>.broadcast();
  final List<({String serverOrigin, String accessToken, String campaignId})>
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

  @override
  Stream<void> get changeStream => _changeController.stream;

  void emitMessage(CampaignChatMessage message) {
    _messageController.add(message);
  }

  void emitChange() {
    _changeController.add(null);
  }
}

class _FakeCampaignClient implements CampaignClient {
  String? lastMessageQuery;
  @override
  Future<void> markCampaignRead({required String apiBaseUrl, required String accessToken, required String campaignId}) async {}
  @override
  Future<CampaignMembership> updateSpeaker({required String apiBaseUrl, required String accessToken, required String campaignId, required String speakerMode, String? actorId}) => throw UnimplementedError();
  @override
  Future<List<CampaignArchiveEntry>> listArchives({required String apiBaseUrl, required String accessToken, required String campaignId, String? kind, String? query, List<String>? tags}) async => const [
    CampaignArchiveEntry(
      id: 'archive-1',
      campaignId: 'camp-1',
      kind: 'clue',
      title: 'The silver key',
      summary: '',
      payload: {},
      pinned: false,
      updatedAt: '2026-07-16T00:00:00.000Z',
    ),
  ];
  @override
  Future<CampaignArchiveEntry> createArchiveEntry({required String apiBaseUrl, required String accessToken, required String campaignId, required String kind, required String title, String? summary, Map<String, Object?>? payload, List<Map<String, Object?>>? bodyBlocks, List<String>? tags, List<Map<String, Object?>>? links, List<Map<String, Object?>>? attachmentRefs}) => throw UnimplementedError();
  @override
  Future<CampaignArchiveEntry> updateArchiveEntry({required String apiBaseUrl, required String accessToken, required String campaignId, required String entryId, String? kind, String? title, String? summary, Map<String, Object?>? payload, bool? pinned, List<Map<String, Object?>>? bodyBlocks, List<String>? tags, List<Map<String, Object?>>? links, List<Map<String, Object?>>? attachmentRefs}) => throw UnimplementedError();
  @override
  Future<void> archiveEntry({required String apiBaseUrl, required String accessToken, required String campaignId, required String entryId}) => throw UnimplementedError();
  @override
  Future<CampaignWorkspaceContext> getWorkspaceContext({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async {
    return CampaignWorkspaceContext(
      campaign: const Campaign(
        id: 'camp-1',
        name: 'Curse of Strahd',
        description: '',
        system: 'dnd5e',
        ownerId: 'user-1',
        status: 'active',
        createdAt: '2026-07-09T00:00:00.000Z',
        updatedAt: '2026-07-09T00:00:00.000Z',
      ),
      membership: const CampaignMembership(
        id: 'member-1',
        campaignId: 'camp-1',
        userId: 'user-1',
        role: 'player',
        displayName: 'ranger',
        joinedAt: '2026-07-09T00:00:00.000Z',
        boundActorId: 'actor-1',
        activeSpeakerActorId: 'actor-1',
      ),
      members: const [],
      actors: const [],
      capabilities: const CampaignCapabilities(
        canManageCampaign: false,
        canManageMembers: false,
        canCreateActors: false,
        canSpeakAsNarrator: false,
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
    String? conversationId,
  }) async {
    lastMessageQuery = query;
    return query == null ? const [] : const [_remoteMessage];
  }

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
    Map<String, Object?>? speakerSnapshot,
    String? conversationId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<CampaignConversation>> listConversations({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async {
    return const [];
  }

  @override
  Future<CampaignConversation> createDirectConversation({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String otherUserId,
  }) async {
    return CampaignConversation(
      id: 'direct-1',
      campaignId: campaignId,
      kind: 'direct',
      title: '',
      participantIds: [otherUserId],
      createdBy: 'user-1',
      createdAt: '2026-07-23T00:00:00.000Z',
      updatedAt: '2026-07-23T00:00:00.000Z',
    );
  }

  @override
  Future<CampaignConversation> createGroupConversation({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String title,
    required List<String> participantIds,
  }) async {
    return CampaignConversation(
      id: 'group-1',
      campaignId: campaignId,
      kind: 'group',
      title: title,
      participantIds: participantIds,
      createdBy: 'user-1',
      createdAt: '2026-07-23T00:00:00.000Z',
      updatedAt: '2026-07-23T00:00:00.000Z',
    );
  }

  @override
  Future<CampaignConversation> updateConversation({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String conversationId,
    String? title,
    bool? archived,
  }) async {
    return CampaignConversation(
      id: conversationId,
      campaignId: campaignId,
      kind: 'group',
      title: title ?? '',
      participantIds: const [],
      createdBy: 'user-1',
      createdAt: '2026-07-23T00:00:00.000Z',
      updatedAt: '2026-07-23T00:00:00.000Z',
    );
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
