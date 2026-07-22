import 'package:dnd_table_client/src/app/dnd_table_app.dart';
import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_api_client.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:dnd_table_client/src/features/auth/domain/auth_session.dart';
import 'package:dnd_table_client/src/features/auth/presentation/auth_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/data/campaign_api_client.dart';
import 'package:dnd_table_client/src/features/campaigns/data/campaign_socket_service.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign_archive_entry.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/campaign_controller.dart';
import 'package:dnd_table_client/src/features/campaigns/presentation/campaigns_tab_page.dart';
import 'package:dnd_table_client/src/features/app_preferences/data/app_preferences_store.dart';
import 'package:dnd_table_client/src/features/app_preferences/domain/app_preferences.dart';
import 'package:dnd_table_client/src/features/app_preferences/presentation/app_preferences_controller.dart';
import 'package:dnd_table_client/src/features/characters/data/local/drift_character_repository.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_controller.dart';
import 'package:dnd_table_client/src/features/characters/presentation/characters_tab_page.dart';
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/client_mode/domain/client_mode.dart';
import 'package:dnd_table_client/src/features/content/data/campaign_aware_content_repository.dart';
import 'package:dnd_table_client/src/features/content/data/local/content_repository.dart';
import 'package:dnd_table_client/src/features/content/domain/content_block.dart';
import 'package:dnd_table_client/src/features/content/domain/content_entry.dart';
import 'package:dnd_table_client/src/features/content/domain/content_package_manifest.dart';
import 'package:dnd_table_client/src/core/dice/dice_roller.dart'
    show DiceRoller;
import 'package:dnd_table_client/src/features/server_profiles/data/server_profile_store.dart';
import 'package:dnd_table_client/src/features/server_profiles/domain/server_profile.dart';
import 'package:dnd_table_client/src/features/server_home/domain/active_server_session.dart';
import 'package:dnd_table_client/src/features/vault/domain/vault_models.dart';
import 'package:dnd_table_client/src/features/vault/presentation/vault_settings_section.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/vault_test_support.dart';
import 'support/character_test_support.dart';
import 'support/campaign_test_support.dart';
import 'support/content_test_support.dart';

void main() {
  SharedPreferences.setMockInitialValues({});
  const profile = ServerProfile(
    id: 'localhost',
    name: 'Local Table',
    baseUrl: 'http://localhost:3000',
    apiBaseUrl: 'http://localhost:3000/api',
    websocketUrl: 'ws://localhost:3000/ws',
    lastKnownVersion: '0.1.0',
  );

  Future<AppDatabase> databaseWithCharacter(CharacterSheet character) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = DriftCharacterRepository(database);
    await repository.save(character);
    return database;
  }

  Future<void> installLocalContent(
    AppDatabase database,
    List<ContentEntry> entries,
  ) async {
    await DriftContentRepository(database).replacePackage(
      manifest: ContentPackageManifest(
        formatVersion: 1,
        id: 'widget-test',
        name: 'Widget test content',
        version: '1.0.0',
        locale: 'zh-CN',
        system: 'dnd5e-2024',
        entryCount: entries.length,
      ),
      entries: entries,
      contentHash: 'widget-test-content',
    );
  }

  testWidgets('shows the server profile empty state', (tester) async {
    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: InMemoryServerProfileStore(),
        authTokenStore: InMemoryAuthTokenStore(),
      ),
    );
    await tester.pumpAndSettle();

    // 离线优先：未配置服务器时直接进入 MainShell（本地模式）。
    expect(find.text('首页'), findsNothing);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.text('战役'), findsWidgets);
    expect(find.text('角色'), findsWidgets);
    expect(find.text('资料库'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
    expect(find.text('连接你的跑团服务器'), findsNothing);
    expect(find.text('未连接服务器'), findsWidgets);
  });

  testWidgets('shows a recoverable startup error instead of a blank page', (
    tester,
  ) async {
    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: InMemoryServerProfileStore(),
        authTokenStore: InMemoryAuthTokenStore(),
        appPreferencesController: AppPreferencesController(
          store: _ThrowingAppPreferencesStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('启动失败'), findsOneWidget);
    expect(find.textContaining('本地预览数据'), findsOneWidget);
  });

  testWidgets('switches client mode from settings', (tester) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);
    await store.setDefaultProfileId(profile.id);

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: InMemoryAuthTokenStore(),
      ),
    );
    await tester.pumpAndSettle();

    // 有默认 profile 时直接进入四入口主界面。
    expect(find.byType(NavigationDestination), findsNWidgets(4));

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    expect(find.text('使用模式'), findsOneWidget);
    expect(find.text('玩家'), findsOneWidget);
    expect(find.text('主持人'), findsOneWidget);

    await tester.ensureVisible(find.text('使用模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('主持人'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.textContaining('主持人模式会显示'), findsOneWidget);
  });

  testWidgets('marks a saved server profile as default', (tester) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: InMemoryAuthTokenStore(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, '管理服务器'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '管理服务器'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('服务器操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设为默认'));
    await tester.pumpAndSettle();

    expect(find.text('默认'), findsOneWidget);
  });

  testWidgets('edits a saved server profile name', (tester) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: InMemoryAuthTokenStore(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, '管理服务器'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '管理服务器'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('服务器操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑名称'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Main Campaign');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('Main Campaign'), findsOneWidget);
    expect(find.text('Local Table'), findsNothing);
  });

  testWidgets('deletes a saved server profile', (tester) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: InMemoryAuthTokenStore(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, '管理服务器'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '管理服务器'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('服务器操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();

    expect(find.text('Local Table'), findsNothing);
    expect(find.text('连接你的跑团服务器'), findsOneWidget);
  });

  testWidgets('opens a saved server profile on the campaigns tab', (
    tester,
  ) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);
    await store.setDefaultProfileId(profile.id);
    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: InMemoryAuthTokenStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsNothing);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.widgetWithText(NavigationDestination, '战役'), findsOneWidget);

    // Settings tab shows server info and mode.
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('Local Table'), findsOneWidget);
    expect(find.text('http://localhost:3000'), findsOneWidget);
    expect(find.text('玩家'), findsOneWidget);
    expect(find.text('未登录'), findsOneWidget);
  });

  testWidgets('switches to dm mode from settings tab', (tester) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);
    await store.setDefaultProfileId(profile.id);

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: InMemoryAuthTokenStore(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('使用模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('主持人'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.textContaining('主持人模式会显示'), findsOneWidget);
  });

  testWidgets('settings tab exposes local app preferences', (tester) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);
    await store.setDefaultProfileId(profile.id);

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: InMemoryAuthTokenStore(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    expect(find.text('外观'), findsOneWidget);
    expect(find.text('Material 3 主题色'), findsOneWidget);
    expect(find.text('高对比 Material 3'), findsOneWidget);
    expect(find.text('默认骰子'), findsOneWidget);
    expect(find.text('掷骰确认'), findsOneWidget);
    expect(find.text('合并连续消息头像'), findsOneWidget);
    expect(find.text('规则与角色创建'), findsOneWidget);
    expect(find.text('默认规则集'), findsOneWidget);
    expect(find.text('默认创建方式'), findsOneWidget);
    expect(find.text('显示 Legacy 内容'), findsNothing);
    expect(find.text('角色卡'), findsOneWidget);
    expect(find.text('默认角色卡标签'), findsOneWidget);

    await tester.ensureVisible(find.text('默认角色卡标签'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('总览'));
    await tester.pumpAndSettle();

    expect(find.text('资源'), findsOneWidget);
    expect(find.text('角色资料'), findsOneWidget);
  });

  testWidgets(
    'settings tab keeps the Material contrast preference accessible',
    (tester) async {
      final store = InMemoryServerProfileStore();
      await store.saveProfile(profile);
      await store.setDefaultProfileId(profile.id);
      final preferencesController = AppPreferencesController(
        store: InMemoryAppPreferencesStore(),
      );
      await preferencesController.initialize();

      await tester.pumpWidget(
        DndTableApp(
          serverProfileStore: store,
          authTokenStore: InMemoryAuthTokenStore(),
          appPreferencesController: preferencesController,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('高对比 Material 3'));
      await tester.pumpAndSettle();
      expect(preferencesController.preferences.highContrastTheme, isFalse);

      await tester.tap(find.widgetWithText(SwitchListTile, '高对比 Material 3'));
      await tester.pumpAndSettle();

      expect(preferencesController.preferences.highContrastTheme, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      preferencesController.dispose();
    },
  );

  testWidgets('uses a navigation rail on wide screens', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);
    await store.setDefaultProfileId(profile.id);

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: InMemoryAuthTokenStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('folds table into campaign tools instead of a top-level tab', (
    tester,
  ) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);
    await store.setDefaultProfileId(profile.id);

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: InMemoryAuthTokenStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(NavigationDestination, '桌面'), findsNothing);
    expect(find.text('战役'), findsWidgets);
  });

  testWidgets('shows a characters tab in the main shell', (tester) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);
    await store.setDefaultProfileId(profile.id);

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: InMemoryAuthTokenStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('角色'), findsWidgets);

    await tester.tap(find.text('角色').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('还没有角色'), findsOneWidget);
  });

  testWidgets('characters tab expands a summary while card opens detail', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CharactersTabPage(
          controller: CharacterController(
            repository: MemoryCharacterRepository(initial: const [_character]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('character-card-char-1')), findsOneWidget);
    expect(find.text('Arannis'), findsOneWidget);
    expect(find.byTooltip('展开角色摘要'), findsOneWidget);
    expect(find.text('14'), findsNothing);

    await tester.tap(find.byKey(const Key('character-expand-char-1')));
    await tester.pumpAndSettle();

    expect(find.byTooltip('收起角色摘要'), findsOneWidget);
    expect(find.text('HP 24/24'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);

    await tester.tap(find.text('调整 HP'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('character-card-hp-amount')),
      '5',
    );
    await tester.tap(find.widgetWithText(FilledButton, '受到伤害'));
    await tester.pumpAndSettle();
    expect(find.text('HP 19/24'), findsOneWidget);

    await tester.tap(find.text('Arannis'));
    await tester.pumpAndSettle();

    expect(find.text('总览'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('characters tab opens the preferred creation flow', (
    tester,
  ) async {
    final preferencesController = AppPreferencesController(
      store: InMemoryAppPreferencesStore(),
    );
    await preferencesController.initialize();
    await preferencesController.setDefaultCreationMethod('standard');

    await tester.pumpWidget(
      MaterialApp(
        home: CharactersTabPage(
          controller: CharacterController(
            repository: MemoryCharacterRepository(),
          ),
          localContentRepository: MemoryContentRepository(
            initialEntries: const [_fighterEntry, _aasimarEntry, _acolyteEntry],
          ),
          appPreferencesController: preferencesController,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FloatingActionButton, '新角色'));
    await tester.pumpAndSettle();

    expect(find.text('标准创建角色'), findsOneWidget);
    expect(find.text('选择创建方式'), findsNothing);
    expect(find.text('战士 / Fighter'), findsOneWidget);
    await tester.tap(find.byKey(const Key('builder-mobile-step-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3. 物种').last);
    await tester.pumpAndSettle();
    expect(find.text('阿斯莫 / Aasimar'), findsOneWidget);
    await tester.tap(find.byKey(const Key('builder-mobile-step-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2. 背景').last);
    await tester.pumpAndSettle();
    expect(find.text('侍僧 / Acolyte'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    preferencesController.dispose();
  });

  testWidgets('campaigns tab uses compact list preference', (tester) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);
    await store.setDefaultProfileId(profile.id);
    final tokenStore = InMemoryAuthTokenStore();
    await tokenStore.saveTokens(
      profile.id,
      const StoredAuthTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    );
    final preferencesController = AppPreferencesController(
      store: InMemoryAppPreferencesStore(),
    );
    await preferencesController.initialize();
    await preferencesController.setCompactLists(true);

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: tokenStore,
        authClient: _FakeAuthClient(),
        campaignClient: _FakeCampaignClient(),
        appPreferencesController: preferencesController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, '战役'));
    await tester.pumpAndSettle();

    expect(find.text('Starter Campaign'), findsOneWidget);
    expect(find.text('主持人'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    preferencesController.dispose();
  });

  testWidgets('campaigns list shows character avatar and status summary', (
    tester,
  ) async {
    final tokenStore = InMemoryAuthTokenStore();
    await tokenStore.saveTokens(
      profile.id,
      const StoredAuthTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    );
    final authController = AuthController(
      tokenStore: tokenStore,
      authClient: _FakeAuthClient(),
      serverProfileId: profile.id,
      apiBaseUrl: profile.apiBaseUrl,
    );
    await authController.initialize();
    final campaignController = CampaignController(
      apiBaseUrl: profile.apiBaseUrl,
      authController: authController,
      campaignClient: _FakeCampaignClient(),
      campaignSocketService: NoopCampaignSocketService(),
    );
    await campaignController.loadCampaigns();
    final characterController = CharacterController(
      repository: MemoryCharacterRepository(initial: const [_character]),
    );
    final modeController = ClientModeController();
    final preferencesController = AppPreferencesController(
      store: InMemoryAppPreferencesStore(),
    );
    await preferencesController.initialize();
    final session = ActiveServerSession()..activate(profile);

    await tester.pumpWidget(
      MaterialApp(
        home: CampaignsTabPage(
          session: session,
          authController: authController,
          campaignController: campaignController,
          characterController: characterController,
          contentRepository: MemoryContentRepository(),
          modeController: modeController,
          appPreferencesController: preferencesController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircleAvatar), findsWidgets);
    expect(find.text('A'), findsOneWidget);
    // 战役名和角色首字母头像应可见。
    expect(find.text('Starter Campaign'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
    preferencesController.dispose();
    modeController.dispose();
    characterController.dispose();
    campaignController.dispose();
    authController.dispose();
  });

  testWidgets('only dm mode can open the three-step campaign creation guide', (
    tester,
  ) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);
    await store.setDefaultProfileId(profile.id);
    final tokenStore = InMemoryAuthTokenStore();
    await tokenStore.saveTokens(
      profile.id,
      const StoredAuthTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    );
    final modeController = ClientModeController();

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: tokenStore,
        authClient: _FakeAuthClient(),
        campaignClient: _FakeCampaignClient(),
        modeController: modeController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, '战役'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('使用邀请码加入战役'), findsOneWidget);
    expect(find.widgetWithText(FloatingActionButton, '加入战役'), findsNothing);
    expect(find.byKey(const Key('campaign-create-button')), findsNothing);

    await modeController.setMode(ClientMode.dungeonMaster);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('campaign-create-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('campaign-create-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('campaign-creation-guide')), findsOneWidget);
    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('下一步'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('campaign-create-button')), findsOneWidget);
    expect(find.widgetWithText(FloatingActionButton, '加入战役'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    modeController.dispose();
  });

  testWidgets('campaigns open a qq-style chat room with say and action input', (
    tester,
  ) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);
    await store.setDefaultProfileId(profile.id);
    final tokenStore = InMemoryAuthTokenStore();
    await tokenStore.saveTokens(
      profile.id,
      const StoredAuthTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    );

    final campaignClient = _FakeCampaignClient(
      initialMessages: const [
        CampaignChatMessage(
          id: 'msg-0',
          campaignId: 'camp-1',
          senderId: 'user-1',
          campaignActorId: 'actor-1',
          displayName: 'Arannis',
          avatarUrl: null,
          kind: 'say',
          content: '酒馆里已经坐满了冒险者',
          createdAt: '2026-07-09T00:00:00.000Z',
        ),
      ],
    );
    final database = await databaseWithCharacter(_character);
    await installLocalContent(database, const [_contentEntry]);
    final modeController = ClientModeController();
    await modeController.setMode(ClientMode.dungeonMaster);

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: tokenStore,
        authClient: _FakeAuthClient(),
        campaignClient: campaignClient,
        campaignSocketService: NoopCampaignSocketService(),
        diceRoller: DiceRoller(nextInt: (_) => 19),
        database: database,
        enableBackgroundSync: false,
        modeController: modeController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, '战役'));
    await tester.pumpAndSettle();

    // Group-chat-style list: last message summary + character status.
    expect(find.textContaining('Arannis: 酒馆里已经坐满了冒险者'), findsOneWidget);
    expect(find.text('主持人'), findsOneWidget);

    await tester.tap(find.text('Starter Campaign'));
    await tester.pumpAndSettle();

    expect(find.text('Starter Campaign'), findsOneWidget);
    expect(find.text('酒馆里已经坐满了冒险者'), findsOneWidget);
    // Identity now lives in the compact composer instead of a tall header.
    expect(find.byKey(const Key('campaign-chat-identity')), findsOneWidget);
    expect(find.byKey(const Key('chat-mode-say')), findsOneWidget);
    expect(find.byKey(const Key('chat-mode-action')), findsOneWidget);
    // Spec §输入栏: separate `+` button is removed; avatar opens merged panel.
    expect(find.byTooltip('更多跑团功能'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('campaign-chat-input')),
      '今晚从酒馆开始',
    );
    await tester.tap(find.byKey(const Key('campaign-chat-send')));
    await tester.pumpAndSettle();
    expect(find.text('今晚从酒馆开始'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chat-mode-action')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campaign-chat-input')),
      '推开吱呀作响的木门',
    );
    await tester.tap(find.byKey(const Key('campaign-chat-send')));
    await tester.pumpAndSettle();

    final actionText = tester.widget<Text>(find.text('推开吱呀作响的木门'));
    expect(actionText.style?.fontStyle, FontStyle.italic);
    expect(campaignClient.sentMessages.last.kind, 'action');
    expect(campaignClient.sentMessages.last.campaignActorId, isNull);

    await tester.tap(find.byKey(const Key('campaign-chat-identity')));
    await tester.pumpAndSettle();
    // Spec §输入栏 merged tool panel: 桌面工具 entry removed; labels follow spec.
    expect(find.text('代掷检定'), findsOneWidget);
    expect(find.text('掷骰'), findsOneWidget);
    expect(find.text('资料条目'), findsOneWidget);

    await tester.tap(find.text('掷骰'));
    await tester.pumpAndSettle();
    expect(find.text('快速掷骰'), findsOneWidget);
    await tester.tap(find.text('d20'));
    await tester.pumpAndSettle();
    expect(find.text('d20 = 20'), findsOneWidget);
    expect(campaignClient.sentMessages.last.kind, 'roll');
    expect(campaignClient.sentMessages.last.content, 'd20 = 20');

    await tester.tap(find.byKey(const Key('campaign-chat-identity')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tool-content-entries')));
    for (var i = 0; i < 10 && find.text('战役资料库').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('战役资料库'), findsOneWidget);
    expect(find.text('Fire Bolt'), findsOneWidget);
    expect(find.text('法术 · SRD'), findsOneWidget);
    await tester.ensureVisible(find.text('Fire Bolt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fire Bolt'));
    await tester.pumpAndSettle();
    expect(find.text('A mote of fire.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('content-detail-close')));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    modeController.dispose();
  });

  testWidgets(
    'campaign chat shows character identity bar with local character',
    (tester) async {
      final store = InMemoryServerProfileStore();
      await store.saveProfile(profile);
      await store.setDefaultProfileId(profile.id);
      final tokenStore = InMemoryAuthTokenStore();
      await tokenStore.saveTokens(
        profile.id,
        const StoredAuthTokens(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        ),
      );
      final conditionedCharacter = _character.copyWith(
        data: const {
          'runtime': {
            'conditions': ['中毒', '倒地'],
          },
        },
      );
      final database = await databaseWithCharacter(conditionedCharacter);

      await tester.pumpWidget(
        DndTableApp(
          serverProfileStore: store,
          authTokenStore: tokenStore,
          authClient: _FakeAuthClient(),
          campaignClient: _FakeCampaignClient(
            campaign: _playerCampaign,
            initialMessages: const [
              CampaignChatMessage(
                id: 'msg-conditions',
                campaignId: 'camp-1',
                senderId: 'user-1',
                campaignActorId: 'actor-1',
                displayName: 'Arannis',
                avatarUrl: null,
                kind: 'say',
                content: 'I need help.',
                createdAt: '2026-07-09T00:00:00.000Z',
              ),
            ],
          ),
          campaignSocketService: NoopCampaignSocketService(),
          database: database,
          enableBackgroundSync: false,
          bundledContentLoader: () async => '{}',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(NavigationDestination, '战役'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Starter Campaign'));
      await tester.pumpAndSettle();

      // The compact composer avatar opens the local character summary.
      await tester.tap(find.byKey(const Key('campaign-chat-identity')));
      await tester.pumpAndSettle();
      expect(find.text('Arannis'), findsWidgets);
      expect(find.text('HP 24/24 · AC 15'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('campaign chat exposes table tools instead of session tab', (
    tester,
  ) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);
    await store.setDefaultProfileId(profile.id);
    final tokenStore = InMemoryAuthTokenStore();
    await tokenStore.saveTokens(
      profile.id,
      const StoredAuthTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    );
    final preferencesController = AppPreferencesController(
      store: InMemoryAppPreferencesStore(),
    );
    await preferencesController.initialize();
    await preferencesController.setCompactLists(true);
    final modeController = ClientModeController();
    await modeController.setMode(ClientMode.dungeonMaster);

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: tokenStore,
        authClient: _FakeAuthClient(),
        campaignClient: _FakeCampaignClient(),
        campaignSocketService: NoopCampaignSocketService(),
        appPreferencesController: preferencesController,
        modeController: modeController,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(NavigationDestination, '桌面'), findsNothing);

    await tester.tap(find.widgetWithText(NavigationDestination, '战役'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Starter Campaign'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('campaign-chat-identity')));
    await tester.pumpAndSettle();

    // Spec §输入栏: 桌面工具 entry removed; merged panel exposes the
    // spec-defined 11 tools directly. Verify a few key tools are present.
    expect(find.text('掷骰'), findsOneWidget);
    expect(find.text('代掷检定'), findsOneWidget);
    expect(find.text('资料条目'), findsOneWidget);
    // 桌面工具 info-only sheet is gone.
    expect(find.text('桌面工具'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    preferencesController.dispose();
    modeController.dispose();
  });

  testWidgets('content library uses compact list preference', (tester) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);
    await store.setDefaultProfileId(profile.id);
    final tokenStore = InMemoryAuthTokenStore();
    await tokenStore.saveTokens(
      profile.id,
      const StoredAuthTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    );
    final preferencesController = AppPreferencesController(
      store: InMemoryAppPreferencesStore(),
    );
    await preferencesController.initialize();
    await preferencesController.setCompactLists(true);

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: tokenStore,
        authClient: _FakeAuthClient(),
        campaignClient: _FakeCampaignClient(),
        appPreferencesController: preferencesController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('资料库'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(find.text('资料库还是空的'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    preferencesController.dispose();
  });

  testWidgets('shows a content library tab in the main shell', (tester) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);
    await store.setDefaultProfileId(profile.id);

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: InMemoryAuthTokenStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('资料库'), findsOneWidget);

    await tester.tap(find.text('资料库'));
    await tester.pumpAndSettle();

    expect(find.text('资料库还是空的'), findsOneWidget);
  });

  testWidgets(
    'keeps the wide-screen wiki focused on search until a detail card opens',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = InMemoryServerProfileStore();
      await store.saveProfile(profile);
      await store.setDefaultProfileId(profile.id);
      final tokenStore = InMemoryAuthTokenStore();
      await tokenStore.saveTokens(
        profile.id,
        const StoredAuthTokens(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        ),
      );

      await tester.pumpWidget(
        DndTableApp(
          serverProfileStore: store,
          authTokenStore: tokenStore,
          authClient: _FakeAuthClient(),
          campaignClient: _FakeCampaignClient(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('资料库'));
      await tester.pumpAndSettle();

      expect(find.text('资料库还是空的'), findsOneWidget);
    },
  );

  testWidgets('character creation can use only selected campaign content', (
    tester,
  ) async {
    final preferencesController = AppPreferencesController(
      store: InMemoryAppPreferencesStore(),
    );
    await preferencesController.initialize();
    await preferencesController.setDefaultCreationMethod('standard');
    final authController = AuthController(
      tokenStore: InMemoryAuthTokenStore(),
      authClient: _FakeAuthClient(),
      serverProfileId: profile.id,
      apiBaseUrl: profile.apiBaseUrl,
    );
    final campaignController = _FixedCampaignController(authController);
    String? activeCampaignId;
    final contentRepository = CampaignAwareContentRepository(
      local: MemoryContentRepository(),
      campaign: MemoryCampaignCacheRepository(
        entries: [
          testContentEntry(
            id: _campaignFighterContent.id,
            campaignId: _campaign.id,
            type: _campaignFighterContent.type,
            slug: _campaignFighterContent.slug,
            name: _campaignFighterContent.name,
          ),
        ],
      ),
      activeCampaignId: () => activeCampaignId,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CharactersTabPage(
          controller: CharacterController(
            repository: MemoryCharacterRepository(),
          ),
          campaignController: campaignController,
          contentRepository: contentRepository,
          localContentRepository: MemoryContentRepository(
            initialEntries: const [_fighterEntry],
          ),
          onCampaignContentSelected: (campaignId) async {
            activeCampaignId = campaignId;
          },
          appPreferencesController: preferencesController,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FloatingActionButton, '新角色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();

    expect(find.text('战役战士 / Campaign Fighter'), findsOneWidget);
    expect(find.text('战士 / Fighter'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    preferencesController.dispose();
    campaignController.dispose();
    authController.dispose();
  });
  testWidgets('shows dm encounter control from campaign chat tools', (
    tester,
  ) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);
    await store.setDefaultProfileId(profile.id);
    final tokenStore = InMemoryAuthTokenStore();
    await tokenStore.saveTokens(
      profile.id,
      const StoredAuthTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    );
    final modeController = ClientModeController();
    await modeController.setMode(ClientMode.dungeonMaster);

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: tokenStore,
        authClient: _FakeAuthClient(),
        campaignClient: _FakeCampaignClient(),
        campaignSocketService: NoopCampaignSocketService(),
        modeController: modeController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, '战役'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Starter Campaign'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('campaign-open-center')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('campaign-overview-dm-control-entry')),
    );
    await tester.pumpAndSettle();

    expect(find.text('遭遇控场'), findsOneWidget);
    expect(find.text('成员状态'), findsOneWidget);
  });

  testWidgets('player campaign chat hides dm-only table tools', (tester) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);
    await store.setDefaultProfileId(profile.id);
    final tokenStore = InMemoryAuthTokenStore();
    await tokenStore.saveTokens(
      profile.id,
      const StoredAuthTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    );

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: tokenStore,
        authClient: _FakeAuthClient(),
        campaignClient: _FakeCampaignClient(campaign: _playerCampaign),
        campaignSocketService: NoopCampaignSocketService(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, '战役'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Starter Campaign'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('campaign-chat-identity')));
    await tester.pumpAndSettle();

    expect(find.text('DM 控场'), findsNothing);
    expect(find.text('代掷检定'), findsNothing);
  });

  testWidgets('offline settings exposes servers and sync status', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(
      DndTableApp(
        database: database,
        enableBackgroundSync: false,
        bundledContentLoader: () async => '{}',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();

    expect(find.text('服务器'), findsOneWidget);
    expect(find.text('尚未连接服务器'), findsOneWidget);
    expect(find.text('同步'), findsOneWidget);
    expect(find.text('仅保存在此设备'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('shows pending vault operations and syncs on command', (
    tester,
  ) async {
    final controller = MemoryVaultSyncActions(
      pendingCount: 3,
      devices: const [
        VaultDeviceView(
          deviceId: 'device-1',
          name: '此设备',
          platform: 'windows',
          lastCursor: '5',
          lastSeenAt: '2026-07-14T00:00:00.000Z',
        ),
        VaultDeviceView(
          deviceId: 'device-2',
          name: 'Laptop',
          platform: 'web',
          lastCursor: '3',
          lastSeenAt: '2026-07-14T00:00:00.000Z',
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VaultSettingsSection(actions: controller)),
      ),
    );
    expect(find.text('3 项等待同步'), findsOneWidget);
    expect(find.text('Laptop'), findsOneWidget);
    await tester.tap(find.text('立即同步'));
    await tester.pumpAndSettle();
    expect(controller.syncCalls, 1);
  });
}

class _ThrowingAppPreferencesStore implements AppPreferencesStore {
  @override
  Future<AppPreferences> load() async {
    throw StateError('corrupt local preview data');
  }

  @override
  Future<void> save(AppPreferences preferences) async {}
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
      username: 'dm',
      email: 'dm@example.com',
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

class _FixedCampaignController extends CampaignController {
  _FixedCampaignController(AuthController authController)
    : super(
        apiBaseUrl: '',
        authController: authController,
        campaignClient: _FakeCampaignClient(),
        campaignSocketService: NoopCampaignSocketService(),
      );

  @override
  List<Campaign> get campaigns => const [_campaign];
}

class _FakeCampaignClient implements CampaignClient {
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
  Future<List<CampaignArchiveEntry>> listArchives({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    String? kind,
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
  }) => throw UnimplementedError();
  @override
  Future<void> archiveEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String entryId,
  }) => throw UnimplementedError();
  _FakeCampaignClient({
    List<CampaignChatMessage> initialMessages = const [],
    Campaign? campaign,
  }) : _messages = [...initialMessages],
       _servedCampaign = campaign ?? _campaign;

  final List<CampaignChatMessage> _messages;
  final Campaign _servedCampaign;
  final List<_SentCampaignMessage> sentMessages = [];

  @override
  Future<CampaignWorkspaceContext> getWorkspaceContext({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async {
    final canManage = _servedCampaign.ownerId == 'user-1';
    return CampaignWorkspaceContext(
      campaign: _servedCampaign,
      membership: CampaignMembership(
        id: 'member-1',
        campaignId: campaignId,
        userId: 'user-1',
        role: canManage ? 'owner' : 'player',
        displayName: 'ranger',
        joinedAt: '2026-07-09T00:00:00.000Z',
      ),
      members: _servedCampaign.memberPreview,
      actors: const [],
      capabilities: CampaignCapabilities(
        canManageCampaign: canManage,
        canManageMembers: canManage,
        canCreateActors: canManage,
        canSpeakAsNarrator: canManage,
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
  }) async {
    return _servedCampaign;
  }

  @override
  Future<List<Campaign>> listCampaigns({
    required String apiBaseUrl,
    required String accessToken,
  }) async {
    if (_messages.isEmpty) {
      return [_servedCampaign];
    }
    // 模拟服务端 listCampaigns 返回最近一条消息。
    return [_servedCampaign.copyWith(lastMessage: _messages.last)];
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
  }) async => const [];

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
  }) async {
    return _messages
        .where((message) => message.campaignId == campaignId)
        .toList(growable: false);
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
    Map<String, Object?>? draftActor,
  }) async {
    sentMessages.add(
      _SentCampaignMessage(
        kind: kind,
        content: content,
        campaignActorId: campaignActorId,
      ),
    );
    final message = CampaignChatMessage(
      id: 'msg-${_messages.length + 1}',
      campaignId: campaignId,
      senderId: 'user-1',
      campaignActorId: campaignActorId,
      displayName: 'Arannis',
      avatarUrl: null,
      kind: kind,
      content: content,
      createdAt: '2026-07-09T00:00:00.000Z',
    );
    _messages.add(message);
    return message;
  }
}

class _SentCampaignMessage {
  const _SentCampaignMessage({
    required this.kind,
    required this.content,
    required this.campaignActorId,
  });

  final String kind;
  final String content;
  final String? campaignActorId;
}

const _campaign = Campaign(
  id: 'camp-1',
  name: 'Starter Campaign',
  description: '',
  system: 'dnd5e',
  ownerId: 'user-1',
  status: 'active',
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
);

const _playerCampaign = Campaign(
  id: 'camp-1',
  name: 'Starter Campaign',
  description: '',
  system: 'dnd5e',
  ownerId: 'user-2',
  status: 'active',
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
);

const _character = CharacterSheet(
  id: 'char-1',
  ownerUserId: 'user-1',
  name: 'Arannis',
  avatarUrl: null,
  system: 'dnd5e',
  level: 3,
  classSummary: 'Ranger',
  raceSummary: 'Elf',
  currentHp: 24,
  maxHp: 24,
  armorClass: 15,
  speed: 30,
  initiativeBonus: 2,
  abilities: {'str': 10, 'dex': 14, 'con': 12, 'int': 10, 'wis': 14, 'cha': 8},
  saves: {'dex': true, 'wis': true},
  skills: {'察觉': true, '隐匿': true},
  inventory: [
    {'name': '长弓', 'quantity': 1},
  ],
  currency: {'gp': 10},
  notes: '',
  data: {},
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
);

const _contentEntry = ContentEntry(
  id: 'widget-test:spell/fire-bolt',
  type: 'spell',
  slug: 'fire-bolt',
  name: 'Fire Bolt',
  summary: 'A mote of fire.',
  body: [ParagraphBlock(text: 'A mote of fire.')],
  revision: 1,
  structured: {'level': 0},
  tags: ['cantrip'],
  source: ContentSource(label: 'SRD'),
);

const _fighterEntry = ContentEntry(
  id: 'widget-test:class/fighter',
  type: 'class',
  slug: 'fighter',
  name: '战士 / Fighter',
  body: [],
  revision: 1,
);

const _aasimarEntry = ContentEntry(
  id: 'widget-test:species/aasimar',
  type: 'species',
  slug: 'aasimar',
  name: '阿斯莫 / Aasimar',
  body: [],
  revision: 1,
);

const _acolyteEntry = ContentEntry(
  id: 'widget-test:background/acolyte',
  type: 'background',
  slug: 'acolyte',
  name: '侍僧 / Acolyte',
  body: [],
  revision: 1,
);

const _campaignFighterContent = ContentEntry(
  id: 'campaign-class-fighter',
  type: 'class',
  slug: 'campaign-fighter',
  name: '战役战士 / Campaign Fighter',
  body: [],
  revision: 1,
  structured: {'page': 1},
  tags: ['class'],
  source: ContentSource(label: 'Campaign rules'),
);
