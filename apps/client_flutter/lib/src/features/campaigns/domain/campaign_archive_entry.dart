/// 战役档案条目。由 DM 或条目创建者维护的战役 Wiki 内容。
///
/// Plan 2026-07-23 task 3: 档案升级为可阅读、可编辑、可搜索的 Wiki。
/// 正文以 `bodyBlocks` 结构化存储，辅以 `tags`、`links`、`attachmentRefs`。
/// 这些字段存储在服务端的 `payload` JSON 中，客户端通过类型安全的
/// getter 访问。
///
/// Plan 2026-07-23 task 4.3: 服务端在 list 响应中附带编辑者/创建者署名
/// 快照（`updatedByName`/`createdByName`），客户端据此在详情页底部与
/// 列表行展示「由 张三」字样。署名为服务端快照，避免每次渲染都发起
/// 用户查询；用户改名后下次 list 刷新即更新。
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
    this.createdByName,
    this.updatedByName,
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

  /// 创建者显示名快照（来自服务端 list 响应）。可能为 null：服务端
  /// 未提供该字段，或对应用户已不存在。
  final String? createdByName;

  /// 最后修改者显示名快照（来自服务端 list 响应）。可能为 null。
  /// 详情页底部优先使用此字段；缺失时回退到 [createdByName]。
  final String? updatedByName;

  /// 详情页与列表行使用的署名：优先 [updatedByName]，其次
  /// [createdByName]，均缺失时返回 null（UI 不展示「由 ...」字样）。
  String? get editorName => updatedByName ?? createdByName;

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
  ///
  /// Plan 2026-07-23 task 4.1: 当 `body` 缺失但 `bodyBlocks` 存在历史脏数据
  /// （元素为字符串而非对象，客户端 `whereType<Map>` 会全部过滤掉）时，
  /// 把字符串元素拼接为正文，避免详情页正文静默消失。
  String get legacyBody {
    final direct = payload['body'];
    if (direct is String) return direct;
    final raw = payload['bodyBlocks'];
    if (raw is List) {
      final strings = raw.whereType<String>().toList(growable: false);
      if (strings.isNotEmpty) return strings.join('\n\n');
    }
    return '';
  }

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
        createdByName: json['createdByName'] as String?,
        updatedByName: json['updatedByName'] as String?,
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
        if (createdByName != null) 'createdByName': createdByName,
        if (updatedByName != null) 'updatedByName': updatedByName,
      };
}
