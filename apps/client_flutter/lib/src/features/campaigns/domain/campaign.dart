class Campaign {
  const Campaign({
    required this.id,
    required this.name,
    required this.description,
    required this.system,
    required this.ownerId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
    this.memberPreview = const [],
  });

  final String id;
  final String name;
  final String description;
  final String system;
  final String ownerId;
  final String status;
  final String createdAt;
  final String updatedAt;
  final CampaignChatMessage? lastMessage;
  final List<CampaignMemberPreview> memberPreview;

  factory Campaign.fromJson(Map<String, Object?> json) {
    final lastMessageJson = json['lastMessage'];
    final memberPreviewJson = json['memberPreview'];
    return Campaign(
      id: json['id']! as String,
      name: json['name']! as String,
      description: json['description']! as String,
      system: json['system']! as String,
      ownerId: json['ownerId']! as String,
      status: json['status']! as String,
      createdAt: json['createdAt']! as String,
      updatedAt: json['updatedAt']! as String,
      lastMessage: lastMessageJson is Map<String, Object?>
          ? CampaignChatMessage.fromJson(lastMessageJson)
          : null,
      memberPreview: memberPreviewJson is List
          ? memberPreviewJson
              .whereType<Map<String, Object?>>()
              .map(CampaignMemberPreview.fromJson)
              .toList(growable: false)
          : const [],
    );
  }

  Campaign copyWith({
    CampaignChatMessage? lastMessage,
    List<CampaignMemberPreview>? memberPreview,
  }) {
    return Campaign(
      id: id,
      name: name,
      description: description,
      system: system,
      ownerId: ownerId,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      memberPreview: memberPreview ?? this.memberPreview,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Campaign &&
            id == other.id &&
            name == other.name &&
            description == other.description &&
            system == other.system &&
            ownerId == other.ownerId &&
            status == other.status &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt &&
            lastMessage == other.lastMessage &&
            _listEquals(memberPreview, other.memberPreview);
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        description,
        system,
        ownerId,
        status,
        createdAt,
        updatedAt,
        lastMessage,
        Object.hashAll(memberPreview),
      );
}

class CampaignMemberPreview {
  const CampaignMemberPreview({
    required this.userId,
    required this.displayName,
    required this.role,
  });

  final String userId;
  final String displayName;
  final String role;

  factory CampaignMemberPreview.fromJson(Map<String, Object?> json) {
    return CampaignMemberPreview(
      userId: json['userId']! as String,
      displayName: json['displayName']! as String,
      role: json['role']! as String,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CampaignMemberPreview &&
            userId == other.userId &&
            displayName == other.displayName &&
            role == other.role;
  }

  @override
  int get hashCode => Object.hash(userId, displayName, role);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class CampaignChatMessage {
  const CampaignChatMessage({
    required this.id,
    required this.campaignId,
    required this.senderId,
    required this.characterId,
    required this.displayName,
    required this.avatarUrl,
    required this.kind,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String campaignId;
  final String senderId;
  final String? characterId;
  final String displayName;
  final String? avatarUrl;
  final String kind;
  final String content;
  final String createdAt;

  factory CampaignChatMessage.fromJson(Map<String, Object?> json) {
    return CampaignChatMessage(
      id: json['id']! as String,
      campaignId: json['campaignId']! as String,
      senderId: json['senderId']! as String,
      characterId: json['characterId'] as String?,
      displayName: json['displayName']! as String,
      avatarUrl: json['avatarUrl'] as String?,
      kind: json['kind']! as String,
      content: json['content']! as String,
      createdAt: json['createdAt']! as String,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CampaignChatMessage &&
            id == other.id &&
            campaignId == other.campaignId &&
            senderId == other.senderId &&
            characterId == other.characterId &&
            displayName == other.displayName &&
            avatarUrl == other.avatarUrl &&
            kind == other.kind &&
            content == other.content &&
            createdAt == other.createdAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    campaignId,
    senderId,
    characterId,
    displayName,
    avatarUrl,
    kind,
    content,
    createdAt,
  );
}

class CampaignInvite {
  const CampaignInvite({
    required this.id,
    required this.campaignId,
    required this.code,
    required this.roleOnJoin,
    required this.expiresAt,
    required this.maxUses,
    required this.usedCount,
    required this.requireApproval,
    required this.createdAt,
  });

  final String id;
  final String campaignId;
  final String code;
  final String roleOnJoin;
  final String? expiresAt;
  final int maxUses;
  final int usedCount;
  final bool requireApproval;
  final String createdAt;

  factory CampaignInvite.fromJson(Map<String, Object?> json) {
    return CampaignInvite(
      id: json['id']! as String,
      campaignId: json['campaignId']! as String,
      code: json['code']! as String,
      roleOnJoin: json['roleOnJoin']! as String,
      expiresAt: json['expiresAt'] as String?,
      maxUses: json['maxUses']! as int,
      usedCount: json['usedCount']! as int,
      requireApproval: json['requireApproval']! as bool,
      createdAt: json['createdAt']! as String,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CampaignInvite &&
            id == other.id &&
            campaignId == other.campaignId &&
            code == other.code &&
            roleOnJoin == other.roleOnJoin &&
            expiresAt == other.expiresAt &&
            maxUses == other.maxUses &&
            usedCount == other.usedCount &&
            requireApproval == other.requireApproval &&
            createdAt == other.createdAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    campaignId,
    code,
    roleOnJoin,
    expiresAt,
    maxUses,
    usedCount,
    requireApproval,
    createdAt,
  );
}

class CampaignMembership {
  const CampaignMembership({
    required this.id,
    required this.campaignId,
    required this.userId,
    required this.role,
    required this.displayName,
    required this.joinedAt,
  });

  final String id;
  final String campaignId;
  final String userId;
  final String role;
  final String displayName;
  final String joinedAt;

  factory CampaignMembership.fromJson(Map<String, Object?> json) {
    return CampaignMembership(
      id: json['id']! as String,
      campaignId: json['campaignId']! as String,
      userId: json['userId']! as String,
      role: json['role']! as String,
      displayName: json['displayName']! as String,
      joinedAt: json['joinedAt']! as String,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CampaignMembership &&
            id == other.id &&
            campaignId == other.campaignId &&
            userId == other.userId &&
            role == other.role &&
            displayName == other.displayName &&
            joinedAt == other.joinedAt;
  }

  @override
  int get hashCode =>
      Object.hash(id, campaignId, userId, role, displayName, joinedAt);
}
