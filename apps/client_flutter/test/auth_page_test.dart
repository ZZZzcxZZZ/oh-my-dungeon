import 'package:dnd_table_client/src/features/auth/data/auth_api_client.dart';
import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:dnd_table_client/src/features/auth/domain/auth_session.dart';
import 'package:dnd_table_client/src/features/auth/presentation/auth_controller.dart';
import 'package:dnd_table_client/src/features/auth/presentation/auth_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _textFieldWithLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}

void main() {
  const apiBaseUrl = 'http://localhost:3000/api';

  AuthController buildController(_FakeAuthClient client) {
    return AuthController(
      tokenStore: InMemoryAuthTokenStore(),
      authClient: client,
      serverProfileId: 'localhost',
      apiBaseUrl: apiBaseUrl,
    );
  }

  testWidgets('shows login form when not logged in', (tester) async {
    final controller = buildController(_FakeAuthClient());
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(home: AuthPage(authController: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, '登录'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.widgetWithText(SwitchListTile, '自动登录'), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, '自动登录'))
          .value,
      isTrue,
    );
    expect(find.text('没有账号？注册'), findsOneWidget);
  });

  test(
    'initialize restores a saved session with the current access token',
    () async {
      final tokenStore = InMemoryAuthTokenStore();
      await tokenStore.saveTokens(
        'localhost',
        const StoredAuthTokens(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        ),
      );
      final client = _FakeAuthClient(validAccessToken: 'access-token');
      final controller = AuthController(
        tokenStore: tokenStore,
        authClient: client,
        serverProfileId: 'localhost',
        apiBaseUrl: apiBaseUrl,
      );

      await controller.initialize();

      expect(controller.isLoggedIn, isTrue);
      expect(client.meCalls, ['access-token']);
      expect(client.refreshCalls, isEmpty);
    },
  );

  test(
    'initialize refreshes an expired access token and restores the session',
    () async {
      final tokenStore = InMemoryAuthTokenStore();
      await tokenStore.saveTokens(
        'localhost',
        const StoredAuthTokens(
          accessToken: 'expired-access',
          refreshToken: 'refresh-token',
        ),
      );
      final client = _FakeAuthClient(
        validAccessToken: 'fresh-access',
        refreshedAccessToken: 'fresh-access',
      );
      final controller = AuthController(
        tokenStore: tokenStore,
        authClient: client,
        serverProfileId: 'localhost',
        apiBaseUrl: apiBaseUrl,
      );

      await controller.initialize();

      expect(controller.isLoggedIn, isTrue);
      expect(client.meCalls, ['expired-access', 'fresh-access']);
      expect(client.refreshCalls, ['refresh-token']);
      expect(
        await tokenStore.getTokens('localhost'),
        const StoredAuthTokens(
          accessToken: 'fresh-access',
          refreshToken: 'refresh-token',
        ),
      );
    },
  );

  test('initialize clears tokens when refresh is rejected', () async {
    final tokenStore = InMemoryAuthTokenStore();
    await tokenStore.saveTokens(
      'localhost',
      const StoredAuthTokens(
        accessToken: 'expired-access',
        refreshToken: 'invalid-refresh',
      ),
    );
    final client = _FakeAuthClient(
      refreshError: const AuthApiException('Unauthorized', statusCode: 401),
    );
    final controller = AuthController(
      tokenStore: tokenStore,
      authClient: client,
      serverProfileId: 'localhost',
      apiBaseUrl: apiBaseUrl,
    );

    await controller.initialize();

    expect(controller.isLoggedIn, isFalse);
    expect(await tokenStore.getTokens('localhost'), isNull);
  });

  test(
    'disabling auto-login clears saved tokens but keeps the current session',
    () async {
      final client = _FakeAuthClient();
      final tokenStore = InMemoryAuthTokenStore();
      final controller = AuthController(
        tokenStore: tokenStore,
        authClient: client,
        serverProfileId: 'localhost',
        apiBaseUrl: apiBaseUrl,
      );
      await controller.initialize();
      await controller.login(identifier: 'ranger', password: 'secret');

      await controller.setAutoLoginEnabled(false);

      expect(controller.autoLoginEnabled, isFalse);
      expect(controller.isLoggedIn, isTrue);
      expect(await tokenStore.getTokens('localhost'), isNull);
    },
  );

  test('login does not persist tokens when auto-login is disabled', () async {
    final client = _FakeAuthClient();
    final tokenStore = InMemoryAuthTokenStore();
    final controller = AuthController(
      tokenStore: tokenStore,
      authClient: client,
      serverProfileId: 'localhost',
      apiBaseUrl: apiBaseUrl,
    );
    await controller.initialize();
    await controller.setAutoLoginEnabled(false);

    await controller.login(identifier: 'ranger', password: 'secret');

    expect(controller.isLoggedIn, isTrue);
    expect(await tokenStore.getTokens('localhost'), isNull);
  });

  testWidgets('auto-login switch updates the server preference', (
    tester,
  ) async {
    final controller = buildController(_FakeAuthClient());
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(home: AuthPage(authController: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SwitchListTile, '自动登录'));
    await tester.pumpAndSettle();

    expect(controller.autoLoginEnabled, isFalse);
    expect(
      tester
          .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, '自动登录'))
          .value,
      isFalse,
    );
  });

  testWidgets('login success shows the username', (tester) async {
    final client = _FakeAuthClient(
      loginSession: AuthSession(
        user: AuthUser(
          id: 'user-1',
          username: 'ranger',
          email: 'ranger@example.com',
        ),
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    );
    final tokenStore = InMemoryAuthTokenStore();
    final controller = AuthController(
      tokenStore: tokenStore,
      authClient: client,
      serverProfileId: 'localhost',
      apiBaseUrl: apiBaseUrl,
    );
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(home: AuthPage(authController: controller)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(_textFieldWithLabel('用户名或邮箱'), 'ranger');
    await tester.enterText(_textFieldWithLabel('密码'), 'p@ssw0rd');
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();

    expect(find.text('ranger'), findsOneWidget);
    expect(find.text('ranger@example.com'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '登录'), findsNothing);
    expect(
      await tokenStore.getTokens('localhost'),
      StoredAuthTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    );
  });

  testWidgets('register success saves session and shows username', (
    tester,
  ) async {
    final client = _FakeAuthClient(
      registerResult: RegisterResult(
        user: AuthUser(
          id: 'user-1',
          username: 'ranger',
          email: 'ranger@example.com',
        ),
        isFirstUser: true,
      ),
      loginSession: AuthSession(
        user: AuthUser(
          id: 'user-1',
          username: 'ranger',
          email: 'ranger@example.com',
        ),
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    );
    final tokenStore = InMemoryAuthTokenStore();
    final controller = AuthController(
      tokenStore: tokenStore,
      authClient: client,
      serverProfileId: 'localhost',
      apiBaseUrl: apiBaseUrl,
    );
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(home: AuthPage(authController: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('没有账号？注册'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, '注册'), findsOneWidget);

    await tester.enterText(_textFieldWithLabel('用户名'), 'ranger');
    await tester.enterText(_textFieldWithLabel('邮箱'), 'ranger@example.com');
    await tester.enterText(_textFieldWithLabel('密码'), 'p@ssw0rd');
    await tester.tap(find.widgetWithText(FilledButton, '注册'));
    await tester.pumpAndSettle();

    expect(find.text('ranger'), findsOneWidget);
    expect(await tokenStore.getTokens('localhost'), isA<StoredAuthTokens>());
    expect(client.registerCalls, hasLength(1));
    expect(client.loginCalls, hasLength(1));
  });

  testWidgets('logout returns to the not-logged-in state', (tester) async {
    final client = _FakeAuthClient(
      loginSession: AuthSession(
        user: AuthUser(
          id: 'user-1',
          username: 'ranger',
          email: 'ranger@example.com',
        ),
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    );
    final tokenStore = InMemoryAuthTokenStore();
    final controller = AuthController(
      tokenStore: tokenStore,
      authClient: client,
      serverProfileId: 'localhost',
      apiBaseUrl: apiBaseUrl,
    );
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(home: AuthPage(authController: controller)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(_textFieldWithLabel('用户名或邮箱'), 'ranger');
    await tester.enterText(_textFieldWithLabel('密码'), 'p@ssw0rd');
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();

    expect(find.text('ranger'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '退出登录'));
    await tester.pumpAndSettle();

    expect(find.text('ranger'), findsNothing);
    expect(find.widgetWithText(FilledButton, '登录'), findsOneWidget);
    expect(await tokenStore.getTokens('localhost'), isNull);
    expect(client.logoutCalls, ['refresh-token']);
  });

  testWidgets(
    'logged-in account can disable auto-login without ending the session',
    (tester) async {
      final client = _FakeAuthClient();
      final tokenStore = InMemoryAuthTokenStore();
      final controller = AuthController(
        tokenStore: tokenStore,
        authClient: client,
        serverProfileId: 'localhost',
        apiBaseUrl: apiBaseUrl,
      );
      await controller.initialize();
      await controller.login(identifier: 'ranger', password: 'secret');

      await tester.pumpWidget(
        MaterialApp(home: AuthPage(authController: controller)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SwitchListTile, '自动登录'));
      await tester.pumpAndSettle();

      expect(controller.isLoggedIn, isTrue);
      expect(controller.autoLoginEnabled, isFalse);
      expect(find.text('ranger'), findsOneWidget);
      expect(await tokenStore.getTokens('localhost'), isNull);
    },
  );

  testWidgets('login failure shows an error message', (tester) async {
    final client = _FakeAuthClient(
      loginError: AuthApiException('Invalid credentials', statusCode: 401),
    );
    final controller = buildController(client);
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(home: AuthPage(authController: controller)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(_textFieldWithLabel('用户名或邮箱'), 'ranger');
    await tester.enterText(_textFieldWithLabel('密码'), 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid credentials'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '登录'), findsOneWidget);
  });
}

class _FakeAuthClient implements AuthClient {
  _FakeAuthClient({
    this.loginSession,
    this.loginError,
    this.registerResult,
    this.validAccessToken,
    this.refreshedAccessToken,
    this.refreshError,
  });

  final AuthSession? loginSession;
  final AuthApiException? loginError;
  final RegisterResult? registerResult;
  final String? validAccessToken;
  final String? refreshedAccessToken;
  final AuthApiException? refreshError;

  final List<({String identifier, String password})> loginCalls = [];
  final List<({String username, String email, String password})> registerCalls =
      [];
  final List<String> logoutCalls = [];
  final List<String> meCalls = [];
  final List<String> refreshCalls = [];

  @override
  Future<RegisterResult> register({
    required String apiBaseUrl,
    required String username,
    required String email,
    required String password,
  }) async {
    registerCalls.add((username: username, email: email, password: password));
    return registerResult ??
        RegisterResult(
          user: AuthUser(id: 'user-1', username: username, email: email),
          isFirstUser: false,
        );
  }

  @override
  Future<AuthSession> login({
    required String apiBaseUrl,
    required String identifier,
    required String password,
  }) async {
    loginCalls.add((identifier: identifier, password: password));
    if (loginError != null) throw loginError!;
    return loginSession ??
        AuthSession(
          user: AuthUser(
            id: 'user-1',
            username: identifier,
            email: '$identifier@example.com',
          ),
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        );
  }

  @override
  Future<AuthUser> me({
    required String apiBaseUrl,
    required String accessToken,
  }) async {
    meCalls.add(accessToken);
    if (accessToken == validAccessToken) {
      return const AuthUser(
        id: 'user-1',
        username: 'ranger',
        email: 'ranger@example.com',
      );
    }
    throw AuthApiException('Unauthorized', statusCode: 401);
  }

  @override
  Future<String> refresh({
    required String apiBaseUrl,
    required String refreshToken,
  }) async {
    refreshCalls.add(refreshToken);
    if (refreshError != null) throw refreshError!;
    if (refreshedAccessToken != null) return refreshedAccessToken!;
    throw AuthApiException('Unauthorized', statusCode: 401);
  }

  @override
  Future<void> logout({
    required String apiBaseUrl,
    required String refreshToken,
  }) async {
    logoutCalls.add(refreshToken);
  }
}
