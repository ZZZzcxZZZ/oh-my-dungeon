import 'package:dnd_table_client/src/features/auth/data/auth_api_client.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:dnd_table_client/src/features/auth/domain/auth_session.dart';
import 'package:dnd_table_client/src/features/auth/presentation/auth_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/data/campaign_api_client.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_archive_entry.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_actor.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/actors/campaign_actor_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/campaign_center_page.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/campaign_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/center/campaign_overview_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/campaign_test_support.dart';

/// Plan 2026-07-23 task 1: narrow screens render `NavigationBar`, wide
/// screens render `NavigationRail`. The center keeps only three top-level
/// destinations — 概览/角色/档案 — so durable information stays focused and
/// the records search lives in the chat workspace, not the campaign center.
/// DM-only affordances follow server capabilities, never optimistic client
/// state. The overview panel renders full-width sections without nested
/// `Card` wrappers, and DM tools / settings are visually separated from the
/// member list.
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

  /// Spec §DM 角色生命周期: DM 在队伍面板创建常驻 NPC/怪物/同伴需要
  /// `CampaignActorController` 走 `/actors` 端点。这里构造一个内存版本，
  /// 预先 selectCampaign 以便 DM 写操作能拿到 campaignId。
  Future<CampaignActorController> buildActorController() async {
    final controller = CampaignActorController(
      cacheRepository: MemoryCampaignCacheRepository(),
      apiClient: MemoryCampaignSyncApiClient(),
      apiBaseUrl: apiBaseUrl,
      accessToken: 'access-token',
      currentUserId: 'user-1',
    );
    await controller.selectCampaign('camp-1');
    return controller;
  }

  Future<void> pumpCenterPage(
    WidgetTester tester,
    CampaignController controller, {
    Size size = const Size(390, 844),
    CampaignActorController? actorController,
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
          actorController: actorController,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('narrow screen shows NavigationBar with three destinations', (
    tester,
  ) async {
    final authController = await buildLoggedInAuthController();
    final controller = await buildCampaignController(
      authController: authController,
      canManage: false,
    );

    await pumpCenterPage(tester, controller);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationDestination), findsNWidgets(3));
    expect(find.text('概览'), findsWidgets);
    expect(find.text('角色'), findsWidgets);
    expect(find.text('档案'), findsWidgets);
    // 记录 is intentionally absent — records search lives in the chat
    // workspace, not the campaign center.
    expect(find.text('记录'), findsNothing);

    controller.dispose();
    authController.dispose();
  });

  testWidgets('wide screen shows NavigationRail with three destinations', (
    tester,
  ) async {
    final authController = await buildLoggedInAuthController();
    final controller = await buildCampaignController(
      authController: authController,
      canManage: false,
    );

    await pumpCenterPage(tester, controller, size: const Size(1400, 900));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    // NavigationRail wraps destinations internally; verify via labels.
    expect(find.text('概览'), findsOneWidget);
    expect(find.text('角色'), findsOneWidget);
    expect(find.text('档案'), findsOneWidget);
    expect(find.text('记录'), findsNothing);

    controller.dispose();
    authController.dispose();
  });

  testWidgets('tapping destinations switches the visible panel', (
    tester,
  ) async {
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

    // Switch to characters panel.
    await tester.tap(find.text('角色').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('campaign-characters-panel')), findsOneWidget);

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
      expect(
        find.byKey(const Key('campaign-create-archive-button')),
        findsNothing,
      );
      playerController.dispose();
      playerAuth.dispose();

      // Reset view for the next pump.
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();

      // DM: manage affordance appears — but only on the archive panel per
      // spec §档案 (new-entry FAB lives inside the archive panel, not the
      // overview/team/records panels).
      final dmAuth = await buildLoggedInAuthController();
      final dmController = await buildCampaignController(
        authController: dmAuth,
        canManage: true,
      );
      await pumpCenterPage(tester, dmController);
      // FAB must NOT appear on the default overview panel.
      expect(
        find.byKey(const Key('campaign-create-archive-button')),
        findsNothing,
      );
      // Navigate to the archive panel — FAB appears here.
      await tester.tap(find.text('档案').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('campaign-create-archive-button')),
        findsOneWidget,
      );

      dmController.dispose();
      dmAuth.dispose();
    },
  );

  // Spec §概览: "DM 在相同位置额外看到控场摘要、群体检定和遭遇准备入口。"
  // The DM control entry is migrated from the chat toolbar to the overview
  // panel — DM sees it, player does not, and tapping opens the control sheet.
  testWidgets(
    'overview panel shows DM control entry only when canManageCampaign is true',
    (tester) async {
      // Player: no DM control entry.
      final playerAuth = await buildLoggedInAuthController();
      final playerController = await buildCampaignController(
        authController: playerAuth,
        canManage: false,
      );
      await pumpCenterPage(tester, playerController);
      expect(
        find.byKey(const Key('campaign-overview-dm-control-entry')),
        findsNothing,
      );
      playerController.dispose();
      playerAuth.dispose();

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();

      // DM: DM control entry appears on the overview panel.
      final dmAuth = await buildLoggedInAuthController();
      final dmController = await buildCampaignController(
        authController: dmAuth,
        canManage: true,
      );
      await pumpCenterPage(tester, dmController);
      expect(
        find.byKey(const Key('campaign-overview-dm-control-entry')),
        findsOneWidget,
      );

      dmController.dispose();
      dmAuth.dispose();
    },
  );

  testWidgets('tapping DM control entry opens the DM control bottom sheet', (
    tester,
  ) async {
    final dmAuth = await buildLoggedInAuthController();
    final dmController = await buildCampaignController(
      authController: dmAuth,
      canManage: true,
    );
    await pumpCenterPage(tester, dmController);

    await tester.tap(
      find.byKey(const Key('campaign-overview-dm-control-entry')),
    );
    await tester.pumpAndSettle();

    // DM control sheet should appear with its characteristic title and
    // submenu entries (遭遇控场 / 快捷操作).
    expect(find.text('DM 控场'), findsWidgets);
    expect(find.text('遭遇控场'), findsOneWidget);
    expect(find.text('快捷操作'), findsOneWidget);

    dmController.dispose();
    dmAuth.dispose();
  });

  // Spec §档案: 新建条目 FAB 只在档案面板出现, 概览/角色面板都不显示。
  testWidgets(
    'create archive FAB only appears on the archive panel, not on overview or characters',
    (tester) async {
      final dmAuth = await buildLoggedInAuthController();
      final dmController = await buildCampaignController(
        authController: dmAuth,
        canManage: true,
      );
      await pumpCenterPage(tester, dmController);

      // Overview (default) — no FAB.
      expect(
        find.byKey(const Key('campaign-create-archive-button')),
        findsNothing,
      );

      // Characters panel — no FAB.
      await tester.tap(find.text('角色').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('campaign-create-archive-button')),
        findsNothing,
      );

      // Archive panel — FAB appears.
      await tester.tap(find.text('档案').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('campaign-create-archive-button')),
        findsOneWidget,
      );

      dmController.dispose();
      dmAuth.dispose();
    },
  );

  // 成员和邀请属于概览，不再与角色管理混合。
  testWidgets(
    'overview shows members and invite button only for campaign managers',
    (tester) async {
      // Player: no invite button.
      final playerAuth = await buildLoggedInAuthController();
      final playerController = await buildCampaignController(
        authController: playerAuth,
        canManage: false,
      );
      await pumpCenterPage(tester, playerController);
      expect(find.byKey(const Key('campaign-member-list')), findsOneWidget);
      expect(find.byKey(const Key('campaign-invite-share')), findsNothing);
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
      expect(find.byKey(const Key('campaign-member-list')), findsOneWidget);
      expect(find.byKey(const Key('campaign-invite-share')), findsOneWidget);

      dmController.dispose();
      dmAuth.dispose();
    },
  );

  testWidgets('player center does not request manager-only campaign detail', (
    tester,
  ) async {
    final authController = await buildLoggedInAuthController();
    final campaignClient = _FakeCampaignClient(canManage: false);
    final controller = CampaignController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      campaignClient: campaignClient,
    );
    await controller.loadWorkspaceContext('camp-1');

    await pumpCenterPage(tester, controller);

    expect(campaignClient.getCampaignCalls, 0);
    expect(campaignClient.listInvitesCalls, 0);

    controller.dispose();
    authController.dispose();
  });

  testWidgets('overview opens the full sheet for a bound member actor', (
    tester,
  ) async {
    CampaignActor? openedActor;
    final actor = CampaignActor(
      id: 'actor-1',
      campaignId: 'camp-1',
      ownerUserId: 'user-1',
      sourceCharacterId: null,
      actorType: 'player',
      status: 'active',
      sheet: const {'name': '莱雅', 'currentHp': 8, 'maxHp': 10},
      revision: 1,
      updatedBy: 'user-1',
      createdAt: '2026-07-18T00:00:00Z',
      updatedAt: '2026-07-18T00:00:00Z',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignOverviewPanel(
            campaign: _campaign,
            canManage: false,
            members: const [
              CampaignMemberPreview(
                userId: 'user-1',
                displayName: '玩家一',
                role: 'player',
              ),
            ],
            actors: [actor],
            onOpenActor: (value) => openedActor = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('玩家一'));

    expect(openedActor, same(actor));
  });

  testWidgets(
    'tapping invite button creates an invite and shows the code dialog',
    (tester) async {
      final dmAuth = await buildLoggedInAuthController();
      final dmController = await buildCampaignController(
        authController: dmAuth,
        canManage: true,
      );
      await pumpCenterPage(tester, dmController);

      await tester.tap(find.byKey(const Key('campaign-invite-share')));
      await tester.pumpAndSettle();

      // The invite code should appear in a dialog.
      expect(find.textContaining('JOIN1234'), findsWidgets);
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
      // FAB lives on the archive panel per spec §档案.
      await tester.tap(find.text('档案').last);
      await tester.pumpAndSettle();

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
      // FAB lives on the archive panel per spec §档案.
      await tester.tap(find.text('档案').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('campaign-create-archive-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('新建地点'));
      await tester.pumpAndSettle();

      // Create form should be open with kind pre-filled.
      expect(find.text('新建战役条目'), findsOneWidget);
      expect(find.text('地点'), findsWidgets);

      dmController.dispose();
      dmAuth.dispose();
    },
  );

  // Spec §DM 角色生命周期: DM 可在 战役中心 → 角色 创建常驻
  // NPC/怪物/同伴（actorType: npc/monster/companion，lifecycle: persistent）。
  testWidgets('DM characters panel shows create persistent actor button', (
    tester,
  ) async {
    final dmAuth = await buildLoggedInAuthController();
    final dmController = await buildCampaignController(
      authController: dmAuth,
      canManage: true,
    );
    final actorController = await buildActorController();
    await pumpCenterPage(
      tester,
      dmController,
      actorController: actorController,
    );
    await tester.tap(find.text('角色').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('characters-create-actor-button')),
      findsOneWidget,
    );

    actorController.dispose();
    dmController.dispose();
    dmAuth.dispose();
  });

  testWidgets(
    'player characters panel does not show create persistent actor button',
    (tester) async {
      final playerAuth = await buildLoggedInAuthController();
      final playerController = await buildCampaignController(
        authController: playerAuth,
        canManage: false,
      );
      final actorController = await buildActorController();
      await pumpCenterPage(
        tester,
        playerController,
        actorController: actorController,
      );
      await tester.tap(find.text('角色').last);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('characters-create-actor-button')),
        findsNothing,
      );

      actorController.dispose();
      playerController.dispose();
      playerAuth.dispose();
    },
  );

  testWidgets(
    'tapping create persistent actor button opens form with actor type choices',
    (tester) async {
      final dmAuth = await buildLoggedInAuthController();
      final dmController = await buildCampaignController(
        authController: dmAuth,
        canManage: true,
      );
      final actorController = await buildActorController();
      await pumpCenterPage(
        tester,
        dmController,
        actorController: actorController,
      );
      await tester.tap(find.text('角色').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('characters-create-actor-button')));
      await tester.pumpAndSettle();

      // Form should show NPC / 怪物 / 同伴 options.
      expect(find.text('创建常驻角色'), findsOneWidget);
      expect(find.text('NPC'), findsOneWidget);
      expect(find.text('怪物'), findsOneWidget);
      expect(find.text('同伴'), findsOneWidget);

      actorController.dispose();
      dmController.dispose();
      dmAuth.dispose();
    },
  );

  // Spec §全局设置: 战役名称/所有权转移/战役归档/离开战役四项低频操作整合到
  // 概览面板"战役设置"区块。DM 可见全部 4 项, 普通玩家只见"离开战役"。
  // 这些操作原来藏在聊天页右上角三点菜单里, 用户要求完全去除三点菜单并
  // 迁移到战役中心, 与 spec 一致。
  testWidgets('DM overview panel shows all four global setting entries', (
    tester,
  ) async {
    final dmAuth = await buildLoggedInAuthController();
    final dmController = await buildCampaignController(
      authController: dmAuth,
      canManage: true,
    );
    await pumpCenterPage(tester, dmController);
    await tester.ensureVisible(
      find.byKey(const Key('campaign-overview-settings')),
    );
    await tester.tap(find.byKey(const Key('campaign-overview-settings')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('campaign-overview-edit-details')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('campaign-overview-transfer-ownership')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('campaign-overview-archive-campaign')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('campaign-overview-leave-campaign')),
      findsOneWidget,
    );

    dmController.dispose();
    dmAuth.dispose();
  });

  testWidgets('player overview panel only shows leave campaign entry', (
    tester,
  ) async {
    final playerAuth = await buildLoggedInAuthController();
    final playerController = await buildCampaignController(
      authController: playerAuth,
      canManage: false,
    );
    await pumpCenterPage(tester, playerController);
    await tester.ensureVisible(
      find.byKey(const Key('campaign-overview-settings')),
    );
    await tester.tap(find.byKey(const Key('campaign-overview-settings')));
    await tester.pumpAndSettle();

    // Owner-only entries must NOT appear for non-managers.
    expect(
      find.byKey(const Key('campaign-overview-edit-details')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('campaign-overview-transfer-ownership')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('campaign-overview-archive-campaign')),
      findsNothing,
    );
    // Leave campaign remains available to any member.
    expect(
      find.byKey(const Key('campaign-overview-leave-campaign')),
      findsOneWidget,
    );

    playerController.dispose();
    playerAuth.dispose();
  });

  testWidgets('tapping leave campaign shows the developing snackbar', (
    tester,
  ) async {
    final playerAuth = await buildLoggedInAuthController();
    final playerController = await buildCampaignController(
      authController: playerAuth,
      canManage: false,
    );
    await pumpCenterPage(tester, playerController);
    await tester.ensureVisible(
      find.byKey(const Key('campaign-overview-settings')),
    );
    await tester.tap(find.byKey(const Key('campaign-overview-settings')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('campaign-overview-leave-campaign')));
    await tester.pumpAndSettle();

    expect(find.text('该功能正在开发中'), findsOneWidget);

    playerController.dispose();
    playerAuth.dispose();
  });

  // Plan 2026-07-23 task 1: 概览使用全宽 section 与清晰间距, 不使用嵌套 Card。
  // DM 工具和战役设置分区, 不与成员列表粘连。
  testWidgets(
    'overview panel does not wrap sections in nested Card widgets',
    (tester) async {
      final dmAuth = await buildLoggedInAuthController();
      final dmController = await buildCampaignController(
        authController: dmAuth,
        canManage: true,
      );
      await pumpCenterPage(tester, dmController);

      // The DM control entry should NOT be wrapped in a Card — it should be a
      // full-width section (e.g. ListTile or Container, not Card.filled).
      final dmControlEntry = find.byKey(
        const Key('campaign-overview-dm-control-entry'),
      );
      expect(dmControlEntry, findsOneWidget);
      // Walk up from the entry to ensure no ancestor Card exists.
      final ancestors = tester.widgetList<Card>(
        find.ancestor(of: dmControlEntry, matching: find.byType(Card)),
      );
      expect(ancestors, isEmpty);

      // The invite share should also not be wrapped in a nested Card.
      final inviteShare = find.byKey(const Key('campaign-invite-share'));
      expect(inviteShare, findsOneWidget);
      final inviteAncestors = tester.widgetList<Card>(
        find.ancestor(of: inviteShare, matching: find.byType(Card)),
      );
      expect(inviteAncestors, isEmpty);

      dmController.dispose();
      dmAuth.dispose();
    },
  );

  // Plan 2026-07-23 Wave 1 Task 1.4: 档案新建 FAB 与角色新建 FAB 风格一致，
  // 都使用 FloatingActionButton.extended + 语义化图标 + 文字标签。
  testWidgets(
    'archive create FAB uses FloatingActionButton.extended with label',
    (tester) async {
      final dmAuth = await buildLoggedInAuthController();
      final dmController = await buildCampaignController(
        authController: dmAuth,
        canManage: true,
      );
      await pumpCenterPage(tester, dmController);
      // Navigate to archive panel where FAB appears.
      await tester.tap(find.text('档案').last);
      await tester.pumpAndSettle();

      final fab = find.byKey(const Key('campaign-create-archive-button'));
      expect(fab, findsOneWidget);
      // Plan 2026-07-23 Task 1.4: FAB 必须是 extended 变体（带可见文字标签），
      // 不是仅图标的普通 FAB。
      expect(find.text('新条目'), findsOneWidget);

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
  }) async => const AuthSession(
    user: _user,
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
  );

  @override
  Future<AuthUser> me({
    required String apiBaseUrl,
    required String accessToken,
  }) async => _user;

  @override
  Future<String> refresh({
    required String apiBaseUrl,
    required String refreshToken,
  }) async => 'access-token';

  @override
  Future<RegisterResult> register({
    required String apiBaseUrl,
    required String username,
    required String email,
    required String password,
  }) async => const RegisterResult(user: _user, isFirstUser: false);

  @override
  Future<void> logout({
    required String apiBaseUrl,
    required String refreshToken,
  }) async {}
}

class _FakeCampaignClient implements CampaignClient {
  _FakeCampaignClient({required this.canManage});

  final bool canManage;
  int getCampaignCalls = 0;
  int listInvitesCalls = 0;

  @override
  Future<CampaignWorkspaceContext> getWorkspaceContext({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async => CampaignWorkspaceContext(
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
  }) async => const CampaignArchiveEntry(
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
    List<Map<String, Object?>>? bodyBlocks,
    List<String>? tags,
    List<Map<String, Object?>>? links,
    List<Map<String, Object?>>? attachmentRefs,
  }) async => throw UnimplementedError();

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
  }) async {
    getCampaignCalls += 1;
    return _campaign;
  }

  @override
  Future<List<Campaign>> listCampaigns({
    required String apiBaseUrl,
    required String accessToken,
  }) async => const [_campaign];

  @override
  Future<CampaignInvite> createInvite({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    int? maxUses,
  }) async => const CampaignInvite(
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
  }) async => const CampaignMembership(
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
  }) async => const [];

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
  }) => throw UnimplementedError();

  @override
  Future<List<CampaignInvite>> listInvites({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async {
    listInvitesCalls += 1;
    return const [];
  }
}
