import 'package:dnd_table_client/src/features/auth/data/auth_api_client.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:dnd_table_client/src/features/auth/domain/auth_session.dart';
import 'package:dnd_table_client/src/features/auth/presentation/auth_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/data/campaign_api_client.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_conversation.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_archive_entry.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/conversation_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan 2026-07-23 task 5.3: 客户端 ConversationController 单元测试.
///
/// 覆盖范围:
/// - loadConversations: 替换列表、保留活动会话、活动会话缺失时回退
/// - loadConversations 错误路径: CampaignApiException 与未知异常
/// - setActiveConversation: 设置活动会话并通知监听者; 同值不通知
/// - createDirectConversation: upsert 并设为活动会话
/// - createGroupConversation: upsert 并设为活动会话
/// - updateConversation: 归档活动会话后回退到 main
/// - clearSelection: 清空所有状态
/// - auth 状态变化: 登出时清空状态
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

  CampaignConversation mainConversation({
    String campaignId = 'camp-1',
    String updatedAt = '2026-07-23T00:00:00.000Z',
  }) => CampaignConversation(
    id: 'main-1',
    campaignId: campaignId,
    kind: 'main',
    title: '主聊天室',
    participantIds: const [],
    createdBy: 'user-1',
    createdAt: '2026-07-23T00:00:00.000Z',
    updatedAt: updatedAt,
  );

  CampaignConversation directConversation({
    String id = 'direct-1',
    String campaignId = 'camp-1',
    String otherUserId = 'user-2',
    String updatedAt = '2026-07-23T10:00:00.000Z',
  }) => CampaignConversation(
    id: id,
    campaignId: campaignId,
    kind: 'direct',
    title: '',
    participantIds: [otherUserId],
    createdBy: 'user-1',
    createdAt: '2026-07-23T00:00:00.000Z',
    updatedAt: updatedAt,
  );

  CampaignConversation groupConversation({
    String id = 'group-1',
    String title = '突袭小队',
    String campaignId = 'camp-1',
    String updatedAt = '2026-07-23T11:00:00.000Z',
  }) => CampaignConversation(
    id: id,
    campaignId: campaignId,
    kind: 'group',
    title: title,
    participantIds: const ['user-2', 'user-3'],
    createdBy: 'user-1',
    createdAt: '2026-07-23T00:00:00.000Z',
    updatedAt: updatedAt,
  );

  test(
    'loadConversations replaces the list and tracks the active campaign',
    () async {
      final auth = await buildLoggedInAuthController();
      final client = _RecordingCampaignClient(
        conversations: [
          mainConversation(),
          directConversation(),
          groupConversation(),
        ],
      );
      final controller = ConversationController(
        apiBaseUrl: apiBaseUrl,
        authController: auth,
        campaignClient: client,
      );

      await controller.loadConversations('camp-1');

      expect(controller.activeCampaignId, 'camp-1');
      expect(controller.conversations, hasLength(3));
      expect(controller.isLoading, isFalse);
      expect(controller.error, isNull);
      // listConversations 应携带 access token.
      expect(client.listConversationsCalls.single.accessToken, 'access-token');
      expect(client.listConversationsCalls.single.campaignId, 'camp-1');

      controller.dispose();
      auth.dispose();
    },
  );

  test(
    'loadConversations preserves the active conversation when still present',
    () async {
      final auth = await buildLoggedInAuthController();
      final client = _RecordingCampaignClient(
        conversations: [mainConversation(), directConversation()],
      );
      final controller = ConversationController(
        apiBaseUrl: apiBaseUrl,
        authController: auth,
        campaignClient: client,
      );

      await controller.loadConversations('camp-1');
      controller.setActiveConversation('direct-1');

      // 重新加载: direct-1 仍在列表中, 活动会话应保留.
      await controller.loadConversations('camp-1');
      expect(controller.activeConversationId, 'direct-1');

      controller.dispose();
      auth.dispose();
    },
  );

  test(
    'loadConversations resets the active conversation when missing',
    () async {
      final auth = await buildLoggedInAuthController();
      final client = _RecordingCampaignClient(
        conversations: [mainConversation(), directConversation()],
      );
      final controller = ConversationController(
        apiBaseUrl: apiBaseUrl,
        authController: auth,
        campaignClient: client,
      );

      await controller.loadConversations('camp-1');
      controller.setActiveConversation('direct-1');

      // 服务端这次只返回 main, direct 被删除.
      client.conversations = [mainConversation()];
      await controller.loadConversations('camp-1');

      expect(controller.activeConversationId, isNull);
      // 活动会话 getter 应回退到 main.
      expect(controller.activeConversation?.id, 'main-1');

      controller.dispose();
      auth.dispose();
    },
  );

  test('loadConversations surfaces CampaignApiException on error', () async {
    final auth = await buildLoggedInAuthController();
    final client = _RecordingCampaignClient(
      conversations: const [],
      listException: const CampaignApiException('Forbidden', statusCode: 403),
    );
    final controller = ConversationController(
      apiBaseUrl: apiBaseUrl,
      authController: auth,
      campaignClient: client,
    );

    await controller.loadConversations('camp-1');

    expect(controller.error, 'Forbidden');
    expect(controller.conversations, isEmpty);
    expect(controller.isLoading, isFalse);

    controller.dispose();
    auth.dispose();
  });

  test(
    'loadConversations surfaces a generic message on unknown exception',
    () async {
      final auth = await buildLoggedInAuthController();
      final client = _RecordingCampaignClient(
        conversations: const [],
        listException: StateError('boom'),
      );
      final controller = ConversationController(
        apiBaseUrl: apiBaseUrl,
        authController: auth,
        campaignClient: client,
      );

      await controller.loadConversations('camp-1');

      expect(controller.error, 'Failed to load conversations');
      expect(controller.isLoading, isFalse);

      controller.dispose();
      auth.dispose();
    },
  );

  test(
    'setActiveConversation updates the value and notifies listeners',
    () async {
      final auth = await buildLoggedInAuthController();
      final client = _RecordingCampaignClient(
        conversations: [mainConversation(), directConversation()],
      );
      final controller = ConversationController(
        apiBaseUrl: apiBaseUrl,
        authController: auth,
        campaignClient: client,
      );
      await controller.loadConversations('camp-1');

      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.setActiveConversation('direct-1');
      expect(controller.activeConversationId, 'direct-1');
      expect(notifyCount, 1);

      // 同值不应再次通知.
      controller.setActiveConversation('direct-1');
      expect(notifyCount, 1);

      controller.dispose();
      auth.dispose();
    },
  );

  test(
    'createDirectConversation upserts and marks the new conversation active',
    () async {
      final auth = await buildLoggedInAuthController();
      final client = _RecordingCampaignClient(
        conversations: [mainConversation()],
      );
      final controller = ConversationController(
        apiBaseUrl: apiBaseUrl,
        authController: auth,
        campaignClient: client,
      );
      await controller.loadConversations('camp-1');

      final created = await controller.createDirectConversation(
        campaignId: 'camp-1',
        otherUserId: 'user-2',
      );

      expect(created, isNotNull);
      expect(created!.id, 'direct-1');
      expect(controller.conversations, hasLength(2));
      expect(controller.activeConversationId, 'direct-1');
      expect(client.createDirectCalls.single.otherUserId, 'user-2');

      controller.dispose();
      auth.dispose();
    },
  );

  test(
    'createDirectConversation upserts an existing conversation id',
    () async {
      final auth = await buildLoggedInAuthController();
      // 列表已包含 direct-1, 服务端再次返回 direct-1 (idempotent).
      final existing = directConversation();
      final client = _RecordingCampaignClient(
        conversations: [mainConversation(), existing],
      );
      final controller = ConversationController(
        apiBaseUrl: apiBaseUrl,
        authController: auth,
        campaignClient: client,
      );
      await controller.loadConversations('camp-1');

      await controller.createDirectConversation(
        campaignId: 'camp-1',
        otherUserId: 'user-2',
      );

      // 列表长度保持 2, 不应重复添加.
      expect(controller.conversations, hasLength(2));
      expect(
        controller.conversations.where((c) => c.id == 'direct-1'),
        hasLength(1),
      );

      controller.dispose();
      auth.dispose();
    },
  );

  test(
    'createDirectConversation returns null and sets error on exception',
    () async {
      final auth = await buildLoggedInAuthController();
      final client = _RecordingCampaignClient(
        conversations: [mainConversation()],
        createDirectException: const CampaignApiException(
          'not a member',
          statusCode: 403,
        ),
      );
      final controller = ConversationController(
        apiBaseUrl: apiBaseUrl,
        authController: auth,
        campaignClient: client,
      );
      await controller.loadConversations('camp-1');

      final result = await controller.createDirectConversation(
        campaignId: 'camp-1',
        otherUserId: 'user-99',
      );

      expect(result, isNull);
      expect(controller.error, 'not a member');
      expect(controller.conversations, hasLength(1));

      controller.dispose();
      auth.dispose();
    },
  );

  test(
    'createGroupConversation upserts and marks the new conversation active',
    () async {
      final auth = await buildLoggedInAuthController();
      final client = _RecordingCampaignClient(
        conversations: [mainConversation()],
      );
      final controller = ConversationController(
        apiBaseUrl: apiBaseUrl,
        authController: auth,
        campaignClient: client,
      );
      await controller.loadConversations('camp-1');

      final created = await controller.createGroupConversation(
        campaignId: 'camp-1',
        title: '突袭小队',
        participantIds: const ['user-2', 'user-3'],
      );

      expect(created, isNotNull);
      expect(created!.id, 'group-1');
      expect(controller.conversations, hasLength(2));
      expect(controller.activeConversationId, 'group-1');
      expect(client.createGroupCalls.single.title, '突袭小队');
      expect(client.createGroupCalls.single.participantIds, [
        'user-2',
        'user-3',
      ]);

      controller.dispose();
      auth.dispose();
    },
  );

  test(
    'createGroupConversation returns null and sets error on exception',
    () async {
      final auth = await buildLoggedInAuthController();
      final client = _RecordingCampaignClient(
        conversations: [mainConversation()],
        createGroupException: StateError('network'),
      );
      final controller = ConversationController(
        apiBaseUrl: apiBaseUrl,
        authController: auth,
        campaignClient: client,
      );
      await controller.loadConversations('camp-1');

      final result = await controller.createGroupConversation(
        campaignId: 'camp-1',
        title: '突袭小队',
        participantIds: const ['user-2'],
      );

      expect(result, isNull);
      expect(controller.error, 'Failed to create group conversation');

      controller.dispose();
      auth.dispose();
    },
  );

  test('updateConversation renames the conversation in the list', () async {
    final auth = await buildLoggedInAuthController();
    final original = groupConversation(title: '旧名称');
    final client = _RecordingCampaignClient(
      conversations: [mainConversation(), original],
    );
    final controller = ConversationController(
      apiBaseUrl: apiBaseUrl,
      authController: auth,
      campaignClient: client,
    );
    await controller.loadConversations('camp-1');

    final updated = await controller.updateConversation(
      campaignId: 'camp-1',
      conversationId: 'group-1',
      title: '新名称',
    );

    expect(updated, isNotNull);
    expect(updated!.title, '新名称');
    // 列表中的 group-1 标题应已替换.
    final groupInList = controller.conversations.firstWhere(
      (c) => c.id == 'group-1',
    );
    expect(groupInList.title, '新名称');

    controller.dispose();
    auth.dispose();
  });

  test(
    'updateConversation archives the active conversation and falls back to main',
    () async {
      final auth = await buildLoggedInAuthController();
      final group = groupConversation();
      final client = _RecordingCampaignClient(
        conversations: [mainConversation(), group],
      );
      final controller = ConversationController(
        apiBaseUrl: apiBaseUrl,
        authController: auth,
        campaignClient: client,
      );
      await controller.loadConversations('camp-1');
      controller.setActiveConversation('group-1');
      expect(controller.activeConversationId, 'group-1');

      // 归档: 服务端返回 archivedAt 已设置.
      final archived = group.copyWith(archivedAt: '2026-07-23T12:00:00.000Z');
      client.updateConversationResult = archived;

      final updated = await controller.updateConversation(
        campaignId: 'camp-1',
        conversationId: 'group-1',
        archived: true,
      );

      expect(updated, isNotNull);
      expect(updated!.isArchived, isTrue);
      // 活动会话已被归档, 应回退到 null (即 main).
      expect(controller.activeConversationId, isNull);
      expect(controller.activeConversation?.id, 'main-1');

      controller.dispose();
      auth.dispose();
    },
  );

  test(
    'updateConversation returns null and sets error on CampaignApiException',
    () async {
      final auth = await buildLoggedInAuthController();
      final client = _RecordingCampaignClient(
        conversations: [mainConversation(), groupConversation()],
        updateException: const CampaignApiException(
          'forbidden',
          statusCode: 403,
        ),
      );
      final controller = ConversationController(
        apiBaseUrl: apiBaseUrl,
        authController: auth,
        campaignClient: client,
      );
      await controller.loadConversations('camp-1');

      final result = await controller.updateConversation(
        campaignId: 'camp-1',
        conversationId: 'group-1',
        title: '新名称',
      );

      expect(result, isNull);
      expect(controller.error, 'forbidden');
      // 列表中的原条目不应被修改.
      expect(
        controller.conversations.firstWhere((c) => c.id == 'group-1').title,
        '突袭小队',
      );

      controller.dispose();
      auth.dispose();
    },
  );

  test('clearSelection resets all state and notifies listeners', () async {
    final auth = await buildLoggedInAuthController();
    final client = _RecordingCampaignClient(
      conversations: [mainConversation(), directConversation()],
    );
    final controller = ConversationController(
      apiBaseUrl: apiBaseUrl,
      authController: auth,
      campaignClient: client,
    );
    await controller.loadConversations('camp-1');
    controller.setActiveConversation('direct-1');

    var notifyCount = 0;
    controller.addListener(() => notifyCount++);

    controller.clearSelection();

    expect(controller.activeCampaignId, isNull);
    expect(controller.conversations, isEmpty);
    expect(controller.activeConversationId, isNull);
    expect(controller.error, isNull);
    expect(notifyCount, 1);

    controller.dispose();
    auth.dispose();
  });

  test('auth logout clears conversation state', () async {
    final auth = await buildLoggedInAuthController();
    final client = _RecordingCampaignClient(
      conversations: [mainConversation(), directConversation()],
    );
    final controller = ConversationController(
      apiBaseUrl: apiBaseUrl,
      authController: auth,
      campaignClient: client,
    );
    await controller.loadConversations('camp-1');
    controller.setActiveConversation('direct-1');
    expect(controller.conversations, isNotEmpty);

    // 模拟登出: AuthController 通知监听者, ConversationController 应清空.
    await auth.logout();

    expect(controller.activeCampaignId, isNull);
    expect(controller.conversations, isEmpty);
    expect(controller.activeConversationId, isNull);

    controller.dispose();
    auth.dispose();
  });

  test('mainConversation getter resolves the main kind conversation', () async {
    final auth = await buildLoggedInAuthController();
    final client = _RecordingCampaignClient(
      conversations: [
        directConversation(),
        groupConversation(),
        mainConversation(),
      ],
    );
    final controller = ConversationController(
      apiBaseUrl: apiBaseUrl,
      authController: auth,
      campaignClient: client,
    );
    await controller.loadConversations('camp-1');

    expect(controller.mainConversation?.id, 'main-1');

    controller.dispose();
    auth.dispose();
  });

  test(
    'directConversations and groupConversations getters sort by updatedAt desc',
    () async {
      final auth = await buildLoggedInAuthController();
      final olderDirect = directConversation(
        id: 'direct-old',
        updatedAt: '2026-07-23T09:00:00.000Z',
      );
      final newerDirect = directConversation(
        id: 'direct-new',
        otherUserId: 'user-3',
        updatedAt: '2026-07-23T18:00:00.000Z',
      );
      final olderGroup = groupConversation(
        id: 'group-old',
        title: '旧小队',
        updatedAt: '2026-07-23T08:00:00.000Z',
      );
      final newerGroup = groupConversation(
        id: 'group-new',
        title: '新小队',
        updatedAt: '2026-07-23T19:00:00.000Z',
      );
      final client = _RecordingCampaignClient(
        conversations: [
          mainConversation(),
          olderDirect,
          newerDirect,
          olderGroup,
          newerGroup,
        ],
      );
      final controller = ConversationController(
        apiBaseUrl: apiBaseUrl,
        authController: auth,
        campaignClient: client,
      );
      await controller.loadConversations('camp-1');

      expect(controller.directConversations.map((c) => c.id).toList(), [
        'direct-new',
        'direct-old',
      ]);
      expect(controller.groupConversations.map((c) => c.id).toList(), [
        'group-new',
        'group-old',
      ]);

      controller.dispose();
      auth.dispose();
    },
  );

  test(
    'activeConversation falls back to main when no active selection',
    () async {
      final auth = await buildLoggedInAuthController();
      final client = _RecordingCampaignClient(
        conversations: [mainConversation(), directConversation()],
      );
      final controller = ConversationController(
        apiBaseUrl: apiBaseUrl,
        authController: auth,
        campaignClient: client,
      );
      await controller.loadConversations('camp-1');

      expect(controller.activeConversationId, isNull);
      expect(controller.activeConversation?.id, 'main-1');

      controller.dispose();
      auth.dispose();
    },
  );
}

/// 测试专用 CampaignClient, 记录每次调用参数并允许注入异常与返回值.
class _RecordingCampaignClient implements CampaignClient {
  _RecordingCampaignClient({
    List<CampaignConversation> conversations = const [],
    this.listException,
    this.createDirectException,
    this.createGroupException,
    this.updateException,
  }) : conversations = [...conversations];

  List<CampaignConversation> conversations;
  Object? listException;
  Object? createDirectException;
  Object? createGroupException;
  Object? updateException;

  /// 下一次 updateConversation 调用返回的结果; 默认按 archived/title 构造.
  CampaignConversation? updateConversationResult;

  final List<({String apiBaseUrl, String accessToken, String campaignId})>
  listConversationsCalls = [];
  final List<({String campaignId, String otherUserId})> createDirectCalls = [];
  final List<({String campaignId, String title, List<String> participantIds})>
  createGroupCalls = [];

  @override
  Future<List<CampaignConversation>> listConversations({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async {
    listConversationsCalls.add((
      apiBaseUrl: apiBaseUrl,
      accessToken: accessToken,
      campaignId: campaignId,
    ));
    final exception = listException;
    if (exception != null) {
      listException = null;
      throw exception;
    }
    return List.unmodifiable(conversations);
  }

  @override
  Future<CampaignConversation> createDirectConversation({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String otherUserId,
  }) async {
    createDirectCalls.add((campaignId: campaignId, otherUserId: otherUserId));
    final exception = createDirectException;
    if (exception != null) {
      createDirectException = null;
      throw exception;
    }
    return CampaignConversation(
      id: 'direct-1',
      campaignId: campaignId,
      kind: 'direct',
      title: '',
      participantIds: [otherUserId],
      createdBy: 'user-1',
      createdAt: '2026-07-23T00:00:00.000Z',
      updatedAt: '2026-07-23T10:00:00.000Z',
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
    createGroupCalls.add((
      campaignId: campaignId,
      title: title,
      participantIds: participantIds,
    ));
    final exception = createGroupException;
    if (exception != null) {
      createGroupException = null;
      throw exception;
    }
    return CampaignConversation(
      id: 'group-1',
      campaignId: campaignId,
      kind: 'group',
      title: title,
      participantIds: participantIds,
      createdBy: 'user-1',
      createdAt: '2026-07-23T00:00:00.000Z',
      updatedAt: '2026-07-23T11:00:00.000Z',
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
    final exception = updateException;
    if (exception != null) {
      updateException = null;
      throw exception;
    }
    final preset = updateConversationResult;
    if (preset != null) {
      updateConversationResult = null;
      return preset;
    }
    // 从 conversations 中查找原始条目, 应用更新.
    final original = conversations.firstWhere(
      (c) => c.id == conversationId,
      orElse: () => CampaignConversation(
        id: conversationId,
        campaignId: campaignId,
        kind: 'group',
        title: '',
        participantIds: const [],
        createdBy: 'user-1',
        createdAt: '2026-07-23T00:00:00.000Z',
        updatedAt: '2026-07-23T00:00:00.000Z',
      ),
    );
    return original.copyWith(
      title: title ?? original.title,
      archivedAt: archived == true
          ? '2026-07-23T12:00:00.000Z'
          : original.archivedAt,
    );
  }

  // 以下方法与本测试无关, 抛 UnimplementedError 即可.
  @override
  Future<CampaignWorkspaceContext> getWorkspaceContext({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
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
  Future<void> archiveEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String entryId,
  }) async {}

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
  Future<Campaign> createCampaign({
    required String apiBaseUrl,
    required String accessToken,
    required String name,
    String? description,
    String? system,
  }) => throw UnimplementedError();

  @override
  Future<Campaign> getCampaign({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) => throw UnimplementedError();

  @override
  Future<List<Campaign>> listCampaigns({
    required String apiBaseUrl,
    required String accessToken,
  }) => throw UnimplementedError();

  @override
  Future<CampaignInvite> createInvite({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    int? maxUses,
  }) => throw UnimplementedError();

  @override
  Future<CampaignMembership> joinCampaign({
    required String apiBaseUrl,
    required String accessToken,
    required String code,
  }) => throw UnimplementedError();

  @override
  Future<List<CampaignChatMessage>> listMessages({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    String? query,
    String? conversationId,
  }) async => const [];

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
  }) => throw UnimplementedError();

  @override
  Future<List<CampaignInvite>> listInvites({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async => const [];
}

class _FakeAuthClient implements AuthClient {
  @override
  Future<AuthSession> login({
    required String apiBaseUrl,
    required String identifier,
    required String password,
  }) => throw UnimplementedError();

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
  }) => throw UnimplementedError();

  @override
  Future<RegisterResult> register({
    required String apiBaseUrl,
    required String username,
    required String email,
    required String password,
  }) => throw UnimplementedError();
}
