import 'package:dnd_table_client/src/features/server_profiles/data/bundled_default_server_seeder.dart';
import 'package:dnd_table_client/src/features/server_profiles/data/server_profile_store.dart';
import 'package:dnd_table_client/src/features/server_profiles/domain/server_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('seeds the bundled default server into an empty store', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = InMemoryServerProfileStore();

    await const BundledDefaultServerSeeder(enabled: true).seedIfEmpty(store, preferences);

    final profiles = await store.listProfiles();
    expect(profiles, hasLength(1));
    final profile = profiles.single;
    expect(profile.baseUrl, BundledDefaultServerSeeder.defaultBaseUrl);
    expect(
      profile.apiBaseUrl,
      '${BundledDefaultServerSeeder.defaultBaseUrl}/api',
    );
    expect(profile.websocketUrl, 'ws://47.122.123.77:3000/campaigns');
    expect(await store.getDefaultProfileId(), profile.id);
    expect(preferences.getBool('server_profiles.bundled_seed.v1'), isTrue);
  });

  test('does not seed again once marked', () async {
    SharedPreferences.setMockInitialValues({
      'server_profiles.bundled_seed.v1': true,
    });
    final preferences = await SharedPreferences.getInstance();
    final store = InMemoryServerProfileStore();

    await const BundledDefaultServerSeeder(enabled: true).seedIfEmpty(store, preferences);

    expect(await store.listProfiles(), isEmpty);
  });

  test('does not overwrite existing user profiles', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = InMemoryServerProfileStore();
    await store.saveProfile(
      const ServerProfile(
        id: 'user-profile',
        serverName: '我的服务器',
        baseUrl: 'http://192.168.1.10:3000',
        apiBaseUrl: 'http://192.168.1.10:3000/api',
        websocketUrl: 'ws://192.168.1.10:3000/campaigns',
        lastKnownVersion: '0.1.0',
      ),
    );

    await const BundledDefaultServerSeeder(enabled: true).seedIfEmpty(store, preferences);

    final profiles = await store.listProfiles();
    expect(profiles, hasLength(1));
    expect(profiles.single.id, 'user-profile');
    expect(await store.getDefaultProfileId(), isNull);
  });
}
