import '../domain/character.dart';

/// 角色本地持久化接口。UI 只读本地，网络同步只把远端变化合并到本地表。
abstract interface class CharacterRepository {
  Stream<List<CharacterSheet>> watchOwnedCharacters();
  Future<CharacterSheet?> getById(String id);
  Future<void> save(CharacterSheet character);
  Future<void> archive(String id);
  Future<void> delete(String id);
}
