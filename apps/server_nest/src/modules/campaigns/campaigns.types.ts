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
  kind: string;
  content: string;
  createdAt: string;
}

export interface CreateCampaignChatMessageInput {
  kind?: string;
  content: string;
  campaignActorId?: string | null;
}

export interface CreateCampaignInput {
  name: string;
  description?: string;
  system?: string;
}

export interface CreateInviteInput {
  campaignId: string;
  roleOnJoin?: string;
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
  joinedAt: string;
}
