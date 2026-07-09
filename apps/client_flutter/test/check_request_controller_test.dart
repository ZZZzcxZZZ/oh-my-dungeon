import 'package:dnd_table_client/src/features/auth/data/auth_api_client.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:dnd_table_client/src/features/auth/domain/auth_session.dart';
import 'package:dnd_table_client/src/features/auth/presentation/auth_controller.dart';
import 'package:dnd_table_client/src/features/check_requests/data/check_request_api_client.dart';
import 'package:dnd_table_client/src/features/check_requests/domain/check_request.dart';
import 'package:dnd_table_client/src/features/check_requests/presentation/check_request_controller.dart';
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

  test('loads and creates check requests', () async {
    final authController = await buildLoggedInAuthController();
    final client = _FakeCheckRequestClient();
    final controller = CheckRequestController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      checkRequestClient: client,
    );

    await controller.loadCheckRequests('sess-1');
    expect(controller.requests, [_request]);

    final ok = await controller.createCheckRequest(
      sessionId: 'sess-1',
      label: 'Perception',
      dc: 15,
    );
    expect(ok, isTrue);
    expect(controller.requests, hasLength(2));

    controller.dispose();
    authController.dispose();
  });

  test('responds to and closes a check request', () async {
    final authController = await buildLoggedInAuthController();
    final client = _FakeCheckRequestClient();
    final controller = CheckRequestController(
      apiBaseUrl: apiBaseUrl,
      authController: authController,
      checkRequestClient: client,
    );
    await controller.loadCheckRequests('sess-1');

    final responded = await controller.respondToCheckRequest(
      requestId: 'check-1',
      actorName: 'Ireena',
      modifier: 2,
    );
    expect(responded, isTrue);
    expect(controller.requests.single.responses, [_response]);

    final closed = await controller.closeCheckRequest('check-1');
    expect(closed, isTrue);
    expect(controller.requests.single.status, 'closed');

    controller.dispose();
    authController.dispose();
  });
}

const _response = CheckResponse(
  id: 'response-1',
  requestId: 'check-1',
  responderId: 'user-1',
  characterId: null,
  notation: '1d20+2',
  total: 17,
  components: [
    CheckRollComponent(notation: '1d20', results: [15]),
  ],
  result: 'success',
  createdAt: '2026-07-09T00:00:00.000Z',
);

const _request = CheckRequest(
  id: 'check-1',
  sessionId: 'sess-1',
  requestedBy: 'user-1',
  label: 'Perception',
  checkType: 'skill',
  ability: null,
  skill: 'perception',
  dc: 15,
  dcVisibility: 'public',
  targetMode: 'all',
  targetUserIds: [],
  targetCharacterIds: [],
  status: 'open',
  createdAt: '2026-07-09T00:00:00.000Z',
  updatedAt: '2026-07-09T00:00:00.000Z',
  responses: [],
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

class _FakeCheckRequestClient implements CheckRequestClient {
  List<CheckRequest> requests = const [_request];

  @override
  Future<List<CheckRequest>> listCheckRequests({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  }) async {
    return requests;
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
  }) async {
    final created = _request.copyWith(id: 'check-2', label: label);
    requests = [...requests, created];
    return created;
  }

  @override
  Future<CheckResponse> respondToCheckRequest({
    required String apiBaseUrl,
    required String accessToken,
    required String requestId,
    required String actorName,
    int? modifier,
    String? characterId,
  }) async {
    return _response;
  }

  @override
  Future<CheckRequest> closeCheckRequest({
    required String apiBaseUrl,
    required String accessToken,
    required String requestId,
  }) async {
    return _request.copyWith(status: 'closed', responses: [_response]);
  }
}
