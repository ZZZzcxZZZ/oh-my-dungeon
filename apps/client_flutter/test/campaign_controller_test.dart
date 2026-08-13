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

    expect(
      controller.workspaceContext?.membership.boundCharacterId,
      'character-1',
    );
    expect(
      controller.workspaceContext?.capabilities.canManageCampaign,
      isFalse,
    );

    controller.dispose();
    authController.dispose();
  });

  test('binds the current player through the campaign controller', () async {
    final authController = await buildLoggedInAuthController();
    final controller = CampaignController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      campaignClient: _FakeCampaignClient(),
    );

    await controller.loadWorkspaceContext('camp-1');
    final updated = await controller.updateMemberBinding(
      campaignId: 'camp-1',
      characterId: 'character-2',
    );

    expect(updated, isTrue);
    expect(
      controller.workspaceContext?.membership.boundCharacterId,
      'character-2',
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

  test(
    'searches campaign records through the server without replacing chat',
    () async {
      final authController = await buildLoggedInAuthController();
      final client = _FakeCampaignClient();
      final controller = CampaignController(
        apiBaseUrl: apiBaseUrl,
        authController: authController,
        campaignClient: client,
      );

      final results = await controller.searchMessages(
        'camp-1',
        query: 'chapel',
      );

      expect(client.lastMessageQuery, 'chapel');
      expect(results, [_remoteMessage]);
      expect(controller.messages, isEmpty);

      controller.dispose();
      authController.dispose();
    },
  );

  test(
    'background message refresh keeps the current timeline mounted',
    () async {
      final authController = await buildLoggedInAuthController();
      final refresh = Completer<List<CampaignChatMessage>>();
      final client = _FakeCampaignClient(
        messageResponses: [
          Future.value(const [_remoteMessage]),
          refresh.future,
        ],
      );
      final controller = CampaignController(
        apiBaseUrl: apiBaseUrl,
        authController: authController,
        campaignClient: client,
      );

      await controller.loadMessages('camp-1');
      final refreshFuture = controller.refreshMessages('camp-1');

      expect(controller.isMessagesLoading, isFalse);
      expect(controller.messages, const [_remoteMessage]);

      refresh.complete(const [_remoteMessage, _secondRemoteMessage]);
      await refreshFuture;

      expect(controller.messages, const [_remoteMessage, _secondRemoteMessage]);

      controller.dispose();
      authController.dispose();
    },
  );

  test('stale background failure cannot overwrite a newer refresh', () async {
    final authController = await buildLoggedInAuthController();
    final stale = Completer<List<CampaignChatMessage>>();
    final latest = Completer<List<CampaignChatMessage>>();
    final client = _FakeCampaignClient(
      messageResponses: [
        Future.value(const [_remoteMessage]),
        stale.future,
        latest.future,
      ],
    );
    final controller = CampaignController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      campaignClient: client,
    );

    await controller.loadMessages('camp-1');
    final staleFuture = controller.refreshMessages('camp-1');
    final latestFuture = controller.refreshMessages('camp-1');
    latest.complete(const [_remoteMessage, _secondRemoteMessage]);
    await latestFuture;
    stale.completeError(Exception('old network failure'));
    await staleFuture;

    expect(controller.messagesError, isNull);
    expect(controller.messages, const [_remoteMessage, _secondRemoteMessage]);

    controller.dispose();
    authController.dispose();
  });

  // Spec §双向同步 切片 A: socket 收到 campaign:changed 信号后应触发
  // onCampaignChanged 回调，由调用方接入 characterController.pullUntilCurrent。
  test(
    'connectCampaignChat subscribes to changeStream and invokes onCampaignChanged',
    () async {
      final authController = await buildLoggedInAuthController();
      final socket = _FakeCampaignSocketService();
      final signals = <CampaignChangeSignal>[];
      final controller = CampaignController(
        apiBaseUrl: apiBaseUrl,
        authController: authController,
        campaignClient: _FakeCampaignClient(),
        campaignSocketService: socket,
        onCampaignChanged: (signal) async {
          signals.add(signal);
        },
      );

      await controller.connectCampaignChat('camp-1');
      socket.emitChange(entityType: 'character', cursor: '7');
      await Future<void>.delayed(Duration.zero);

      expect(signals, hasLength(1));
      expect(signals.single.entityType, 'character');
      expect(signals.single.cursor, '7');

      // 多次信号都应触发。
      socket.emitChange();
      socket.emitChange();
      await Future<void>.delayed(Duration.zero);
      expect(signals, hasLength(3));

      // 断开后不再触发。
      await controller.disconnectCampaignChat();
      socket.emitChange();
      await Future<void>.delayed(Duration.zero);
      expect(signals, hasLength(3));

      controller.dispose();
      authController.dispose();
    },
  );
}

const _remoteMessage = CampaignChatMessage(
  id: 'msg-remote',
  campaignId: 'camp-1',
  senderId: 'user-2',
  campaignCharacterId: 'character-2',
  displayName: 'Mira',
  avatarUrl: null,
  kind: 'say',
  content: '火把亮了起来',
  createdAt: '2026-07-09T00:00:00.000Z',
);

const _secondRemoteMessage = CampaignChatMessage(
  id: 'msg-second',
  campaignId: 'camp-1',
  senderId: 'user-2',
  campaignCharacterId: 'character-2',
  displayName: 'Mira',
  avatarUrl: null,
  kind: 'say',
  content: '门后传来脚步声',
  createdAt: '2026-07-09T00:00:01.000Z',
);

class _FakeCampaignSocketService implements CampaignSocketService {
  final _messageController = StreamController<CampaignChatMessage>.broadcast();
  final _changeController = StreamController<CampaignChangeSignal>.broadcast();
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
  Stream<CampaignChangeSignal> get changeStream => _changeController.stream;

  void emitMessage(CampaignChatMessage message) {
    _messageController.add(message);
  }

  void emitChange({String entityType = 'character', String? cursor}) {
    _changeController.add(
      CampaignChangeSignal(
        campaignId: 'camp-1',
        entityType: entityType,
        cursor: cursor,
      ),
    );
  }
}

class _FakeCampaignClient implements CampaignClient, CampaignBindingClient {
  _FakeCampaignClient({
    List<Future<List<CampaignChatMessage>>>? messageResponses,
  }) : _messageResponses = messageResponses ?? [];

  String? lastMessageQuery;
  final List<Future<List<CampaignChatMessage>>> _messageResponses;
  @override
  Future<void> markCampaignRead({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async {}
  @override
  Future<void> markConversationRead({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String conversationId,
  }) async {}
  @override
  Future<CampaignMembership> updateSpeaker({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String speakerMode,
    String? characterId,
  }) => throw UnimplementedError();
  @override
  Future<List<CampaignArchiveEntry>> listArchives({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    String? kind,
    String? query,
    List<String>? tags,
  }) async => const [
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
  }) => throw UnimplementedError();
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
        boundCharacterId: 'character-1',
        activeSpeakerCharacterId: 'character-1',
      ),
      members: const [],
      characters: const [],
      capabilities: const CampaignCapabilities(
        canManageCampaign: false,
        canManageMembers: false,
        canCreateCharacters: false,
        canSpeakAsNarrator: false,
      ),
    );
  }

  @override
  Future<CampaignMembership> updateMemberBinding({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String userId,
    required String? characterId,
  }) async {
    return CampaignMembership(
      id: 'member-1',
      campaignId: campaignId,
      userId: userId,
      role: 'player',
      displayName: 'ranger',
      joinedAt: '2026-07-09T00:00:00.000Z',
      boundCharacterId: characterId,
      speakerMode: 'boundCharacter',
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
    if (query == null && _messageResponses.isNotEmpty) {
      return _messageResponses.removeAt(0);
    }
    return query == null ? const [] : const [_remoteMessage];
  }

  @override
  Future<CampaignChatMessage> sendMessage({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String kind,
    required String content,
    String? campaignCharacterId,
    String? actionId,
    Map<String, Object?>? eventData,
    Map<String, Object?>? speakerSnapshot,
    Object? speaker,
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
