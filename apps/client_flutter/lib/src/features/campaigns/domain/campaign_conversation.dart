import 'campaign.dart';

/// Plan 2026-07-23 task 5.3: campaign conversation (main / direct / group).
///
/// Mirrors the server `CampaignConversationView`. Main is the campaign-wide
/// room auto-created with the campaign. Direct is a 1:1 side channel keyed by
/// a sorted participant pair. Group is a DM-created named room. Messages
/// optionally carry a `conversationId`; legacy messages with null
/// conversationId remain visible via the main conversation listing.
class CampaignConversation {
  const CampaignConversation({
    required this.id,
    required this.campaignId,
    required this.kind,
    required this.title,
    required this.participantIds,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    this.lastMessage,
    this.unreadCount = 0,
  });

  final String id;
  final String campaignId;

  /// `main | direct | group`
  final String kind;
  final String title;
  final List<String> participantIds;
  final String createdBy;
  final String createdAt;
  final String updatedAt;
  final String? archivedAt;
  final CampaignChatMessage? lastMessage;
  final int unreadCount;

  /// Convenience: true when this is the campaign-wide main room.
  bool get isMain => kind == 'main';

  /// Convenience: true when archived.
  bool get isArchived => archivedAt != null;

  factory CampaignConversation.fromJson(Map<String, Object?> json) {
    final lastMessageJson = json['lastMessage'];
    return CampaignConversation(
      id: json['id']! as String,
      campaignId: json['campaignId']! as String,
      kind: json['kind'] as String? ?? 'main',
      title: json['title'] as String? ?? '',
      participantIds: (json['participantIds'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      createdBy: json['createdBy']! as String,
      createdAt: json['createdAt']! as String,
      updatedAt: json['updatedAt']! as String,
      archivedAt: json['archivedAt'] as String?,
      lastMessage: lastMessageJson is Map<String, Object?>
          ? CampaignChatMessage.fromJson(lastMessageJson)
          : null,
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }

  CampaignConversation copyWith({
    String? title,
    String? archivedAt,
    CampaignChatMessage? lastMessage,
    int? unreadCount,
  }) {
    return CampaignConversation(
      id: id,
      campaignId: campaignId,
      kind: kind,
      title: title ?? this.title,
      participantIds: participantIds,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CampaignConversation &&
            id == other.id &&
            campaignId == other.campaignId &&
            kind == other.kind &&
            title == other.title &&
            _listEquals(participantIds, other.participantIds) &&
            createdBy == other.createdBy &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt &&
            archivedAt == other.archivedAt &&
            lastMessage == other.lastMessage &&
            unreadCount == other.unreadCount;
  }

  @override
  int get hashCode => Object.hash(
        id,
        campaignId,
        kind,
        title,
        Object.hashAll(participantIds),
        createdBy,
        createdAt,
        updatedAt,
        archivedAt,
        lastMessage,
        unreadCount,
      );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
