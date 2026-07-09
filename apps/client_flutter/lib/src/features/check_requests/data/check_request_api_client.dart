import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/check_request.dart';

abstract class CheckRequestClient {
  Future<CheckRequest> createCheckRequest({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
    required String label,
    String? checkType,
    String? ability,
    String? skill,
    int? dc,
    String? dcVisibility,
    String? targetMode,
    List<String>? targetUserIds,
    List<String>? targetCharacterIds,
  });

  Future<List<CheckRequest>> listCheckRequests({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  });

  Future<CheckResponse> respondToCheckRequest({
    required String apiBaseUrl,
    required String accessToken,
    required String requestId,
    required String actorName,
    int? modifier,
    String? characterId,
  });

  Future<CheckRequest> closeCheckRequest({
    required String apiBaseUrl,
    required String accessToken,
    required String requestId,
  });
}

class CheckRequestApiClient implements CheckRequestClient {
  CheckRequestApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  @override
  Future<CheckRequest> createCheckRequest({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
    required String label,
    String? checkType,
    String? ability,
    String? skill,
    int? dc,
    String? dcVisibility,
    String? targetMode,
    List<String>? targetUserIds,
    List<String>? targetCharacterIds,
  }) async {
    final body = <String, Object?>{'label': label};
    if (checkType != null) body['checkType'] = checkType;
    if (ability != null) body['ability'] = ability;
    if (skill != null) body['skill'] = skill;
    if (dc != null) body['dc'] = dc;
    if (dcVisibility != null) body['dcVisibility'] = dcVisibility;
    if (targetMode != null) body['targetMode'] = targetMode;
    if (targetUserIds != null) body['targetUserIds'] = targetUserIds;
    if (targetCharacterIds != null) {
      body['targetCharacterIds'] = targetCharacterIds;
    }

    final response = await _httpClient.post(
      Uri.parse('${_normalize(apiBaseUrl)}/sessions/$sessionId/check-requests'),
      headers: _headers(accessToken),
      body: jsonEncode(body),
    );

    if (response.statusCode != 201) {
      throw _toException(response);
    }

    return CheckRequest.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<List<CheckRequest>> listCheckRequests({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('${_normalize(apiBaseUrl)}/sessions/$sessionId/check-requests'),
      headers: {'authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw _toException(response);
    }

    final decoded = jsonDecode(response.body) as List<Object?>;
    return decoded
        .map((item) => CheckRequest.fromJson(item as Map<String, Object?>))
        .toList();
  }

  @override
  Future<CheckResponse> respondToCheckRequest({
    required String apiBaseUrl,
    required String accessToken,
    required String requestId,
    required String actorName,
    int? modifier,
    String? characterId,
  }) async {
    final body = <String, Object?>{'actorName': actorName};
    if (modifier != null) body['modifier'] = modifier;
    if (characterId != null) body['characterId'] = characterId;

    final response = await _httpClient.post(
      Uri.parse(
        '${_normalize(apiBaseUrl)}/check-requests/$requestId/responses',
      ),
      headers: _headers(accessToken),
      body: jsonEncode(body),
    );

    if (response.statusCode != 201) {
      throw _toException(response);
    }

    return CheckResponse.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<CheckRequest> closeCheckRequest({
    required String apiBaseUrl,
    required String accessToken,
    required String requestId,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('${_normalize(apiBaseUrl)}/check-requests/$requestId/close'),
      headers: _headers(accessToken),
    );

    if (response.statusCode != 200) {
      throw _toException(response);
    }

    return CheckRequest.fromJson(
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

CheckRequestApiException _toException(http.Response response) {
  String message;
  try {
    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    message = decoded['message']! as String;
  } catch (_) {
    message = 'Check request failed with HTTP ${response.statusCode}.';
  }
  return CheckRequestApiException(message, statusCode: response.statusCode);
}

class CheckRequestApiException implements Exception {
  const CheckRequestApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
