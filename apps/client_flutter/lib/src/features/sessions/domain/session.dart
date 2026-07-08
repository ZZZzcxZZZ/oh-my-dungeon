class Session {
  const Session({
    required this.id,
    required this.campaignId,
    required this.name,
    required this.status,
    required this.startedAt,
    required this.endedAt,
    required this.createdAt,
    required this.updatedAt,
    this.members = const [],
    this.recentMessages = const [],
  });

  final String id;
  final String campaignId;
  final String name;
  final String status;
  final String? startedAt;
  final String? endedAt;
  final String createdAt;
  final String updatedAt;
  final List<SessionMember> members;
  final List<ChatMessage> recentMessages;

  factory Session.fromJson(Map<String, Object?> json) {
    return Session(
      id: json['id']! as String,
      campaignId: json['campaignId']! as String,
      name: json['name']! as String,
      status: json['status']! as String,
      startedAt: json['startedAt'] as String?,
      endedAt: json['endedAt'] as String?,
      createdAt: json['createdAt']! as String,
      updatedAt: json['updatedAt']! as String,
      members: (json['members'] as List<Object?>?)
              ?.map((e) => SessionMember.fromJson(e as Map<String, Object?>))
              .toList() ??
          const [],
      recentMessages: (json['recentMessages'] as List<Object?>?)
              ?.map((e) => ChatMessage.fromJson(e as Map<String, Object?>))
              .toList() ??
          const [],
    );
  }

  bool get isActive => status == 'active';
  bool get isScheduled => status == 'scheduled';
  bool get isEnded => status == 'ended';
}

class SessionMember {
  const SessionMember({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    required this.leftAt,
  });

  final String id;
  final String sessionId;
  final String userId;
  final String role;
  final String joinedAt;
  final String? leftAt;

  factory SessionMember.fromJson(Map<String, Object?> json) {
    return SessionMember(
      id: json['id']! as String,
      sessionId: json['sessionId']! as String,
      userId: json['userId']! as String,
      role: json['role']! as String,
      joinedAt: json['joinedAt']! as String,
      leftAt: json['leftAt'] as String?,
    );
  }

  bool get isManager => role == 'owner' || role == 'dm';
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.senderId,
    required this.kind,
    required this.visibility,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String sessionId;
  final String senderId;
  final String kind;
  final String visibility;
  final String content;
  final String createdAt;

  factory ChatMessage.fromJson(Map<String, Object?> json) {
    return ChatMessage(
      id: json['id']! as String,
      sessionId: json['sessionId']! as String,
      senderId: json['senderId']! as String,
      kind: json['kind']! as String,
      visibility: json['visibility']! as String,
      content: json['content']! as String,
      createdAt: json['createdAt']! as String,
    );
  }

  bool get isRoll => kind == 'roll';
  bool get isSystem => kind == 'system';
  bool get isDmOnly => visibility == 'dm';
}

class DiceRoll {
  const DiceRoll({
    required this.id,
    required this.sessionId,
    required this.actorId,
    required this.actorName,
    required this.notation,
    required this.total,
    required this.components,
    required this.visibility,
    required this.createdAt,
  });

  final String id;
  final String sessionId;
  final String actorId;
  final String actorName;
  final String notation;
  final int total;
  final List<DiceRollComponent> components;
  final String visibility;
  final String createdAt;

  factory DiceRoll.fromJson(Map<String, Object?> json) {
    return DiceRoll(
      id: json['id']! as String,
      sessionId: json['sessionId']! as String,
      actorId: json['actorId']! as String,
      actorName: json['actorName']! as String,
      notation: json['notation']! as String,
      total: (json['total'] as num).toInt(),
      components: (json['components'] as List<Object?>?)
              ?.map((e) =>
                  DiceRollComponent.fromJson(e as Map<String, Object?>))
              .toList() ??
          const [],
      visibility: json['visibility']! as String,
      createdAt: json['createdAt']! as String,
    );
  }

  bool get isDmOnly => visibility == 'dm';
  bool get isBlind => visibility == 'blind';
}

class DiceRollComponent {
  const DiceRollComponent({
    required this.notation,
    required this.results,
  });

  final String notation;
  final List<int> results;

  factory DiceRollComponent.fromJson(Map<String, Object?> json) {
    return DiceRollComponent(
      notation: json['notation']! as String,
      results: (json['results'] as List<Object?>)
          .map((e) => (e as num).toInt())
          .toList(),
    );
  }
}

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.sessionId,
    required this.type,
    required this.summary,
    required this.refId,
    required this.createdAt,
  });

  final String id;
  final String sessionId;
  final String type;
  final String summary;
  final String? refId;
  final String createdAt;

  factory JournalEntry.fromJson(Map<String, Object?> json) {
    return JournalEntry(
      id: json['id']! as String,
      sessionId: json['sessionId']! as String,
      type: json['type']! as String,
      summary: json['summary']! as String,
      refId: json['refId'] as String?,
      createdAt: json['createdAt']! as String,
    );
  }
}
