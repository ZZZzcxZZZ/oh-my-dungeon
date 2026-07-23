import 'package:dnd_table_client/src/core/dice/dice_roller.dart';
import 'package:dnd_table_client/src/features/campaigns/data/campaign_api_client.dart';
import 'package:dnd_table_client/src/features/campaigns/data/campaign_socket_service.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_archive_entry.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/actors/campaign_actor_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/actors/dm_quick_ops_sheet.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/campaign_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/campaign_event_dispatcher.dart';
import 'package:dnd_table_client/src/features/auth/presentation/auth_controller.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_api_client.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:dnd_table_client/src/features/auth/domain/auth_session.dart';
import 'package:dnd_table_client/src/features/server_profiles/domain/server_profile.dart';
import 'package:dnd_table_client/src/features/content/data/local/content_repository.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_test_support.dart';
import 'support/content_test_support.dart';

void main() {
  const profile = ServerProfile(
    id: 'localhost',
    name: 'Local Table',
    baseUrl: 'http://localhost:3000',
    apiBaseUrl: 'http://localhost:3000/api',
    websocketUrl: 'ws://localhost:3000/ws',
    lastKnownVersion: '0.1.0',
  );

  late CampaignActorController actorController;
  late MemoryCampaignSyncApiClient syncClient;
  late CampaignEventDispatcher dispatcher;
  late CampaignController campaignController;
  late AuthController authController;

  setUp(() async {
    syncClient = MemoryCampaignSyncApiClient();
    actorController = CampaignActorController(
      cacheRepository: MemoryCampaignCacheRepository(actors: [
        testCampaignActor(id: 'a1', campaignId: 'c1', sheet: {'name': 'Gandalf', 'currentHp': 52, 'maxHp': 60}),
        testCampaignActor(id: 'a2', campaignId: 'c1', sheet: {'name': 'Frodo', 'currentHp': 28, 'maxHp': 30}),
      ]),
      apiClient: syncClient,
      apiBaseUrl: profile.apiBaseUrl,
      accessToken: 'tok',
      currentUserId: 'dm-1',
    );
    await actorController.selectCampaign('c1');

    final tokenStore = InMemoryAuthTokenStore();
    await tokenStore.saveTokens(
      profile.id,
      const StoredAuthTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    );
    await tokenStore.setAutoLoginEnabled(profile.id, true);
    authController = AuthController(
      tokenStore: tokenStore,
      authClient: _StubAuthClient(),
      serverProfileId: profile.id,
      apiBaseUrl: profile.apiBaseUrl,
    );
    await authController.initialize();

    campaignController = CampaignController(
      apiBaseUrl: profile.apiBaseUrl,
      authController: authController,
      campaignClient: _RecordingCampaignClient(),
      campaignSocketService: NoopCampaignSocketService(),
    );

    dispatcher = CampaignEventDispatcher(
      apiClient: syncClient,
      apiBaseUrlProvider: () => profile.apiBaseUrl,
      accessTokenProvider: () => 'tok',
    );
  });

  tearDown(() {
    actorController.dispose();
    campaignController.dispose();
    authController.dispose();
  });

  Future<void> pumpSheet(
    WidgetTester tester, {
    ContentRepository? contentRepository,
    DiceRoller? diceRoller,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DmQuickOpsSheet(
            campaignId: 'c1',
            actorController: actorController,
            eventDispatcher: dispatcher,
            campaignController: campaignController,
            contentRepository: contentRepository,
            diceRoller: diceRoller ?? DiceRoller(nextInt: (max) => max - 1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('batch HP change applies to selected actors (Task 3.4)', (tester) async {
    await pumpSheet(tester);

    // Open the "批量扣血/治疗" entry.
    await tester.tap(find.text('批量扣血/治疗'));
    await tester.pumpAndSettle();

    // Select both actors via checkboxes.
    final checkboxes = find.byType(Checkbox);
    expect(checkboxes, findsNWidgets(2));
    await tester.tap(checkboxes.at(0));
    await tester.pump();
    await tester.tap(checkboxes.at(1));
    await tester.pumpAndSettle();

    // Enter damage delta -5.
    await tester.enterText(find.byKey(const Key('dm-batch-hp-delta')), '-5');
    await tester.pumpAndSettle();

    // Apply.
    await tester.tap(find.byKey(const Key('dm-batch-hp-apply')));
    await tester.pumpAndSettle();

    // Two changeActorHp calls with delta=-5.
    expect(syncClient.changeActorHpCalls, hasLength(2));
    expect(syncClient.changeActorHpCalls[0]['delta'], -5);
    expect(syncClient.changeActorHpCalls[1]['delta'], -5);
    final actorIds = syncClient.changeActorHpCalls.map((c) => c['actorId']).toSet();
    expect(actorIds, {'a1', 'a2'});
  });

  testWidgets('grant item writes inventory and emits event (Task 3.4)', (tester) async {
    final contentRepo = MemoryContentRepository(initialEntries: const [
      ContentEntry(
        id: 'item-longsword',
        type: 'equipment',
        slug: 'longsword',
        name: '长剑',
        body: [],
        revision: 1,
        structured: {},
        tags: [],
        source: ContentSource(label: 'PHB'),
      ),
    ]);
    await pumpSheet(tester, contentRepository: contentRepo);

    await tester.tap(find.text('给予装备'));
    await tester.pumpAndSettle();

    // Pick actor a1.
    await tester.tap(find.text('Gandalf'));
    await tester.pumpAndSettle();

    // Pick the longsword item — this dispatches grantItem immediately.
    await tester.tap(find.text('长剑'));
    await tester.pumpAndSettle();

    expect(syncClient.grantItemCalls, hasLength(1));
    expect(syncClient.grantItemCalls.single['actorId'], 'a1');
    expect(syncClient.grantItemCalls.single['itemId'], 'item-longsword');
    expect(syncClient.grantItemCalls.single['name'], '长剑');
  });

  testWidgets('quick check rolls d20 and sends chat message (Task 3.4)', (tester) async {
    final recordingClient = _RecordingCampaignClient();
    campaignController = CampaignController(
      apiBaseUrl: profile.apiBaseUrl,
      authController: authController,
      campaignClient: recordingClient,
      campaignSocketService: NoopCampaignSocketService(),
    );

    await pumpSheet(tester, diceRoller: DiceRoller(nextInt: (max) => 17));

    await tester.tap(find.text('快速检定'));
    await tester.pumpAndSettle();

    // Pick actor a2 (Frodo).
    await tester.tap(find.text('Frodo'));
    await tester.pumpAndSettle();

    // Set DC 15.
    await tester.enterText(find.byKey(const Key('dm-quick-check-dc')), '15');
    await tester.pumpAndSettle();

    // Roll.
    await tester.tap(find.byKey(const Key('dm-quick-check-roll')));
    await tester.pumpAndSettle();

    expect(recordingClient.sentMessages, hasLength(1));
    final msg = recordingClient.sentMessages.single;
    expect(msg.kind, 'roll');
    expect(msg.campaignActorId, 'a2');
    expect((msg.eventData?['total'] as num?)?.toInt(), 18); // 17+1 = 18 (dex +1)
    expect((msg.eventData?['dc'] as num?)?.toInt(), 15);
    expect(msg.eventData?['success'], true);
  });
}

class _StubAuthClient implements AuthClient {
  @override
  Future<AuthSession> login({required String apiBaseUrl, required String identifier, required String password}) =>
      throw UnimplementedError();
  @override
  Future<void> logout({required String apiBaseUrl, required String refreshToken}) async {}
  @override
  Future<AuthUser> me({required String apiBaseUrl, required String accessToken}) async {
    return const AuthUser(
      id: 'dm-1',
      username: 'dm',
      email: 'dm@example.com',
    );
  }
  @override
  Future<String> refresh({required String apiBaseUrl, required String refreshToken}) => throw UnimplementedError();
  @override
  Future<RegisterResult> register({required String apiBaseUrl, required String username, required String email, required String password}) =>
      throw UnimplementedError();
}

class _RecordingCampaignClient implements CampaignClient {
  final List<_SentMessage> sentMessages = [];

  @override
  Future<void> markCampaignRead({required String apiBaseUrl, required String accessToken, required String campaignId}) async {}
  @override
  Future<CampaignMembership> updateSpeaker({required String apiBaseUrl, required String accessToken, required String campaignId, required String speakerMode, String? actorId}) =>
      throw UnimplementedError();
  @override
  Future<List<CampaignArchiveEntry>> listArchives({required String apiBaseUrl, required String accessToken, required String campaignId, String? kind, String? query}) async => const [];
  @override
  Future<CampaignArchiveEntry> createArchiveEntry({required String apiBaseUrl, required String accessToken, required String campaignId, required String kind, required String title, String? summary, Map<String, Object?>? payload, List<Map<String, Object?>>? bodyBlocks, List<String>? tags, List<Map<String, Object?>>? links, List<Map<String, Object?>>? attachmentRefs}) =>
      throw UnimplementedError();
  @override
  Future<CampaignArchiveEntry> updateArchiveEntry({required String apiBaseUrl, required String accessToken, required String campaignId, required String entryId, String? kind, String? title, String? summary, Map<String, Object?>? payload, bool? pinned, List<Map<String, Object?>>? bodyBlocks, List<String>? tags, List<Map<String, Object?>>? links, List<Map<String, Object?>>? attachmentRefs}) =>
      throw UnimplementedError();
  @override
  Future<void> archiveEntry({required String apiBaseUrl, required String accessToken, required String campaignId, required String entryId}) => throw UnimplementedError();
  @override
  Future<CampaignWorkspaceContext> getWorkspaceContext({required String apiBaseUrl, required String accessToken, required String campaignId}) =>
      throw UnimplementedError();
  @override
  Future<List<Campaign>> listCampaigns({required String apiBaseUrl, required String accessToken}) async => const [];
  @override
  Future<Campaign> getCampaign({required String apiBaseUrl, required String accessToken, required String campaignId}) => throw UnimplementedError();
  @override
  Future<List<CampaignInvite>> listInvites({required String apiBaseUrl, required String accessToken, required String campaignId}) async => const [];
  @override
  Future<CampaignMembership> joinCampaign({required String apiBaseUrl, required String accessToken, required String code}) => throw UnimplementedError();
  @override
  Future<List<CampaignChatMessage>> listMessages({required String apiBaseUrl, required String accessToken, required String campaignId, String? query}) async => const [];
  @override
  Future<CampaignInvite> createInvite({required String apiBaseUrl, required String accessToken, required String campaignId, int? maxUses}) => throw UnimplementedError();
  @override
  Future<CampaignChatMessage> sendMessage({required String apiBaseUrl, required String accessToken, required String campaignId, required String kind, required String content, String? campaignActorId, String? actionId, Map<String, Object?>? eventData, Map<String, Object?>? draftActor}) async {
    final msg = _SentMessage(kind: kind, content: content, campaignActorId: campaignActorId, eventData: eventData);
    sentMessages.add(msg);
    return CampaignChatMessage(
      id: 'm-${sentMessages.length}',
      campaignId: campaignId,
      senderId: 'dm-1',
      campaignActorId: campaignActorId,
      displayName: 'DM',
      avatarUrl: null,
      kind: kind,
      content: content,
      eventData: eventData ?? const {},
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
  }
  @override
  Future<Campaign> createCampaign({required String apiBaseUrl, required String accessToken, required String name, String? description, String? system}) => throw UnimplementedError();
}

class _SentMessage {
  const _SentMessage({required this.kind, required this.content, this.campaignActorId, this.eventData});
  final String kind;
  final String content;
  final String? campaignActorId;
  final Map<String, Object?>? eventData;
}
