import 'package:dnd_table_client/src/features/server_profiles/data/server_profile_store.dart';
import 'package:dnd_table_client/src/features/server_profiles/domain/server_profile.dart';
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

  test('persists server profiles across store instances', () async {
    SharedPreferences.setMockInitialValues({});
    final firstStore = SharedPreferencesServerProfileStore(
      await SharedPreferences.getInstance(),
    );

    await firstStore.saveProfile(profile);

    final secondStore = SharedPreferencesServerProfileStore(
      await SharedPreferences.getInstance(),
    );
    expect(await secondStore.listProfiles(), [profile]);
  });

  test('replaces profiles with the same id', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesServerProfileStore(
      await SharedPreferences.getInstance(),
    );
    const updatedProfile = ServerProfile(
      id: 'localhost',
      name: 'Renamed Table',
      baseUrl: 'http://localhost:3000',
      apiBaseUrl: 'http://localhost:3000/api',
      websocketUrl: 'ws://localhost:3000/ws',
      lastKnownVersion: '0.2.0',
    );

    await store.saveProfile(profile);
    await store.saveProfile(updatedProfile);

    expect(await store.listProfiles(), [updatedProfile]);
  });
}
