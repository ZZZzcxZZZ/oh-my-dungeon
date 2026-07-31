import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Moves the global server list out of the legacy all-in-one database.
final class LegacyBootstrapMigrator {
  LegacyBootstrapMigrator({
    required AppDatabase source,
    required AppDatabase target,
  }) : _source = source,
       _target = target;

  static const markerKey = 'legacy-app-db-to-bootstrap-v1';

  final AppDatabase _source;
  final AppDatabase _target;

  Future<bool> run() async {
    final completed = await (_target.select(
      _target.migrationMarkers,
    )..where((row) => row.key.equals(markerKey))).getSingleOrNull();
    if (completed != null) return false;

    final profiles = await _source.select(_source.serverProfiles).get();
    await _target.transaction(() async {
      for (final row in profiles) {
        await _target
            .into(_target.serverProfiles)
            .insert(row.toCompanion(true), mode: InsertMode.insertOrIgnore);
      }
      await _target
          .into(_target.migrationMarkers)
          .insert(
            MigrationMarkersCompanion.insert(
              key: markerKey,
              completedAt: DateTime.now().toUtc(),
            ),
          );
    });
    return true;
  }
}
