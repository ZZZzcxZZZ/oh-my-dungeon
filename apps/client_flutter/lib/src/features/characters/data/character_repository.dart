import '../domain/character.dart';

class CharacterMarkdownExternalChange {
  const CharacterMarkdownExternalChange({
    required this.existing,
    required this.imported,
  });

  final CharacterSheet existing;
  final CharacterSheet imported;
}

abstract interface class CharacterMarkdownChangeRepository {
  Future<List<CharacterMarkdownExternalChange>> detectExternalMarkdownChanges();
}

/// 角色本地持久化接口。UI 只读本地，网络同步只把远端变化合并到本地表。
abstract interface class CharacterRepository {
  Stream<List<CharacterSheet>> watchOwnedCharacters();
  Future<CharacterSheet?> getById(String id);
  Future<void> save(CharacterSheet character);
  Future<void> saveRemote(CharacterSheet character, int syncRevision);
  Future<void> archive(String id);
  Future<void> delete(String id);
}

/// No-op [CharacterRepository] used as a fallback when no database is
/// available (e.g. tests that inject in-memory stores).
class EmptyCharacterRepository implements CharacterRepository {
  @override
  Stream<List<CharacterSheet>> watchOwnedCharacters() => Stream.value(const []);
  @override
  Future<CharacterSheet?> getById(String id) async => null;
  @override
  Future<void> save(CharacterSheet character) async {}
  @override
  Future<void> saveRemote(CharacterSheet character, int syncRevision) async {}
  @override
  Future<void> archive(String id) async {}
  @override
  Future<void> delete(String id) async {}
}
