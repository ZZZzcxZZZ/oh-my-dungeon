import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/character.dart';
import '../../domain/character_content_reference.dart';
import '../character_repository.dart';

class DriftCharacterRepository implements CharacterRepository {
  DriftCharacterRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<List<CharacterSheet>> watchOwnedCharacters() {
    final db = _database;
    return (db.select(db.characters)
          ..where((t) => t.archivedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch()
        .asyncMap((rows) async {
      final result = <CharacterSheet>[];
      for (final row in rows) {
        final refs = await _loadRefs(row.id);
        result.add(_toCharacter(row, refs));
      }
      return result;
    });
  }

  @override
  Future<CharacterSheet?> getById(String id) async {
    final db = _database;
    final row = await (db.select(db.characters)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    final refs = await _loadRefs(id);
    return _toCharacter(row, refs);
  }

  @override
  Future<void> save(CharacterSheet character) async {
    final db = _database;
    await db.transaction(() async {
      await db.into(db.characters).insertOnConflictUpdate(
            CharactersCompanion.insert(
              id: character.id,
              ownerLocalId: Value(character.ownerUserId),
              sheetJson: jsonEncode(character.toJson()),
              updatedAt: Value(DateTime.now()),
            ),
          );
      await (db.delete(db.characterContentRefs)
            ..where((t) => t.characterId.equals(character.id)))
          .go();
      for (final ref in character.contentReferences) {
        await db.into(db.characterContentRefs).insert(
              CharacterContentRefsCompanion.insert(
                characterId: character.id,
                slot: ref.slot,
                entryKey: ref.entryKey,
                sourceRevision: Value(ref.sourceRevision),
                snapshotJson: Value(jsonEncode(ref.snapshot)),
              ),
            );
      }
    });
  }

  @override
  Future<void> archive(String id) async {
    final db = _database;
    await (db.update(db.characters)
          ..where((t) => t.id.equals(id)))
        .write(CharactersCompanion(archivedAt: Value(DateTime.now())));
  }

  @override
  Future<void> delete(String id) async {
    final db = _database;
    await db.transaction(() async {
      await (db.delete(db.characterContentRefs)
            ..where((t) => t.characterId.equals(id)))
          .go();
      await (db.delete(db.characters)
            ..where((t) => t.id.equals(id)))
          .go();
    });
  }

  Future<List<CharacterContentReference>> _loadRefs(String characterId) async {
    final db = _database;
    final rows = await (db.select(db.characterContentRefs)
          ..where((t) => t.characterId.equals(characterId))
          ..orderBy([(t) => OrderingTerm.asc(t.slot)]))
        .get();
    return rows
        .map((row) => CharacterContentReference(
              slot: row.slot,
              entryKey: row.entryKey,
              sourceRevision: row.sourceRevision,
              snapshot: row.snapshotJson.isEmpty
                  ? const <String, Object?>{}
                  : Map<String, Object?>.from(
                      jsonDecode(row.snapshotJson) as Map,
                    ),
            ))
        .toList();
  }

  CharacterSheet _toCharacter(
    CharacterRow row,
    List<CharacterContentReference> refs,
  ) {
    final json = jsonDecode(row.sheetJson) as Map<String, Object?>;
    final character = CharacterSheet.fromJson(json);
    return character.copyWith(contentReferences: refs);
  }
}
