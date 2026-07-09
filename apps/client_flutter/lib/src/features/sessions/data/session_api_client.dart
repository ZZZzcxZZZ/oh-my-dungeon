import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/session.dart';

abstract class SessionClient {
  Future<Session> createSession({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String name,
  });

  Future<List<Session>> listSessions({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  });

  Future<Session> getSession({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  });

  Future<Session> startSession({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  });

  Future<Session> endSession({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  });

  Future<List<ChatMessage>> listMessages({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  });

  Future<ChatMessage> sendMessage({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
    required String content,
    String? kind,
    String? visibility,
  });

  Future<List<DiceRoll>> listRolls({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  });

  Future<DiceRoll> createRoll({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
    required String notation,
    required String actorName,
    String? visibility,
  });

  Future<List<JournalEntry>> listJournal({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  });
}

class SessionApiClient implements SessionClient {
  SessionApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  @override
  Future<Session> createSession({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String name,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns/$campaignId/sessions'),
      headers: _headers(accessToken),
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode != 201) {
      throw _toException(response);
    }
    return Session.fromJson(jsonDecode(response.body) as Map<String, Object?>);
  }

  @override
  Future<List<Session>> listSessions({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns/$campaignId/sessions'),
      headers: {'authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw _toException(response);
    }
    final decoded = jsonDecode(response.body) as List<Object?>;
    return decoded
        .map((item) => Session.fromJson(item as Map<String, Object?>))
        .toList();
  }

  @override
  Future<Session> getSession({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('${_normalize(apiBaseUrl)}/sessions/$sessionId'),
      headers: {'authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw _toException(response);
    }
    return Session.fromJson(jsonDecode(response.body) as Map<String, Object?>);
  }

  @override
  Future<Session> startSession({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('${_normalize(apiBaseUrl)}/sessions/$sessionId/start'),
      headers: _headers(accessToken),
    );
    if (response.statusCode != 200) {
      throw _toException(response);
    }
    return Session.fromJson(jsonDecode(response.body) as Map<String, Object?>);
  }

  @override
  Future<Session> endSession({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('${_normalize(apiBaseUrl)}/sessions/$sessionId/end'),
      headers: _headers(accessToken),
    );
    if (response.statusCode != 200) {
      throw _toException(response);
    }
    return Session.fromJson(jsonDecode(response.body) as Map<String, Object?>);
  }

  @override
  Future<List<ChatMessage>> listMessages({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('${_normalize(apiBaseUrl)}/sessions/$sessionId/messages'),
      headers: {'authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw _toException(response);
    }
    final decoded = jsonDecode(response.body) as List<Object?>;
    return decoded
        .map((item) => ChatMessage.fromJson(item as Map<String, Object?>))
        .toList();
  }

  @override
  Future<ChatMessage> sendMessage({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
    required String content,
    String? kind,
    String? visibility,
  }) async {
    final body = <String, Object?>{'content': content};
    if (kind != null) body['kind'] = kind;
    if (visibility != null) body['visibility'] = visibility;

    final response = await _httpClient.post(
      Uri.parse('${_normalize(apiBaseUrl)}/sessions/$sessionId/messages'),
      headers: _headers(accessToken),
      body: jsonEncode(body),
    );
    if (response.statusCode != 201) {
      throw _toException(response);
    }
    return ChatMessage.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<List<DiceRoll>> listRolls({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('${_normalize(apiBaseUrl)}/sessions/$sessionId/rolls'),
      headers: {'authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw _toException(response);
    }
    final decoded = jsonDecode(response.body) as List<Object?>;
    return decoded
        .map((item) => DiceRoll.fromJson(item as Map<String, Object?>))
        .toList();
  }

  @override
  Future<DiceRoll> createRoll({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
    required String notation,
    required String actorName,
    String? visibility,
  }) async {
    final body = <String, Object?>{
      'notation': notation,
      'actorName': actorName,
    };
    if (visibility != null) body['visibility'] = visibility;

    final response = await _httpClient.post(
      Uri.parse('${_normalize(apiBaseUrl)}/sessions/$sessionId/rolls'),
      headers: _headers(accessToken),
      body: jsonEncode(body),
    );
    if (response.statusCode != 201) {
      throw _toException(response);
    }
    return DiceRoll.fromJson(jsonDecode(response.body) as Map<String, Object?>);
  }

  @override
  Future<List<JournalEntry>> listJournal({
    required String apiBaseUrl,
    required String accessToken,
    required String sessionId,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('${_normalize(apiBaseUrl)}/sessions/$sessionId/journal'),
      headers: {'authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw _toException(response);
    }
    final decoded = jsonDecode(response.body) as List<Object?>;
    return decoded
        .map((item) => JournalEntry.fromJson(item as Map<String, Object?>))
        .toList();
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

SessionApiException _toException(http.Response response) {
  String message;
  try {
    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    message = decoded['message']! as String;
  } catch (_) {
    message = 'Session request failed with HTTP ${response.statusCode}.';
  }
  return SessionApiException(message, statusCode: response.statusCode);
}

class SessionApiException implements Exception {
  const SessionApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
