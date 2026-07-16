import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../../characters/data/local/drift_character_repository.dart';
import '../../characters/domain/character.dart';
import '../domain/vault_models.dart';
import 'vault_sync_service.dart';

/// Applies remote Vault changes to the local Drift database without
/// re-enqueuing them to the outbox. This prevents the infinite sync loop
/// that would occur if applying a remote change triggered a new push.
class DriftVaultChangeApplier implements VaultChangeApplier {
  DriftVaultChangeApplier(this._database);

  final AppDatabase _database;

  @override
  Future<void> applyAll(List<VaultChange> changes) async {
    for (final change in changes) {
      var handled = true;
      switch (change.entityType) {
        case 'character':
          await _applyCharacter(change);
          break;
        case 'favorite':
          await _applyFavorite(change);
          break;
        case 'note':
          await _applyNote(change);
          break;
        case 'preferences':
          // Preferences sync is a no-op until wired to SharedPreferences.
          break;
        case 'personalContentEntry':
          // Personal content entries are not enqueued in this milestone.
          break;
        case 'installedPackageManifest':
          // Manifest sync is informational only — don't auto-install packages.
          break;
        default:
          // Ignore unknown entity types.
          handled = false;
          break;
      }
      if (handled) await _saveRevision(change);
    }
  }

  Future<void> _applyCharacter(VaultChange change) async {
    final payload = jsonDecode(change.payloadJson) as Map<String, Object?>;
    final character = CharacterSheet.fromJson(payload);
    await DriftCharacterRepository(_database).saveRemote(
      character,
      change.revision,
    );
  }

  Future<void> _applyFavorite(VaultChange change) async {
    final payload = jsonDecode(change.payloadJson) as Map<String, Object?>;
    final entryKey = payload['entryKey'] as String;
    final favorite = payload['favorite'] as bool? ?? false;
    final db = _database;
    if (change.operation != 'delete' && favorite) {
      await db.into(db.contentFavorites).insertOnConflictUpdate(
            ContentFavoritesCompanion.insert(
              entryKey: entryKey,
              createdAt: DateTime.now(),
            ),
          );
    } else {
      await (db.delete(db.contentFavorites)
            ..where((t) => t.entryKey.equals(entryKey)))
          .go();
    }
  }

  Future<void> _applyNote(VaultChange change) async {
    final payload = jsonDecode(change.payloadJson) as Map<String, Object?>;
    final entryKey = payload['entryKey'] as String;
    final markdown = payload['markdown'] as String? ?? '';
    final db = _database;
    if (change.operation == 'delete') {
      await (db.delete(db.contentNotes)
            ..where((table) => table.entryKey.equals(entryKey)))
          .go();
      return;
    }
    await db.into(db.contentNotes).insertOnConflictUpdate(
          ContentNotesCompanion.insert(
            entryKey: entryKey,
            markdown: markdown,
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<void> _saveRevision(VaultChange change) async {
    await _database.into(_database.vaultEntityRevisions).insertOnConflictUpdate(
          VaultEntityRevisionsCompanion.insert(
            entityType: change.entityType,
            entityId: change.entityId,
            revision: change.revision,
            updatedAt: DateTime.now(),
          ),
        );
  }
}
