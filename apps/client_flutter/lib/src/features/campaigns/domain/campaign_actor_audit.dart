class CampaignActorAudit {
  const CampaignActorAudit({
    required this.id,
    required this.campaignActorId,
    required this.campaignId,
    required this.actorUserId,
    required this.baseRevision,
    required this.resultRevision,
    required this.changedPaths,
    required this.beforeSheet,
    required this.afterSheet,
    required this.createdAt,
  });

  final String id;
  final String campaignActorId;
  final String campaignId;
  final String actorUserId;
  final int baseRevision;
  final int resultRevision;
  final List<String> changedPaths;
  final Map<String, Object?> beforeSheet;
  final Map<String, Object?> afterSheet;
  final String createdAt;

  factory CampaignActorAudit.fromJson(Map<String, Object?> json) {
    return CampaignActorAudit(
      id: json['id']?.toString() ?? '',
      campaignActorId: json['campaignActorId']?.toString() ?? '',
      campaignId: json['campaignId']?.toString() ?? '',
      actorUserId: json['actorUserId']?.toString() ?? '',
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
