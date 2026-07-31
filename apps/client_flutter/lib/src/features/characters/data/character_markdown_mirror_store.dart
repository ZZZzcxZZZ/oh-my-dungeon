import 'character_markdown_mirror_store_base.dart';
import 'character_markdown_mirror_store_stub.dart'
    if (dart.library.io) 'character_markdown_mirror_store_io.dart'
    as implementation;

export 'character_markdown_mirror_store_base.dart';

CharacterMarkdownMirrorStore? createCharacterMarkdownMirrorStore(
  String workspaceStorageKey,
) {
  return implementation.createCharacterMarkdownMirrorStore(workspaceStorageKey);
}
