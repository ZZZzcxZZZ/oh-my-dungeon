import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'character_markdown_mirror_store_base.dart';

CharacterMarkdownMirrorStore createCharacterMarkdownMirrorStore(
  String workspaceStorageKey,
) {
  return FileCharacterMarkdownMirrorStore(
    workspaceStorageKey: workspaceStorageKey,
  );
}

final class FileCharacterMarkdownMirrorStore
    implements CharacterMarkdownMirrorStore {
  FileCharacterMarkdownMirrorStore({required this.workspaceStorageKey});

  final String workspaceStorageKey;

  @override
  Future<String?> read(String characterId) async {
    final file = await _file(characterId);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> write({
    required String characterId,
    required String markdown,
  }) async {
    final target = await _file(characterId);
    await target.parent.create(recursive: true);
    final temporary = File('${target.path}.tmp');
    final backup = File('${target.path}.bak');
    await temporary.writeAsString(markdown, flush: true);
    if (await target.exists()) {
      if (await backup.exists()) await backup.delete();
      await target.rename(backup.path);
    }
    try {
      await temporary.rename(target.path);
      if (await backup.exists()) await backup.delete();
    } on Object {
      if (await backup.exists() && !await target.exists()) {
        await backup.rename(target.path);
      }
      rethrow;
    }
  }

  Future<File> _file(String characterId) async {
    final root = await getApplicationSupportDirectory();
    return File(
      path.join(
        root.path,
        'dnd-table',
        'workspaces',
        workspaceStorageKey,
        'characters',
        _safeSegment(characterId),
        'character.md',
      ),
    );
  }

  String _safeSegment(String value) {
    final readable = value
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^[._]+|[._]+$'), '');
    final hash = sha256
        .convert(utf8.encode(value))
        .toString()
        .substring(0, 12);
    return '${readable.isEmpty ? 'character' : readable}-$hash';
  }
}
