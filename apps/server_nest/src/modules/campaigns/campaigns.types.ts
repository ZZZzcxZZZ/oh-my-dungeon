export interface CampaignView {
  id: string;
  name: string;
  description: string;
  system: string;
  ownerId: string;
  status: string;
  createdAt: string;
  updatedAt: string;
  lastMessage: CampaignChatMessageView | null;
  unreadCount: number;
  memberPreview: CampaignMemberPreview[];
}

export interface CampaignMemberPreview {
  userId: string;
  displayName: string;
  role: string;
  boundCharacterId: string | null;
}

export interface CampaignChatMessageView {
  id: string;
  campaignId: string;
  senderId: string;
  campaignCharacterId: string | null;
  displayName: string;
  avatarUrl: string | null;
  speakerMode: string;
  delegatedByUserId: string | null;
  speakerAvatarAssetId: string | null;
  publicHealthState: string | null;
  publicHealthFraction: number | null;
  ooc: boolean;
  kind: string;
  content: string;
  actionSnapshot: Record<string, unknown> | null;
  eventData: Record<string, unknown> | null;
  createdAt: string;
}

/**
 * Use-once speaker snapshot. Plan 2026-07-23 task 5.2: a DM may send a single
 * message under a throwaway identity (e.g. an NPC the party just met) without
 * persisting a CampaignCharacter. The snapshot is written onto the message row
 * directly and discarded — no character is created and the DM's active speaker is
 * not mutated.
 */
export interface SpeakerSnapshotInput {
  displayName: string;
  avatarUrl?: string | null;
}

export type MessageSpeakerInput =
  | { kind: "narrator" }
  | { kind: "ooc" }
  | { kind: "character"; characterId: string }
  | {
      kind: "temporary";
      displayName: string;
      avatarUrl?: string | null;
    };

export interface CreateCampaignChatMessageInput {
  kind?: string;
  content: string;
  campaignCharacterId?: string | null;
  actionId?: string | null;
  eventData?: Record<string, unknown> | null;
  speakerSnapshot?: SpeakerSnapshotInput | null;
  speaker?: MessageSpeakerInput | null;
  conversationId?: string | null;
}

export interface CreateCampaignInput {
  name: string;
  description?: string;
  system?: string;
}

export interface CreateInviteInput {
  campaignId: string;
  maxUses?: number;
  expiresAt?: Date | null;
}

export interface InviteView {
  id: string;
  campaignId: string;
  code: string;
  roleOnJoin: string;
  expiresAt: string | null;
  maxUses: number;
  usedCount: number;
  requireApproval: boolean;
  createdAt: string;
}

export interface JoinCampaignInput {
  code: string;
}

export interface MembershipView {
  id: string;
  campaignId: string;
  userId: string;
  role: string;
  displayName: string;
  boundCharacterId: string | null;
  activeSpeakerCharacterId: string | null;
  speakerMode: string;
  lastReadAt: string | null;
  joinedAt: string;
}

export interface CampaignCapabilitiesView {
  canManageCampaign: boolean;
  canManageMembers: boolean;
  canInviteMembers: boolean;
  canCreateCharacters: boolean;
  canManageCharacters: boolean;
  canEditAnyCharacter: boolean;
  canSpeakAsNarrator: boolean;
  canCreateArchive: boolean;
  canManageArchive: boolean;
}

export interface CampaignWorkspaceCharacterView {
  id: string;
  ownerUserId: string | null;
  characterType: string;
  status: string;
  lifecycle: string;
  visibleToPlayers: boolean;
  displayName: string;
  avatarAssetId: string | null;
  publicHealthState: "healthy" | "injured" | "critical" | "down" | "unknown";
}

export interface CampaignWorkspaceContextView {
  campaign: CampaignView;
  membership: MembershipView;
  members: CampaignMemberPreview[];
  characters: CampaignWorkspaceCharacterView[];
  capabilities: CampaignCapabilitiesView;
}

/**
 * 检定请求视图。message 是 DM 发起的 kind='checkRequest' 消息，
 * responses 是玩家回复的 kind='roll' 且 eventData.requestId 匹配的消息列表，
 * status 来自 eventData.status（默认 'open'），'closed' 表示 DM 已关闭、玩家不能再响应。
 */
export interface CampaignCheckRequestView {
  message: CampaignChatMessageView;
  responses: CampaignChatMessageView[];
  status: "open" | "closed";
}

/**
 * 战役日志条目视图。journal 是 system/checkRequest/roll/archivePublished
 * 等关键事件的归档，campaignId 关联到所属战役，refId 指回触发的消息 id。
 */
export interface CampaignJournalEntryView {
  id: string;
  campaignId: string;
  type: string;
  summary: string;
  refId: string | null;
  createdAt: string;
}

export interface CampaignConversationView {
  id: string;
  campaignId: string;
  kind: string;
  title: string;
  participantIds: string[];
  createdBy: string;
  createdAt: string;
  updatedAt: string;
  archivedAt: string | null;
  lastMessage: CampaignChatMessageView | null;
  unreadCount: number;
}

export interface CreateDirectConversationInput {
  otherUserId: string;
}

export interface CreateGroupConversationInput {
  title: string;
  participantIds: string[];
}

export interface UpdateConversationInput {
  title?: string;
  archived?: boolean;
}
