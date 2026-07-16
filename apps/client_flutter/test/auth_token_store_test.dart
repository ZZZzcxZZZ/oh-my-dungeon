import 'package:dnd_table_client/src/features/auth/data/auth_token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const tokensA = StoredAuthTokens(
    accessToken: 'access-a',
    refreshToken: 'refresh-a',
  );
  const tokensB = StoredAuthTokens(
    accessToken: 'access-b',
    refreshToken: 'refresh-b',
  );

  group('InMemoryAuthTokenStore', () {
    test('enables auto-login by default', () async {
      final store = InMemoryAuthTokenStore();
      expect(await store.getAutoLoginEnabled('server-a'), isTrue);
    });

    test('stores auto-login preference per server', () async {
      final store = InMemoryAuthTokenStore();
      await store.setAutoLoginEnabled('server-a', false);

      expect(await store.getAutoLoginEnabled('server-a'), isFalse);
      expect(await store.getAutoLoginEnabled('server-b'), isTrue);
    });

    test('returns null when no tokens have been saved for a server', () async {
      final store = InMemoryAuthTokenStore();
      expect(await store.getTokens('server-a'), isNull);
    });

    test('saves and retrieves tokens for a server profile', () async {
      final store = InMemoryAuthTokenStore();
      await store.saveTokens('server-a', tokensA);
      expect(await store.getTokens('server-a'), tokensA);
    });

    test('replaces tokens when saving again for the same server', () async {
      final store = InMemoryAuthTokenStore();
      await store.saveTokens('server-a', tokensA);
      await store.saveTokens('server-a', tokensB);
      expect(await store.getTokens('server-a'), tokensB);
    });

    test('isolates tokens between different server profiles', () async {
      final store = InMemoryAuthTokenStore();
      await store.saveTokens('server-a', tokensA);
      await store.saveTokens('server-b', tokensB);
      expect(await store.getTokens('server-a'), tokensA);
      expect(await store.getTokens('server-b'), tokensB);
    });

    test('clears tokens only for the targeted server', () async {
      final store = InMemoryAuthTokenStore();
      await store.saveTokens('server-a', tokensA);
      await store.saveTokens('server-b', tokensB);
      await store.clearTokens('server-a');
      expect(await store.getTokens('server-a'), isNull);
      expect(await store.getTokens('server-b'), tokensB);
    });

    test('clearing a server with no tokens is a no-op', () async {
      final store = InMemoryAuthTokenStore();
      await store.clearTokens('server-a');
      expect(await store.getTokens('server-a'), isNull);
    });
  });

  group('SharedPreferencesAuthTokenStore', () {
    test('enables auto-login by default', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPreferencesAuthTokenStore(
        await SharedPreferences.getInstance(),
      );

      expect(await store.getAutoLoginEnabled('server-a'), isTrue);
    });

    test('persists auto-login preference across store instances', () async {
      SharedPreferences.setMockInitialValues({});
      final firstStore = SharedPreferencesAuthTokenStore(
        await SharedPreferences.getInstance(),
      );
      await firstStore.setAutoLoginEnabled('server-a', false);

      final secondStore = SharedPreferencesAuthTokenStore(
        await SharedPreferences.getInstance(),
      );
      expect(await secondStore.getAutoLoginEnabled('server-a'), isFalse);
      expect(await secondStore.getAutoLoginEnabled('server-b'), isTrue);
    });

    test('persists tokens across store instances', () async {
      SharedPreferences.setMockInitialValues({});
      final firstStore = SharedPreferencesAuthTokenStore(
        await SharedPreferences.getInstance(),
      );
      await firstStore.saveTokens('server-a', tokensA);

      final secondStore = SharedPreferencesAuthTokenStore(
        await SharedPreferences.getInstance(),
      );
      expect(await secondStore.getTokens('server-a'), tokensA);
    });

    test('isolates tokens between different server profiles', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPreferencesAuthTokenStore(
        await SharedPreferences.getInstance(),
      );
      await store.saveTokens('server-a', tokensA);
      await store.saveTokens('server-b', tokensB);

      expect(await store.getTokens('server-a'), tokensA);
      expect(await store.getTokens('server-b'), tokensB);
    });

    test('clears tokens only for the targeted server', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPreferencesAuthTokenStore(
        await SharedPreferences.getInstance(),
      );
      await store.saveTokens('server-a', tokensA);
      await store.saveTokens('server-b', tokensB);
      await store.clearTokens('server-a');

      expect(await store.getTokens('server-a'), isNull);
      expect(await store.getTokens('server-b'), tokensB);
    });

    test('returns null when no tokens exist for a server', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPreferencesAuthTokenStore(
        await SharedPreferences.getInstance(),
      );
      expect(await store.getTokens('server-a'), isNull);
    });

    test('replaces tokens when saving again for the same server', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPreferencesAuthTokenStore(
        await SharedPreferences.getInstance(),
      );
      await store.saveTokens('server-a', tokensA);
      await store.saveTokens('server-a', tokensB);
      expect(await store.getTokens('server-a'), tokensB);
    });
  });
}
