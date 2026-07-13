import 'dart:async';

import 'package:dnd_table_client/src/features/characters/data/character_repository.dart';
import 'package:dnd_table_client/src/features/characters/data/legacy_character_importer.dart';
import 'package:dnd_table_client/src/features/characters/domain/character.dart';
import 'package:dnd_table_client/src/features/vault/domain/vault_models.dart';

CharacterSheet testCharacter({
  String id = 'character-1',
  String name = 'Test Hero',
  String notes = '',
  int level = 1,
}) {
  return CharacterSheet.local(
    id: id,
    name: name,
    level: level,
    notes: notes,
  );
}

class MemoryCharacterRepository implements CharacterRepository {
  MemoryCharacterRepository({List<CharacterSheet> initial = const []})
      : _characters = {
          for (final character in initial) character.id: character,
        };

  final Map<String, CharacterSheet> _characters;
  final Set<String> _archived = {};
  final StreamController<List<CharacterSheet>> _controller =
      StreamController<List<CharacterSheet>>.broadcast();

  void _emit() {
    _controller.add(_nonArchived());
  }

  List<CharacterSheet> _nonArchived() {
    return _characters.values
        .where((character) => !_archived.contains(character.id))
        .toList();
  }

  @override
  Stream<List<CharacterSheet>> watchOwnedCharacters() {
    final controller = StreamController<List<CharacterSheet>>.broadcast();
    scheduleMicrotask(() => controller.add(_nonArchived()));
    _controller.stream.listen(controller.add);
    return controller.stream;
  }

  @override
  Future<CharacterSheet?> getById(String id) async => _characters[id];

  @override
  Future<void> save(CharacterSheet character) async {
    _characters[character.id] = character;
    _archived.remove(character.id);
    _emit();
  }

  @override
  Future<void> archive(String id) async {
    _archived.add(id);
    _emit();
  }

  @override
  Future<void> delete(String id) async {
    _characters.remove(id);
    _archived.remove(id);
    _emit();
  }
}

class MemoryLegacyCharacterClient implements LegacyCharacterClient {
  MemoryLegacyCharacterClient({
    this.characters = const [],
    this.throwOnList = false,
  });

  final List<CharacterSheet> characters;
  final bool throwOnList;

  @override
  Future<List<CharacterSheet>> list(VaultSession session) async {
    if (throwOnList) throw Exception('Network error');
    return List.of(characters);
  }
}

class MemoryMigrationMarkers implements MigrationMarkers {
  final Set<String> completed = {};

  @override
  Future<bool> contains(String key) async => completed.contains(key);

  @override
  Future<void> markCompleted(String key) async => completed.add(key);
}
