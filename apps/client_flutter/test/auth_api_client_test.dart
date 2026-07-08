import 'dart:convert';

import 'package:dnd_table_client/src/features/auth/data/auth_api_client.dart';
import 'package:dnd_table_client/src/features/auth/domain/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _apiBaseUrl = 'http://localhost:3000/api';

void main() {
  group('AuthApiClient.register', () {
    test('posts credentials and parses the register result', () async {
      http.Request? captured;
      final client = AuthApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'user': {
                'id': 'user-1',
                'username': 'ranger',
                'email': 'ranger@example.com',
              },
              'isFirstUser': true,
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await client.register(
        apiBaseUrl: _apiBaseUrl,
        username: 'ranger',
        email: 'ranger@example.com',
        password: 'p@ssw0rd',
      );

      expect(captured?.method, 'POST');
      expect(captured?.url.toString(), '$_apiBaseUrl/auth/register');
      expect(
        jsonDecode(captured!.body),
        {
          'username': 'ranger',
          'email': 'ranger@example.com',
          'password': 'p@ssw0rd',
        },
      );
      expect(
        result,
        RegisterResult(
          user: AuthUser(
            id: 'user-1',
            username: 'ranger',
            email: 'ranger@example.com',
          ),
          isFirstUser: true,
        ),
      );
    });

    test('throws AuthApiException with server message on 409 conflict', () async {
      final client = AuthApiClient(
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({'message': 'Username already exists'}),
            409,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      expect(
        () => client.register(
          apiBaseUrl: _apiBaseUrl,
          username: 'ranger',
          email: 'ranger@example.com',
          password: 'p@ssw0rd',
        ),
        throwsA(
          isA<AuthApiException>()
              .having((e) => e.message, 'message', 'Username already exists')
              .having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });

    test('throws AuthApiException on 403 registration disabled', () async {
      final client = AuthApiClient(
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({'message': 'Registration is disabled'}),
            403,
          );
        }),
      );

      expect(
        () => client.register(
          apiBaseUrl: _apiBaseUrl,
          username: 'ranger',
          email: 'ranger@example.com',
          password: 'p@ssw0rd',
        ),
        throwsA(
          isA<AuthApiException>()
              .having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
    });
  });

  group('AuthApiClient.login', () {
    test('posts identifier and password, returns session with tokens', () async {
      http.Request? captured;
      final client = AuthApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'user': {
                'id': 'user-1',
                'username': 'ranger',
                'email': 'ranger@example.com',
              },
              'accessToken': 'access-token',
              'refreshToken': 'refresh-token',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final session = await client.login(
        apiBaseUrl: _apiBaseUrl,
        identifier: 'ranger',
        password: 'p@ssw0rd',
      );

      expect(captured?.method, 'POST');
      expect(captured?.url.toString(), '$_apiBaseUrl/auth/login');
      expect(
        jsonDecode(captured!.body),
        {'identifier': 'ranger', 'password': 'p@ssw0rd'},
      );
      expect(
        session,
        AuthSession(
          user: AuthUser(
            id: 'user-1',
            username: 'ranger',
            email: 'ranger@example.com',
          ),
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        ),
      );
    });

    test('throws AuthApiException on 401 invalid credentials', () async {
      final client = AuthApiClient(
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({'message': 'Invalid credentials'}),
            401,
          );
        }),
      );

      expect(
        () => client.login(
          apiBaseUrl: _apiBaseUrl,
          identifier: 'ranger',
          password: 'wrong',
        ),
        throwsA(
          isA<AuthApiException>()
              .having((e) => e.message, 'message', 'Invalid credentials')
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });
  });

  group('AuthApiClient.me', () {
    test('sends bearer token and returns the current user', () async {
      http.Request? captured;
      final client = AuthApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'id': 'user-1',
              'username': 'ranger',
              'email': 'ranger@example.com',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final user = await client.me(
        apiBaseUrl: _apiBaseUrl,
        accessToken: 'access-token',
      );

      expect(captured?.method, 'GET');
      expect(captured?.url.toString(), '$_apiBaseUrl/auth/me');
      expect(captured?.headers['authorization'], 'Bearer access-token');
      expect(
        user,
        AuthUser(
          id: 'user-1',
          username: 'ranger',
          email: 'ranger@example.com',
        ),
      );
    });

    test('throws AuthApiException on 401', () async {
      final client = AuthApiClient(
        httpClient: MockClient((request) async {
          return http.Response('Unauthorized', 401);
        }),
      );

      expect(
        () => client.me(apiBaseUrl: _apiBaseUrl, accessToken: 'bad-token'),
        throwsA(
          isA<AuthApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });
  });

  group('AuthApiClient.refresh', () {
    test('posts refresh token and returns a new access token', () async {
      http.Request? captured;
      final client = AuthApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'accessToken': 'new-access-token'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final accessToken = await client.refresh(
        apiBaseUrl: _apiBaseUrl,
        refreshToken: 'refresh-token',
      );

      expect(captured?.method, 'POST');
      expect(captured?.url.toString(), '$_apiBaseUrl/auth/refresh');
      expect(jsonDecode(captured!.body), {'refreshToken': 'refresh-token'});
      expect(accessToken, 'new-access-token');
    });

    test('throws AuthApiException on 401', () async {
      final client = AuthApiClient(
        httpClient: MockClient((request) async {
          return http.Response('Unauthorized', 401);
        }),
      );

      expect(
        () => client.refresh(
          apiBaseUrl: _apiBaseUrl,
          refreshToken: 'expired-token',
        ),
        throwsA(isA<AuthApiException>()),
      );
    });
  });

  group('AuthApiClient.logout', () {
    test('posts refresh token and completes on 204', () async {
      http.Request? captured;
      final client = AuthApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response('', 204);
        }),
      );

      await client.logout(
        apiBaseUrl: _apiBaseUrl,
        refreshToken: 'refresh-token',
      );

      expect(captured?.method, 'POST');
      expect(captured?.url.toString(), '$_apiBaseUrl/auth/logout');
      expect(jsonDecode(captured!.body), {'refreshToken': 'refresh-token'});
    });

    test('does not throw on 401 for already-revoked tokens', () async {
      final client = AuthApiClient(
        httpClient: MockClient((request) async {
          return http.Response('', 401);
        }),
      );

      await client.logout(
        apiBaseUrl: _apiBaseUrl,
        refreshToken: 'already-revoked',
      );
    });
  });

  test('normalizes trailing slashes in the api base url', () async {
    final client = AuthApiClient(
      httpClient: MockClient((request) async {
        expect(
          request.url.toString(),
          'http://localhost:3000/api/auth/login',
        );
        return http.Response(
          jsonEncode({
            'user': {
              'id': 'user-1',
              'username': 'ranger',
              'email': 'ranger@example.com',
            },
            'accessToken': 'access-token',
            'refreshToken': 'refresh-token',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await client.login(
      apiBaseUrl: 'http://localhost:3000/api/',
      identifier: 'ranger',
      password: 'p@ssw0rd',
    );
  });
}
