/// 一条战役变更。entity 字段仅在 operation == 'upsert' 时存在，delete 时为 null。
class CampaignChange {
  const CampaignChange({
    required this.id,
    required this.campaignId,
    required this.cursor,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.revision,
    required this.createdAt,
    this.entity,
  });

  final String id;
  final String campaignId;
  final String cursor;
  final String entityType;
  final String entityId;
  final String operation;
  final int revision;
  final String createdAt;
  final Map<String, Object?>? entity;

  factory CampaignChange.fromJson(Map<String, Object?> json) {
    final entity = json['entity'];
    final revisionValue = json['revision'];
    return CampaignChange(
      id: json['id']?.toString() ?? '',
      campaignId: json['campaignId']?.toString() ?? '',
      cursor: json['cursor']?.toString() ?? '0',
      entityType: json['entityType']?.toString() ?? '',
      entityId: json['entityId']?.toString() ?? '',
      operation: json['operation']?.toString() ?? '',
      revision: revisionValue is num ? revisionValue.toInt() : 0,
      createdAt: json['createdAt']?.toString() ?? '',
      entity: entity is Map
          ? Map<String, Object?>.from(entity)
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CampaignChange &&
        id == other.id &&
        campaignId == other.campaignId &&
        cursor == other.cursor &&
        entityType == other.entityType &&
        entityId == other.entityId &&
        operation == other.operation &&
        revision == other.revision &&
        createdAt == other.createdAt &&
        _mapEquals(entity, other.entity);
  }

  @override
  int get hashCode => Object.hash(
        id,
        campaignId,
        cursor,
        entityType,
        entityId,
        operation,
        revision,
        createdAt,
        entity == null ? null : Object.hashAllUnordered(entity!.entries),
      );
}

/// 战役内容条目摘要。entry 为松散 JSON 结构。
class CampaignContentEntrySummary {
  const CampaignContentEntrySummary({
    required this.id,
    required this.campaignId,
    required this.type,
    required this.slug,
    required this.name,
    required this.entry,
    required this.revision,
    required this.createdBy,
    required this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String campaignId;
  final String type;
  final String slug;
  final String name;
  final Map<String, Object?> entry;
  final int revision;
  final String createdBy;
  final String updatedBy;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;

  factory CampaignContentEntrySummary.fromJson(Map<String, Object?> json) {
    final entry = json['entry'];
    final revisionValue = json['revision'];
    return CampaignContentEntrySummary(
      id: json['id']?.toString() ?? '',
      campaignId: json['campaignId']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      entry: entry is Map
          ? Map<String, Object?>.from(entry)
          : const <String, Object?>{},
      revision: revisionValue is num ? revisionValue.toInt() : 0,
      createdBy: json['createdBy']?.toString() ?? '',
      updatedBy: json['updatedBy']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
      deletedAt: json['deletedAt'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'campaignId': campaignId,
        'type': type,
        'slug': slug,
        'name': name,
        'entry': entry,
        'revision': revision,
        'createdBy': createdBy,
        'updatedBy': updatedBy,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'deletedAt': deletedAt,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CampaignContentEntrySummary &&
        id == other.id &&
        campaignId == other.campaignId &&
        type == other.type &&
        slug == other.slug &&
        name == other.name &&
        _mapEquals(entry, other.entry) &&
        revision == other.revision &&
        createdBy == other.createdBy &&
        updatedBy == other.updatedBy &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt &&
        deletedAt == other.deletedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        campaignId,
        type,
        slug,
        name,
        revision,
        createdBy,
        updatedBy,
        createdAt,
        updatedAt,
        deletedAt,
        Object.hashAllUnordered(entry.entries),
      );
}

/// 一页战役变更。nextCursor 为空字符串或 '0' 表示无更多数据。
class CampaignChangePage {
  const CampaignChangePage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<CampaignChange> items;
  final String nextCursor;
  final bool hasMore;

  factory CampaignChangePage.fromJson(Map<String, Object?> json) {
    final itemsJson = json['items'] as List<Object?>? ?? const [];
    return CampaignChangePage(
      items: itemsJson
          .whereType<Map<String, Object?>>()
          .map(CampaignChange.fromJson)
          .toList(growable: false),
      nextCursor: json['nextCursor']?.toString() ?? '0',
      hasMore: (json['hasMore'] as bool?) ?? false,
    );
  }
}

bool _mapEquals(Map<String, Object?>? a, Map<String, Object?>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || a[key] != b[key]) return false;
  }
  return true;
}
