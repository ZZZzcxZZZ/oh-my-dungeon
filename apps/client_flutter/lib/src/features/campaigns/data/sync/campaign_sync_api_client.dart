import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/campaign_character.dart';
import '../../domain/campaign_character_audit.dart';
import '../../domain/campaign_change.dart';
import '../../domain/campaign_event.dart';

/// 战役同步 HTTP 接口的通用错误。
class CampaignSyncException implements Exception {
  const CampaignSyncException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// 远端返回 409 时抛出，携带服务端当前实体快照。
class CampaignConflictException implements Exception {
  const CampaignConflictException(this.current);

  final Map<String, Object?> current;

  @override
  String toString() =>
      'Campaign conflict: server has revision ${current['revision']}';
}

/// 战役角色与内容的同步 HTTP 接口。所有方法要求 Bearer token。
abstract interface class CampaignSyncApiClient {
  Future<CampaignChangePage> listChanges({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String cursor,
    int? limit,
  });

  Future<CampaignCharacter> publishCharacter({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String sourceCharacterId,
    required String characterType,
    required int baseRevision,
    required Map<String, Object?> sheet,
  });

  Future<CampaignCharacter> createCharacter({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterType,
    String? ownerUserId,
    String lifecycle = 'persistent',
    required Map<String, Object?> sheet,
  });

  Future<List<CampaignCharacter>> listCharacters({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  });

  Future<CampaignCharacter> getCharacter({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
  });

  Future<List<CampaignCharacterAudit>> listCharacterAudits({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
  });

  Future<CampaignCharacter> updateCharacter({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
    required int baseRevision,
    required Map<String, Object?> sheet,
    String? lifecycle,
    bool? visibleToPlayers,
  });

  Future<CampaignCharacter> archiveCharacter({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
    required int baseRevision,
  });

  Future<CampaignCharacter> restoreCharacter({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
    required int baseRevision,
  });

  Future<CampaignContentEntrySummary> createEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String type,
    required String slug,
    required String name,
    required Map<String, Object?> entry,
  });

  Future<CampaignContentEntrySummary> updateEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String entryId,
    required int baseRevision,
    required Map<String, Object?> entry,
  });

  Future<void> deleteEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String entryId,
  });

  Future<Map<String, Object?>> validateEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String type,
    required String slug,
    required String name,
    required Map<String, Object?> entry,
  });

  // Task 3.1 — CampaignEvent 原子事件端点.

  /// 调整 character HP (delta < 0 伤害, > 0 治疗), 同事务追加 character.hp_changed 事件.
  Future<CampaignEventResult> changeCharacterHp({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
    required int delta,
    String? reason,
    int? baseRevision,
  });

  /// 给予 character 物品, 同事务追加 character.item_granted 事件.
  Future<CampaignEventResult> grantItem({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
    required String itemId,
    required String name,
    int quantity,
    int? baseRevision,
  });

  /// 给予 character 结构化状态, 同事务追加 character.condition_added 事件.
  Future<CampaignEventResult> addCondition({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
    required String type,
    required String name,
    int? durationRounds,
    int? baseRevision,
  });
}

/// 基于 `package:http` 的实现。构造时注入 [client] 以便测试用 MockClient 替换。
class HttpCampaignSyncApiClient implements CampaignSyncApiClient {
  HttpCampaignSyncApiClient({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<CampaignChangePage> listChanges({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String cursor,
    int? limit,
  }) async {
    final query = <String, String>{'cursor': cursor};
    if (limit != null) query['limit'] = limit.toString();
    final uri = Uri.parse(
      '${_normalize(apiBaseUrl)}/campaigns/$campaignId/changes',
    ).replace(queryParameters: query);
    final response = await _client.get(uri, headers: _headers(accessToken));
    if (response.statusCode != 200) {
      throw _toException(response);
    }
    return CampaignChangePage.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<CampaignCharacter> publishCharacter({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String sourceCharacterId,
    required String characterType,
    required int baseRevision,
    required Map<String, Object?> sheet,
  }) async {
    final response = await _client.post(
      Uri.parse(
        '${_normalize(apiBaseUrl)}/campaigns/$campaignId/characters/publish',
      ),
      headers: _headers(accessToken),
      body: jsonEncode({
        'sourceCharacterId': sourceCharacterId,
        'characterType': characterType,
        'baseRevision': baseRevision,
        'sheet': sheet,
      }),
    );
    if (response.statusCode == 409) {
      throw CampaignConflictException(_decodeConflict(response));
    }
    if (response.statusCode != 201) {
      throw _toException(response);
    }
    return CampaignCharacter.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<CampaignCharacter> createCharacter({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterType,
    String? ownerUserId,
    String lifecycle = 'persistent',
    required Map<String, Object?> sheet,
  }) async {
    final body = <String, Object?>{
      'characterType': characterType,
      'sheet': sheet,
    };
    if (ownerUserId != null) body['ownerUserId'] = ownerUserId;
    if (lifecycle != 'persistent') body['lifecycle'] = lifecycle;
    final response = await _client.post(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns/$campaignId/characters'),
      headers: _headers(accessToken),
      body: jsonEncode(body),
    );
    if (response.statusCode == 409) {
      throw CampaignConflictException(_decodeConflict(response));
    }
    if (response.statusCode != 201) {
      throw _toException(response);
    }
    return CampaignCharacter.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<List<CampaignCharacter>> listCharacters({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async {
    final response = await _client.get(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns/$campaignId/characters'),
      headers: _headers(accessToken),
    );
    if (response.statusCode != 200) {
      throw _toException(response);
    }
    final decoded = jsonDecode(response.body) as List<Object?>;
    return decoded
        .map((item) => CampaignCharacter.fromJson(item as Map<String, Object?>))
        .toList(growable: false);
  }

  @override
  Future<CampaignCharacter> getCharacter({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
  }) async {
    final response = await _client.get(
      Uri.parse(
        '${_normalize(apiBaseUrl)}/campaigns/$campaignId/characters/$characterId',
      ),
      headers: _headers(accessToken),
    );
    if (response.statusCode != 200) {
      throw _toException(response);
    }
    return CampaignCharacter.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<List<CampaignCharacterAudit>> listCharacterAudits({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
  }) async {
    final response = await _client.get(
      Uri.parse(
        '${_normalize(apiBaseUrl)}/campaigns/$campaignId/characters/$characterId/audits',
      ),
      headers: _headers(accessToken),
    );
    if (response.statusCode != 200) {
      throw _toException(response);
    }
    final decoded = jsonDecode(response.body) as List<Object?>;
    return decoded
        .whereType<Map>()
        .map(
          (item) =>
              CampaignCharacterAudit.fromJson(Map<String, Object?>.from(item)),
        )
        .toList(growable: false);
  }

  @override
  Future<CampaignCharacter> updateCharacter({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
    required int baseRevision,
    required Map<String, Object?> sheet,
    String? lifecycle,
    bool? visibleToPlayers,
  }) async {
    final body = <String, Object?>{
      'baseRevision': baseRevision,
      'sheet': sheet,
      'lifecycle': ?lifecycle,
      'visibleToPlayers': ?visibleToPlayers,
    };
    final response = await _client.put(
      Uri.parse(
        '${_normalize(apiBaseUrl)}/campaigns/$campaignId/characters/$characterId',
      ),
      headers: _headers(accessToken),
      body: jsonEncode(body),
    );
    if (response.statusCode == 409) {
      throw CampaignConflictException(_decodeConflict(response));
    }
    if (response.statusCode != 200) {
      throw _toException(response);
    }
    return CampaignCharacter.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<CampaignCharacter> archiveCharacter({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
    required int baseRevision,
  }) async {
    final response = await _client.post(
      Uri.parse(
        '${_normalize(apiBaseUrl)}/campaigns/$campaignId/characters/$characterId/archive',
      ),
      headers: _headers(accessToken),
      body: jsonEncode({'baseRevision': baseRevision}),
    );
    if (response.statusCode == 409) {
      throw CampaignConflictException(_decodeConflict(response));
    }
    if (response.statusCode != 200) {
      throw _toException(response);
    }
    return CampaignCharacter.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<CampaignCharacter> restoreCharacter({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
    required int baseRevision,
  }) async {
    final response = await _client.post(
      Uri.parse(
        '${_normalize(apiBaseUrl)}/campaigns/$campaignId/characters/$characterId/restore',
      ),
      headers: _headers(accessToken),
      body: jsonEncode({'baseRevision': baseRevision}),
    );
    if (response.statusCode == 409) {
      throw CampaignConflictException(_decodeConflict(response));
    }
    if (response.statusCode != 200) {
      throw _toException(response);
    }
    return CampaignCharacter.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<CampaignContentEntrySummary> createEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String type,
    required String slug,
    required String name,
    required Map<String, Object?> entry,
  }) async {
    final response = await _client.post(
      Uri.parse(
        '${_normalize(apiBaseUrl)}/campaigns/$campaignId/content/entries',
      ),
      headers: _headers(accessToken),
      body: jsonEncode({
        'type': type,
        'slug': slug,
        'name': name,
        'entry': entry,
      }),
    );
    if (response.statusCode == 409) {
      throw CampaignConflictException(_decodeConflict(response));
    }
    if (response.statusCode != 201) {
      throw _toException(response);
    }
    return CampaignContentEntrySummary.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<CampaignContentEntrySummary> updateEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String entryId,
    required int baseRevision,
    required Map<String, Object?> entry,
  }) async {
    final response = await _client.put(
      Uri.parse(
        '${_normalize(apiBaseUrl)}/campaigns/$campaignId/content/entries/$entryId',
      ),
      headers: _headers(accessToken),
      body: jsonEncode({'baseRevision': baseRevision, 'entry': entry}),
    );
    if (response.statusCode == 409) {
      throw CampaignConflictException(_decodeConflict(response));
    }
    if (response.statusCode != 200) {
      throw _toException(response);
    }
    return CampaignContentEntrySummary.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<void> deleteEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String entryId,
  }) async {
    final response = await _client.delete(
      Uri.parse(
        '${_normalize(apiBaseUrl)}/campaigns/$campaignId/content/entries/$entryId',
      ),
      headers: _headers(accessToken),
    );
    if (response.statusCode != 200) {
      throw _toException(response);
    }
  }

  @override
  Future<Map<String, Object?>> validateEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String type,
    required String slug,
    required String name,
    required Map<String, Object?> entry,
  }) async {
    final response = await _client.post(
      Uri.parse(
        '${_normalize(apiBaseUrl)}/campaigns/$campaignId/content/entries/validate',
      ),
      headers: _headers(accessToken),
      body: jsonEncode({
        'type': type,
        'slug': slug,
        'name': name,
        'entry': entry,
      }),
    );
    if (response.statusCode != 200) {
      throw _toException(response);
    }
    return Map<String, Object?>.from(jsonDecode(response.body) as Map);
  }

  // Task 3.1 — CampaignEvent 原子事件端点实现.

  @override
  Future<CampaignEventResult> changeCharacterHp({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
    required int delta,
    String? reason,
    int? baseRevision,
  }) async {
    final body = <String, Object?>{'delta': delta};
    if (reason != null && reason.trim().isNotEmpty) {
      body['reason'] = reason.trim();
    }
    if (baseRevision != null) body['baseRevision'] = baseRevision;
    final response = await _client.post(
      Uri.parse(
        '${_normalize(apiBaseUrl)}/campaigns/$campaignId/characters/$characterId/hp',
      ),
      headers: _headers(accessToken),
      body: jsonEncode(body),
    );
    if (response.statusCode == 409) {
      throw CampaignConflictException(_decodeConflict(response));
    }
    if (response.statusCode != 201) {
      throw _toException(response);
    }
    return CampaignEventResult.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<CampaignEventResult> grantItem({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
    required String itemId,
    required String name,
    int quantity = 1,
    int? baseRevision,
  }) async {
    final body = <String, Object?>{
      'itemId': itemId,
      'name': name,
      'quantity': quantity,
    };
    if (baseRevision != null) body['baseRevision'] = baseRevision;
    final response = await _client.post(
      Uri.parse(
        '${_normalize(apiBaseUrl)}/campaigns/$campaignId/characters/$characterId/items',
      ),
      headers: _headers(accessToken),
      body: jsonEncode(body),
    );
    if (response.statusCode == 409) {
      throw CampaignConflictException(_decodeConflict(response));
    }
    if (response.statusCode != 201) {
      throw _toException(response);
    }
    return CampaignEventResult.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<CampaignEventResult> addCondition({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
    required String type,
    required String name,
    int? durationRounds,
    int? baseRevision,
  }) async {
    final body = <String, Object?>{'type': type, 'name': name};
    if (durationRounds != null) {
      body['durationRounds'] = durationRounds;
    }
    if (baseRevision != null) body['baseRevision'] = baseRevision;
    final response = await _client.post(
      Uri.parse(
        '${_normalize(apiBaseUrl)}/campaigns/$campaignId/characters/$characterId/conditions',
      ),
      headers: _headers(accessToken),
      body: jsonEncode(body),
    );
    if (response.statusCode == 409) {
      throw CampaignConflictException(_decodeConflict(response));
    }
    if (response.statusCode != 201) {
      throw _toException(response);
    }
    return CampaignEventResult.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  Map<String, String> _headers(String accessToken) => {
    'authorization': 'Bearer $accessToken',
    'content-type': 'application/json',
  };

  String _normalize(String apiBaseUrl) {
    return apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
  }

  Map<String, Object?> _decodeConflict(http.Response response) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, Object?>;
      if (decoded['current'] is Map) {
        return Map<String, Object?>.from(decoded['current'] as Map);
      }
      return decoded;
    } catch (_) {
      return const <String, Object?>{};
    }
  }

  CampaignSyncException _toException(http.Response response) {
    String message;
    try {
      final decoded = jsonDecode(response.body) as Map<String, Object?>;
      message =
          decoded['message']?.toString() ??
          'Campaign sync request failed with HTTP ${response.statusCode}.';
    } catch (_) {
      message =
          'Campaign sync request failed with HTTP ${response.statusCode}.';
    }
    return CampaignSyncException(message, statusCode: response.statusCode);
  }
}
