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
  });

  final String id;
  final String name;
  final String description;
  final String system;
  final String ownerId;
  final String status;
  final String createdAt;
  final String updatedAt;

  factory Campaign.fromJson(Map<String, Object?> json) {
    return Campaign(
      id: json['id']! as String,
      name: json['name']! as String,
      description: json['description']! as String,
      system: json['system']! as String,
      ownerId: json['ownerId']! as String,
      status: json['status']! as String,
      createdAt: json['createdAt']! as String,
      updatedAt: json['updatedAt']! as String,
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
            updatedAt == other.updatedAt;
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
