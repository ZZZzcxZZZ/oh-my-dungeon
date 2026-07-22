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
}

export interface CampaignChatMessageView {
  id: string;
  campaignId: string;
  senderId: string;
  campaignActorId: string | null;
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

export interface DraftActorInput {
  displayName: string;
  avatarUrl?: string | null;
}

export interface CreateCampaignChatMessageInput {
  kind?: string;
  content: string;
  campaignActorId?: string | null;
  actionId?: string | null;
  eventData?: Record<string, unknown> | null;
  draftActor?: DraftActorInput | null;
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
  boundActorId: string | null;
  activeSpeakerActorId: string | null;
  speakerMode: string;
  lastReadAt: string | null;
  joinedAt: string;
}

export interface CampaignCapabilitiesView {
  canManageCampaign: boolean;
  canManageMembers: boolean;
  canInviteMembers: boolean;
  canCreateActors: boolean;
  canManageActors: boolean;
  canEditAnyActor: boolean;
  canSpeakAsNarrator: boolean;
  canCreateArchive: boolean;
  canManageArchive: boolean;
}

export interface CampaignWorkspaceActorView {
  id: string;
  ownerUserId: string | null;
  actorType: string;
  status: string;
  lifecycle: string;
  displayName: string;
  avatarAssetId: string | null;
  publicHealthState: "healthy" | "injured" | "critical" | "down" | "unknown";
}

export interface CampaignWorkspaceContextView {
  campaign: CampaignView;
  membership: MembershipView;
  members: CampaignMemberPreview[];
  actors: CampaignWorkspaceActorView[];
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
