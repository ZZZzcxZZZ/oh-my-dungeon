import 'package:dnd_table_client/src/core/database/app_database.dart';
import 'package:dnd_table_client/src/features/server_profiles/data/drift_server_profile_store.dart';
import 'package:dnd_table_client/src/features/server_profiles/data/server_profile_migrator.dart';
import 'package:dnd_table_client/src/features/server_profiles/data/server_profile_store.dart';
import 'package:dnd_table_client/src/features/server_profiles/domain/server_profile.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const profile = ServerProfile(
    id: 'localhost',
    name: 'Local',
    baseUrl: 'http://localhost:3000',
    apiBaseUrl: 'http://localhost:3000/api',
    websocketUrl: 'ws://localhost:3000/ws',
    lastKnownVersion: '0.1.0',
  );

  test('migrates shared-preferences profiles only once', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final legacy = SharedPreferencesServerProfileStore(preferences);
    await legacy.saveProfile(profile);
    await legacy.setDefaultProfileId(profile.id);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final migrator = ServerProfileMigrator(database, preferences);

    await migrator.run();
    await migrator.run();

    final store = DriftServerProfileStore(database);
    expect(await store.listProfiles(), [profile]);
    expect(await store.getDefaultProfileId(), profile.id);
    await database.close();
  });

  test('migrator is a no-op when no legacy profiles exist', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final migrator = ServerProfileMigrator(database, preferences);

    await migrator.run();

    final store = DriftServerProfileStore(database);
    expect(await store.listProfiles(), isEmpty);
    expect(await store.getDefaultProfileId(), isNull);
    await database.close();
  });

  test(
    'drift store persists profiles and default id across instances',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final first = DriftServerProfileStore(database);
      await first.saveProfile(profile);
      await first.setDefaultProfileId(profile.id);

      final second = DriftServerProfileStore(database);
      expect(await second.listProfiles(), [profile]);
      expect(await second.getDefaultProfileId(), profile.id);

      await second.deleteProfile(profile.id);
      expect(await second.listProfiles(), isEmpty);
      expect(await second.getDefaultProfileId(), isNull);
      await database.close();
    },
  );

  test('refreshing discovered metadata preserves the local alias', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final store = DriftServerProfileStore(database);
    await store.saveProfile(profile.copyWith(localAlias: '周五团'));

    await store.saveProfile(
      profile.copyWith(serverName: 'Renamed Server', localAlias: null),
    );

    final saved = (await store.listProfiles()).single;
    expect(saved.serverName, 'Renamed Server');
    expect(saved.localAlias, '周五团');
    expect(saved.displayName, '周五团');
    await database.close();
  });

  // 确保旧契约仍可用（迁移期间保留 SharedPreferences 原值）。
  test('legacy store still reads profiles after migration', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final legacy = SharedPreferencesServerProfileStore(preferences);
    await legacy.saveProfile(profile);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await ServerProfileMigrator(database, preferences).run();

    final legacyAgain = SharedPreferencesServerProfileStore(preferences);
    expect(await legacyAgain.listProfiles(), [profile]);
    await database.close();
  });
}
