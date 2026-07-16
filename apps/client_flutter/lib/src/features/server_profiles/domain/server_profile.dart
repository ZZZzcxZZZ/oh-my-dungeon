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
      apiBaseUrl: normalizeApiBaseUrl(metadata.apiBaseUrl),
      websocketUrl: metadata.websocketUrl,
      lastKnownVersion: metadata.version,
    );
  }

  ServerProfile copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? apiBaseUrl,
    String? websocketUrl,
    String? lastKnownVersion,
  }) {
    return ServerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      websocketUrl: websocketUrl ?? this.websocketUrl,
      lastKnownVersion: lastKnownVersion ?? this.lastKnownVersion,
    );
  }

  factory ServerProfile.fromJson(Map<String, Object?> json) {
    return ServerProfile(
      id: json['id']! as String,
      name: json['name']! as String,
      baseUrl: json['baseUrl']! as String,
      apiBaseUrl: normalizeApiBaseUrl(json['apiBaseUrl']! as String),
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

  /// All server APIs use the stable `/api` prefix. Older previews persisted
  /// the server origin here, so normalize that legacy shape while loading it.
  static String normalizeApiBaseUrl(String value) {
    final normalized = value.replaceFirst(RegExp(r'/+$'), '');
    return normalized.endsWith('/api') ? normalized : '$normalized/api';
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
