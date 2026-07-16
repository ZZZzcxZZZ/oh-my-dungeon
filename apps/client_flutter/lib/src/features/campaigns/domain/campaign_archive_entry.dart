class CampaignArchiveEntry {
  const CampaignArchiveEntry({
    required this.id,
    required this.campaignId,
    required this.kind,
    required this.title,
    required this.summary,
    required this.payload,
    required this.pinned,
    required this.updatedAt,
  });
  final String id;
  final String campaignId;
  final String kind;
  final String title;
  final String summary;
  final Map<String, Object?> payload;
  final bool pinned;
  final String updatedAt;
  factory CampaignArchiveEntry.fromJson(Map<String, Object?> json) =>
      CampaignArchiveEntry(
        id: json['id']! as String,
        campaignId: json['campaignId']! as String,
        kind: json['kind']! as String,
        title: json['title']! as String,
        summary: json['summary'] as String? ?? '',
        payload: json['payload'] is Map
            ? Map<String, Object?>.from(json['payload']! as Map)
            : const {},
        pinned: json['pinned'] as bool? ?? false,
        updatedAt: json['updatedAt']! as String,
      );
}
