import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/room.dart';

abstract class RoomClient {
  Future<List<Room>> listRooms({required String apiBaseUrl});

  Future<Room> createRoom({required String apiBaseUrl, required String name});
}

class RoomApiClient implements RoomClient {
  RoomApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  @override
  Future<List<Room>> listRooms({required String apiBaseUrl}) async {
    final normalizedApiBaseUrl = apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    final response = await _httpClient.get(
      Uri.parse('$normalizedApiBaseUrl/rooms'),
    );

    if (response.statusCode != 200) {
      throw RoomApiException(
        'Room list request failed with HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body) as List<Object?>;
    return decoded
        .map((item) => Room.fromJson(item! as Map<String, Object?>))
        .toList(growable: false);
  }

  @override
  Future<Room> createRoom({
    required String apiBaseUrl,
    required String name,
  }) async {
    final normalizedApiBaseUrl = apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    final response = await _httpClient.post(
      Uri.parse('$normalizedApiBaseUrl/rooms'),
      headers: {'content-type': 'application/json', 'x-client-mode': 'dm'},
      body: jsonEncode({'name': name}),
    );

    if (response.statusCode != 201) {
      throw RoomApiException(
        'Room creation failed with HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    return Room.fromJson(decoded);
  }
}

class RoomApiException implements Exception {
  const RoomApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
