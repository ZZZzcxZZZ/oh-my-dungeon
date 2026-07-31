abstract interface class CharacterMarkdownMirrorStore {
  Future<void> write({required String characterId, required String markdown});

  Future<String?> read(String characterId);
}
