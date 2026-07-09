class CharacterSheet {
  const CharacterSheet({
    required this.id,
    required this.ownerUserId,
    required this.name,
    required this.avatarUrl,
    required this.system,
    required this.level,
    required this.classSummary,
    required this.raceSummary,
    required this.currentHp,
    required this.maxHp,
    required this.armorClass,
    required this.speed,
    required this.initiativeBonus,
    required this.abilities,
    required this.saves,
    required this.skills,
    required this.inventory,
    required this.currency,
    required this.notes,
    required this.data,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ownerUserId;
  final String name;
  final String? avatarUrl;
  final String system;
  final int level;
  final String classSummary;
  final String raceSummary;
  final int currentHp;
  final int maxHp;
  final int armorClass;
  final int speed;
  final int initiativeBonus;
  final Object? abilities;
  final Object? saves;
  final Object? skills;
  final Object? inventory;
  final Object? currency;
  final String notes;
  final Object? data;
  final String createdAt;
  final String updatedAt;

  factory CharacterSheet.fromJson(Map<String, Object?> json) {
    return CharacterSheet(
      id: json['id']! as String,
      ownerUserId: json['ownerUserId']! as String,
      name: json['name']! as String,
      avatarUrl: json['avatarUrl'] as String?,
      system: json['system']! as String,
      level: (json['level'] as num).toInt(),
      classSummary: json['classSummary']! as String,
      raceSummary: json['raceSummary']! as String,
      currentHp: (json['currentHp'] as num).toInt(),
      maxHp: (json['maxHp'] as num).toInt(),
      armorClass: (json['armorClass'] as num).toInt(),
      speed: (json['speed'] as num).toInt(),
      initiativeBonus: (json['initiativeBonus'] as num).toInt(),
      abilities: json['abilities'],
      saves: json['saves'],
      skills: json['skills'],
      inventory: json['inventory'],
      currency: json['currency'],
      notes: json['notes']! as String,
      data: json['data'],
      createdAt: json['createdAt']! as String,
      updatedAt: json['updatedAt']! as String,
    );
  }

  CharacterSheet copyWith({
    String? name,
    int? level,
    String? classSummary,
    String? raceSummary,
    int? currentHp,
    int? maxHp,
    int? armorClass,
    int? speed,
    int? initiativeBonus,
  }) {
    return CharacterSheet(
      id: id,
      ownerUserId: ownerUserId,
      name: name ?? this.name,
      avatarUrl: avatarUrl,
      system: system,
      level: level ?? this.level,
      classSummary: classSummary ?? this.classSummary,
      raceSummary: raceSummary ?? this.raceSummary,
      currentHp: currentHp ?? this.currentHp,
      maxHp: maxHp ?? this.maxHp,
      armorClass: armorClass ?? this.armorClass,
      speed: speed ?? this.speed,
      initiativeBonus: initiativeBonus ?? this.initiativeBonus,
      abilities: abilities,
      saves: saves,
      skills: skills,
      inventory: inventory,
      currency: currency,
      notes: notes,
      data: data,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CharacterSheet &&
            id == other.id &&
            ownerUserId == other.ownerUserId &&
            name == other.name &&
            avatarUrl == other.avatarUrl &&
            system == other.system &&
            level == other.level &&
            classSummary == other.classSummary &&
            raceSummary == other.raceSummary &&
            currentHp == other.currentHp &&
            maxHp == other.maxHp &&
            armorClass == other.armorClass &&
            speed == other.speed &&
            initiativeBonus == other.initiativeBonus &&
            notes == other.notes &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        ownerUserId,
        name,
        avatarUrl,
        system,
        level,
        classSummary,
        raceSummary,
        currentHp,
        maxHp,
        armorClass,
        speed,
        initiativeBonus,
        notes,
        createdAt,
        updatedAt,
      );
}

class CharacterCampaignBinding {
  const CharacterCampaignBinding({
    required this.id,
    required this.campaignId,
    required this.characterId,
    required this.userId,
    required this.visibility,
    required this.status,
    required this.dmNotes,
    required this.joinedAt,
    required this.updatedAt,
    this.character,
  });

  final String id;
  final String campaignId;
  final String characterId;
  final String userId;
  final String visibility;
  final String status;
  final String dmNotes;
  final String joinedAt;
  final String updatedAt;
  final CharacterSheet? character;

  factory CharacterCampaignBinding.fromJson(Map<String, Object?> json) {
    return CharacterCampaignBinding(
      id: json['id']! as String,
      campaignId: json['campaignId']! as String,
      characterId: json['characterId']! as String,
      userId: json['userId']! as String,
      visibility: json['visibility']! as String,
      status: json['status']! as String,
      dmNotes: json['dmNotes']! as String,
      joinedAt: json['joinedAt']! as String,
      updatedAt: json['updatedAt']! as String,
      character: json['character'] == null
          ? null
          : CharacterSheet.fromJson(json['character']! as Map<String, Object?>),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CharacterCampaignBinding &&
            id == other.id &&
            campaignId == other.campaignId &&
            characterId == other.characterId &&
            userId == other.userId &&
            visibility == other.visibility &&
            status == other.status &&
            dmNotes == other.dmNotes &&
            joinedAt == other.joinedAt &&
            updatedAt == other.updatedAt &&
            character == other.character;
  }

  @override
  int get hashCode => Object.hash(
        id,
        campaignId,
        characterId,
        userId,
        visibility,
        status,
        dmNotes,
        joinedAt,
        updatedAt,
        character,
      );
}
