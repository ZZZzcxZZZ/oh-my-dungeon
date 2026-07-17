import 'package:dnd_table_client/src/features/app_preferences/data/app_preferences_store.dart';
import 'package:dnd_table_client/src/features/app_preferences/presentation/app_preferences_controller.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_api_client.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:dnd_table_client/src/features/auth/domain/auth_session.dart';
import 'package:dnd_table_client/src/features/auth/presentation/auth_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/data/campaign_api_client.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_archive_entry.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/campaign_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/campaigns_tab_page.dart';
import 'package:dnd_table_client/src/features/characters/data/character_repository.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_controller.dart';
import 'package:dnd_table_client/src/features/client_mode/domain/client_mode.dart';
import 'package:dnd_table_client/src/features/content/data/local/content_repository.dart';
import 'package:dnd_table_client/src/features/server_home/domain/active_server_session.dart';
import 'package:dnd_table_client/src/features/server_profiles/domain/server_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec §客户端工作模式: 战役创建入口只在 DM 模式显示。Player 模式下
/// 应隐藏 FAB，并保留加入/刷新入口；空态文案也应随模式调整。
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

  Future<CampaignController> buildCampaignController(
    AuthController authController,
  ) async {
    final controller = CampaignController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      campaignClient: _FakeCampaignClient(),
    );
    await controller.loadCampaigns();
    return controller;
  }

  AppPreferencesController buildAppPreferencesController() {
    return AppPreferencesController(store: InMemoryAppPreferencesStore());
  }

  ActiveServerSession buildActiveServerSession() {
    final session = ActiveServerSession();
    session.activate(
      const ServerProfile(
        id: 'localhost',
        name: 'Local Table',
        baseUrl: 'http://localhost:3000',
        apiBaseUrl: 'http://localhost:3000/api',
        websocketUrl: 'ws://localhost:3000/ws',
        lastKnownVersion: '0.1.0',
      ),
    );
    return session;
  }

  Future<void> pumpCampaignsTab(
    WidgetTester tester, {
    required AuthController authController,
    required CampaignController campaignController,
    required ClientModeController modeController,
    required AppPreferencesController appPreferencesController,
    required ActiveServerSession session,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CampaignsTabPage(
          session: session,
          authController: authController,
          campaignController: campaignController,
          characterController: CharacterController(
            repository: EmptyCharacterRepository(),
          ),
          contentRepository: EmptyContentRepository(),
          modeController: modeController,
          appPreferencesController: appPreferencesController,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'DM mode shows the create-campaign FAB',
    (tester) async {
      final auth = await buildLoggedInAuthController();
      final campaignController = await buildCampaignController(auth);
      final modeController = ClientModeController(
        initialMode: ClientMode.dungeonMaster,
      );
      final prefs = buildAppPreferencesController();
      await prefs.initialize();
      final session = buildActiveServerSession();

      await pumpCampaignsTab(
        tester,
        authController: auth,
        campaignController: campaignController,
        modeController: modeController,
        appPreferencesController: prefs,
        session: session,
      );

      expect(
        find.byKey(const Key('campaign-create-button')),
        findsOneWidget,
      );
      expect(find.text('创建战役'), findsOneWidget);

      modeController.dispose();
      prefs.dispose();
      campaignController.dispose();
      auth.dispose();
      session.dispose();
    },
  );

  testWidgets(
    'Player mode hides the create-campaign FAB',
    (tester) async {
      final auth = await buildLoggedInAuthController();
      final campaignController = await buildCampaignController(auth);
      final modeController = ClientModeController(
        initialMode: ClientMode.player,
      );
      final prefs = buildAppPreferencesController();
      await prefs.initialize();
      final session = buildActiveServerSession();

      await pumpCampaignsTab(
        tester,
        authController: auth,
        campaignController: campaignController,
        modeController: modeController,
        appPreferencesController: prefs,
        session: session,
      );

      expect(
        find.byKey(const Key('campaign-create-button')),
        findsNothing,
      );
      // AppBar entries remain accessible in either mode.
      expect(find.byTooltip('使用邀请码加入战役'), findsOneWidget);
      expect(find.byTooltip('刷新战役'), findsOneWidget);

      modeController.dispose();
      prefs.dispose();
      campaignController.dispose();
      auth.dispose();
      session.dispose();
    },
  );

  testWidgets(
    'toggling from Player to DM mode reveals the FAB without remounting',
    (tester) async {
      final auth = await buildLoggedInAuthController();
      final campaignController = await buildCampaignController(auth);
      final modeController = ClientModeController(
        initialMode: ClientMode.player,
      );
      final prefs = buildAppPreferencesController();
      await prefs.initialize();
      final session = buildActiveServerSession();

      await pumpCampaignsTab(
        tester,
        authController: auth,
        campaignController: campaignController,
        modeController: modeController,
        appPreferencesController: prefs,
        session: session,
      );

      expect(find.byKey(const Key('campaign-create-button')), findsNothing);

      await modeController.setMode(ClientMode.dungeonMaster);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('campaign-create-button')), findsOneWidget);

      modeController.dispose();
      prefs.dispose();
      campaignController.dispose();
      auth.dispose();
      session.dispose();
    },
  );

  testWidgets(
    'Player mode empty-state copy points to invite entry instead of FAB',
    (tester) async {
      final auth = await buildLoggedInAuthController();
      // Use a campaign client that returns no campaigns.
      final campaignController = CampaignController(
        apiBaseUrl: apiBaseUrl,
        authController: auth,
        campaignClient: _FakeCampaignClient(campaigns: const []),
      );
      await campaignController.loadCampaigns();
      final modeController = ClientModeController(
        initialMode: ClientMode.player,
      );
      final prefs = buildAppPreferencesController();
      await prefs.initialize();
      final session = buildActiveServerSession();

      await pumpCampaignsTab(
        tester,
        authController: auth,
        campaignController: campaignController,
        modeController: modeController,
        appPreferencesController: prefs,
        session: session,
      );

      expect(find.textContaining('使用上方邀请码入口加入朋友的团'), findsOneWidget);

      modeController.dispose();
      prefs.dispose();
      campaignController.dispose();
      auth.dispose();
      session.dispose();
    },
  );

  testWidgets(
    'DM mode empty-state copy still mentions the bottom-right FAB',
    (tester) async {
      final auth = await buildLoggedInAuthController();
      final campaignController = CampaignController(
        apiBaseUrl: apiBaseUrl,
        authController: auth,
        campaignClient: _FakeCampaignClient(campaigns: const []),
      );
      await campaignController.loadCampaigns();
      final modeController = ClientModeController(
        initialMode: ClientMode.dungeonMaster,
      );
      final prefs = buildAppPreferencesController();
      await prefs.initialize();
      final session = buildActiveServerSession();

      await pumpCampaignsTab(
        tester,
        authController: auth,
        campaignController: campaignController,
        modeController: modeController,
        appPreferencesController: prefs,
        session: session,
      );

      expect(find.textContaining('点击右下角创建'), findsOneWidget);

      modeController.dispose();
      prefs.dispose();
      campaignController.dispose();
      auth.dispose();
      session.dispose();
    },
  );
}

const _user = AuthUser(
  id: 'user-1',
  username: 'ranger',
  email: 'ranger@example.com',
);

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
  _FakeCampaignClient({List<Campaign> campaigns = const [_campaign]})
    : _campaigns = campaigns;

  final List<Campaign> _campaigns;

  @override
  Future<CampaignWorkspaceContext> getWorkspaceContext({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async =>
      throw UnimplementedError();

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
      throw UnimplementedError();

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
  }) async =>
      _campaign;

  @override
  Future<Campaign> getCampaign({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async =>
      _campaigns.first;

  @override
  Future<List<Campaign>> listCampaigns({
    required String apiBaseUrl,
    required String accessToken,
  }) async =>
      _campaigns;

  @override
  Future<CampaignInvite> createInvite({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    int? maxUses,
  }) async =>
      throw UnimplementedError();

  @override
  Future<CampaignMembership> joinCampaign({
    required String apiBaseUrl,
    required String accessToken,
    required String code,
  }) async =>
      throw UnimplementedError();

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
  }) async =>
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
  }) async =>
      throw UnimplementedError();

  @override
  Future<List<CampaignInvite>> listInvites({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async =>
      const [];
}
