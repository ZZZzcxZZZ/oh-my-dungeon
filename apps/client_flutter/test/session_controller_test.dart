import 'package:dnd_table_client/src/features/auth/data/auth_api_client.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:dnd_table_client/src/features/auth/domain/auth_session.dart';
import 'package:dnd_table_client/src/features/auth/presentation/auth_controller.dart';
import 'package:dnd_table_client/src/features/sessions/data/session_api_client.dart';
import 'package:dnd_table_client/src/features/sessions/domain/session.dart';
import 'package:dnd_table_client/src/features/sessions/presentation/session_controller.dart';
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

  test('openSession loads the session, historical rolls, and journal', () async {
    final authController = await buildLoggedInAuthController();
    final sessionClient = _FakeSessionClient(
      session: _session,
      rolls: const [
        DiceRoll(
          id: 'roll-1',
          sessionId: 'sess-1',
          actorId: 'user-1',
          actorName: 'ranger',
          notation: '1d20',
          total: 17,
          components: [
            DiceRollComponent(notation: '1d20', results: [17]),
          ],
          visibility: 'public',
          createdAt: '2026-07-09T00:01:00.000Z',
        ),
      ],
      journal: const [
        JournalEntry(
          id: 'journal-1',
          sessionId: 'sess-1',
          type: 'roll',
          summary: 'ranger rolled 1d20 = 17',
          refId: 'roll-1',
          createdAt: '2026-07-09T00:01:00.000Z',
        ),
      ],
    );
    final controller = SessionController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      sessionClient: sessionClient,
    );

    await controller.openSession('sess-1');

    expect(controller.activeSession?.id, 'sess-1');
    expect(controller.messages, hasLength(1));
    expect(controller.rolls, hasLength(1));
    expect(controller.rolls.single.total, 17);
    expect(controller.journal, hasLength(1));
    expect(sessionClient.listRollCalls, ['sess-1']);
    expect(sessionClient.listJournalCalls, ['sess-1']);

    controller.dispose();
    authController.dispose();
  });
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
  recentMessages: [
    ChatMessage(
      id: 'msg-1',
      sessionId: 'sess-1',
      senderId: 'user-1',
      kind: 'text',
      visibility: 'public',
      content: 'hello',
      createdAt: '2026-07-09T00:00:30.000Z',
    ),
  ],
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
  _FakeSessionClient({
    required this.session,
    this.rolls = const [],
    this.journal = const [],
  });

  final Session session;
  final List<DiceRoll> rolls;
  final List<JournalEntry> journal;
  final List<String> listRollCalls = [];
  final List<String> listJournalCalls = [];

  @override
  Future<Session> getSession({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  }) async {
    return session;
  }

  @override
  Future<List<DiceRoll>> listRolls({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  }) async {
    listRollCalls.add(sessionId);
    return rolls;
  }

  @override
  Future<List<JournalEntry>> listJournal({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  }) async {
    listJournalCalls.add(sessionId);
    return journal;
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
  Future<ChatMessage> sendMessage({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
    required String content,
    String? kind,
    String? visibility,
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
  }) {
    throw UnimplementedError();
  }
}
