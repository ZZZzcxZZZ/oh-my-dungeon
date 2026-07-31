import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// One-time, non-destructive migration from the pre-workspace `app.db` into
/// the anonymous local workspace.
///
/// Server profiles belong to the bootstrap database and campaign caches can
/// be downloaded again, so neither is copied here.
final class LegacyWorkspaceMigrator {
  LegacyWorkspaceMigrator({
    required AppDatabase source,
    required AppDatabase target,
    this.failAfterCopyForTesting = false,
  }) : _source = source,
       _target = target;

  static const markerKey = 'legacy-app-db-to-local-workspace-v1';

  final AppDatabase _source;
  final AppDatabase _target;
  final bool failAfterCopyForTesting;

  /// Returns true when migration ran, or false when it had already completed.
  Future<bool> run() async {
    final completed = await (_target.select(
      _target.migrationMarkers,
    )..where((row) => row.key.equals(markerKey))).getSingleOrNull();
    if (completed != null) return false;

    final packages = await _source.select(_source.localContentPackages).get();
    final entries = await _source.select(_source.localContentEntries).get();
    final assets = await _source.select(_source.localContentAssets).get();
    final links = await _source.select(_source.contentLinks).get();
    final favorites = await _source.select(_source.contentFavorites).get();
    final notes = await _source.select(_source.contentNotes).get();
    final readHistory = await _source.select(_source.contentReadHistory).get();
    final characters = await _source.select(_source.characters).get();
    final characterRefs = await _source
        .select(_source.characterContentRefs)
        .get();

    await _target.transaction(() async {
      for (final row in packages) {
        await _target
            .into(_target.localContentPackages)
            .insert(row.toCompanion(true), mode: InsertMode.insertOrIgnore);
      }
      for (final row in entries) {
        await _target
            .into(_target.localContentEntries)
            .insert(row.toCompanion(true), mode: InsertMode.insertOrIgnore);
      }
      for (final row in assets) {
        await _target
            .into(_target.localContentAssets)
            .insert(row.toCompanion(true), mode: InsertMode.insertOrIgnore);
      }
      for (final row in links) {
        await _target
            .into(_target.contentLinks)
            .insert(row.toCompanion(true), mode: InsertMode.insertOrIgnore);
      }
      for (final row in favorites) {
        await _target
            .into(_target.contentFavorites)
            .insert(row.toCompanion(true), mode: InsertMode.insertOrIgnore);
      }
      for (final row in notes) {
        await _target
            .into(_target.contentNotes)
            .insert(row.toCompanion(true), mode: InsertMode.insertOrIgnore);
      }
      for (final row in readHistory) {
        await _target
            .into(_target.contentReadHistory)
            .insert(row.toCompanion(true), mode: InsertMode.insertOrIgnore);
      }
      for (final row in characters) {
        await _target
            .into(_target.characters)
            .insert(row.toCompanion(true), mode: InsertMode.insertOrIgnore);
      }
      for (final row in characterRefs) {
        await _target
            .into(_target.characterContentRefs)
            .insert(row.toCompanion(true), mode: InsertMode.insertOrIgnore);
      }

      if (failAfterCopyForTesting) {
        throw StateError('Simulated legacy migration failure');
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
