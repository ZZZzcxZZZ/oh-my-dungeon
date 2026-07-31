/// 战役角色。由 DM 发布或由玩家从本地角色卡发布而来。
class CampaignCharacter {
  const CampaignCharacter({
    required this.id,
    required this.campaignId,
    required this.ownerUserId,
    required this.sourceCharacterId,
    required this.characterType,
    required this.status,
    this.lifecycle = 'persistent',
    this.visibleToPlayers = true,
    required this.sheet,
    required this.revision,
    required this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String campaignId;
  final String? ownerUserId;
  final String? sourceCharacterId;
  final String characterType;
  final String status;
  final String lifecycle;
  final bool visibleToPlayers;
  final Map<String, Object?> sheet;
  final int revision;
  final String updatedBy;
  final String createdAt;
  final String updatedAt;

  factory CampaignCharacter.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final campaignId = json['campaignId'];
    final characterType = json['characterType'];
    final status = json['status'];
    final sheet = json['sheet'];
    final revision = json['revision'];

    if (id is! String) {
      throw FormatException('CampaignCharacter.id missing or not a string');
    }
    if (campaignId is! String) {
      throw FormatException(
        'CampaignCharacter.campaignId missing or not a string',
      );
    }
    if (characterType is! String) {
      throw FormatException(
        'CampaignCharacter.characterType missing or not a string',
      );
    }
    if (status is! String) {
      throw FormatException('CampaignCharacter.status missing or not a string');
    }
    if (sheet is! Map) {
      throw FormatException('CampaignCharacter.sheet missing or not a map');
    }
    if (revision is! num) {
      throw FormatException(
        'CampaignCharacter.revision missing or not a number',
      );
    }

    return CampaignCharacter(
      id: id,
      campaignId: campaignId,
      ownerUserId: json['ownerUserId'] as String?,
      sourceCharacterId: json['sourceCharacterId'] as String?,
      characterType: characterType,
      status: status,
      lifecycle: json['lifecycle'] as String? ?? 'persistent',
      visibleToPlayers:
          json['visibleToPlayers'] as bool? ?? characterType == 'player',
      sheet: Map<String, Object?>.from(sheet),
      revision: revision.toInt(),
      updatedBy: json['updatedBy'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'campaignId': campaignId,
    'ownerUserId': ownerUserId,
    'sourceCharacterId': sourceCharacterId,
    'characterType': characterType,
    'status': status,
    'lifecycle': lifecycle,
    'visibleToPlayers': visibleToPlayers,
    'sheet': sheet,
    'revision': revision,
    'updatedBy': updatedBy,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CampaignCharacter &&
        id == other.id &&
        campaignId == other.campaignId &&
        ownerUserId == other.ownerUserId &&
        sourceCharacterId == other.sourceCharacterId &&
        characterType == other.characterType &&
        status == other.status &&
        lifecycle == other.lifecycle &&
        visibleToPlayers == other.visibleToPlayers &&
        _mapEquals(sheet, other.sheet) &&
        revision == other.revision &&
        updatedBy == other.updatedBy &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    campaignId,
    ownerUserId,
    sourceCharacterId,
    characterType,
    status,
    lifecycle,
    visibleToPlayers,
    revision,
    updatedBy,
    createdAt,
    updatedAt,
    Object.hashAllUnordered(sheet.entries),
  );
}

bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || a[key] != b[key]) return false;
  }
  return true;
}
