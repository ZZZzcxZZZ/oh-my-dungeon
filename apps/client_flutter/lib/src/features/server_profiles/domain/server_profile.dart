import 'server_metadata.dart';

class ServerProfile {
  const ServerProfile({
    required this.id,
    String? serverName,
    String? name,
    this.localAlias,
    required this.baseUrl,
    required this.apiBaseUrl,
    required this.websocketUrl,
    required this.lastKnownVersion,
  }) : assert(serverName != null || name != null),
       serverName = serverName ?? name ?? '';

  final String id;
  final String serverName;
  final String? localAlias;
  final String baseUrl;
  final String apiBaseUrl;
  final String websocketUrl;
  final String lastKnownVersion;

  String get instanceId => id;
  String get displayName {
    final alias = localAlias?.trim() ?? '';
    return alias.isEmpty ? serverName : alias;
  }

  /// Compatibility getter for older call sites. New code should choose
  /// [serverName] or [displayName] explicitly.
  String get name => displayName;

  factory ServerProfile.fromMetadata({
    required String baseUrl,
    required ServerMetadata metadata,
  }) {
    return ServerProfile(
      id: metadata.instanceId,
      serverName: metadata.name,
      baseUrl: baseUrl,
      apiBaseUrl: normalizeApiBaseUrl(metadata.apiBaseUrl),
      websocketUrl: metadata.websocketUrl,
      lastKnownVersion: metadata.version,
    );
  }

  ServerProfile copyWith({
    String? id,
    String? serverName,
    String? localAlias,
    String? baseUrl,
    String? apiBaseUrl,
    String? websocketUrl,
    String? lastKnownVersion,
  }) {
    return ServerProfile(
      id: id ?? this.id,
      serverName: serverName ?? this.serverName,
      localAlias: localAlias ?? this.localAlias,
      baseUrl: baseUrl ?? this.baseUrl,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      websocketUrl: websocketUrl ?? this.websocketUrl,
      lastKnownVersion: lastKnownVersion ?? this.lastKnownVersion,
    );
  }

  factory ServerProfile.fromJson(Map<String, Object?> json) {
    return ServerProfile(
      id: (json['instanceId'] ?? json['id'])! as String,
      serverName: (json['serverName'] ?? json['name'])! as String,
      localAlias: json['localAlias'] as String?,
      baseUrl: json['baseUrl']! as String,
      apiBaseUrl: normalizeApiBaseUrl(json['apiBaseUrl']! as String),
      websocketUrl: json['websocketUrl']! as String,
      lastKnownVersion: json['lastKnownVersion']! as String,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'instanceId': instanceId,
      'name': serverName,
      'serverName': serverName,
      'localAlias': localAlias,
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
            serverName == other.serverName &&
            localAlias == other.localAlias &&
            baseUrl == other.baseUrl &&
            apiBaseUrl == other.apiBaseUrl &&
            websocketUrl == other.websocketUrl &&
            lastKnownVersion == other.lastKnownVersion;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      serverName,
      localAlias,
      baseUrl,
      apiBaseUrl,
      websocketUrl,
      lastKnownVersion,
    );
  }
}
