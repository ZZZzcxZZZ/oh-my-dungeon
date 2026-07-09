import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/character.dart';

abstract class CharacterClient {
  Future<CharacterSheet> createCharacter({
    required String apiBaseUrl,
    required String accessToken,
    required String name,
    int? level,
    String? classSummary,
    String? raceSummary,
    int? currentHp,
    int? maxHp,
    int? armorClass,
    int? speed,
    int? initiativeBonus,
  });

  Future<List<CharacterSheet>> listCharacters({
    required String apiBaseUrl,
    required String accessToken,
  });

  Future<CharacterSheet> updateCharacter({
    required String apiBaseUrl,
    required String accessToken,
    required String characterId,
    String? campaignId,
    String? name,
    int? level,
    String? classSummary,
    String? raceSummary,
    int? currentHp,
    int? maxHp,
    int? armorClass,
    int? speed,
    int? initiativeBonus,
  });

  Future<CharacterCampaignBinding> bindCharacterToCampaign({
    required String apiBaseUrl,
    required String accessToken,
    required String characterId,
    required String campaignId,
  });

  Future<List<CharacterCampaignBinding>> listCampaignCharacters({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  });

  Future<CharacterSheet> adjustCampaignCharacterHp({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
    int? delta,
    int? currentHp,
  });
}

class CharacterApiClient implements CharacterClient {
  CharacterApiClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  @override
  Future<CharacterSheet> createCharacter({
    required String apiBaseUrl,
    required String accessToken,
    required String name,
    int? level,
    String? classSummary,
    String? raceSummary,
    int? currentHp,
    int? maxHp,
    int? armorClass,
    int? speed,
    int? initiativeBonus,
  }) async {
    final body = <String, Object?>{'name': name};
    if (level != null) body['level'] = level;
    if (classSummary != null) body['classSummary'] = classSummary;
    if (raceSummary != null) body['raceSummary'] = raceSummary;
    if (currentHp != null) body['currentHp'] = currentHp;
    if (maxHp != null) body['maxHp'] = maxHp;
    if (armorClass != null) body['armorClass'] = armorClass;
    if (speed != null) body['speed'] = speed;
    if (initiativeBonus != null) body['initiativeBonus'] = initiativeBonus;

    final response = await _httpClient.post(
      Uri.parse('${_normalize(apiBaseUrl)}/characters'),
      headers: _headers(accessToken),
      body: jsonEncode(body),
    );
    if (response.statusCode != 201) {
      throw _toException(response);
    }
    return CharacterSheet.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<List<CharacterSheet>> listCharacters({
    required String apiBaseUrl,
    required String accessToken,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('${_normalize(apiBaseUrl)}/characters'),
      headers: {'authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw _toException(response);
    }
    final decoded = jsonDecode(response.body) as List<Object?>;
    return decoded
        .map((item) => CharacterSheet.fromJson(item as Map<String, Object?>))
        .toList();
  }

  @override
  Future<CharacterSheet> updateCharacter({
    required String apiBaseUrl,
    required String accessToken,
    required String characterId,
    String? campaignId,
    String? name,
    int? level,
    String? classSummary,
    String? raceSummary,
    int? currentHp,
    int? maxHp,
    int? armorClass,
    int? speed,
    int? initiativeBonus,
  }) async {
    final body = <String, Object?>{};
    if (campaignId != null) body['campaignId'] = campaignId;
    if (name != null) body['name'] = name;
    if (level != null) body['level'] = level;
    if (classSummary != null) body['classSummary'] = classSummary;
    if (raceSummary != null) body['raceSummary'] = raceSummary;
    if (currentHp != null) body['currentHp'] = currentHp;
    if (maxHp != null) body['maxHp'] = maxHp;
    if (armorClass != null) body['armorClass'] = armorClass;
    if (speed != null) body['speed'] = speed;
    if (initiativeBonus != null) body['initiativeBonus'] = initiativeBonus;

    final response = await _httpClient.patch(
      Uri.parse('${_normalize(apiBaseUrl)}/characters/$characterId'),
      headers: _headers(accessToken),
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw _toException(response);
    }
    return CharacterSheet.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<CharacterCampaignBinding> bindCharacterToCampaign({
    required String apiBaseUrl,
    required String accessToken,
    required String characterId,
    required String campaignId,
  }) async {
    final response = await _httpClient.post(
      Uri.parse(
        '${_normalize(apiBaseUrl)}/characters/$characterId/campaign-bindings',
      ),
      headers: _headers(accessToken),
      body: jsonEncode({'campaignId': campaignId}),
    );
    if (response.statusCode != 201) {
      throw _toException(response);
    }
    return CharacterCampaignBinding.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<List<CharacterCampaignBinding>> listCampaignCharacters({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns/$campaignId/characters'),
      headers: {'authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw _toException(response);
    }
    final decoded = jsonDecode(response.body) as List<Object?>;
    return decoded
        .map((item) =>
            CharacterCampaignBinding.fromJson(item as Map<String, Object?>))
        .toList();
  }

  @override
  Future<CharacterSheet> adjustCampaignCharacterHp({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String characterId,
    int? delta,
    int? currentHp,
  }) async {
    final body = <String, Object?>{};
    if (delta != null) body['delta'] = delta;
    if (currentHp != null) body['currentHp'] = currentHp;

    final response = await _httpClient.post(
      Uri.parse(
        '${_normalize(apiBaseUrl)}/campaigns/$campaignId/characters/$characterId/hp',
      ),
      headers: _headers(accessToken),
      body: jsonEncode(body),
    );
    if (response.statusCode != 201) {
      throw _toException(response);
    }
    return CharacterSheet.fromJson(
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

CharacterApiException _toException(http.Response response) {
  String message;
  try {
    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    message = decoded['message']! as String;
  } catch (_) {
    message = 'Character request failed with HTTP ${response.statusCode}.';
  }
  return CharacterApiException(message, statusCode: response.statusCode);
}

class CharacterApiException implements Exception {
  const CharacterApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
