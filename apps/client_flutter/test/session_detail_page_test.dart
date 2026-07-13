import 'package:dnd_table_client/src/features/auth/data/auth_api_client.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:dnd_table_client/src/features/auth/domain/auth_session.dart';
import 'package:dnd_table_client/src/features/auth/presentation/auth_controller.dart';
import 'package:dnd_table_client/src/features/app_preferences/data/app_preferences_store.dart';
import 'package:dnd_table_client/src/features/app_preferences/presentation/app_preferences_controller.dart';
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/characters/presentation/character_controller.dart';
import 'package:dnd_table_client/src/features/check_requests/data/check_request_api_client.dart';
import 'package:dnd_table_client/src/features/check_requests/domain/check_request.dart';
import 'package:dnd_table_client/src/features/check_requests/presentation/check_request_controller.dart';
import 'package:dnd_table_client/src/features/rooms/domain/dice_roller.dart'
    hide DiceRoll;
import 'package:dnd_table_client/src/features/server_profiles/domain/server_profile.dart';
import 'package:dnd_table_client/src/features/sessions/data/session_api_client.dart';
import 'package:dnd_table_client/src/features/sessions/domain/session.dart';
import 'package:dnd_table_client/src/features/sessions/presentation/session_controller.dart';
import 'package:dnd_table_client/src/features/sessions/presentation/session_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/character_test_support.dart';

void main() {
  const apiBaseUrl = 'http://localhost:3000/api';
  const profile = ServerProfile(
    id: 'localhost',
    name: 'Local Table',
    baseUrl: 'http://localhost:3000',
    apiBaseUrl: apiBaseUrl,
    websocketUrl: 'ws://localhost:3000/realtime',
    lastKnownVersion: '0.1.0',
  );

  testWidgets('session detail sends character sheet rolls to the timeline', (
    tester,
  ) async {
    final authController = await _buildLoggedInAuthController();
    final sessionClient = _FakeSessionClient();
    final sessionController = SessionController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      sessionClient: sessionClient,
    );
    await sessionController.openSession('sess-1');

    final characterController = CharacterController(
      repository: MemoryCharacterRepository(initial: [_character]),
    );

    final checkRequestController = CheckRequestController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      checkRequestClient: _FakeCheckRequestClient(),
    );
    final appPreferencesController = AppPreferencesController(
      store: InMemoryAppPreferencesStore(),
    );
    await appPreferencesController.initialize();
    await appPreferencesController.setDefaultDice('2d6+1');

    await tester.pumpWidget(
      MaterialApp(
        home: SessionDetailPage(
          profile: profile,
          authController: authController,
          sessionController: sessionController,
          checkRequestController: checkRequestController,
          characterController: characterController,
          appPreferencesController: appPreferencesController,
          diceRoller: DiceRoller(nextInt: (max) => max - 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('角色卡'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arannis'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('动作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('察觉 +4'));
    await tester.pumpAndSettle();

    expect(sessionClient.sentMessages.single.content, '察觉：d20+4 = 24');
    expect(sessionClient.sentMessages.single.kind, 'roll');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('角色卡掷骰'), findsOneWidget);
    expect(find.text('察觉：d20+4 = 24'), findsAtLeastNWidgets(1));

    await tester.tap(find.widgetWithIcon(IconButton, Icons.casino_outlined));
    await tester.pumpAndSettle();

    expect(find.text('2d6+1'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));

    appPreferencesController.dispose();
    checkRequestController.dispose();
    characterController.dispose();
    sessionController.dispose();
    authController.dispose();
  });

  testWidgets(
    'session roll sheet confirms default dice when preference is on',
    (tester) async {
      final authController = await _buildLoggedInAuthController();
      final sessionClient = _FakeSessionClient();
      final sessionController = SessionController(
        apiBaseUrl: apiBaseUrl,
        authController: authController,
        sessionClient: sessionClient,
      );
      await sessionController.openSession('sess-1');

      final characterController = CharacterController(
      repository: MemoryCharacterRepository(initial: [_character]),
    );

    final checkRequestController = CheckRequestController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      checkRequestClient: _FakeCheckRequestClient(),
    );
    final appPreferencesController = AppPreferencesController(
      store: InMemoryAppPreferencesStore(),
    );
    await appPreferencesController.initialize();
    await appPreferencesController.setDefaultDice('2d6+1');
    await appPreferencesController.setConfirmBeforeRoll(true);

      await tester.pumpWidget(
        MaterialApp(
          home: SessionDetailPage(
            profile: profile,
            authController: authController,
            sessionController: sessionController,
            checkRequestController: checkRequestController,
            characterController: characterController,
            appPreferencesController: appPreferencesController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithIcon(IconButton, Icons.casino_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '掷'));
      await tester.pumpAndSettle();

      expect(find.text('确认掷骰'), findsOneWidget);
      expect(sessionClient.createdRolls, isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, '确认'));
      await tester.pumpAndSettle();

      expect(sessionClient.createdRolls.single.notation, '2d6+1');

      await tester.pumpWidget(const SizedBox.shrink());

      appPreferencesController.dispose();
      checkRequestController.dispose();
      characterController.dispose();
      sessionController.dispose();
      authController.dispose();
    },
  );

  testWidgets(
    'session character sheet logs runtime hp changes when preference is on',
    (tester) async {
      final authController = await _buildLoggedInAuthController();
      final sessionClient = _FakeSessionClient();
      final sessionController = SessionController(
        apiBaseUrl: apiBaseUrl,
        authController: authController,
        sessionClient: sessionClient,
      );
      await sessionController.openSession('sess-1');

      final characterRepository = MemoryCharacterRepository(initial: [_character]);
      final characterController = CharacterController(
        repository: characterRepository,
      );

      final checkRequestController = CheckRequestController(
        apiBaseUrl: apiBaseUrl,
        authController: authController,
        checkRequestClient: _FakeCheckRequestClient(),
      );
      final appPreferencesController = AppPreferencesController(
        store: InMemoryAppPreferencesStore(),
      );
      await appPreferencesController.initialize();
      await appPreferencesController.setDefaultCharacterTab('status');

      await tester.pumpWidget(
        MaterialApp(
          home: SessionDetailPage(
            profile: profile,
            authController: authController,
            sessionController: sessionController,
            checkRequestController: checkRequestController,
            characterController: characterController,
            appPreferencesController: appPreferencesController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('角色卡'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arannis'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('受到 1 点伤害'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('受到 1 点伤害'));
      await tester.pumpAndSettle();

      expect((await characterRepository.getById('char-1'))?.currentHp, 23);
      expect(sessionClient.sentMessages.single.kind, 'character_runtime');
      expect(
        sessionClient.sentMessages.single.content,
        'Arannis 当前 HP 24/24 -> 23/24',
      );

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('角色状态'), findsOneWidget);
      expect(find.text('角色卡掷骰'), findsNothing);
      expect(find.text('Arannis 当前 HP 24/24 -> 23/24'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());

      appPreferencesController.dispose();
      checkRequestController.dispose();
      characterController.dispose();
      sessionController.dispose();
      authController.dispose();
    },
  );

  testWidgets(
    'session character sheet skips runtime logs when preference is off',
    (tester) async {
      final authController = await _buildLoggedInAuthController();
      final sessionClient = _FakeSessionClient();
      final sessionController = SessionController(
        apiBaseUrl: apiBaseUrl,
        authController: authController,
        sessionClient: sessionClient,
      );
      await sessionController.openSession('sess-1');

      final characterRepository = MemoryCharacterRepository(initial: [_character]);
      final characterController = CharacterController(
        repository: characterRepository,
      );

      final checkRequestController = CheckRequestController(
        apiBaseUrl: apiBaseUrl,
        authController: authController,
        checkRequestClient: _FakeCheckRequestClient(),
      );
      final appPreferencesController = AppPreferencesController(
        store: InMemoryAppPreferencesStore(),
      );
      await appPreferencesController.initialize();
      await appPreferencesController.setDefaultCharacterTab('status');
      await appPreferencesController.setLogCharacterRuntimeChanges(false);

      await tester.pumpWidget(
        MaterialApp(
          home: SessionDetailPage(
            profile: profile,
            authController: authController,
            sessionController: sessionController,
            checkRequestController: checkRequestController,
            characterController: characterController,
            appPreferencesController: appPreferencesController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('角色卡'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arannis'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('受到 1 点伤害'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('受到 1 点伤害'));
      await tester.pumpAndSettle();

      expect((await characterRepository.getById('char-1'))?.currentHp, 23);
      expect(sessionClient.sentMessages, isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());

      appPreferencesController.dispose();
      checkRequestController.dispose();
      characterController.dispose();
      sessionController.dispose();
      authController.dispose();
    },
  );
}

Future<AuthController> _buildLoggedInAuthController() async {
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
    apiBaseUrl: 'http://localhost:3000/api',
  );
  await controller.initialize();
  return controller;
}

const _session = Session(
  id: 'sess-1',
  campaignId: 'camp-1',
  name: 'Session 1',
  status: 'active',
  startedAt: '2026-07-09T00:00:00.000Z',
  endedAt: null,
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
  members: [
    SessionMember(
      id: 'member-1',
      sessionId: 'sess-1',
      userId: 'user-1',
      role: 'owner',
      joinedAt: '2026-07-09T00:00:00.000Z',
      leftAt: null,
    ),
  ],
  recentMessages: [],
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

class _FakeSessionClient implements SessionClient {
  final sentMessages =
      <
        ({String sessionId, String content, String? kind, String? visibility})
      >[];
  final createdRolls =
      <
        ({
          String sessionId,
          String notation,
          String actorName,
          String? visibility,
        })
      >[];

  @override
  Future<Session> getSession({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  }) async {
    return _session;
  }

  @override
  Future<List<DiceRoll>> listRolls({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  }) async {
    return const [];
  }

  @override
  Future<List<JournalEntry>> listJournal({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  }) async {
    return const [];
  }

  @override
  Future<ChatMessage> sendMessage({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
    required String content,
    String? kind,
    String? visibility,
  }) async {
    sentMessages.add((
      sessionId: sessionId,
      content: content,
      kind: kind,
      visibility: visibility,
    ));
    return ChatMessage(
      id: 'msg-${sentMessages.length}',
      sessionId: sessionId,
      senderId: 'user-1',
      kind: kind ?? 'text',
      visibility: visibility ?? 'public',
      content: content,
      createdAt: '2026-07-09T00:00:30.000Z',
    );
  }

  @override
  Future<Session> createSession({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String name,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<Session>> listSessions({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Session> startSession({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Session> endSession({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<ChatMessage>> listMessages({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<DiceRoll> createRoll({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
    required String notation,
    required String actorName,
    String? visibility,
  }) async {
    createdRolls.add((
      sessionId: sessionId,
      notation: notation,
      actorName: actorName,
      visibility: visibility,
    ));
    return DiceRoll(
      id: 'roll-${createdRolls.length}',
      sessionId: sessionId,
      actorId: 'user-1',
      actorName: actorName,
      notation: notation,
      total: 8,
      components: const [],
      visibility: visibility ?? 'public',
      createdAt: '2026-07-09T00:00:40.000Z',
    );
  }
}

class _FakeCheckRequestClient implements CheckRequestClient {
  @override
  Future<List<CheckRequest>> listCheckRequests({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  }) async {
    return const [];
  }

  @override
  Future<CheckRequest> createCheckRequest({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
    required String label,
    String? checkType,
    String? ability,
    String? skill,
    int? dc,
    String? dcVisibility,
    String? targetMode,
    List<String>? targetUserIds,
    List<String>? targetCharacterIds,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CheckResponse> respondToCheckRequest({
    required String apiBaseUrl,
    required String accessToken,
    required String requestId,
    required String actorName,
    int? modifier,
    String? characterId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CheckRequest> closeCheckRequest({
    required String apiBaseUrl,
    required String accessToken,
    required String requestId,
  }) {
    throw UnimplementedError();
  }
}
