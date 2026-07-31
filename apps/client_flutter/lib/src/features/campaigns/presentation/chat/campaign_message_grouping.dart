import '../../domain/campaign.dart';

class CampaignMessagePresentation {
  const CampaignMessagePresentation({
    required this.isOwn,
    required this.showIdentity,
    required this.showTimeDivider,
  });

  final bool isOwn;
  final bool showIdentity;
  final bool showTimeDivider;

  static CampaignMessagePresentation resolve({
    CampaignChatMessage? previous,
    required CampaignChatMessage current,
    required String? currentUserId,
    bool groupConsecutiveMessages = true,
  }) {
    final gap = _gap(previous, current);
    final separated =
        previous == null ||
        gap == null ||
        gap.isNegative ||
        gap.inMinutes >= 10;
    final ordinary = current.kind == 'say' || current.kind == 'action';
    final previousOrdinary =
        previous?.kind == 'say' || previous?.kind == 'action';
    final sameSpeaker =
        previous != null &&
        previous.senderId == current.senderId &&
        previous.campaignCharacterId == current.campaignCharacterId &&
        previous.speakerMode == current.speakerMode;

    return CampaignMessagePresentation(
      isOwn: currentUserId != null && current.senderId == currentUserId,
      showIdentity:
          !groupConsecutiveMessages ||
          !(ordinary && previousOrdinary && sameSpeaker && !separated),
      showTimeDivider: previous == null || separated,
    );
  }

  static Duration? _gap(
    CampaignChatMessage? previous,
    CampaignChatMessage current,
  ) {
    if (previous == null) return null;
    final previousAt = DateTime.tryParse(previous.createdAt);
    final currentAt = DateTime.tryParse(current.createdAt);
    if (previousAt == null || currentAt == null) return null;
    return currentAt.difference(previousAt);
  }
}
