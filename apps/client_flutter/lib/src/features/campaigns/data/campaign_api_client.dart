import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/campaign.dart';

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

  Future<CampaignInvite> createInvite({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    String? roleOnJoin,
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
  });

  Future<CampaignChatMessage> sendMessage({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String kind,
    required String content,
    String? characterId,
    String? displayName,
    String? avatarUrl,
  });
}

class CampaignApiClient implements CampaignClient {
  CampaignApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

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
  Future<CampaignInvite> createInvite({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    String? roleOnJoin,
    int? maxUses,
  }) async {
    final body = <String, Object?>{};
    if (roleOnJoin != null) body['roleOnJoin'] = roleOnJoin;
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
  }) async {
    final response = await _httpClient.get(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns/$campaignId/messages'),
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
    String? characterId,
    String? displayName,
    String? avatarUrl,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns/$campaignId/messages'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'kind': kind,
        'content': content,
        'characterId': characterId,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
      }),
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
