import { Injectable, NotFoundException } from "@nestjs/common";
import { randomBytes } from "crypto";
import { PrismaService } from "../../prisma/prisma.service";
import { AccessTokenPayload } from "../auth/auth.types";
import { CampaignsGateway } from "../realtime/campaigns.gateway";
import {
  CampaignContext,
  CampaignMemberSummary,
  CampaignPolicy,
  InviteContext,
} from "./policies/campaign.policy";
import type {
  CampaignChatMessageView,
  CampaignMemberPreview,
  CampaignView,
  CreateCampaignChatMessageInput,
  CreateCampaignInput,
  CreateInviteInput,
  InviteView,
  MembershipView,
} from "./campaigns.types";

const INVITE_CODE_BYTES = 6;
const CAMPAIGN_MESSAGE_LIMIT = 100;
const MEMBER_PREVIEW_LIMIT = 5;

@Injectable()
export class CampaignsService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly policy: CampaignPolicy,
    private readonly gateway: CampaignsGateway,
  ) {}

  async createCampaign(
    actor: AccessTokenPayload,
    input: CreateCampaignInput,
  ): Promise<CampaignView> {
    this.policy.canCreateCampaign(actor);

    const campaign = await this.prismaService.$transaction(async (tx) => {
      const created = await tx.campaign.create({
        data: {
          name: input.name,
          description: input.description ?? "",
          system: input.system ?? "dnd5e",
          ownerId: actor.userId,
        },
      });

      await tx.campaignMember.create({
        data: {
          campaignId: created.id,
          userId: actor.userId,
          role: "owner",
          displayName: actor.username,
        },
      });

      return created;
    });

    return toCampaignView(campaign);
  }

  async listCampaigns(actor: AccessTokenPayload): Promise<CampaignView[]> {
    const memberships = await this.prismaService.campaignMember.findMany({
      where: { userId: actor.userId },
      include: {
        campaign: {
          include: {
            members: {
              orderBy: { joinedAt: "asc" },
              take: MEMBER_PREVIEW_LIMIT,
            },
            chatMessages: {
              orderBy: { createdAt: "desc" },
              take: 1,
            },
          },
        },
      },
    });

    return memberships.map((membership: any) =>
      toCampaignView(membership.campaign),
    );
  }

  async getCampaign(
    actor: AccessTokenPayload,
    campaignId: string,
  ): Promise<CampaignView> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canViewCampaign(actor, campaign.context);
    return campaign.view;
  }

  async listMessages(
    actor: AccessTokenPayload,
    campaignId: string,
  ): Promise<CampaignChatMessageView[]> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canViewCampaign(actor, campaign.context);

    const messages = await this.prismaService.campaignChatMessage.findMany({
      where: { campaignId },
      orderBy: { createdAt: "desc" },
      take: CAMPAIGN_MESSAGE_LIMIT,
    });

    return messages.map(toCampaignChatMessageView).reverse();
  }

  async sendMessage(
    actor: AccessTokenPayload,
    campaignId: string,
    input: CreateCampaignChatMessageInput,
  ): Promise<CampaignChatMessageView> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canViewCampaign(actor, campaign.context);

    const content = input.content.trim();
    const kind = normalizeMessageKind(input.kind);
    const created = await this.prismaService.campaignChatMessage.create({
      data: {
        campaignId,
        senderId: actor.userId,
        characterId: input.characterId ?? null,
        displayName: input.displayName?.trim() || actor.username,
        avatarUrl: input.avatarUrl ?? null,
        kind,
        content,
      },
    });

    const view = toCampaignChatMessageView(created);
    this.gateway.broadcastToCampaign(
      campaignId,
      "campaign:message:new",
      view,
    );

    return view;
  }

  async createInvite(
    actor: AccessTokenPayload,
    input: CreateInviteInput,
  ): Promise<InviteView> {
    const campaign = await this.fetchCampaignContext(input.campaignId);
    this.policy.canManageCampaign(actor, campaign.context);

    const code = generateInviteCode();
    const created = await this.prismaService.campaignInvite.create({
      data: {
        campaignId: input.campaignId,
        code,
        roleOnJoin: input.roleOnJoin ?? "player",
        expiresAt: input.expiresAt ?? null,
        maxUses: input.maxUses ?? 1,
        usedCount: 0,
        requireApproval: false,
        createdBy: actor.userId,
      },
    });

    return toInviteView(created);
  }

  async listInvites(
    actor: AccessTokenPayload,
    campaignId: string,
  ): Promise<InviteView[]> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canManageCampaign(actor, campaign.context);

    const invites = await this.prismaService.campaignInvite.findMany({
      where: { campaignId },
    });

    return invites.map(toInviteView);
  }

  async joinCampaign(
    actor: AccessTokenPayload,
    code: string,
  ): Promise<MembershipView> {
    const invite = await this.prismaService.campaignInvite.findUnique({
      where: { code },
    });
    const inviteContext: InviteContext | null = invite
      ? {
          id: invite.id,
          campaignId: invite.campaignId,
          code: invite.code,
          roleOnJoin: invite.roleOnJoin,
          expiresAt: invite.expiresAt,
          maxUses: invite.maxUses,
          usedCount: invite.usedCount,
          requireApproval: invite.requireApproval,
        }
      : null;

    const existingMembership =
      await this.prismaService.campaignMember.findFirst({
        where: {
          userId: actor.userId,
          campaignId: invite?.campaignId ?? "__none__",
        },
      });
    const existingSummary: CampaignMemberSummary | null = existingMembership
      ? {
          userId: existingMembership.userId,
          role: existingMembership.role,
        }
      : null;

    this.policy.canJoinCampaign({
      invite: inviteContext,
      existingMembership: existingSummary,
    });

    if (existingSummary) {
      const membership = await this.prismaService.campaignMember.findFirst({
        where: {
          userId: actor.userId,
          campaignId: invite!.campaignId,
        },
      });
      return toMembershipView(membership!);
    }

    const membership = await this.prismaService.$transaction(async (tx) => {
      const created = await tx.campaignMember.create({
        data: {
          campaignId: invite!.campaignId,
          userId: actor.userId,
          role: invite!.roleOnJoin,
          displayName: actor.username,
        },
      });

      await tx.campaignInvite.update({
        where: { id: invite!.id },
        data: { usedCount: { increment: 1 } },
      });

      return created;
    });

    return toMembershipView(membership);
  }

  private async fetchCampaignContext(campaignId: string): Promise<{
    view: CampaignView;
    context: CampaignContext;
  }> {
    const campaign = await this.prismaService.campaign.findUnique({
      where: { id: campaignId },
      include: { members: true },
    });

    if (!campaign) {
      throw new NotFoundException("Campaign not found");
    }

    return {
      view: toCampaignView(campaign),
      context: {
        campaignId: campaign.id,
        ownerId: campaign.ownerId,
        members: campaign.members.map((member: any) => ({
          userId: member.userId,
          role: member.role,
        })),
      },
    };
  }
}

function toCampaignView(campaign: any): CampaignView {
  const members: any[] = campaign.members ?? [];
  const chatMessages: any[] = campaign.chatMessages ?? [];
  const lastMessageRaw =
    chatMessages.length > 0
      ? [...chatMessages].sort(
          (a, b) =>
            new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
        )[0]
      : null;

  const memberPreview: CampaignMemberPreview[] = members.map((member) => ({
    userId: member.userId,
    displayName: member.displayName,
    role: member.role,
  }));

  return {
    id: campaign.id,
    name: campaign.name,
    description: campaign.description,
    system: campaign.system,
    ownerId: campaign.ownerId,
    status: campaign.status,
    createdAt:
      campaign.createdAt instanceof Date
        ? campaign.createdAt.toISOString()
        : campaign.createdAt,
    updatedAt:
      campaign.updatedAt instanceof Date
        ? campaign.updatedAt.toISOString()
        : campaign.updatedAt,
    lastMessage: lastMessageRaw
      ? toCampaignChatMessageView(lastMessageRaw)
      : null,
    memberPreview,
  };
}

function toCampaignChatMessageView(message: any): CampaignChatMessageView {
  return {
    id: message.id,
    campaignId: message.campaignId,
    senderId: message.senderId,
    characterId: message.characterId ?? null,
    displayName: message.displayName,
    avatarUrl: message.avatarUrl ?? null,
    kind: message.kind,
    content: message.content,
    createdAt:
      message.createdAt instanceof Date
        ? message.createdAt.toISOString()
        : message.createdAt,
  };
}

function normalizeMessageKind(kind: string | undefined): string {
  if (kind === "action") return "action";
  return "say";
}

function toInviteView(invite: any): InviteView {
  return {
    id: invite.id,
    campaignId: invite.campaignId,
    code: invite.code,
    roleOnJoin: invite.roleOnJoin,
    expiresAt: invite.expiresAt
      ? invite.expiresAt instanceof Date
        ? invite.expiresAt.toISOString()
        : invite.expiresAt
      : null,
    maxUses: invite.maxUses,
    usedCount: invite.usedCount,
    requireApproval: invite.requireApproval,
    createdAt:
      invite.createdAt instanceof Date
        ? invite.createdAt.toISOString()
        : invite.createdAt,
  };
}

function toMembershipView(membership: any): MembershipView {
  return {
    id: membership.id,
    campaignId: membership.campaignId,
    userId: membership.userId,
    role: membership.role,
    displayName: membership.displayName,
    joinedAt:
      membership.joinedAt instanceof Date
        ? membership.joinedAt.toISOString()
        : membership.joinedAt,
  };
}

function generateInviteCode(): string {
  return randomBytes(INVITE_CODE_BYTES).toString("base64url").toUpperCase();
}
