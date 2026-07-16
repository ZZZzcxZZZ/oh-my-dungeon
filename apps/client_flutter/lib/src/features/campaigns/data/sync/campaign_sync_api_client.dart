import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/campaign_actor.dart';
import '../../domain/campaign_actor_audit.dart';
import '../../domain/campaign_change.dart';

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

  Future<CampaignActor> publishActor({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String sourceCharacterId,
    required String actorType,
    required int baseRevision,
    required Map<String, Object?> sheet,
  });

  Future<CampaignActor> createActor({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String actorType,
    String? ownerUserId,
    String lifecycle = 'persistent',
    required Map<String, Object?> sheet,
  });

  Future<List<CampaignActor>> listActors({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  });

  Future<CampaignActor> getActor({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String actorId,
  });

  Future<List<CampaignActorAudit>> listActorAudits({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String actorId,
  });

  Future<CampaignActor> updateActor({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String actorId,
    required int baseRevision,
    required Map<String, Object?> sheet,
  });

  Future<CampaignActor> archiveActor({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String actorId,
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
  Future<CampaignActor> publishActor({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String sourceCharacterId,
    required String actorType,
    required int baseRevision,
    required Map<String, Object?> sheet,
  }) async {
    final response = await _client.post(
      Uri.parse(
        '${_normalize(apiBaseUrl)}/campaigns/$campaignId/actors/publish',
      ),
      headers: _headers(accessToken),
      body: jsonEncode({
        'sourceCharacterId': sourceCharacterId,
        'actorType': actorType,
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
    return CampaignActor.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<CampaignActor> createActor({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String actorType,
    String? ownerUserId,
    String lifecycle = 'persistent',
    required Map<String, Object?> sheet,
  }) async {
    final body = <String, Object?>{'actorType': actorType, 'sheet': sheet};
    if (ownerUserId != null) body['ownerUserId'] = ownerUserId;
    if (lifecycle != 'persistent') body['lifecycle'] = lifecycle;
    final response = await _client.post(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns/$campaignId/actors'),
      headers: _headers(accessToken),
      body: jsonEncode(body),
    );
    if (response.statusCode == 409) {
      throw CampaignConflictException(_decodeConflict(response));
    }
    if (response.statusCode != 201) {
      throw _toException(response);
    }
    return CampaignActor.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<List<CampaignActor>> listActors({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async {
    final response = await _client.get(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns/$campaignId/actors'),
      headers: _headers(accessToken),
    );
    if (response.statusCode != 200) {
      throw _toException(response);
    }
    final decoded = jsonDecode(response.body) as List<Object?>;
    return decoded
        .map((item) => CampaignActor.fromJson(item as Map<String, Object?>))
        .toList(growable: false);
  }

  @override
  Future<CampaignActor> getActor({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String actorId,
  }) async {
    final response = await _client.get(
      Uri.parse(
        '${_normalize(apiBaseUrl)}/campaigns/$campaignId/actors/$actorId',
      ),
      headers: _headers(accessToken),
    );
    if (response.statusCode != 200) {
      throw _toException(response);
    }
    return CampaignActor.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<List<CampaignActorAudit>> listActorAudits({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String actorId,
  }) async {
    final response = await _client.get(
      Uri.parse(
        '${_normalize(apiBaseUrl)}/campaigns/$campaignId/actors/$actorId/audits',
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
              CampaignActorAudit.fromJson(Map<String, Object?>.from(item)),
        )
        .toList(growable: false);
  }

  @override
  Future<CampaignActor> updateActor({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String actorId,
    required int baseRevision,
    required Map<String, Object?> sheet,
  }) async {
    final response = await _client.put(
      Uri.parse(
        '${_normalize(apiBaseUrl)}/campaigns/$campaignId/actors/$actorId',
      ),
      headers: _headers(accessToken),
      body: jsonEncode({'baseRevision': baseRevision, 'sheet': sheet}),
    );
    if (response.statusCode == 409) {
      throw CampaignConflictException(_decodeConflict(response));
    }
    if (response.statusCode != 200) {
      throw _toException(response);
    }
    return CampaignActor.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<CampaignActor> archiveActor({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String actorId,
    required int baseRevision,
  }) async {
    final response = await _client.post(
      Uri.parse(
        '${_normalize(apiBaseUrl)}/campaigns/$campaignId/actors/$actorId/archive',
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
    return CampaignActor.fromJson(
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
