class ServerMetadata {
  const ServerMetadata({
    required this.name,
    required this.version,
    required this.apiBaseUrl,
    required this.websocketUrl,
    required this.registrationEnabled,
    required this.serverMode,
    required this.supportedSystems,
  });

  final String name;
  final String version;
  final String apiBaseUrl;
  final String websocketUrl;
  final bool registrationEnabled;
  final String serverMode;
  final List<String> supportedSystems;

  factory ServerMetadata.fromJson(Map<String, Object?> json) {
    return ServerMetadata(
      name: json['name'] as String,
      version: json['version'] as String,
      apiBaseUrl: json['apiBaseUrl'] as String,
      websocketUrl: json['websocketUrl'] as String,
      registrationEnabled: json['registrationEnabled'] as bool,
      serverMode: json['serverMode'] as String,
      supportedSystems: (json['supportedSystems'] as List<Object?>)
          .map((system) => system as String)
          .toList(growable: false),
    );
  }
}
