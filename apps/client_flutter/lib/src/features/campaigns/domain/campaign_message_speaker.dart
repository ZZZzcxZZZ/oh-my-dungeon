enum CampaignMessageSpeakerKind { narrator, ooc, character, temporary }

class CampaignMessageSpeaker {
  const CampaignMessageSpeaker.narrator()
    : kind = CampaignMessageSpeakerKind.narrator,
      characterId = null,
      displayName = null,
      avatarUrl = null;

  const CampaignMessageSpeaker.ooc()
    : kind = CampaignMessageSpeakerKind.ooc,
      characterId = null,
      displayName = null,
      avatarUrl = null;

  const CampaignMessageSpeaker.character(this.characterId)
    : kind = CampaignMessageSpeakerKind.character,
      displayName = null,
      avatarUrl = null;

  const CampaignMessageSpeaker.temporary({
    required this.displayName,
    this.avatarUrl,
  }) : kind = CampaignMessageSpeakerKind.temporary,
       characterId = null;

  final CampaignMessageSpeakerKind kind;
  final String? characterId;
  final String? displayName;
  final String? avatarUrl;

  Map<String, Object?> toJson() => switch (kind) {
    CampaignMessageSpeakerKind.narrator => const {'kind': 'narrator'},
    CampaignMessageSpeakerKind.ooc => const {'kind': 'ooc'},
    CampaignMessageSpeakerKind.character => {
      'kind': 'character',
      'characterId': characterId,
    },
    CampaignMessageSpeakerKind.temporary => {
      'kind': 'temporary',
      'displayName': displayName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    },
  };
}
