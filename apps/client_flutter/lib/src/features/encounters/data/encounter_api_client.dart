import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/encounter.dart';

abstract class EncounterClient {
  Future<Npc> createNpc({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String name,
    Object? stats,
  });

  Future<Encounter> createEncounter({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String name,
  });

  Future<List<Encounter>> listEncounters({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  });

  Future<Encounter> getEncounter({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
  });

  Future<Encounter> startEncounter({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
  });

  Future<Encounter> advanceTurn({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
  });

  Future<Encounter> endEncounter({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
  });

  Future<EncounterParticipant> updateParticipant({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
    required String participantId,
    int? hpCurrent,
    List<String>? conditions,
  });
}

class EncounterApiClient implements EncounterClient {
  EncounterApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  @override
  Future<Npc> createNpc({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String name,
    Object? stats,
  }) async {
    final body = <String, Object?>{'name': name};
    if (stats != null) body['stats'] = stats;

    final response = await _httpClient.post(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns/$campaignId/npcs'),
      headers: _headers(accessToken),
      body: jsonEncode(body),
    );
    if (response.statusCode != 201) throw _toException(response);
    return Npc.fromJson(jsonDecode(response.body) as Map<String, Object?>);
  }

  @override
  Future<Encounter> createEncounter({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String name,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns/$campaignId/encounters'),
      headers: _headers(accessToken),
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode != 201) throw _toException(response);
    return Encounter.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<List<Encounter>> listEncounters({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns/$campaignId/encounters'),
      headers: {'authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) throw _toException(response);
    final decoded = jsonDecode(response.body) as List<Object?>;
    return decoded
        .map((item) => Encounter.fromJson(item as Map<String, Object?>))
        .toList();
  }

  @override
  Future<Encounter> getEncounter({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('${_normalize(apiBaseUrl)}/encounters/$encounterId'),
      headers: {'authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) throw _toException(response);
    return Encounter.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<Encounter> startEncounter({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
  }) {
    return _postEncounter(
      apiBaseUrl,
      accessToken,
      'encounters/$encounterId/start',
    );
  }

  @override
  Future<Encounter> advanceTurn({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
  }) {
    return _postEncounter(
      apiBaseUrl,
      accessToken,
      'encounters/$encounterId/advance-turn',
    );
  }

  @override
  Future<Encounter> endEncounter({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
  }) {
    return _postEncounter(
      apiBaseUrl,
      accessToken,
      'encounters/$encounterId/end',
    );
  }

  Future<Encounter> _postEncounter(
    String apiBaseUrl,
    String accessToken,
    String path,
  ) async {
    final response = await _httpClient.post(
      Uri.parse('${_normalize(apiBaseUrl)}/$path'),
      headers: _headers(accessToken),
    );
    if (response.statusCode != 201) throw _toException(response);
    return Encounter.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<EncounterParticipant> updateParticipant({
    required String apiBaseUrl,
    required String accessToken,
    required String encounterId,
    required String participantId,
    int? hpCurrent,
    List<String>? conditions,
  }) async {
    final body = <String, Object?>{};
    if (hpCurrent != null) body['hpCurrent'] = hpCurrent;
    if (conditions != null) body['conditions'] = conditions;

    final response = await _httpClient.patch(
      Uri.parse(
        '${_normalize(apiBaseUrl)}/encounters/$encounterId/participants/$participantId',
      ),
      headers: _headers(accessToken),
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) throw _toException(response);
    return EncounterParticipant.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  Map<String, String> _headers(String accessToken) {
    return {
      'content-type': 'application/json',
      'authorization': 'Bearer $accessToken',
    };
  }
}

String _normalize(String apiBaseUrl) {
  return apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
}

EncounterApiException _toException(http.Response response) {
  String message;
  try {
    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    message = decoded['message']! as String;
  } catch (_) {
    message = 'Encounter request failed with HTTP ${response.statusCode}.';
  }
  return EncounterApiException(message, statusCode: response.statusCode);
}

class EncounterApiException implements Exception {
  const EncounterApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
