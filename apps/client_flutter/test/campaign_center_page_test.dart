import 'package:dnd_table_client/src/features/auth/data/auth_api_client.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:dnd_table_client/src/features/auth/domain/auth_session.dart';
import 'package:dnd_table_client/src/features/auth/presentation/auth_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/data/campaign_api_client.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_archive_entry.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/campaign_center_page.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/campaign_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan 3 task 2: narrow screens render `NavigationBar`, wide screens render
/// `NavigationRail`, all four panels (overview/team/archive/records) are
/// reachable, and DM-only affordances only appear when server capabilities
/// allow `canManageCampaign`.
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

  Future<CampaignController> buildCampaignController({
    required AuthController authController,
    required bool canManage,
  }) async {
    final controller = CampaignController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      campaignClient: _FakeCampaignClient(canManage: canManage),
    );
    // Pre-load workspace context so the page reads capabilities on first
    // frame; otherwise the FAB test would race the post-frame callback.
    await controller.loadWorkspaceContext('camp-1');
    return controller;
  }

  Future<void> pumpCenterPage(
    WidgetTester tester,
    CampaignController controller, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: CampaignCenterPage(
          campaign: _campaign,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('narrow screen shows NavigationBar with four destinations',
      (tester) async {
    final authController = await buildLoggedInAuthController();
    final controller = await buildCampaignController(
      authController: authController,
      canManage: false,
    );

    await pumpCenterPage(tester, controller);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.text('概览'), findsWidgets);
    expect(find.text('队伍'), findsWidgets);
    expect(find.text('档案'), findsWidgets);
    expect(find.text('记录'), findsWidgets);

    controller.dispose();
    authController.dispose();
  });

  testWidgets('wide screen shows NavigationRail with four destinations',
      (tester) async {
    final authController = await buildLoggedInAuthController();
    final controller = await buildCampaignController(
      authController: authController,
      canManage: false,
    );

    await pumpCenterPage(
      tester,
      controller,
      size: const Size(1400, 900),
    );

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    // NavigationRail wraps destinations internally; verify via labels.
    expect(find.text('概览'), findsOneWidget);
    expect(find.text('队伍'), findsOneWidget);
    expect(find.text('档案'), findsOneWidget);
    expect(find.text('记录'), findsOneWidget);

    controller.dispose();
    authController.dispose();
  });

  testWidgets('tapping destinations switches the visible panel',
      (tester) async {
    final authController = await buildLoggedInAuthController();
    final controller = await buildCampaignController(
      authController: authController,
      canManage: false,
    );

    await pumpCenterPage(tester, controller);

    // Default landing: overview panel.
    expect(find.byKey(const Key('campaign-overview-panel')), findsOneWidget);

    // Switch to archives panel by tapping the 档案 destination label.
    await tester.tap(find.text('档案').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('campaign-archive-panel')), findsOneWidget);

    // Switch to records panel.
    await tester.tap(find.text('记录').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('campaign-records-panel')), findsOneWidget);

    // Switch to team panel.
    await tester.tap(find.text('队伍').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('campaign-team-panel')), findsOneWidget);

    controller.dispose();
    authController.dispose();
  });

  testWidgets(
      'DM-only manage button only shows when canManageCampaign is true',
      (tester) async {
    // Player: no manage affordance.
    final playerAuth = await buildLoggedInAuthController();
    final playerController = await buildCampaignController(
      authController: playerAuth,
      canManage: false,
    );
    await pumpCenterPage(tester, playerController);
    expect(find.byKey(const Key('campaign-create-archive-button')), findsNothing);
    playerController.dispose();
    playerAuth.dispose();

    // Reset view for the next pump.
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();

    // DM: manage affordance appears.
    final dmAuth = await buildLoggedInAuthController();
    final dmController = await buildCampaignController(
      authController: dmAuth,
      canManage: true,
    );
    await pumpCenterPage(tester, dmController);
    expect(
      find.byKey(const Key('campaign-create-archive-button')),
      findsOneWidget,
    );

    dmController.dispose();
    dmAuth.dispose();
  });

  // Spec §队伍: 邀请和管理成员在 战役中心 → 队伍，DM 就地操作。
  testWidgets(
    'team panel shows invite button only when canManageCampaign is true',
    (tester) async {
      // Player: no invite button.
      final playerAuth = await buildLoggedInAuthController();
      final playerController = await buildCampaignController(
        authController: playerAuth,
        canManage: false,
      );
      await pumpCenterPage(tester, playerController);
      await tester.tap(find.text('队伍').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('team-invite-button')), findsNothing);
      playerController.dispose();
      playerAuth.dispose();

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();

      // DM: invite button appears.
      final dmAuth = await buildLoggedInAuthController();
      final dmController = await buildCampaignController(
        authController: dmAuth,
        canManage: true,
      );
      await pumpCenterPage(tester, dmController);
      await tester.tap(find.text('队伍').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('team-invite-button')), findsOneWidget);

      dmController.dispose();
      dmAuth.dispose();
    },
  );

  testWidgets(
    'tapping invite button creates an invite and shows the code dialog',
    (tester) async {
      final dmAuth = await buildLoggedInAuthController();
      final dmController = await buildCampaignController(
        authController: dmAuth,
        canManage: true,
      );
      await pumpCenterPage(tester, dmController);
      await tester.tap(find.text('队伍').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('team-invite-button')));
      await tester.pumpAndSettle();

      // The invite code should appear in a dialog.
      expect(find.textContaining('JOIN1234'), findsOneWidget);
      expect(find.text('邀请码已创建'), findsOneWidget);

      dmController.dispose();
      dmAuth.dispose();
    },
  );

  // Spec §档案: 新建条目按钮按类型区分。FAB 点击后弹出类型选择菜单。
  testWidgets(
    'DM archive FAB opens a type selection menu with the four kinds',
    (tester) async {
      final dmAuth = await buildLoggedInAuthController();
      final dmController = await buildCampaignController(
        authController: dmAuth,
        canManage: true,
      );
      await pumpCenterPage(tester, dmController);

      await tester.tap(find.byKey(const Key('campaign-create-archive-button')));
      await tester.pumpAndSettle();

      // Type menu should show all four kinds.
      expect(find.text('新建资料'), findsOneWidget);
      expect(find.text('新建地点'), findsOneWidget);
      expect(find.text('新建线索'), findsOneWidget);
      expect(find.text('新建文件'), findsOneWidget);

      dmController.dispose();
      dmAuth.dispose();
    },
  );

  testWidgets(
    'selecting a type from the FAB menu opens the create form pre-filled with that kind',
    (tester) async {
      final dmAuth = await buildLoggedInAuthController();
      final dmController = await buildCampaignController(
        authController: dmAuth,
        canManage: true,
      );
      await pumpCenterPage(tester, dmController);

      await tester.tap(find.byKey(const Key('campaign-create-archive-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('新建地点'));
      await tester.pumpAndSettle();

      // Create form should be open with kind pre-filled.
      expect(find.text('新建战役条目'), findsOneWidget);
      expect(find.text('地点'), findsOneWidget);

      dmController.dispose();
      dmAuth.dispose();
    },
  );
}

const _campaign = Campaign(
  id: 'camp-1',
  name: 'Curse of Strahd',
  description: 'A gothic horror adventure',
  system: 'dnd5e',
  ownerId: 'user-1',
  status: 'active',
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
);

const _user = AuthUser(
  id: 'user-1',
  username: 'ranger',
  email: 'ranger@example.com',
);

class _FakeAuthClient implements AuthClient {
  @override
  Future<AuthSession> login({
    required String apiBaseUrl,
    required String identifier,
    required String password,
  }) async =>
      const AuthSession(
        user: _user,
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      );

  @override
  Future<AuthUser> me({
    required String apiBaseUrl,
    required String accessToken,
  }) async =>
      _user;

  @override
  Future<String> refresh({
    required String apiBaseUrl,
    required String refreshToken,
  }) async =>
      'access-token';

  @override
  Future<RegisterResult> register({
    required String apiBaseUrl,
    required String username,
    required String email,
    required String password,
  }) async =>
      const RegisterResult(user: _user, isFirstUser: false);

  @override
  Future<void> logout({
    required String apiBaseUrl,
    required String refreshToken,
  }) async {}
}

class _FakeCampaignClient implements CampaignClient {
  _FakeCampaignClient({required this.canManage});

  final bool canManage;

  @override
  Future<CampaignWorkspaceContext> getWorkspaceContext({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async =>
      CampaignWorkspaceContext(
        campaign: _campaign,
        membership: const CampaignMembership(
          id: 'member-1',
          campaignId: 'camp-1',
          userId: 'user-1',
          role: 'player',
          displayName: 'ranger',
          joinedAt: '2026-07-09T00:00:00.000Z',
        ),
        members: const [],
        actors: const [],
        capabilities: CampaignCapabilities(
          canManageCampaign: canManage,
          canManageMembers: canManage,
          canCreateActors: canManage,
          canSpeakAsNarrator: canManage,
        ),
      );

  @override
  Future<List<CampaignArchiveEntry>> listArchives({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    String? kind,
  }) async =>
      const [];

  @override
  Future<CampaignArchiveEntry> createArchiveEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String kind,
    required String title,
    String? summary,
    Map<String, Object?>? payload,
  }) async =>
      const CampaignArchiveEntry(
        id: 'archive-new',
        campaignId: 'camp-1',
        kind: 'clue',
        title: 'New clue',
        summary: '',
        payload: {},
        pinned: false,
        updatedAt: '2026-07-17T00:00:00.000Z',
      );

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
  }) async =>
      throw UnimplementedError();

  @override
  Future<Campaign> createCampaign({
    required String apiBaseUrl,
    required String accessToken,
    required String name,
    String? description,
    String? system,
  }) =>
      throw UnimplementedError();

  @override
  Future<Campaign> getCampaign({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async =>
      _campaign;

  @override
  Future<List<Campaign>> listCampaigns({
    required String apiBaseUrl,
    required String accessToken,
  }) async =>
      const [_campaign];

  @override
  Future<CampaignInvite> createInvite({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    int? maxUses,
  }) async =>
      const CampaignInvite(
        id: 'invite-1',
        campaignId: 'camp-1',
        code: 'JOIN1234',
        roleOnJoin: 'player',
        expiresAt: null,
        maxUses: 1,
        usedCount: 0,
        requireApproval: false,
        createdAt: '2026-07-17T00:00:00.000Z',
      );

  @override
  Future<CampaignMembership> joinCampaign({
    required String apiBaseUrl,
    required String accessToken,
    required String code,
  }) async =>
      const CampaignMembership(
        id: 'member-2',
        campaignId: 'camp-1',
        userId: 'user-1',
        role: 'player',
        displayName: 'ranger',
        joinedAt: '2026-07-09T00:00:00.000Z',
      );

  @override
  Future<List<CampaignChatMessage>> listMessages({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    String? query,
  }) async =>
      const [];

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
  }) =>
      throw UnimplementedError();

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
  }) =>
      throw UnimplementedError();

  @override
  Future<List<CampaignInvite>> listInvites({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async =>
      const [];
}
