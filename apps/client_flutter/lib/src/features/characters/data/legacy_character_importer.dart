import '../domain/character.dart';
import '../../vault/domain/vault_models.dart';
import 'character_repository.dart';

/// 拉取旧服务器上的角色列表，用于一次性迁移到本地。
abstract class LegacyCharacterClient {
  Future<List<CharacterSheet>> list(VaultSession session);
}

/// 一次性迁移标记存储。生产实现使用 Drift `MigrationMarkers` 表。
abstract class MigrationMarkers {
  Future<bool> contains(String key);
  Future<void> markCompleted(String key);
}

/// 把旧服务器上的角色安全迁移到本地。
///
/// 首次运行时拉取远端角色：本地不存在相同 ID 则直接导入；相同 ID 且内容不同
/// 则保留本地角色，把远端角色以新本地 UUID 和“（服务器导入）”后缀复制一份。
/// 全部成功后写入 marker，保证幂等。任何失败都不写 marker，异常向上抛出。
class LegacyCharacterImporter {
  LegacyCharacterImporter(this._local, this._legacy, this._markers);

  final CharacterRepository _local;
  final LegacyCharacterClient _legacy;
  final MigrationMarkers _markers;

  Future<void> run(VaultSession session) async {
    final markerKey =
        'legacy-characters:${_serverKey(session.baseUrl)}:${session.remoteUserId}';
    if (await _markers.contains(markerKey)) return;

    final remoteCharacters = await _legacy.list(session);

    for (final remote in remoteCharacters) {
      final existing = await _local.getById(remote.id);
      if (existing == null) {
        await _local.save(remote);
      } else if (_contentMatches(existing, remote)) {
        continue;
      } else {
        await _local.save(_copyWithNewId(remote));
      }
    }

    await _markers.markCompleted(markerKey);
  }

  bool _contentMatches(CharacterSheet a, CharacterSheet b) {
    return a.name == b.name &&
        a.notes == b.notes &&
        a.level == b.level &&
        a.classSummary == b.classSummary;
  }

  String _serverKey(String baseUrl) {
    return Uri.tryParse(baseUrl)?.host ?? baseUrl;
  }

  String _generateLocalId() {
    final now = DateTime.now();
    return 'local-${now.millisecondsSinceEpoch}-${now.microsecond.toRadixString(36)}';
  }

  CharacterSheet _copyWithNewId(CharacterSheet original) {
    final json = original.toJson();
    json['id'] = _generateLocalId();
    json['name'] = '${original.name}（服务器导入）';
    return CharacterSheet.fromJson(json);
  }
}
