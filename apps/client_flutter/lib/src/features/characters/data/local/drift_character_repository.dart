import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_models.dart';
import '../../../../core/sync/sync_repository.dart';
import '../../domain/character.dart';
import '../../domain/character_content_reference.dart';
import '../character_markdown_codec.dart';
import '../character_markdown_mirror_store_base.dart';
import '../character_repository.dart';

class DriftCharacterRepository
    implements CharacterRepository, CharacterMarkdownChangeRepository {
  DriftCharacterRepository(
    this._database, {
    CharacterMarkdownCodec markdownCodec = const CharacterMarkdownCodec(),
    CharacterMarkdownMirrorStore? markdownMirrorStore,
  }) : _markdownCodec = markdownCodec,
       _markdownMirrorStore = markdownMirrorStore;

  final AppDatabase _database;
  final CharacterMarkdownCodec _markdownCodec;
  final CharacterMarkdownMirrorStore? _markdownMirrorStore;

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
    final row = await (db.select(
      db.characters,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    final refs = await _loadRefs(id);
    return _toCharacter(row, refs);
  }

  @override
  Future<void> save(CharacterSheet character) async {
    final db = _database;
    late String markdown;
    await db.transaction(() async {
      final existing = await (db.select(
        db.characters,
      )..where((t) => t.id.equals(character.id))).getSingleOrNull();
      final localRevision = (existing?.revision ?? 0) + 1;
      markdown = await _writeCharacter(character, localRevision: localRevision);
      await (db.delete(db.syncOutbox)..where(
            (t) =>
                t.scope.equals('vault') &
                t.entityType.equals('character') &
                t.entityId.equals(character.id),
          ))
          .go();
      await DriftSyncRepository(_database).enqueue(
        SyncOperation(
          id: 'vault:character:${character.id}:${DateTime.now().microsecondsSinceEpoch}',
          scope: 'vault',
          entityType: 'character',
          entityId: character.id,
          baseRevision: existing?.syncRevision ?? 0,
          payloadJson: jsonEncode(character.toJson()),
        ),
      );
    });
    await _writeFileMirror(character.id, markdown);
  }

  /// Saves a character that arrived from the remote Vault without enqueuing a
  /// new outbox operation. [syncRevision] records the server revision so the
  /// local store can detect remote-origin writes.
  @override
  Future<void> saveRemote(CharacterSheet character, int syncRevision) async {
    final db = _database;
    late String markdown;
    await db.transaction(() async {
      final existing = await (db.select(
        db.characters,
      )..where((t) => t.id.equals(character.id))).getSingleOrNull();
      final localRevision = (existing?.revision ?? 0) + 1;
      markdown = await _writeCharacter(
        character,
        localRevision: localRevision,
        syncRevision: Value(syncRevision),
      );
    });
    await _writeFileMirror(character.id, markdown);
  }

  Future<String> _writeCharacter(
    CharacterSheet character, {
    required int localRevision,
    Value<int?> syncRevision = const Value.absent(),
  }) async {
    final db = _database;
    final markdown = _markdownCodec.encode(character, revision: localRevision);
    await db
        .into(db.characters)
        .insertOnConflictUpdate(
          CharactersCompanion.insert(
            id: character.id,
            ownerLocalId: Value(character.ownerUserId),
            sheetJson: jsonEncode(character.toJson()),
            markdownMirror: Value(markdown),
            markdownDirty: Value(_markdownMirrorStore != null),
            revision: Value(localRevision),
            syncRevision: syncRevision,
            updatedAt: Value(DateTime.now()),
          ),
        );
    await (db.delete(
      db.characterContentRefs,
    )..where((t) => t.characterId.equals(character.id))).go();
    for (final ref in character.contentReferences) {
      await db
          .into(db.characterContentRefs)
          .insert(
            CharacterContentRefsCompanion.insert(
              characterId: character.id,
              slot: ref.slot,
              entryKey: ref.entryKey,
              sourceRevision: Value(ref.sourceRevision),
              snapshotJson: Value(jsonEncode(ref.snapshot)),
            ),
          );
    }
    return markdown;
  }

  Future<void> _writeFileMirror(String characterId, String markdown) async {
    final store = _markdownMirrorStore;
    if (store == null) return;
    try {
      await store.write(characterId: characterId, markdown: markdown);
      await (_database.update(_database.characters)
            ..where((table) => table.id.equals(characterId)))
          .write(const CharactersCompanion(markdownDirty: Value(false)));
    } on Object {
      // The committed structured record remains authoritative. The dirty flag
      // keeps this derivative eligible for a later repair.
    }
  }

  Future<void> repairMarkdownMirrors() async {
    if (_markdownMirrorStore == null) return;
    final rows = await (_database.select(
      _database.characters,
    )..where((table) => table.markdownDirty.equals(true))).get();
    for (final row in rows) {
      final markdown = row.markdownMirror;
      if (markdown == null || markdown.isEmpty) continue;
      await _writeFileMirror(row.id, markdown);
    }
  }

  @override
  Future<List<CharacterMarkdownExternalChange>>
  detectExternalMarkdownChanges() async {
    final store = _markdownMirrorStore;
    if (store == null) return const [];
    final rows = await (_database.select(
      _database.characters,
    )..where((table) => table.markdownDirty.equals(false))).get();
    final changes = <CharacterMarkdownExternalChange>[];
    for (final row in rows) {
      final source = await store.read(row.id);
      if (source == null || source == row.markdownMirror) continue;
      try {
        final imported = _markdownCodec.decode(source).character;
        if (imported.id != row.id) continue;
        final refs = await _loadRefs(row.id);
        changes.add(
          CharacterMarkdownExternalChange(
            existing: _toCharacter(row, refs),
            imported: imported,
          ),
        );
      } on CharacterMarkdownFormatException {
        // Invalid external drafts are left untouched and can still be opened
        // manually through the import action for a readable validation error.
      }
    }
    return changes;
  }

  @override
  Future<void> archive(String id) async {
    final db = _database;
    await (db.update(db.characters)..where((t) => t.id.equals(id))).write(
      CharactersCompanion(archivedAt: Value(DateTime.now())),
    );
  }

  @override
  Future<void> delete(String id) async {
    final db = _database;
    await db.transaction(() async {
      await (db.delete(
        db.characterContentRefs,
      )..where((t) => t.characterId.equals(id))).go();
      await (db.delete(db.characters)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<List<CharacterContentReference>> _loadRefs(String characterId) async {
    final db = _database;
    final rows =
        await (db.select(db.characterContentRefs)
              ..where((t) => t.characterId.equals(characterId))
              ..orderBy([(t) => OrderingTerm.asc(t.slot)]))
            .get();
    return rows
        .map(
          (row) => CharacterContentReference(
            slot: row.slot,
            entryKey: row.entryKey,
            sourceRevision: row.sourceRevision,
            snapshot: row.snapshotJson.isEmpty
                ? const <String, Object?>{}
                : Map<String, Object?>.from(
                    jsonDecode(row.snapshotJson) as Map,
                  ),
          ),
        )
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
