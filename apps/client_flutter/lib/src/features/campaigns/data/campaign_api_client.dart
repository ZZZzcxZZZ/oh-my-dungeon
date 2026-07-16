import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/campaign.dart';
import '../domain/campaign_archive_entry.dart';

abstract class CampaignClient {
  Future<Campaign> createCampaign({
    required String apiBaseUrl,
    required String accessToken,
    required String name,
    String? description,
    String? system,
  });

  Future<List<Campaign>> listCampaigns({
    required String apiBaseUrl,
    required String accessToken,
  });

  Future<Campaign> getCampaign({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  });

  Future<CampaignWorkspaceContext> getWorkspaceContext({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  });

  Future<CampaignMembership> updateSpeaker({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String speakerMode,
    String? actorId,
  });

  Future<void> markCampaignRead({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  });

  Future<CampaignInvite> createInvite({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    int? maxUses,
  });

  Future<List<CampaignInvite>> listInvites({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  });

  Future<CampaignMembership> joinCampaign({
    required String apiBaseUrl,
    required String accessToken,
    required String code,
  });

  Future<List<CampaignChatMessage>> listMessages({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    String? query,
  });

  Future<CampaignChatMessage> sendMessage({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String kind,
    required String content,
    String? campaignActorId,
    String? actionId,
    Map<String, Object?>? eventData,
  });

  Future<List<CampaignArchiveEntry>> listArchives({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    String? kind,
  });

  Future<CampaignArchiveEntry> createArchiveEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String kind,
    required String title,
    String? summary,
    Map<String, Object?>? payload,
  });

  Future<CampaignArchiveEntry> updateArchiveEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String entryId,
    String? kind,
    String? title,
    String? summary,
    Map<String, Object?>? payload,
    bool? pinned,
  });

  Future<void> archiveEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String entryId,
  });
}

class CampaignApiClient implements CampaignClient {
  CampaignApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  @override
  Future<List<CampaignArchiveEntry>> listArchives({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    String? kind,
  }) async {
    final uri = Uri.parse(
      '${_normalize(apiBaseUrl)}/campaigns/$campaignId/archives',
    ).replace(queryParameters: kind == null ? null : {'kind': kind});
    final response = await _httpClient.get(
      uri,
      headers: {'authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) throw _toException(response);
    return (jsonDecode(response.body) as List)
        .map(
          (item) => CampaignArchiveEntry.fromJson(
            Map<String, Object?>.from(item as Map),
          ),
        )
        .toList();
  }

  @override
  Future<CampaignArchiveEntry> createArchiveEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String kind,
    required String title,
    String? summary,
    Map<String, Object?>? payload,
  }) async {
    final body = <String, Object?>{'kind': kind, 'title': title};
    if (summary != null) body['summary'] = summary;
    if (payload != null) body['payload'] = payload;
    final response = await _httpClient.post(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns/$campaignId/archives'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode != 201) throw _toException(response);
    return CampaignArchiveEntry.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<CampaignArchiveEntry> updateArchiveEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String entryId,
    String? kind,
    String? title,
    String? summary,
    Map<String, Object?>? payload,
    bool? pinned,
  }) async {
    final body = <String, Object?>{};
    if (kind != null) body['kind'] = kind;
    if (title != null) body['title'] = title;
    if (summary != null) body['summary'] = summary;
    if (payload != null) body['payload'] = payload;
    if (pinned != null) body['pinned'] = pinned;
    final response = await _httpClient.put(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns/$campaignId/archives/$entryId'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) throw _toException(response);
    return CampaignArchiveEntry.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<void> archiveEntry({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String entryId,
  }) async {
    final response = await _httpClient.delete(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns/$campaignId/archives/$entryId'),
      headers: {'authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) throw _toException(response);
  }

  @override
  Future<Campaign> createCampaign({
    required String apiBaseUrl,
    required String accessToken,
    required String name,
    String? description,
    String? system,
  }) async {
    final body = <String, Object?>{'name': name};
    if (description != null) body['description'] = description;
    if (system != null) body['system'] = system;

    final response = await _httpClient.post(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 201) {
      throw _toException(response);
    }

    return Campaign.fromJson(jsonDecode(response.body) as Map<String, Object?>);
  }

  @override
  Future<List<Campaign>> listCampaigns({
    required String apiBaseUrl,
    required String accessToken,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns'),
      headers: {'authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw _toException(response);
    }

    final decoded = jsonDecode(response.body) as List<Object?>;
    return decoded
        .map((item) => Campaign.fromJson(item as Map<String, Object?>))
        .toList();
  }

  @override
  Future<Campaign> getCampaign({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns/$campaignId'),
      headers: {'authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw _toException(response);
    }

    return Campaign.fromJson(jsonDecode(response.body) as Map<String, Object?>);
  }

  @override
  Future<CampaignWorkspaceContext> getWorkspaceContext({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns/$campaignId/context'),
      headers: {'authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw _toException(response);
    }
    return CampaignWorkspaceContext.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<CampaignMembership> updateSpeaker({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String speakerMode,
    String? actorId,
  }) async {
    final body = <String, Object?>{'speakerMode': speakerMode};
    if (actorId != null) body['actorId'] = actorId;
    final response = await _httpClient.put(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns/$campaignId/speaker'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) throw _toException(response);
    return CampaignMembership.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<void> markCampaignRead({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns/$campaignId/read'),
      headers: {'authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 201) throw _toException(response);
  }

  @override
  Future<CampaignInvite> createInvite({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    int? maxUses,
  }) async {
    final body = <String, Object?>{};
    if (maxUses != null) body['maxUses'] = maxUses;

    final response = await _httpClient.post(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns/$campaignId/invites'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 201) {
      throw _toException(response);
    }

    return CampaignInvite.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<List<CampaignInvite>> listInvites({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns/$campaignId/invites'),
      headers: {'authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw _toException(response);
    }

    final decoded = jsonDecode(response.body) as List<Object?>;
    return decoded
        .map((item) => CampaignInvite.fromJson(item as Map<String, Object?>))
        .toList();
  }

  @override
  Future<CampaignMembership> joinCampaign({
    required String apiBaseUrl,
    required String accessToken,
    required String code,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns/join'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'code': code}),
    );

    if (response.statusCode != 201) {
      throw _toException(response);
    }

    return CampaignMembership.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<List<CampaignChatMessage>> listMessages({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    String? query,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns/$campaignId/messages')
          .replace(queryParameters: query == null || query.trim().isEmpty ? null : {'query': query.trim()}),
      headers: {'authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw _toException(response);
    }

    final decoded = jsonDecode(response.body) as List<Object?>;
    return decoded
        .map(
          (item) => CampaignChatMessage.fromJson(item as Map<String, Object?>),
        )
        .toList();
  }

  @override
  Future<CampaignChatMessage> sendMessage({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String kind,
    required String content,
    String? campaignActorId,
    String? actionId,
    Map<String, Object?>? eventData,
  }) async {
    final body = <String, Object?>{
      'kind': kind,
      'content': content,
      'campaignActorId': campaignActorId,
    };
    if (actionId != null) body['actionId'] = actionId;
    if (eventData != null) body['eventData'] = eventData;
    final response = await _httpClient.post(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns/$campaignId/messages'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 201) {
      throw _toException(response);
    }

    return CampaignChatMessage.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }
}

String _normalize(String apiBaseUrl) {
  return apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
}

CampaignApiException _toException(http.Response response) {
  String message;
  try {
    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    message = decoded['message']! as String;
  } catch (_) {
    message = 'Campaign request failed with HTTP ${response.statusCode}.';
  }
  return CampaignApiException(message, statusCode: response.statusCode);
}

class CampaignApiException implements Exception {
  const CampaignApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
