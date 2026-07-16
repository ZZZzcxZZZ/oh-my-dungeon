import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/server_profile.dart';
import 'server_profile_store.dart';

/// 基于 Drift 的服务器 Profile 存储，实现与 SharedPreferences 版本相同的契约。
class DriftServerProfileStore implements ServerProfileStore {
  DriftServerProfileStore(this._database);

  final AppDatabase _database;

  @override
  Future<List<ServerProfile>> listProfiles() async {
    final rows = await (_database.select(_database.serverProfiles)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    return rows.map(_toProfile).toList(growable: false);
  }

  @override
  Future<void> saveProfile(ServerProfile profile) async {
    final existing = await (_database.select(_database.serverProfiles)
          ..where((t) => t.id.equals(profile.id)))
        .getSingleOrNull();
    await _database.into(_database.serverProfiles).insertOnConflictUpdate(
          ServerProfilesCompanion.insert(
            id: profile.id,
            name: profile.name,
            baseUrl: profile.baseUrl,
            apiBaseUrl: profile.apiBaseUrl,
            websocketUrl: profile.websocketUrl,
            lastKnownVersion: Value(profile.lastKnownVersion),
            isDefault: Value(existing?.isDefault ?? false),
            lastConnectedAt: Value(existing?.lastConnectedAt),
          ),
        );
  }

  @override
  Future<void> deleteProfile(String id) async {
    await (_database.delete(_database.serverProfiles)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  @override
  Future<String?> getDefaultProfileId() async {
    final row = await (_database.select(_database.serverProfiles)
          ..where((t) => t.isDefault.equals(true))
          ..limit(1))
        .getSingleOrNull();
    return row?.id;
  }

  @override
  Future<void> setDefaultProfileId(String? id) async {
    await _database.transaction(() async {
      await (_database.update(_database.serverProfiles))
          .write(const ServerProfilesCompanion(isDefault: Value(false)));
      if (id != null) {
        await (_database.update(_database.serverProfiles)
              ..where((t) => t.id.equals(id)))
            .write(const ServerProfilesCompanion(isDefault: Value(true)));
      }
    });
  }

  ServerProfile _toProfile(ServerProfileRow row) {
    return ServerProfile(
      id: row.id,
      name: row.name,
      baseUrl: row.baseUrl,
      apiBaseUrl: ServerProfile.normalizeApiBaseUrl(row.apiBaseUrl),
      websocketUrl: row.websocketUrl,
      lastKnownVersion: row.lastKnownVersion,
    );
  }
}
