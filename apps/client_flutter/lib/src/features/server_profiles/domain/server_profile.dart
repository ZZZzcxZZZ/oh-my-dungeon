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

  factory ServerProfile.fromJson(Map<String, Object?> json) {
    return ServerProfile(
      id: json['id']! as String,
      name: json['name']! as String,
      baseUrl: json['baseUrl']! as String,
      apiBaseUrl: json['apiBaseUrl']! as String,
      websocketUrl: json['websocketUrl']! as String,
      lastKnownVersion: json['lastKnownVersion']! as String,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'baseUrl': baseUrl,
      'apiBaseUrl': apiBaseUrl,
      'websocketUrl': websocketUrl,
      'lastKnownVersion': lastKnownVersion,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ServerProfile &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            name == other.name &&
            baseUrl == other.baseUrl &&
            apiBaseUrl == other.apiBaseUrl &&
            websocketUrl == other.websocketUrl &&
            lastKnownVersion == other.lastKnownVersion;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      baseUrl,
      apiBaseUrl,
      websocketUrl,
      lastKnownVersion,
    );
  }
}
