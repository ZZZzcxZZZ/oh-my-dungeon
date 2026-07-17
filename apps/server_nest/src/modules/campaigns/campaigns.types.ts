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
  canCreateActors: boolean;
  canSpeakAsNarrator: boolean;
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
