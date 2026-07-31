import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import 'drift_server_profile_store.dart';
import 'server_profile_store.dart';

/// 把 SharedPreferences 中的服务器 Profile 一次性迁移到 Drift。
///
/// 迁移成功后写入 MigrationMarker，后续调用是 no-op。SharedPreferences 原值
/// 保留一个版本，不主动删除，保证回退路径可用。
class ServerProfileMigrator {
  ServerProfileMigrator(this._database, this._preferences);

  final AppDatabase _database;
  final SharedPreferences _preferences;

  static const _markerKey = 'server-profiles-v1';

  Future<bool> hasMigrated() async {
    final row = await (_database.select(
      _database.migrationMarkers,
    )..where((t) => t.key.equals(_markerKey))).getSingleOrNull();
    return row != null;
  }

  Future<void> run() async {
    if (await hasMigrated()) return;

    final legacy = SharedPreferencesServerProfileStore(_preferences);
    final profiles = await legacy.listProfiles();
    final defaultId = await legacy.getDefaultProfileId();

    await _database.transaction(() async {
      final drift = DriftServerProfileStore(_database);
      for (final profile in profiles) {
        await drift.saveProfile(profile);
      }
      if (defaultId != null) {
        await drift.setDefaultProfileId(defaultId);
      }
      await _database
          .into(_database.migrationMarkers)
          .insertOnConflictUpdate(
            MigrationMarkersCompanion.insert(
              key: _markerKey,
              completedAt: DateTime.now(),
            ),
          );
    });
  }
}
