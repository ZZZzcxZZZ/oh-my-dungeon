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
    this.unreadCount = 0,
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
  final int unreadCount;
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
      unreadCount: json['unreadCount'] as int? ?? 0,
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
    int? unreadCount,
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
      unreadCount: unreadCount ?? this.unreadCount,
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
            unreadCount == other.unreadCount &&
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
    unreadCount,
    Object.hashAll(memberPreview),
  );
}

class CampaignMemberPreview {
  const CampaignMemberPreview({
    required this.userId,
    required this.displayName,
    required this.role,
    this.boundCharacterId,
  });

  final String userId;
  final String displayName;
  final String role;

  /// 成员绑定的战役角色 id。null 表示未绑定。
  final String? boundCharacterId;

  factory CampaignMemberPreview.fromJson(Map<String, Object?> json) {
    return CampaignMemberPreview(
      userId: json['userId']! as String,
      displayName: json['displayName']! as String,
      role: json['role']! as String,
      boundCharacterId: json['boundCharacterId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CampaignMemberPreview &&
            userId == other.userId &&
            displayName == other.displayName &&
            role == other.role &&
            boundCharacterId == other.boundCharacterId;
  }

  @override
  int get hashCode => Object.hash(userId, displayName, role, boundCharacterId);
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
    required this.campaignCharacterId,
    required this.displayName,
    required this.avatarUrl,
    required this.kind,
    required this.content,
    required this.createdAt,
    this.speakerMode = 'character',
    this.delegatedByUserId,
    this.speakerAvatarAssetId,
    this.publicHealthState,
    this.publicHealthFraction,
    this.ooc = false,
    this.actionSnapshot,
    this.eventData,
  });

  final String id;
  final String campaignId;
  final String senderId;
  final String? campaignCharacterId;
  final String displayName;
  final String? avatarUrl;
  final String speakerMode;
  final String? delegatedByUserId;
  final String? speakerAvatarAssetId;
  final String? publicHealthState;
  final double? publicHealthFraction;
  final bool ooc;
  final String kind;
  final String content;
  final String createdAt;
  final Map<String, Object?>? actionSnapshot;
  final Map<String, Object?>? eventData;

  factory CampaignChatMessage.fromJson(Map<String, Object?> json) {
    return CampaignChatMessage(
      id: json['id']! as String,
      campaignId: json['campaignId']! as String,
      senderId: json['senderId']! as String,
      campaignCharacterId: json['campaignCharacterId'] as String?,
      displayName: json['displayName']! as String,
      avatarUrl: json['avatarUrl'] as String?,
      speakerMode: json['speakerMode'] as String? ?? 'character',
      delegatedByUserId: json['delegatedByUserId'] as String?,
      speakerAvatarAssetId: json['speakerAvatarAssetId'] as String?,
      publicHealthState: json['publicHealthState'] as String?,
      publicHealthFraction: (json['publicHealthFraction'] as num?)?.toDouble(),
      ooc: json['ooc'] as bool? ?? false,
      kind: json['kind']! as String,
      content: json['content']! as String,
      createdAt: json['createdAt']! as String,
      actionSnapshot: json['actionSnapshot'] is Map
          ? Map<String, Object?>.from(json['actionSnapshot']! as Map)
          : null,
      eventData: json['eventData'] is Map
          ? Map<String, Object?>.from(json['eventData']! as Map)
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CampaignChatMessage &&
            id == other.id &&
            campaignId == other.campaignId &&
            senderId == other.senderId &&
            campaignCharacterId == other.campaignCharacterId &&
            displayName == other.displayName &&
            avatarUrl == other.avatarUrl &&
            speakerMode == other.speakerMode &&
            delegatedByUserId == other.delegatedByUserId &&
            speakerAvatarAssetId == other.speakerAvatarAssetId &&
            publicHealthState == other.publicHealthState &&
            publicHealthFraction == other.publicHealthFraction &&
            ooc == other.ooc &&
            kind == other.kind &&
            content == other.content &&
            createdAt == other.createdAt &&
            _mapEquals(actionSnapshot, other.actionSnapshot) &&
            _mapEquals(eventData, other.eventData);
  }

  @override
  int get hashCode => Object.hash(
    id,
    campaignId,
    senderId,
    campaignCharacterId,
    displayName,
    avatarUrl,
    speakerMode,
    delegatedByUserId,
    speakerAvatarAssetId,
    publicHealthState,
    publicHealthFraction,
    ooc,
    kind,
    content,
    createdAt,
    actionSnapshot == null
        ? null
        : Object.hashAllUnordered(actionSnapshot!.entries),
    eventData == null ? null : Object.hashAllUnordered(eventData!.entries),
  );
}

bool _mapEquals(Map<String, Object?>? first, Map<String, Object?>? second) {
  if (identical(first, second)) return true;
  if (first == null || second == null || first.length != second.length) {
    return false;
  }
  for (final entry in first.entries) {
    if (!second.containsKey(entry.key) || second[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
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
    this.boundCharacterId,
    this.activeSpeakerCharacterId,
    this.speakerMode = 'boundCharacter',
    this.lastReadAt,
  });

  final String id;
  final String campaignId;
  final String userId;
  final String role;
  final String displayName;
  final String joinedAt;
  final String? boundCharacterId;
  final String? activeSpeakerCharacterId;
  final String speakerMode;
  final String? lastReadAt;

  factory CampaignMembership.fromJson(Map<String, Object?> json) {
    return CampaignMembership(
      id: json['id']! as String,
      campaignId: json['campaignId']! as String,
      userId: json['userId']! as String,
      role: json['role']! as String,
      displayName: json['displayName']! as String,
      joinedAt: json['joinedAt']! as String,
      boundCharacterId: json['boundCharacterId'] as String?,
      activeSpeakerCharacterId: json['activeSpeakerCharacterId'] as String?,
      speakerMode: json['speakerMode'] as String? ?? 'boundCharacter',
      lastReadAt: json['lastReadAt'] as String?,
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
            joinedAt == other.joinedAt &&
            boundCharacterId == other.boundCharacterId &&
            activeSpeakerCharacterId == other.activeSpeakerCharacterId &&
            speakerMode == other.speakerMode &&
            lastReadAt == other.lastReadAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    campaignId,
    userId,
    role,
    displayName,
    joinedAt,
    boundCharacterId,
    activeSpeakerCharacterId,
    speakerMode,
    lastReadAt,
  );
}

class CampaignWorkspaceContext {
  const CampaignWorkspaceContext({
    required this.campaign,
    required this.membership,
    required this.members,
    required this.characters,
    required this.capabilities,
  });

  final Campaign campaign;
  final CampaignMembership membership;
  final List<CampaignMemberPreview> members;
  final List<CampaignWorkspaceCharacter> characters;
  final CampaignCapabilities capabilities;

  factory CampaignWorkspaceContext.fromJson(Map<String, Object?> json) {
    return CampaignWorkspaceContext(
      campaign: Campaign.fromJson(json['campaign']! as Map<String, Object?>),
      membership: CampaignMembership.fromJson(
        json['membership']! as Map<String, Object?>,
      ),
      members: (json['members'] as List? ?? const [])
          .whereType<Map<String, Object?>>()
          .map(CampaignMemberPreview.fromJson)
          .toList(growable: false),
      characters: (json['characters'] as List? ?? const [])
          .whereType<Map<String, Object?>>()
          .map(CampaignWorkspaceCharacter.fromJson)
          .toList(growable: false),
      capabilities: CampaignCapabilities.fromJson(
        json['capabilities']! as Map<String, Object?>,
      ),
    );
  }

  CampaignWorkspaceContext copyWith({CampaignMembership? membership}) {
    return CampaignWorkspaceContext(
      campaign: campaign,
      membership: membership ?? this.membership,
      members: members,
      characters: characters,
      capabilities: capabilities,
    );
  }
}

class CampaignWorkspaceCharacter {
  const CampaignWorkspaceCharacter({
    required this.id,
    required this.ownerUserId,
    this.sourceCharacterId,
    required this.characterType,
    required this.status,
    required this.lifecycle,
    this.visibleToPlayers = true,
    required this.displayName,
    required this.avatarAssetId,
    required this.publicHealthState,
  });

  final String id;
  final String? ownerUserId;
  final String? sourceCharacterId;
  final String characterType;
  final String status;
  final String lifecycle;
  final bool visibleToPlayers;
  final String displayName;
  final String? avatarAssetId;
  final String publicHealthState;

  factory CampaignWorkspaceCharacter.fromJson(Map<String, Object?> json) {
    return CampaignWorkspaceCharacter(
      id: json['id']! as String,
      ownerUserId: json['ownerUserId'] as String?,
      sourceCharacterId: json['sourceCharacterId'] as String?,
      characterType: json['characterType']! as String,
      status: json['status']! as String,
      lifecycle: json['lifecycle'] as String? ?? 'persistent',
      visibleToPlayers:
          json['visibleToPlayers'] as bool? ??
          json['characterType'] == 'player',
      displayName: json['displayName']! as String,
      avatarAssetId: json['avatarAssetId'] as String?,
      publicHealthState: json['publicHealthState'] as String? ?? 'unknown',
    );
  }
}

class CampaignCapabilities {
  const CampaignCapabilities({
    required this.canManageCampaign,
    required this.canManageMembers,
    this.canInviteMembers = false,
    required this.canCreateCharacters,
    this.canManageCharacters = false,
    this.canEditAnyCharacter = false,
    required this.canSpeakAsNarrator,
    this.canCreateArchive = false,
    this.canManageArchive = false,
  });

  final bool canManageCampaign;
  final bool canManageMembers;
  final bool canInviteMembers;
  final bool canCreateCharacters;
  final bool canManageCharacters;
  final bool canEditAnyCharacter;
  final bool canSpeakAsNarrator;
  final bool canCreateArchive;
  final bool canManageArchive;

  factory CampaignCapabilities.fromJson(Map<String, Object?> json) {
    final canManageCampaign = json['canManageCampaign'] as bool? ?? false;
    return CampaignCapabilities(
      canManageCampaign: canManageCampaign,
      canManageMembers: json['canManageMembers'] as bool? ?? false,
      canInviteMembers: json['canInviteMembers'] as bool? ?? canManageCampaign,
      canCreateCharacters: json['canCreateCharacters'] as bool? ?? false,
      canManageCharacters:
          json['canManageCharacters'] as bool? ?? canManageCampaign,
      canEditAnyCharacter:
          json['canEditAnyCharacter'] as bool? ?? canManageCampaign,
      canSpeakAsNarrator: json['canSpeakAsNarrator'] as bool? ?? false,
      canCreateArchive: json['canCreateArchive'] as bool? ?? canManageCampaign,
      canManageArchive: json['canManageArchive'] as bool? ?? canManageCampaign,
    );
  }
}
