/// Task 3.1 — CampaignEvent 事件层客户端领域模型.
///
/// 形式化战役事件的命名空间. 服务端持久化为 kind='system' 的
/// CampaignChatMessage, 客户端通过 [CampaignEvent.eventType] 分发渲染.
class CampaignEvent {
  const CampaignEvent({
    required this.id,
    required this.campaignId,
    required this.senderId,
    required this.campaignActorId,
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
  final String? campaignActorId;
  final String displayName;
  final String kind;
  final String content;
  final Map<String, Object?> eventData;
  final String createdAt;

  /// 事件类型 (eventData.eventType), 例如 'actor.hp_changed'.
  /// 不存在时返回空字符串.
  String get eventType => eventData['eventType']?.toString() ?? '';

  factory CampaignEvent.fromJson(Map<String, Object?> json) {
    final eventData = json['eventData'];
    return CampaignEvent(
      id: json['id']?.toString() ?? '',
      campaignId: json['campaignId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      campaignActorId: json['campaignActorId'] as String?,
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
        'campaignActorId': campaignActorId,
        'displayName': displayName,
        'kind': kind,
        'content': content,
        'eventData': eventData,
        'createdAt': createdAt,
      };
}

/// CampaignEvent 事件类型常量.
class CampaignEventTypes {
  static const actorHpChanged = 'actor.hp_changed';
  static const actorItemGranted = 'actor.item_granted';
  static const rollDice = 'roll.dice';
  static const rollCheck = 'roll.check';
  static const archivePublished = 'archive.published';
  static const systemNotice = 'system.notice';

  const CampaignEventTypes._();
}

/// 原子事件操作的返回: 同时返回更新后的 actor 和追加的事件消息.
class CampaignEventResult {
  const CampaignEventResult({required this.actor, required this.event});

  /// 更新后的 actor 快照 (revision 已递增).
  final Map<String, Object?> actor;

  /// kind='system' 的事件消息, 已广播到战役聊天.
  final CampaignEvent event;

  factory CampaignEventResult.fromJson(Map<String, Object?> json) {
    final actor = json['actor'];
    return CampaignEventResult(
      actor: actor is Map
          ? Map<String, Object?>.from(actor)
          : const <String, Object?>{},
      event: CampaignEvent.fromJson(
        json['event'] is Map ? Map<String, Object?>.from(json['event'] as Map) : const {},
      ),
    );
  }
}
