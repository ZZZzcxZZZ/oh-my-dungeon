import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/character_document.dart';

abstract interface class CharacterOperationsClient {
  Future<CharacterOperationResult> adjustHitPoints({
    required String apiBaseUrl,
    required String accessToken,
    required String characterId,
    required String requestId,
    String? campaignId,
    int? expectedRevision,
    int? delta,
    int? current,
    int? temporary,
  });

  Future<CharacterOperationResult> addCondition({
    required String apiBaseUrl,
    required String accessToken,
    required String characterId,
    required String requestId,
    required Map<String, Object?> condition,
    String? campaignId,
    int? expectedRevision,
  });

  Future<CharacterOperationResult> removeCondition({
    required String apiBaseUrl,
    required String accessToken,
    required String characterId,
    required String requestId,
    required String conditionId,
    String? campaignId,
    int? expectedRevision,
  });

  Future<CharacterOperationResult> consumeResource({
    required String apiBaseUrl,
    required String accessToken,
    required String characterId,
    required String requestId,
    required String resourceId,
    int amount = 1,
    String? campaignId,
    int? expectedRevision,
  });

  Future<CharacterOperationResult> restoreResource({
    required String apiBaseUrl,
    required String accessToken,
    required String characterId,
    required String requestId,
    required String resourceId,
    int amount = 1,
    String? campaignId,
    int? expectedRevision,
  });

  Future<CharacterOperationResult> grantItem({
    required String apiBaseUrl,
    required String accessToken,
    required String characterId,
    required String requestId,
    required Map<String, Object?> item,
    String? campaignId,
    int? expectedRevision,
  });
}

class CharacterOperationResult {
  const CharacterOperationResult({
    required this.state,
    required this.revision,
    required this.event,
  });

  factory CharacterOperationResult.fromJson(Map<String, Object?> json) {
    return CharacterOperationResult(
      state: CharacterDocument.fromJson(_objectMap(json['state'])),
      revision: (json['revision'] as num?)?.toInt() ?? 0,
      event: _objectMap(json['event']),
    );
  }

  final CharacterDocument state;
  final int revision;
  final Map<String, Object?> event;
}

class CharacterApiClient implements CharacterOperationsClient {
  CharacterApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  @override
  Future<CharacterOperationResult> adjustHitPoints({
    required String apiBaseUrl,
    required String accessToken,
    required String characterId,
    required String requestId,
    String? campaignId,
    int? expectedRevision,
    int? delta,
    int? current,
    int? temporary,
  }) {
    return _postOperation(
      apiBaseUrl: apiBaseUrl,
      accessToken: accessToken,
      path: 'characters/$characterId/actions/adjust-hp',
      body: _operationBody(
        requestId: requestId,
        campaignId: campaignId,
        expectedRevision: expectedRevision,
        values: {'delta': ?delta, 'current': ?current, 'temporary': ?temporary},
      ),
    );
  }

  @override
  Future<CharacterOperationResult> addCondition({
    required String apiBaseUrl,
    required String accessToken,
    required String characterId,
    required String requestId,
    required Map<String, Object?> condition,
    String? campaignId,
    int? expectedRevision,
  }) {
    return _postOperation(
      apiBaseUrl: apiBaseUrl,
      accessToken: accessToken,
      path: 'characters/$characterId/actions/add-condition',
      body: _operationBody(
        requestId: requestId,
        campaignId: campaignId,
        expectedRevision: expectedRevision,
        values: {'condition': condition},
      ),
    );
  }

  @override
  Future<CharacterOperationResult> removeCondition({
    required String apiBaseUrl,
    required String accessToken,
    required String characterId,
    required String requestId,
    required String conditionId,
    String? campaignId,
    int? expectedRevision,
  }) {
    return _postOperation(
      apiBaseUrl: apiBaseUrl,
      accessToken: accessToken,
      path: 'characters/$characterId/actions/remove-condition',
      body: _operationBody(
        requestId: requestId,
        campaignId: campaignId,
        expectedRevision: expectedRevision,
        values: {'conditionId': conditionId},
      ),
    );
  }

  @override
  Future<CharacterOperationResult> consumeResource({
    required String apiBaseUrl,
    required String accessToken,
    required String characterId,
    required String requestId,
    required String resourceId,
    int amount = 1,
    String? campaignId,
    int? expectedRevision,
  }) {
    return _resourceOperation(
      apiBaseUrl: apiBaseUrl,
      accessToken: accessToken,
      characterId: characterId,
      requestId: requestId,
      action: 'consume-resource',
      resourceId: resourceId,
      amount: amount,
      campaignId: campaignId,
      expectedRevision: expectedRevision,
    );
  }

  @override
  Future<CharacterOperationResult> restoreResource({
    required String apiBaseUrl,
    required String accessToken,
    required String characterId,
    required String requestId,
    required String resourceId,
    int amount = 1,
    String? campaignId,
    int? expectedRevision,
  }) {
    return _resourceOperation(
      apiBaseUrl: apiBaseUrl,
      accessToken: accessToken,
      characterId: characterId,
      requestId: requestId,
      action: 'restore-resource',
      resourceId: resourceId,
      amount: amount,
      campaignId: campaignId,
      expectedRevision: expectedRevision,
    );
  }

  Future<CharacterOperationResult> _resourceOperation({
    required String apiBaseUrl,
    required String accessToken,
    required String characterId,
    required String requestId,
    required String action,
    required String resourceId,
    required int amount,
    String? campaignId,
    int? expectedRevision,
  }) {
    return _postOperation(
      apiBaseUrl: apiBaseUrl,
      accessToken: accessToken,
      path: 'characters/$characterId/actions/$action',
      body: _operationBody(
        requestId: requestId,
        campaignId: campaignId,
        expectedRevision: expectedRevision,
        values: {'resourceId': resourceId, 'amount': amount},
      ),
    );
  }

  @override
  Future<CharacterOperationResult> grantItem({
    required String apiBaseUrl,
    required String accessToken,
    required String characterId,
    required String requestId,
    required Map<String, Object?> item,
    String? campaignId,
    int? expectedRevision,
  }) {
    return _postOperation(
      apiBaseUrl: apiBaseUrl,
      accessToken: accessToken,
      path: 'characters/$characterId/items',
      body: _operationBody(
        requestId: requestId,
        campaignId: campaignId,
        expectedRevision: expectedRevision,
        values: {'item': item},
      ),
    );
  }

  Future<CharacterOperationResult> _postOperation({
    required String apiBaseUrl,
    required String accessToken,
    required String path,
    required Map<String, Object?> body,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('${_normalize(apiBaseUrl)}/$path'),
      headers: _headers(accessToken),
      body: jsonEncode(body),
    );
    if (response.statusCode != 201) {
      throw _toException(response);
    }
    return CharacterOperationResult.fromJson(
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

Map<String, Object?> _operationBody({
  required String requestId,
  required String? campaignId,
  required int? expectedRevision,
  required Map<String, Object?> values,
}) {
  return {
    'requestId': requestId,
    'campaignId': ?campaignId,
    'expectedRevision': ?expectedRevision,
    ...values,
  };
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is! Map) return {};
  return value.map((key, item) => MapEntry('$key', item));
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
