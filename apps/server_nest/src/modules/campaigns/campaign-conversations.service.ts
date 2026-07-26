import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { PrismaService } from "../../prisma/prisma.service";
import { AccessTokenPayload } from "../auth/auth.types";
import { CampaignPolicy } from "./policies/campaign.policy";
import type {
  CampaignChatMessageView,
  CampaignConversationView,
  CreateDirectConversationInput,
  CreateGroupConversationInput,
  UpdateConversationInput,
} from "./campaigns.types";

/**
 * Plan 2026-07-23 task 5.3: campaign conversations (main / direct / group).
 * Main is the campaign-wide room auto-created with the campaign. Direct is a
 * 1:1 side channel keyed by a sorted participant pair. Group is a DM-created
 * named room. Messages optionally carry a conversationId; legacy messages
 * with null conversationId remain visible via the main conversation listing.
 */
@Injectable()
export class CampaignConversationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly policy: CampaignPolicy,
  ) {}

  async listConversations(
    actor: AccessTokenPayload,
    campaignId: string,
  ): Promise<CampaignConversationView[]> {
    const context = await this.context(campaignId);
    this.policy.canViewCampaign(actor, context);

    // Legacy campaigns created before task 5.3 may not have a main row yet.
    await this.ensureMainConversation(campaignId, actor.userId);

    const conversations = await this.prisma.campaignConversation.findMany({
      where: { campaignId, archivedAt: null },
      orderBy: [{ kind: "asc" }, { createdAt: "asc" }],
    });

    // Main is visible to all members; direct/group only to participants.
    const visible = conversations.filter((c: any) =>
      this.canAccessConversation(actor.userId, c),
    );

    return Promise.all(
      visible.map((c: any) => this.toViewWithMeta(c, actor.userId)),
    );
  }

  async markRead(
    actor: AccessTokenPayload,
    campaignId: string,
    conversationId: string,
  ): Promise<{ lastReadAt: string }> {
    const context = await this.context(campaignId);
    this.policy.canViewCampaign(actor, context);
    const conversation = await this.getConversationOrThrow(
      campaignId,
      conversationId,
    );
    if (
      conversation.archivedAt ||
      !this.canAccessConversation(actor.userId, conversation)
    ) {
      throw new NotFoundException("Conversation not found");
    }
    const lastReadAt = new Date();
    await this.prisma.campaignConversationRead.upsert({
      where: {
        conversationId_userId: {
          conversationId,
          userId: actor.userId,
        },
      },
      create: { conversationId, userId: actor.userId, lastReadAt },
      update: { lastReadAt },
    });
    return { lastReadAt: lastReadAt.toISOString() };
  }

  async ensureMainConversation(
    campaignId: string,
    createdBy: string,
  ): Promise<void> {
    await this.prisma.campaignConversation.upsert({
      where: { campaignId_mainKey: { campaignId, mainKey: "main" } },
      create: {
        campaignId,
        kind: "main",
        title: "",
        mainKey: "main",
        participantIds: [],
        createdBy,
      },
      update: {},
    });
  }

  async createDirectConversation(
    actor: AccessTokenPayload,
    campaignId: string,
    input: CreateDirectConversationInput,
  ): Promise<CampaignConversationView> {
    const context = await this.context(campaignId);
    this.policy.canViewCampaign(actor, context);

    const otherUserId = input.otherUserId;
    if (!otherUserId || typeof otherUserId !== "string") {
      throw new BadRequestException("otherUserId is required");
    }
    if (otherUserId === actor.userId) {
      throw new BadRequestException(
        "Cannot create a direct conversation with yourself",
      );
    }

    // Both users must be active campaign members.
    const otherMembership = await this.prisma.campaignMember.findFirst({
      where: { campaignId, userId: otherUserId },
    });
    if (!otherMembership) {
      throw new NotFoundException("Other user is not a campaign member");
    }

    // Sorted pair key dedupes the 1:1 channel regardless of who initiates.
    const directKey = [actor.userId, otherUserId].sort().join(":");

    const conversation = await this.prisma.campaignConversation.upsert({
      where: { campaignId_directKey: { campaignId, directKey } },
      create: {
        campaignId,
        kind: "direct",
        title: "",
        directKey,
        participantIds: [actor.userId, otherUserId],
        createdBy: actor.userId,
      },
      update: {},
    });

    return this.toViewWithMeta(conversation, actor.userId);
  }

  async createGroupConversation(
    actor: AccessTokenPayload,
    campaignId: string,
    input: CreateGroupConversationInput,
  ): Promise<CampaignConversationView> {
    const context = await this.context(campaignId);
    this.policy.canManageCampaign(actor, context);

    if (!input.title || !input.title.trim()) {
      throw new BadRequestException("Group conversation title is required");
    }
    if (
      !Array.isArray(input.participantIds) ||
      input.participantIds.some((id) => typeof id !== "string")
    ) {
      throw new BadRequestException("participantIds must be an array of strings");
    }

    // The creator is always a participant.
    const participantIds = Array.from(
      new Set([actor.userId, ...input.participantIds]),
    );

    const members = await this.prisma.campaignMember.findMany({
      where: { campaignId, userId: { in: participantIds } },
      select: { userId: true },
    });
    const memberUserIds = new Set(members.map((m) => m.userId));
    const missing = participantIds.filter((id) => !memberUserIds.has(id));
    if (missing.length > 0) {
      throw new BadRequestException(
        "All participants must be campaign members",
      );
    }

    const conversation = await this.prisma.campaignConversation.create({
      data: {
        campaignId,
        kind: "group",
        title: input.title.trim(),
        participantIds,
        createdBy: actor.userId,
      },
    });

    return this.toViewWithMeta(conversation, actor.userId);
  }

  async updateConversation(
    actor: AccessTokenPayload,
    campaignId: string,
    conversationId: string,
    input: UpdateConversationInput,
  ): Promise<CampaignConversationView> {
    const context = await this.context(campaignId);
    const conversation = await this.getConversationOrThrow(
      campaignId,
      conversationId,
    );

    const data: {
      title?: string;
      archivedAt?: Date | null;
    } = {};

    if (input.archived !== undefined) {
      // Archiving a conversation is a DM-only operation.
      this.policy.canManageCampaign(actor, context);
      data.archivedAt = input.archived ? new Date() : null;
    }

    if (input.title !== undefined) {
      if (conversation.kind !== "group") {
        throw new BadRequestException(
          "Only group conversations can be renamed",
        );
      }
      // Group creator may rename; otherwise a DM is required.
      if (conversation.createdBy !== actor.userId) {
        this.policy.canManageCampaign(actor, context);
      }
      if (!input.title.trim()) {
        throw new BadRequestException("Title is required");
      }
      data.title = input.title.trim();
    }

    if (Object.keys(data).length === 0) {
      return this.toViewWithMeta(conversation, actor.userId);
    }

    const updated = await this.prisma.campaignConversation.update({
      where: { id: conversationId },
      data,
    });

    return this.toViewWithMeta(updated, actor.userId);
  }

  canAccessConversation(
    userId: string,
    conversation: { kind: string; participantIds: string[] },
  ): boolean {
    if (conversation.kind === "main") return true;
    return conversation.participantIds.includes(userId);
  }

  async getConversationOrThrow(campaignId: string, conversationId: string) {
    const conversation = await this.prisma.campaignConversation.findFirst({
      where: { id: conversationId, campaignId },
    });
    if (!conversation) {
      throw new NotFoundException("Conversation not found");
    }
    return conversation;
  }

  private async toViewWithMeta(
    conversation: any,
    viewerUserId: string,
  ): Promise<CampaignConversationView> {
    const read = await this.prisma.campaignConversationRead.findUnique({
      where: {
        conversationId_userId: {
          conversationId: conversation.id,
          userId: viewerUserId,
        },
      },
    });
    const lastReadAt = read?.lastReadAt ?? null;
    const conversationWhere =
      conversation.kind === "main"
        ? {
            OR: [
              { conversationId: conversation.id },
              { conversationId: null, campaignId: conversation.campaignId },
            ],
          }
        : { conversationId: conversation.id };
    const lastMessage = await this.prisma.campaignChatMessage.findFirst({
      where: conversationWhere,
      orderBy: { createdAt: "desc" },
    });
    const unreadCount = await this.prisma.campaignChatMessage.count({
      where: {
        ...conversationWhere,
        senderId: { not: viewerUserId },
        ...(lastReadAt ? { createdAt: { gt: lastReadAt } } : {}),
      },
    });
    return this.toView(conversation, lastMessage, unreadCount);
  }

  private toView(
    conversation: any,
    lastMessage: any,
    unreadCount: number,
  ): CampaignConversationView {
    return {
      id: conversation.id,
      campaignId: conversation.campaignId,
      kind: conversation.kind,
      title: conversation.title ?? "",
      participantIds: Array.isArray(conversation.participantIds)
        ? conversation.participantIds
        : [],
      createdBy: conversation.createdBy,
      createdAt: toDateStr(conversation.createdAt),
      updatedAt: toDateStr(conversation.updatedAt),
      archivedAt: conversation.archivedAt
        ? toDateStr(conversation.archivedAt)
        : null,
      lastMessage: lastMessage ? toChatMessageView(lastMessage) : null,
      unreadCount,
    };
  }

  private async context(campaignId: string) {
    const campaign = await this.prisma.campaign.findUnique({
      where: { id: campaignId },
      include: { members: true },
    });
    if (!campaign) throw new NotFoundException("Campaign not found");
    return {
      campaignId: campaign.id,
      ownerId: campaign.ownerId,
      members: campaign.members.map((member: any) => ({
        userId: member.userId,
        role: member.role,
      })),
    };
  }
}

function toDateStr(value: unknown): string {
  if (value instanceof Date) return value.toISOString();
  return String(value);
}

function toChatMessageView(message: any): CampaignChatMessageView {
  return {
    id: message.id,
    campaignId: message.campaignId,
    senderId: message.senderId,
    campaignActorId: message.campaignActorId ?? null,
    displayName: message.displayName,
    avatarUrl: message.avatarUrl ?? null,
    speakerMode: message.speakerMode ?? "actor",
    delegatedByUserId: message.delegatedByUserId ?? null,
    speakerAvatarAssetId: message.speakerAvatarAssetId ?? null,
    publicHealthState: message.publicHealthState ?? null,
    publicHealthFraction:
      typeof message.publicHealthFraction === "number"
        ? message.publicHealthFraction
        : null,
    ooc: message.ooc ?? false,
    kind: message.kind,
    content: message.content,
    actionSnapshot:
      message.actionSnapshot && typeof message.actionSnapshot === "object"
        ? (message.actionSnapshot as Record<string, unknown>)
        : null,
    eventData:
      message.eventData && typeof message.eventData === "object"
        ? (message.eventData as Record<string, unknown>)
        : null,
    createdAt:
      message.createdAt instanceof Date
        ? message.createdAt.toISOString()
        : message.createdAt,
  };
}
