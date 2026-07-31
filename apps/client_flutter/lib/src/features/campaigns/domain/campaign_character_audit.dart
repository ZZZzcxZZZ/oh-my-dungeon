class CampaignCharacterAudit {
  const CampaignCharacterAudit({
    required this.id,
    required this.campaignCharacterId,
    required this.campaignId,
    required this.characterUserId,
    required this.baseRevision,
    required this.resultRevision,
    required this.changedPaths,
    required this.beforeSheet,
    required this.afterSheet,
    required this.createdAt,
  });

  final String id;
  final String campaignCharacterId;
  final String campaignId;
  final String characterUserId;
  final int baseRevision;
  final int resultRevision;
  final List<String> changedPaths;
  final Map<String, Object?> beforeSheet;
  final Map<String, Object?> afterSheet;
  final String createdAt;

  factory CampaignCharacterAudit.fromJson(Map<String, Object?> json) {
    return CampaignCharacterAudit(
      id: json['id']?.toString() ?? '',
      campaignCharacterId: json['campaignCharacterId']?.toString() ?? '',
      campaignId: json['campaignId']?.toString() ?? '',
      characterUserId: json['characterUserId']?.toString() ?? '',
      baseRevision: _intValue(json['baseRevision']),
      resultRevision: _intValue(json['resultRevision']),
      changedPaths: (json['changedPaths'] as List<Object?>? ?? const [])
          .map((path) => path.toString())
          .toList(growable: false),
      beforeSheet: _mapValue(json['beforeSheet']),
      afterSheet: _mapValue(json['afterSheet']),
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  static int _intValue(Object? value) => value is num ? value.toInt() : 0;

  static Map<String, Object?> _mapValue(Object? value) => value is Map
      ? Map<String, Object?>.from(value)
      : const <String, Object?>{};
}
