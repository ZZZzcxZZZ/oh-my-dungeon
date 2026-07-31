/// Task 3.1 — CampaignEvent 事件层客户端领域模型.
///
/// 形式化战役事件的命名空间. 服务端持久化为 kind='system' 的
/// CampaignChatMessage, 客户端通过 [CampaignEvent.eventType] 分发渲染.
class CampaignEvent {
  const CampaignEvent({
    required this.id,
    required this.campaignId,
    required this.senderId,
    required this.campaignCharacterId,
    required this.displayName,
    required this.kind,
    required this.content,
    required this.eventData,
    required this.createdAt,
  });

  /// 事件消息 ID (CampaignChatMessage.id).
  final String id;
  final String campaignId;
  final String senderId;
  final String? campaignCharacterId;
  final String displayName;
  final String kind;
  final String content;
  final Map<String, Object?> eventData;
  final String createdAt;

  /// 事件类型 (eventData.eventType), 例如 'character.hp_changed'.
  /// 不存在时返回空字符串.
  String get eventType => eventData['eventType']?.toString() ?? '';

  factory CampaignEvent.fromJson(Map<String, Object?> json) {
    final eventData = json['eventData'];
    return CampaignEvent(
      id: json['id']?.toString() ?? '',
      campaignId: json['campaignId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      campaignCharacterId: json['campaignCharacterId'] as String?,
      displayName: json['displayName']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'system',
      content: json['content']?.toString() ?? '',
      eventData: eventData is Map
          ? Map<String, Object?>.from(eventData)
          : const <String, Object?>{},
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'campaignId': campaignId,
    'senderId': senderId,
    'campaignCharacterId': campaignCharacterId,
    'displayName': displayName,
    'kind': kind,
    'content': content,
    'eventData': eventData,
    'createdAt': createdAt,
  };
}

/// CampaignEvent 事件类型常量.
class CampaignEventTypes {
  static const characterHpChanged = 'character.hp_changed';
  static const characterItemGranted = 'character.item_granted';
  static const characterConditionAdded = 'character.condition_added';
  static const rollDice = 'roll.dice';
  static const rollCheck = 'roll.check';
  static const archivePublished = 'archive.published';
  static const systemNotice = 'system.notice';

  const CampaignEventTypes._();
}

/// 原子事件操作的返回: 同时返回更新后的 character 和追加的事件消息.
class CampaignEventResult {
  const CampaignEventResult({required this.character, required this.event});

  /// 更新后的 character 快照 (revision 已递增).
  final Map<String, Object?> character;

  /// kind='system' 的事件消息, 已广播到战役聊天.
  final CampaignEvent event;

  factory CampaignEventResult.fromJson(Map<String, Object?> json) {
    final character = json['character'];
    return CampaignEventResult(
      character: character is Map
          ? Map<String, Object?>.from(character)
          : const <String, Object?>{},
      event: CampaignEvent.fromJson(
        json['event'] is Map
            ? Map<String, Object?>.from(json['event'] as Map)
            : const {},
      ),
    );
  }
}
