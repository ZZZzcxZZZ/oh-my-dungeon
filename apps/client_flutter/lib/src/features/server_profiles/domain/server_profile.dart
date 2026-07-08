import 'server_metadata.dart';

class ServerProfile {
  const ServerProfile({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.apiBaseUrl,
    required this.websocketUrl,
    required this.lastKnownVersion,
  });

  final String id;
  final String name;
  final String baseUrl;
  final String apiBaseUrl;
  final String websocketUrl;
  final String lastKnownVersion;

  factory ServerProfile.fromMetadata({
    required String baseUrl,
    required ServerMetadata metadata,
  }) {
    return ServerProfile(
      id: Uri.parse(baseUrl).host,
      name: metadata.name,
      baseUrl: baseUrl,
      apiBaseUrl: metadata.apiBaseUrl,
      websocketUrl: metadata.websocketUrl,
      lastKnownVersion: metadata.version,
    );
  }
}
