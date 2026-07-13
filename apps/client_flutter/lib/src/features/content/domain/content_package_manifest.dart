class ContentPackageManifest {
  const ContentPackageManifest({
    required this.formatVersion,
    required this.id,
    required this.name,
    required this.version,
    required this.locale,
    required this.system,
    required this.entryCount,
  });

  final int formatVersion;
  final String id;
  final String name;
  final String version;
  final String locale;
  final String system;
  final int entryCount;

  factory ContentPackageManifest.fromJson(Map<String, Object?> json) {
    final formatVersion = json['formatVersion'];
    final id = json['id'];
    final name = json['name'];
    final version = json['version'];
    final locale = json['locale'];
    final system = json['system'];
    final entryCount = json['entryCount'];
    if (formatVersion == null ||
        id == null ||
        name == null ||
        version == null ||
        locale == null ||
        system == null ||
        entryCount == null) {
      throw FormatException(
        'Missing required ContentPackageManifest fields: $json',
      );
    }
    return ContentPackageManifest(
      formatVersion: (formatVersion as num).toInt(),
      id: id as String,
      name: name as String,
      version: version as String,
      locale: locale as String,
      system: system as String,
      entryCount: (entryCount as num).toInt(),
    );
  }

  Map<String, Object?> toJson() => {
        'formatVersion': formatVersion,
        'id': id,
        'name': name,
        'version': version,
        'locale': locale,
        'system': system,
        'entryCount': entryCount,
      };
}
