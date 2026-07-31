import 'package:dnd_table_client/src/features/auth/data/auth_api_client.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:dnd_table_client/src/features/auth/domain/auth_session.dart';
import 'package:dnd_table_client/src/features/auth/presentation/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'transient refresh failure preserves the offline account session',
    () async {
      final store = InMemoryAuthTokenStore();
      await store.saveTokens(
        'server-1',
        const StoredAuthTokens(
          accessToken: 'eyJhbGciOiJub25lIn0.eyJleHAiOjF9.',
          refreshToken: 'refresh-token',
        ),
      );
      final controller = AuthController(
        tokenStore: store,
        authClient: _OfflineRefreshAuthClient(),
        serverProfileId: 'server-1',
        apiBaseUrl: 'https://table.example/api',
      );
      await controller.initialize();
      expect(controller.isLoggedIn, isTrue);

      expect(await controller.ensureValidAccessToken(), isNull);

      expect(controller.isLoggedIn, isTrue);
      expect(controller.user?.id, 'user-1');
      expect(await store.getTokens('server-1'), isNotNull);
      controller.dispose();
    },
  );

  test('restores cached account identity when startup is offline', () async {
    final store = InMemoryAuthTokenStore();
    await store.saveTokens(
      'server-1',
      const StoredAuthTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        user: AuthUser(
          id: 'user-1',
          username: 'aria',
          email: 'aria@example.com',
        ),
      ),
    );
    final controller = AuthController(
      tokenStore: store,
      authClient: _OfflineStartupAuthClient(),
      serverProfileId: 'server-1',
      apiBaseUrl: 'https://table.example/api',
    );

    await controller.initialize();

    expect(controller.isLoggedIn, isTrue);
    expect(controller.user?.id, 'user-1');
    controller.dispose();
  });
}

class _OfflineRefreshAuthClient implements AuthClient {
  @override
  Future<AuthUser> me({
    required String apiBaseUrl,
    required String accessToken,
  }) async {
    return const AuthUser(
      id: 'user-1',
      username: 'aria',
      email: 'aria@example.com',
    );
  }

  @override
  Future<String> refresh({
    required String apiBaseUrl,
    required String refreshToken,
  }) {
    throw StateError('network unavailable');
  }

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
  Future<RegisterResult> register({
    required String apiBaseUrl,
    required String username,
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }
}

class _OfflineStartupAuthClient extends _OfflineRefreshAuthClient {
  @override
  Future<AuthUser> me({
    required String apiBaseUrl,
    required String accessToken,
  }) {
    throw StateError('network unavailable');
  }
}
