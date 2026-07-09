class Npc {
  const Npc({
    required this.id,
    required this.campaignId,
    required this.contentItemId,
    required this.name,
    required this.publicDescription,
    required this.dmNotes,
    required this.stats,
    required this.tags,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String campaignId;
  final String? contentItemId;
  final String name;
  final String publicDescription;
  final String dmNotes;
  final Object? stats;
  final Object? tags;
  final String createdBy;
  final String createdAt;
  final String updatedAt;

  factory Npc.fromJson(Map<String, Object?> json) {
    return Npc(
      id: json['id']! as String,
      campaignId: json['campaignId']! as String,
      contentItemId: json['contentItemId'] as String?,
      name: json['name']! as String,
      publicDescription: json['publicDescription']! as String,
      dmNotes: json['dmNotes']! as String,
      stats: json['stats'],
      tags: json['tags'],
      createdBy: json['createdBy']! as String,
      createdAt: json['createdAt']! as String,
      updatedAt: json['updatedAt']! as String,
    );
  }
}

class EncounterParticipant {
  const EncounterParticipant({
    required this.id,
    required this.encounterId,
    required this.participantType,
    required this.characterId,
    required this.npcId,
    required this.displayName,
    required this.initiative,
    required this.hpCurrent,
    required this.hpMax,
    required this.armorClass,
    required this.conditions,
    required this.isHiddenFromPlayers,
    required this.sortOrder,
    required this.snapshot,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String encounterId;
  final String participantType;
  final String? characterId;
  final String? npcId;
  final String displayName;
  final int initiative;
  final int hpCurrent;
  final int hpMax;
  final int armorClass;
  final Object? conditions;
  final bool isHiddenFromPlayers;
  final int sortOrder;
  final Object? snapshot;
  final String createdAt;
  final String updatedAt;

  factory EncounterParticipant.fromJson(Map<String, Object?> json) {
    return EncounterParticipant(
      id: json['id']! as String,
      encounterId: json['encounterId']! as String,
      participantType: json['participantType']! as String,
      characterId: json['characterId'] as String?,
      npcId: json['npcId'] as String?,
      displayName: json['displayName']! as String,
      initiative: (json['initiative'] as num).toInt(),
      hpCurrent: (json['hpCurrent'] as num).toInt(),
      hpMax: (json['hpMax'] as num).toInt(),
      armorClass: (json['armorClass'] as num).toInt(),
      conditions: json['conditions'],
      isHiddenFromPlayers: json['isHiddenFromPlayers']! as bool,
      sortOrder: (json['sortOrder'] as num).toInt(),
      snapshot: json['snapshot'],
      createdAt: json['createdAt']! as String,
      updatedAt: json['updatedAt']! as String,
    );
  }

  EncounterParticipant copyWith({int? hpCurrent, Object? conditions}) {
    return EncounterParticipant(
      id: id,
      encounterId: encounterId,
      participantType: participantType,
      characterId: characterId,
      npcId: npcId,
      displayName: displayName,
      initiative: initiative,
      hpCurrent: hpCurrent ?? this.hpCurrent,
      hpMax: hpMax,
      armorClass: armorClass,
      conditions: conditions ?? this.conditions,
      isHiddenFromPlayers: isHiddenFromPlayers,
      sortOrder: sortOrder,
      snapshot: snapshot,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is EncounterParticipant &&
            id == other.id &&
            encounterId == other.encounterId &&
            participantType == other.participantType &&
            characterId == other.characterId &&
            npcId == other.npcId &&
            displayName == other.displayName &&
            initiative == other.initiative &&
            hpCurrent == other.hpCurrent &&
            hpMax == other.hpMax &&
            armorClass == other.armorClass &&
            isHiddenFromPlayers == other.isHiddenFromPlayers &&
            sortOrder == other.sortOrder &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    encounterId,
    participantType,
    characterId,
    npcId,
    displayName,
    initiative,
    hpCurrent,
    hpMax,
    armorClass,
    isHiddenFromPlayers,
    sortOrder,
    createdAt,
    updatedAt,
  );
}

class Encounter {
  const Encounter({
    required this.id,
    required this.campaignId,
    required this.sessionId,
    required this.name,
    required this.status,
    required this.round,
    required this.currentTurnParticipantId,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.participants,
  });

  final String id;
  final String campaignId;
  final String? sessionId;
  final String name;
  final String status;
  final int round;
  final String? currentTurnParticipantId;
  final String createdBy;
  final String createdAt;
  final String updatedAt;
  final List<EncounterParticipant> participants;

  factory Encounter.fromJson(Map<String, Object?> json) {
    final participantsJson = json['participants'] as List<Object?>? ?? const [];
    return Encounter(
      id: json['id']! as String,
      campaignId: json['campaignId']! as String,
      sessionId: json['sessionId'] as String?,
      name: json['name']! as String,
      status: json['status']! as String,
      round: (json['round'] as num).toInt(),
      currentTurnParticipantId: json['currentTurnParticipantId'] as String?,
      createdBy: json['createdBy']! as String,
      createdAt: json['createdAt']! as String,
      updatedAt: json['updatedAt']! as String,
      participants: participantsJson
          .map(
            (item) =>
                EncounterParticipant.fromJson(item as Map<String, Object?>),
          )
          .toList(),
    );
  }

  Encounter copyWith({List<EncounterParticipant>? participants}) {
    return Encounter(
      id: id,
      campaignId: campaignId,
      sessionId: sessionId,
      name: name,
      status: status,
      round: round,
      currentTurnParticipantId: currentTurnParticipantId,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      participants: participants ?? this.participants,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Encounter &&
            id == other.id &&
            campaignId == other.campaignId &&
            sessionId == other.sessionId &&
            name == other.name &&
            status == other.status &&
            round == other.round &&
            currentTurnParticipantId == other.currentTurnParticipantId &&
            createdBy == other.createdBy &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    campaignId,
    sessionId,
    name,
    status,
    round,
    currentTurnParticipantId,
    createdBy,
    createdAt,
    updatedAt,
  );
}
