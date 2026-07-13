import 'package:dnd_table_client/src/app/dnd_table_app.dart';
import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_api_client.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:dnd_table_client/src/features/auth/domain/auth_session.dart';
import 'package:dnd_table_client/src/features/campaigns/data/campaign_api_client.dart';
import 'package:dnd_table_client/src/features/campaigns/data/campaign_socket_service.dart';
import 'package:dnd_table_client/src/features/campaigns/domain/campaign.dart';
import 'package:dnd_table_client/src/features/app_preferences/data/app_preferences_store.dart';
import 'package:dnd_table_client/src/features/app_preferences/domain/app_preferences.dart';
import 'package:dnd_table_client/src/features/app_preferences/presentation/app_preferences_controller.dart';
import 'package:dnd_table_client/src/features/characters/data/character_api_client.dart';
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/client_mode/domain/client_mode.dart';
import 'package:dnd_table_client/src/features/content/data/content_api_client.dart';
import 'package:dnd_table_client/src/features/content/domain/content.dart';
import 'package:dnd_table_client/src/features/encounters/data/encounter_api_client.dart';
import 'package:dnd_table_client/src/features/encounters/domain/encounter.dart';
import 'package:dnd_table_client/src/features/rooms/data/room_api_client.dart';
import 'package:dnd_table_client/src/features/rooms/domain/dice_roller.dart'
    show DiceRoller;
import 'package:dnd_table_client/src/features/rooms/domain/room.dart';
import 'package:dnd_table_client/src/features/rooms/domain/room_roll.dart';
import 'package:dnd_table_client/src/features/server_profiles/data/server_profile_store.dart';
import 'package:dnd_table_client/src/features/server_profiles/domain/server_profile.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const profile = ServerProfile(
    id: 'localhost',
    name: 'Local Table',
    baseUrl: 'http://localhost:3000',
    apiBaseUrl: 'http://localhost:3000/api',
    websocketUrl: 'ws://localhost:3000/ws',
    lastKnownVersion: '0.1.0',
  );

  testWidgets('shows the server profile empty state', (tester) async {
    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: InMemoryServerProfileStore(),
        authTokenStore: InMemoryAuthTokenStore(),
      ),
    );
    await tester.pumpAndSettle();

    // 离线优先：未配置服务器时直接进入 MainShell（本地模式）。
    expect(find.text('首页'), findsWidgets);
    expect(find.text('战役'), findsWidgets);
    expect(find.text('角色'), findsWidgets);
    expect(find.text('资料库'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
    expect(find.text('连接你的跑团服务器'), findsNothing);
    expect(find.text('本地模式'), findsOneWidget);
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

    // 有默认 profile 时直接进入主界面（底部导航）。
    expect(find.text('首页'), findsWidgets);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    expect(find.text('客户端模式'), findsOneWidget);
    expect(find.text('Player'), findsOneWidget);
    expect(find.text('DM'), findsOneWidget);

    await tester.ensureVisible(find.text('客户端模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DM'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('当前模式：DM'), findsOneWidget);
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

  testWidgets('opens a saved server profile and shows dashboard tab', (
    tester,
  ) async {
    final store = InMemoryServerProfileStore();
    await store.saveProfile(profile);
    await store.setDefaultProfileId(profile.id);
    final roomClient = _FakeRoomClient(
      initialRooms: const [Room(id: 'room-1', name: 'Friday One Shot')],
    );

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: InMemoryAuthTokenStore(),
        roomClient: roomClient,
      ),
    );
    await tester.pumpAndSettle();

    // Default tab is 首页, giving the app a product-level entry point.
    expect(find.text('首页'), findsWidgets);
    expect(find.text('跑团总览'), findsOneWidget);
    expect(find.text('登录后同步战役、角色和跑团状态'), findsOneWidget);

    // Settings tab shows server info and mode.
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('Local Table'), findsOneWidget);
    expect(find.text('http://localhost:3000'), findsOneWidget);
    expect(find.text('当前模式：Player'), findsOneWidget);
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
    await tester.ensureVisible(find.text('客户端模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DM'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('当前模式：DM'), findsOneWidget);
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
    expect(find.text('主题风格'), findsOneWidget);
    expect(find.text('高对比 Material 3'), findsOneWidget);
    expect(find.text('默认骰子'), findsOneWidget);
    expect(find.text('列表密度'), findsOneWidget);
    expect(find.text('掷骰确认'), findsOneWidget);
    expect(find.text('规则与角色创建'), findsOneWidget);
    expect(find.text('默认规则集'), findsOneWidget);
    expect(find.text('默认创建方式'), findsOneWidget);
    expect(find.text('显示 Legacy 内容'), findsOneWidget);
    expect(find.text('角色卡'), findsOneWidget);
    expect(find.text('默认角色卡标签'), findsOneWidget);
    expect(find.text('显示字段来源'), findsOneWidget);
    expect(find.text('显示负重'), findsOneWidget);
    expect(find.text('角色状态写入日志'), findsOneWidget);

    await tester.ensureVisible(find.text('默认角色卡标签'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('总览'));
    await tester.pumpAndSettle();

    expect(find.text('状态'), findsOneWidget);
  });

  testWidgets('settings tab toggles character runtime log preference', (
    tester,
  ) async {
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

    await tester.ensureVisible(find.text('角色状态写入日志'));
    await tester.pumpAndSettle();
    expect(
      preferencesController.preferences.logCharacterRuntimeChanges,
      isTrue,
    );

    await tester.tap(find.widgetWithText(SwitchListTile, '角色状态写入日志'));
    await tester.pumpAndSettle();

    expect(
      preferencesController.preferences.logCharacterRuntimeChanges,
      isFalse,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    preferencesController.dispose();
  });

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

    expect(find.text('登录后管理角色'), findsOneWidget);
  });

  testWidgets('characters tab uses compact list preference', (tester) async {
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
        characterClient: _FakeCharacterClient(),
        contentClient: _FakeContentClient(
          items: const [_fighterContent, _aasimarContent, _acolyteContent],
        ),
        appPreferencesController: preferencesController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('角色').last);
    await tester.pumpAndSettle();

    expect(find.text('紧凑角色列表'), findsOneWidget);
    expect(find.text('Arannis'), findsOneWidget);
    expect(find.text('HP 24/24 · AC 15 · 先攻 +2'), findsOneWidget);

    preferencesController.dispose();
  });

  testWidgets('characters tab opens the preferred creation flow', (
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
    await preferencesController.setDefaultCreationMethod('standard');

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: tokenStore,
        authClient: _FakeAuthClient(),
        campaignClient: _FakeCampaignClient(),
        characterClient: _FakeCharacterClient(),
        contentClient: _FakeContentClient(
          items: const [_fighterContent, _aasimarContent, _acolyteContent],
        ),
        appPreferencesController: preferencesController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('角色').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FloatingActionButton, '新角色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('使用通用资料'));
    await tester.pumpAndSettle();

    expect(find.text('标准创建角色'), findsOneWidget);
    expect(find.text('选择创建方式'), findsNothing);
    expect(find.text('战士 / Fighter'), findsOneWidget);
    expect(find.text('阿斯莫 / Aasimar'), findsOneWidget);
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

    await tester.tap(find.text('战役'));
    await tester.pumpAndSettle();

    expect(find.text('Starter Campaign'), findsOneWidget);
    expect(find.text('主持人'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    preferencesController.dispose();
  });

  testWidgets('campaigns list shows character avatar and status summary', (
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

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: tokenStore,
        authClient: _FakeAuthClient(),
        campaignClient: _FakeCampaignClient(),
        characterClient: _FakeCharacterClient(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('战役'));
    await tester.pumpAndSettle();

    expect(find.byType(CircleAvatar), findsWidgets);
    expect(find.text('A'), findsOneWidget);
    // 战役名和角色首字母头像应可见。
    expect(find.text('Starter Campaign'), findsOneWidget);
  });

  testWidgets('campaign actions match player and dm modes', (tester) async {
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
        characterClient: _FakeCharacterClient(),
        modeController: modeController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('战役'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('使用邀请码加入战役'), findsOneWidget);
    expect(find.widgetWithText(FloatingActionButton, '加入战役'), findsNothing);
    expect(find.widgetWithText(FloatingActionButton, '创建战役'), findsNothing);

    await modeController.setMode(ClientMode.dungeonMaster);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FloatingActionButton, '创建战役'), findsOneWidget);
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
          characterId: 'char-1',
          displayName: 'Arannis',
          avatarUrl: null,
          kind: 'say',
          content: '酒馆里已经坐满了冒险者',
          createdAt: '2026-07-09T00:00:00.000Z',
        ),
      ],
    );

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: tokenStore,
        authClient: _FakeAuthClient(),
        campaignClient: campaignClient,
        campaignSocketService: NoopCampaignSocketService(),
        characterClient: _FakeCharacterClient(),
        contentClient: _FakeContentClient(),
        diceRoller: DiceRoller(nextInt: (_) => 19),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('战役'));
    await tester.pumpAndSettle();

    // Group-chat-style list: last message summary + character status.
    expect(find.textContaining('Arannis: 酒馆里已经坐满了冒险者'), findsOneWidget);
    expect(find.text('主持人'), findsOneWidget);

    await tester.tap(find.text('Starter Campaign'));
    await tester.pumpAndSettle();

    expect(find.text('Starter Campaign'), findsOneWidget);
    expect(find.text('酒馆里已经坐满了冒险者'), findsOneWidget);
    expect(find.text('Arannis · HP 24/24 · AC 15'), findsNWidgets(2));
    expect(find.text('说'), findsOneWidget);
    expect(find.text('做'), findsOneWidget);
    expect(find.byKey(const Key('campaign-say-tab')), findsOneWidget);
    expect(find.byKey(const Key('campaign-act-tab')), findsOneWidget);
    expect(find.byTooltip('更多跑团功能'), findsOneWidget);

    await tester.tap(find.byTooltip('成员'));
    await tester.pumpAndSettle();
    expect(find.text('战役成员'), findsOneWidget);
    expect(find.text('Arannis'), findsWidgets);
    expect(find.text('Ranger · Elf'), findsOneWidget);
    expect(find.text('HP 24/24 · AC 15'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('campaign-chat-input')),
      '今晚从酒馆开始',
    );
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();
    expect(find.text('今晚从酒馆开始'), findsOneWidget);
    expect(find.text('Arannis · HP 24/24 · AC 15'), findsWidgets);

    await tester.tap(find.text('做'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campaign-chat-input')),
      '推开吱呀作响的木门',
    );
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();

    final actionText = tester.widget<Text>(find.text('推开吱呀作响的木门'));
    expect(actionText.style?.fontStyle, FontStyle.italic);
    expect(campaignClient.sentMessages.last.kind, 'action');
    expect(campaignClient.sentMessages.last.characterId, 'char-1');
    expect(campaignClient.sentMessages.last.displayName, 'Arannis');

    await tester.tap(find.byTooltip('更多跑团功能'));
    await tester.pumpAndSettle();
    expect(find.text('桌面工具'), findsOneWidget);
    expect(find.text('DM 控场'), findsNothing);
    expect(find.text('检定请求'), findsOneWidget);
    expect(find.text('掷骰'), findsOneWidget);
    expect(find.text('角色卡'), findsOneWidget);
    expect(find.text('资料库'), findsOneWidget);

    await tester.tap(find.text('掷骰'));
    await tester.pumpAndSettle();
    expect(find.text('快速掷骰'), findsOneWidget);
    await tester.tap(find.text('d20'));
    await tester.pumpAndSettle();
    expect(find.text('d20 = 20'), findsOneWidget);
    expect(campaignClient.sentMessages.last.kind, 'roll');
    expect(campaignClient.sentMessages.last.content, 'd20 = 20');

    await tester.tap(find.byTooltip('更多跑团功能'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('资料库'));
    await tester.pumpAndSettle();
    expect(find.text('战役资料库'), findsOneWidget);
    expect(find.text('Fire Bolt'), findsOneWidget);
    expect(find.text('法术 · SRD'), findsOneWidget);
    await tester.tap(find.text('Fire Bolt'));
    await tester.pumpAndSettle();
    expect(find.text('A mote of fire.'), findsOneWidget);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.close).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多跑团功能'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('角色卡'));
    await tester.pumpAndSettle();
    expect(find.text('Elf / Ranger / Lv.3'), findsOneWidget);
    expect(find.text('属性'), findsWidgets);
  });

  testWidgets('campaign chat shows character conditions beside the name', (
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
    final conditionedCharacter = _character.copyWith(
      data: const {
        'runtime': {
          'conditions': ['中毒', '倒地'],
        },
      },
    );

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: tokenStore,
        authClient: _FakeAuthClient(),
        campaignClient: _FakeCampaignClient(
          initialMessages: const [
            CampaignChatMessage(
              id: 'msg-conditions',
              campaignId: 'camp-1',
              senderId: 'user-1',
              characterId: 'char-1',
              displayName: 'Arannis',
              avatarUrl: null,
              kind: 'say',
              content: 'I need help.',
              createdAt: '2026-07-09T00:00:00.000Z',
            ),
          ],
        ),
        campaignSocketService: NoopCampaignSocketService(),
        characterClient: _FakeCharacterClient(character: conditionedCharacter),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('战役'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Starter Campaign'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Arannis · HP 24/24 · AC 15 · 中毒, 倒地'),
      findsOneWidget,
    );
  });

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

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: tokenStore,
        authClient: _FakeAuthClient(),
        campaignClient: _FakeCampaignClient(),
        campaignSocketService: NoopCampaignSocketService(),
        characterClient: _FakeCharacterClient(),
        contentClient: _FakeContentClient(),
        appPreferencesController: preferencesController,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(NavigationDestination, '桌面'), findsNothing);

    await tester.tap(find.text('战役'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Starter Campaign'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多跑团功能'));
    await tester.pumpAndSettle();

    expect(find.text('桌面工具'), findsOneWidget);
    expect(find.text('检定、日志和战役现场工具'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    preferencesController.dispose();
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
        contentClient: _FakeContentClient(),
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

  testWidgets('uses a side-by-side wiki detail pane on wide screens', (
    tester,
  ) async {
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
        characterClient: _FakeCharacterClient(),
        contentClient: _FakeContentClient(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('资料库'));
    await tester.pumpAndSettle();

    expect(find.text('选择一个条目'), findsOneWidget);
    expect(find.text('资料库还是空的'), findsOneWidget);
  });

  testWidgets('character creation can use only selected campaign content', (
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
    await preferencesController.setDefaultCreationMethod('standard');

    await tester.pumpWidget(
      DndTableApp(
        serverProfileStore: store,
        authTokenStore: tokenStore,
        authClient: _FakeAuthClient(),
        campaignClient: _FakeCampaignClient(),
        characterClient: _FakeCharacterClient(),
        contentClient: _FakeContentClient(
          items: const [_fighterContent, _aasimarContent, _acolyteContent],
          availableItems: const [_campaignFighterContent],
        ),
        appPreferencesController: preferencesController,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('角色').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FloatingActionButton, '新角色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();

    expect(find.text('战役战士 / Campaign Fighter'), findsOneWidget);
    expect(find.text('战士 / Fighter'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    preferencesController.dispose();
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
        characterClient: _FakeCharacterClient(),
        contentClient: _FakeContentClient(),
        encounterClient: _FakeEncounterClient(),
        modeController: modeController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('战役'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Starter Campaign'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多跑团功能'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DM 控场'));
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
        campaignClient: _FakeCampaignClient(),
        campaignSocketService: NoopCampaignSocketService(),
        characterClient: _FakeCharacterClient(),
        contentClient: _FakeContentClient(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('战役'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Starter Campaign'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多跑团功能'));
    await tester.pumpAndSettle();

    expect(find.text('DM 控场'), findsNothing);
    expect(find.text('检定请求'), findsOneWidget);
  });

  testWidgets('offline settings exposes servers and sync status', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(DndTableApp(database: database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();

    expect(find.text('服务器'), findsOneWidget);
    expect(find.text('尚未连接服务器'), findsOneWidget);
    expect(find.text('同步'), findsOneWidget);
    expect(find.text('仅保存在此设备'), findsOneWidget);
    await database.close();
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

class _FakeRoomClient implements RoomClient {
  _FakeRoomClient({List<Room> initialRooms = const []})
    : _rooms = [...initialRooms];

  final List<Room> _rooms;
  final List<RoomRoll> _rolls = [];
  final List<String> createdRoomNames = [];

  @override
  Future<List<Room>> listRooms({required String apiBaseUrl}) async {
    return List.unmodifiable(_rooms);
  }

  @override
  Future<Room> createRoom({
    required String apiBaseUrl,
    required String name,
  }) async {
    createdRoomNames.add(name);
    final room = Room(id: 'room-${createdRoomNames.length}', name: name);
    _rooms.add(room);
    return room;
  }

  @override
  Future<List<RoomRoll>> listRolls({
    required String apiBaseUrl,
    required String roomId,
  }) async {
    return _rolls
        .where((roll) => roll.roomId == roomId)
        .toList(growable: false);
  }

  @override
  Future<RoomRoll> createRoll({
    required String apiBaseUrl,
    required String roomId,
    required String notation,
    required int total,
    required String actorName,
    required ClientMode actorMode,
  }) async {
    final roll = RoomRoll(
      id: 'roll-${_rolls.length + 1}',
      roomId: roomId,
      notation: notation,
      total: total,
      actorName: actorName,
      actorMode: switch (actorMode) {
        ClientMode.player => 'player',
        ClientMode.dungeonMaster => 'dm',
      },
      createdAt: '2026-07-09T00:00:00.000Z',
    );
    _rolls.add(roll);
    return roll;
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

class _FakeCampaignClient implements CampaignClient {
  _FakeCampaignClient({List<CampaignChatMessage> initialMessages = const []})
    : _messages = [...initialMessages];

  final List<CampaignChatMessage> _messages;
  final List<_SentCampaignMessage> sentMessages = [];

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
    return _campaign;
  }

  @override
  Future<List<Campaign>> listCampaigns({
    required String apiBaseUrl,
    required String accessToken,
  }) async {
    if (_messages.isEmpty) {
      return const [_campaign];
    }
    // 模拟服务端 listCampaigns 返回最近一条消息。
    return [_campaign.copyWith(lastMessage: _messages.last)];
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
    String? characterId,
    String? displayName,
    String? avatarUrl,
  }) async {
    sentMessages.add(
      _SentCampaignMessage(
        kind: kind,
        content: content,
        characterId: characterId,
        displayName: displayName,
      ),
    );
    final message = CampaignChatMessage(
      id: 'msg-${_messages.length + 1}',
      campaignId: campaignId,
      senderId: 'user-1',
      characterId: characterId,
      displayName: displayName ?? 'dm',
      avatarUrl: avatarUrl,
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
    required this.characterId,
    required this.displayName,
  });

  final String kind;
  final String content;
  final String? characterId;
  final String? displayName;
}

class _FakeCharacterClient implements CharacterClient {
  _FakeCharacterClient({CharacterSheet character = _character})
    : _characterSheet = character;

  final CharacterSheet _characterSheet;

  @override
  Future<List<CharacterSheet>> listCharacters({
    required String apiBaseUrl,
    required String accessToken,
  }) async {
    return [_characterSheet];
  }

  @override
  Future<CharacterSheet> createCharacter({
    required String apiBaseUrl,
    required String accessToken,
    required String name,
    int? level,
    String? classSummary,
    String? raceSummary,
    int? currentHp,
    int? maxHp,
    int? armorClass,
    int? speed,
    int? initiativeBonus,
    Object? abilities,
    Object? saves,
    Object? skills,
    Object? inventory,
    Object? currency,
    String? notes,
    Object? data,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CharacterSheet> updateCharacter({
    required String apiBaseUrl,
    required String accessToken,
    required String characterId,
    String? campaignId,
    String? name,
    int? level,
    String? classSummary,
    String? raceSummary,
    int? currentHp,
    int? maxHp,
    int? armorClass,
    int? speed,
    int? initiativeBonus,
    Object? abilities,
    Object? saves,
    Object? skills,
    Object? inventory,
    Object? currency,
    String? notes,
    Object? data,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CharacterCampaignBinding> bindCharacterToCampaign({
    required String apiBaseUrl,
    required String accessToken,
    required String characterId,
    required String campaignId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<CharacterCampaignBinding>> listCampaignCharacters({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async {
    return [
      CharacterCampaignBinding(
        id: 'bind-1',
        campaignId: campaignId,
        characterId: _characterSheet.id,
        userId: 'user-1',
        visibility: 'party',
        status: 'active',
        dmNotes: '',
        joinedAt: '2026-07-09T00:00:00.000Z',
        updatedAt: '2026-07-09T00:00:00.000Z',
        character: _characterSheet,
      ),
    ];
  }

  @override
  Future<CharacterSheet> adjustCampaignCharacterHp({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
    int? delta,
    int? currentHp,
  }) {
    throw UnimplementedError();
  }
}

class _FakeContentClient implements ContentClient {
  @override
  Future<ContentItemDetail> getCampaignItem({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String itemId,
  }) async => ContentItemDetail(
    item: _contentItem,
    isFavorite: false,
    outgoingLinks: const [],
  );
  @override
  Future<ImportContentPackageResult> importCampaignPackage({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required Object package,
    bool dryRun = false,
  }) {
    importedCampaignIds.add(campaignId);
    return importPackage(
      apiBaseUrl: apiBaseUrl,
      accessToken: accessToken,
      package: package,
      dryRun: dryRun,
    );
  }

  @override
  Future<void> setCampaignItemFavorite({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String itemId,
    required bool favorite,
  }) async {}
  _FakeContentClient({
    this.items = const [_contentItem],
    this.availableItems = const [_contentItem],
  });

  final List<ContentItem> items;
  final List<ContentItem> availableItems;
  final List<String> importedCampaignIds = [];
  final List<Map<String, Object?>> importedPackages = [];
  final List<({bool dryRun, Map<String, Object?> package})> importCalls = [];

  @override
  Future<ImportContentPackageResult> importPackage({
    required String apiBaseUrl,
    required String accessToken,
    required Object package,
    bool dryRun = false,
  }) async {
    final packageMap = Map<String, Object?>.from(
      package as Map<dynamic, dynamic>,
    );
    importCalls.add((dryRun: dryRun, package: packageMap));
    if (!dryRun) {
      importedPackages.add(packageMap);
    }
    return ImportContentPackageResult(
      valid: true,
      errors: const [],
      package: ContentPackage(
        id: 'pkg-${importedPackages.length}',
        scope: 'user',
        ownerUserId: 'user-1',
        campaignId: null,
        name: packageMap['name']! as String,
        version: packageMap['version']! as String,
        schemaVersion: packageMap['schemaVersion']! as int,
        locale: packageMap['locale']! as String,
        status: 'active',
        createdBy: 'user-1',
        createdAt: '2026-07-09T00:00:00.000Z',
        updatedAt: '2026-07-09T00:00:00.000Z',
      ),
    );
  }

  @override
  Future<List<ContentPackage>> listPackages({
    required String apiBaseUrl,
    required String accessToken,
  }) async {
    return const [];
  }

  @override
  Future<Map<String, Object?>> exportPackage({
    required String apiBaseUrl,
    required String accessToken,
    required String packageId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<ContentItem>> listItems({
    required String apiBaseUrl,
    required String accessToken,
    String? type,
    String? query,
    String? packageId,
  }) async {
    return items
        .where((item) => type == null || item.type == type)
        .where(
          (item) =>
              query == null ||
              item.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList(growable: false);
  }

  @override
  Future<List<ContentItem>> listAvailableCampaignItems({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    String? type,
    String? query,
    bool favoriteOnly = false,
  }) async {
    return availableItems
        .where((item) => type == null || item.type == type)
        .where(
          (item) =>
              query == null ||
              item.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList(growable: false);
  }

  @override
  Future<void> setCampaignPackage({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String packageId,
    required bool enabled,
  }) async {}

  @override
  Future<void> disableCampaignItem({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String itemId,
    String? reason,
  }) {
    throw UnimplementedError();
  }
}

class _FakeEncounterClient implements EncounterClient {
  @override
  Future<List<Encounter>> listEncounters({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async {
    return const [_encounter];
  }

  @override
  Future<Encounter> getEncounter({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
  }) async {
    return _encounter;
  }

  @override
  Future<Npc> createNpc({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String name,
    Object? stats,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Encounter> createEncounter({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String name,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Encounter> startEncounter({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Encounter> advanceTurn({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Encounter> endEncounter({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<EncounterParticipant> updateParticipant({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
    required String participantId,
    int? hpCurrent,
    List<String>? conditions,
  }) {
    throw UnimplementedError();
  }
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

const _contentItem = ContentItem(
  id: 'item-1',
  packageId: 'pkg-1',
  type: 'spell',
  slug: 'fire-bolt',
  name: 'Fire Bolt',
  description: 'A mote of fire.',
  structured: {'level': 0},
  tags: ['cantrip'],
  sourceLabel: 'SRD',
  schemaVersion: 1,
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
);

const _fighterContent = ContentItem(
  id: 'content-class-fighter',
  packageId: 'pkg-phb',
  type: 'class',
  slug: 'class-fighter',
  name: '战士 / Fighter',
  description: '',
  structured: {'page': 60},
  tags: ['private-phb-2024-index', 'class'],
  sourceLabel: 'Private PHB 2024 PDF Index',
  schemaVersion: 1,
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
);

const _campaignFighterContent = ContentItem(
  id: 'campaign-class-fighter',
  packageId: 'campaign-package',
  type: 'class',
  slug: 'campaign-fighter',
  name: '战役战士 / Campaign Fighter',
  description: '',
  structured: {'page': 1},
  tags: ['class'],
  sourceLabel: 'Campaign rules',
  schemaVersion: 1,
  createdAt: '2026-07-13T00:00:00.000Z',
  updatedAt: '2026-07-13T00:00:00.000Z',
);

const _aasimarContent = ContentItem(
  id: 'content-species-aasimar',
  packageId: 'pkg-phb',
  type: 'species',
  slug: 'species-aasimar',
  name: '阿斯莫 / Aasimar',
  description: '',
  structured: {'page': 113},
  tags: ['private-phb-2024-index', 'species'],
  sourceLabel: 'Private PHB 2024 PDF Index',
  schemaVersion: 1,
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
);

const _acolyteContent = ContentItem(
  id: 'content-background-acolyte',
  packageId: 'pkg-phb',
  type: 'background',
  slug: 'background-acolyte',
  name: '侍僧 / Acolyte',
  description: '',
  structured: {'page': 111},
  tags: ['private-phb-2024-index', 'background'],
  sourceLabel: 'Private PHB 2024 PDF Index',
  schemaVersion: 1,
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
);

const _encounter = Encounter(
  id: 'enc-1',
  campaignId: 'camp-1',
  sessionId: null,
  name: 'Road Ambush',
  status: 'draft',
  round: 0,
  currentTurnParticipantId: null,
  createdBy: 'user-1',
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
  participants: [
    EncounterParticipant(
      id: 'part-1',
      encounterId: 'enc-1',
      participantType: 'npc',
      characterId: null,
      npcId: 'npc-1',
      displayName: 'Road Bandit',
      initiative: 12,
      hpCurrent: 7,
      hpMax: 7,
      armorClass: 13,
      conditions: [],
      isHiddenFromPlayers: false,
      sortOrder: 0,
      snapshot: {},
      createdAt: '2026-07-09T00:00:00.000Z',
      updatedAt: '2026-07-09T00:00:00.000Z',
    ),
  ],
);
