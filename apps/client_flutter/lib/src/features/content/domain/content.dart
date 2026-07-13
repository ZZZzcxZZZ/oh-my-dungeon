class ContentItem {
  const ContentItem({
    required this.id,
    required this.packageId,
    required this.type,
    required this.slug,
    required this.name,
    required this.description,
    required this.structured,
    required this.tags,
    required this.sourceLabel,
    required this.schemaVersion,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String packageId;
  final String type;
  final String slug;
  final String name;
  final String description;
  final Object? structured;
  final Object? tags;
  final String sourceLabel;
  final int schemaVersion;
  final String createdAt;
  final String updatedAt;

  factory ContentItem.fromJson(Map<String, Object?> json) {
    return ContentItem(
      id: json['id']! as String,
      packageId: json['packageId']! as String,
      type: json['type']! as String,
      slug: json['slug']! as String,
      name: json['name']! as String,
      description: json['description']! as String,
      structured: json['structured'],
      tags: json['tags'],
      sourceLabel: json['sourceLabel']! as String,
      schemaVersion: (json['schemaVersion'] as num).toInt(),
      createdAt: json['createdAt']! as String,
      updatedAt: json['updatedAt']! as String,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ContentItem &&
            id == other.id &&
            packageId == other.packageId &&
            type == other.type &&
            slug == other.slug &&
            name == other.name &&
            description == other.description &&
            sourceLabel == other.sourceLabel &&
            schemaVersion == other.schemaVersion &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    packageId,
    type,
    slug,
    name,
    description,
    sourceLabel,
    schemaVersion,
    createdAt,
    updatedAt,
  );
}

class ContentPackage {
  const ContentPackage({
    required this.id,
    required this.scope,
    required this.ownerUserId,
    required this.campaignId,
    required this.name,
    required this.version,
    required this.schemaVersion,
    required this.locale,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.items,
  });

  final String id;
  final String scope;
  final String? ownerUserId;
  final String? campaignId;
  final String name;
  final String version;
  final int schemaVersion;
  final String locale;
  final String status;
  final String createdBy;
  final String createdAt;
  final String updatedAt;
  final List<ContentItem>? items;

  factory ContentPackage.fromJson(Map<String, Object?> json) {
    final itemsJson = json['items'] as List<Object?>?;
    return ContentPackage(
      id: json['id']! as String,
      scope: json['scope']! as String,
      ownerUserId: json['ownerUserId'] as String?,
      campaignId: json['campaignId'] as String?,
      name: json['name']! as String,
      version: json['version']! as String,
      schemaVersion: (json['schemaVersion'] as num).toInt(),
      locale: json['locale']! as String,
      status: json['status']! as String,
      createdBy: json['createdBy']! as String,
      createdAt: json['createdAt']! as String,
      updatedAt: json['updatedAt']! as String,
      items: itemsJson
          ?.map((item) => ContentItem.fromJson(item as Map<String, Object?>))
          .toList(),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ContentPackage &&
            id == other.id &&
            scope == other.scope &&
            ownerUserId == other.ownerUserId &&
            campaignId == other.campaignId &&
            name == other.name &&
            version == other.version &&
            schemaVersion == other.schemaVersion &&
            locale == other.locale &&
            status == other.status &&
            createdBy == other.createdBy &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    scope,
    ownerUserId,
    campaignId,
    name,
    version,
    schemaVersion,
    locale,
    status,
    createdBy,
    createdAt,
    updatedAt,
  );
}

class ImportContentPackageResult {
  const ImportContentPackageResult({
    required this.valid,
    required this.errors,
    required this.package,
  });

  final bool valid;
  final List<String> errors;
  final ContentPackage? package;

  factory ImportContentPackageResult.fromJson(Map<String, Object?> json) {
    final errorsJson = json['errors'] as List<Object?>? ?? const [];
    return ImportContentPackageResult(
      valid: json['valid']! as bool,
      errors: errorsJson.map((item) => item as String).toList(),
      package: json['package'] == null
          ? null
          : ContentPackage.fromJson(json['package']! as Map<String, Object?>),
    );
  }
}

class ContentItemLink {
  const ContentItemLink({required this.relation, required this.label, required this.target});
  final String relation;
  final String label;
  final ContentItem target;
  factory ContentItemLink.fromJson(Map<String, Object?> json) => ContentItemLink(
    relation: json['relation']! as String,
    label: json['label']! as String,
    target: ContentItem.fromJson(json['target']! as Map<String, Object?>),
  );
}

class ContentItemDetail {
  const ContentItemDetail({required this.item, required this.isFavorite, required this.outgoingLinks});
  final ContentItem item;
  final bool isFavorite;
  final List<ContentItemLink> outgoingLinks;
  factory ContentItemDetail.fromJson(Map<String, Object?> json) {
    final links = json['outgoingLinks'] as List<Object?>? ?? const [];
    return ContentItemDetail(
      item: ContentItem.fromJson(json),
      isFavorite: json['isFavorite'] as bool? ?? false,
      outgoingLinks: links.map((entry) => ContentItemLink.fromJson(entry as Map<String, Object?>)).toList(),
    );
  }
}
