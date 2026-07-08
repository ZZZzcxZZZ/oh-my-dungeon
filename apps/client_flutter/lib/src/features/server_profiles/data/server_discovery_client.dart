import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/server_metadata.dart';

class ServerDiscoveryClient {
  ServerDiscoveryClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<ServerMetadata> discover(String baseUrl) async {
    final normalizedBaseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.parse('$normalizedBaseUrl/.well-known/dnd-tool-server');
    final response = await _httpClient.get(uri);

    if (response.statusCode != 200) {
      throw ServerDiscoveryException(
        'Server metadata request failed with HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    return ServerMetadata.fromJson(decoded);
  }
}

class ServerDiscoveryException implements Exception {
  const ServerDiscoveryException(this.message);

  final String message;

  @override
  String toString() => message;
}
