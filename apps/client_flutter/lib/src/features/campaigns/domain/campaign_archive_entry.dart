/// 战役档案条目。由 DM 或条目创建者维护的战役 Wiki 内容。
///
/// Plan 2026-07-23 task 3: 档案升级为可阅读、可编辑、可搜索的 Wiki。
/// 正文以 `bodyBlocks` 结构化存储，辅以 `tags`、`links`、`attachmentRefs`。
/// 这些字段存储在服务端的 `payload` JSON 中，客户端通过类型安全的
/// getter 访问。
class CampaignArchiveEntry {
  const CampaignArchiveEntry({
    required this.id,
    required this.campaignId,
    required this.kind,
    required this.title,
    required this.summary,
    required this.payload,
    required this.pinned,
    required this.updatedAt,
    this.createdBy,
  });
  final String id;
  final String campaignId;
  final String kind;
  final String title;
  final String summary;
  final Map<String, Object?> payload;
  final bool pinned;
  final String updatedAt;
  final String? createdBy;

  /// 结构化正文 blocks。每个 block 至少包含 `type` 和 `text` 字段。
  List<Map<String, Object?>> get bodyBlocks {
    final raw = payload['bodyBlocks'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
  }

  /// 标签列表，用于分类与搜索。
  List<String> get tags {
    final raw = payload['tags'];
    if (raw is! List) return const [];
    return raw.whereType<String>().toList(growable: false);
  }

  /// 关联条目（角色、地点、其他档案等）。
  List<Map<String, Object?>> get links {
    final raw = payload['links'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
  }

  /// 附件引用（图片、文件等）。
  List<Map<String, Object?>> get attachmentRefs {
    final raw = payload['attachmentRefs'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
  }

  /// 兼容旧数据：从 `payload.body` 读取纯文本正文。
  String get legacyBody => payload['body'] as String? ?? '';

  factory CampaignArchiveEntry.fromJson(Map<String, Object?> json) =>
      CampaignArchiveEntry(
        id: json['id']! as String,
        campaignId: json['campaignId']! as String,
        kind: json['kind']! as String,
        title: json['title']! as String,
        summary: json['summary'] as String? ?? '',
        payload: json['payload'] is Map
            ? Map<String, Object?>.from(json['payload']! as Map)
            : const {},
        pinned: json['pinned'] as bool? ?? false,
        updatedAt: json['updatedAt']! as String,
        createdBy: json['createdBy'] as String?,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'campaignId': campaignId,
        'kind': kind,
        'title': title,
        'summary': summary,
        'payload': payload,
        'pinned': pinned,
        'updatedAt': updatedAt,
        if (createdBy != null) 'createdBy': createdBy,
      };
}
