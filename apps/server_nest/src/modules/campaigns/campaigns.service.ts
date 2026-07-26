import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { Prisma } from "@prisma/client";
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
  CampaignCheckRequestView,
  CampaignJournalEntryView,
  CampaignWorkspaceContextView,
  CampaignMemberPreview,
  CampaignView,
  CreateCampaignChatMessageInput,
  CreateCampaignInput,
  CreateInviteInput,
  SpeakerSnapshotInput,
  InviteView,
  MembershipView,
} from "./campaigns.types";

const INVITE_CODE_BYTES = 6;
const CAMPAIGN_MESSAGE_LIMIT = 100;
const MEMBER_PREVIEW_LIMIT = 5;
const PUBLIC_INVITE_ROLE = "player";
const MANAGER_MESSAGE_KINDS = new Set(["system", "checkRequest"]);

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

      // Plan 2026-07-23 task 5.3: seed the main campaign conversation so
      // every campaign has a default chat room from creation. mainKey is
      // the unique dedupe key for the [campaignId, mainKey] constraint.
      await tx.campaignConversation.create({
        data: {
          campaignId: created.id,
          kind: "main",
          title: "",
          mainKey: "main",
          participantIds: [],
          createdBy: actor.userId,
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

    return Promise.all(
      memberships.map(async (membership: any) => {
        const unreadCount = await this.prismaService.campaignChatMessage.count({
          where: {
            campaignId: membership.campaignId,
            senderId: { not: actor.userId },
            ...(membership.lastReadAt
              ? { createdAt: { gt: membership.lastReadAt } }
              : {}),
          },
        });
        return toCampaignView(membership.campaign, unreadCount);
      }),
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

  async getWorkspaceContext(
    actor: AccessTokenPayload,
    campaignId: string,
  ): Promise<CampaignWorkspaceContextView> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canViewCampaign(actor, campaign.context);

    const membership = campaign.members.find(
      (member: any) => member.userId === actor.userId,
    );
    if (!membership) {
      throw new ForbiddenException("Campaign membership not found");
    }

    const actors = await this.prismaService.campaignActor.findMany({
      where: { campaignId },
      orderBy: { createdAt: "asc" },
    });

    return {
      campaign: campaign.view,
      membership: toMembershipView(membership),
      members: campaign.view.memberPreview,
      actors: actors.map(toCampaignWorkspaceActorView),
      capabilities: this.policy.capabilitiesFor(actor, campaign.context),
    };
  }

  async updateMemberBinding(
    actor: AccessTokenPayload,
    campaignId: string,
    targetUserId: string,
    actorId: string | null,
  ): Promise<MembershipView> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canViewCampaign(actor, campaign.context);

    const membership = await this.prismaService.campaignMember.findFirst({
      where: { campaignId, userId: targetUserId },
    });
    if (!membership) {
      throw new NotFoundException("Campaign membership not found");
    }

    this.policy.canManageMembershipBinding(
      actor,
      campaign.context,
      targetUserId,
      !!membership.boundActorId,
    );

    if (actorId === null) {
      const updated = await this.prismaService.campaignMember.update({
        where: { id: membership.id },
        data: {
          boundActorId: null,
          activeSpeakerActorId: null,
          speakerMode: "ooc",
        },
      });
      return toMembershipView(updated);
    }

    const campaignActor = await this.prismaService.campaignActor.findUnique({
      where: { id: actorId },
    });
    if (!campaignActor || campaignActor.campaignId !== campaignId) {
      throw new BadRequestException("Actor does not belong to this campaign");
    }
    this.policy.canBindActor(actor, campaign.context, targetUserId, {
      ownerUserId: campaignActor.ownerUserId,
      actorType: campaignActor.actorType,
      status: campaignActor.status,
    });

    const updated = await this.prismaService.campaignMember.update({
      where: { id: membership.id },
      data: {
        boundActorId: actorId,
        activeSpeakerActorId: actorId,
        speakerMode: "boundActor",
      },
    });
    return toMembershipView(updated);
  }

  async updateSpeaker(
    actor: AccessTokenPayload,
    campaignId: string,
    input: { speakerMode: "boundActor" | "actor" | "narrator" | "ooc"; actorId: string | null },
  ): Promise<MembershipView> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canViewCampaign(actor, campaign.context);
    const membership = campaign.members.find(
      (member: any) => member.userId === actor.userId,
    );
    if (!membership) {
      throw new ForbiddenException("Campaign membership not found");
    }

    if (input.speakerMode === "ooc") {
      return this.saveSpeaker(membership.id, null, "ooc");
    }
    if (input.speakerMode === "narrator") {
      if (!this.policy.capabilitiesFor(actor, campaign.context).canSpeakAsNarrator) {
        throw new ForbiddenException("Only a DM can speak as narrator");
      }
      return this.saveSpeaker(membership.id, null, "narrator");
    }

    const actorId =
      input.speakerMode === "boundActor"
        ? membership.boundActorId
        : input.actorId;
    if (!actorId) {
      throw new BadRequestException("A bound actor is required for this speaker mode");
    }
    const campaignActor = await this.prismaService.campaignActor.findUnique({
      where: { id: actorId },
    });
    if (!campaignActor || campaignActor.campaignId !== campaignId) {
      throw new BadRequestException("Actor does not belong to this campaign");
    }
    this.policy.canSpeakAsActor(actor, campaign.context, {
      ownerUserId: campaignActor.ownerUserId,
      actorType: campaignActor.actorType,
      status: campaignActor.status,
    });
    if (
      !this.policy.capabilitiesFor(actor, campaign.context).canManageCampaign &&
      membership.boundActorId !== actorId
    ) {
      throw new ForbiddenException("Players can only speak as their bound actor");
    }
    return this.saveSpeaker(membership.id, actorId, input.speakerMode);
  }

  async markRead(
    actor: AccessTokenPayload,
    campaignId: string,
  ): Promise<MembershipView> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canViewCampaign(actor, campaign.context);
    const membership = campaign.members.find(
      (member: any) => member.userId === actor.userId,
    );
    if (!membership) {
      throw new ForbiddenException("Campaign membership not found");
    }
    const updated = await this.prismaService.campaignMember.update({
      where: { id: membership.id },
      data: { lastReadAt: new Date() },
    });
    return toMembershipView(updated);
  }

  private async saveSpeaker(
    membershipId: string,
    activeSpeakerActorId: string | null,
    speakerMode: string,
  ): Promise<MembershipView> {
    const updated = await this.prismaService.campaignMember.update({
      where: { id: membershipId },
      data: { activeSpeakerActorId, speakerMode },
    });
    return toMembershipView(updated);
  }

  async listMessages(
    actor: AccessTokenPayload,
    campaignId: string,
    query?: string,
    conversationId?: string,
  ): Promise<CampaignChatMessageView[]> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canViewCampaign(actor, campaign.context);

    const conversationFilter = await this.resolveConversationFilter(
      actor.userId,
      campaignId,
      conversationId,
    );

    const normalizedQuery = query?.trim();
    const messages = await this.prismaService.campaignChatMessage.findMany({
      where: {
        campaignId,
        ...conversationFilter,
        ...(normalizedQuery
          ? { content: { contains: normalizedQuery, mode: "insensitive" } }
          : {}),
      },
      orderBy: { createdAt: "desc" },
      take: CAMPAIGN_MESSAGE_LIMIT,
    });

    return messages.map(toCampaignChatMessageView).reverse();
  }

  /**
   * 列出战役内的检定请求（kind='checkRequest'）及其响应（kind='roll' 且
   * eventData.requestId 匹配的）。status 来自原始 checkRequest 消息的
   * eventData.status，默认 'open'。
   */
  async listCheckRequests(
    actor: AccessTokenPayload,
    campaignId: string,
  ): Promise<CampaignCheckRequestView[]> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canViewCampaign(actor, campaign.context);

    const messages = await this.prismaService.campaignChatMessage.findMany({
      where: {
        campaignId,
        OR: [{ kind: "checkRequest" }, { kind: "roll" }],
      },
      orderBy: { createdAt: "desc" },
    });

    const checkRequests = messages.filter((m: any) => m.kind === "checkRequest");
    const rolls = messages.filter((m: any) => m.kind === "roll");

    return checkRequests.map((checkRequest: any) => {
      const requestData = asRecord(checkRequest.eventData) ?? {};
      const status: "open" | "closed" =
        requestData.status === "closed" ? "closed" : "open";
      const responses = rolls
        .filter((roll: any) => {
          const rollData = asRecord(roll.eventData) ?? {};
          return rollData.requestId === checkRequest.id;
        })
        .map(toCampaignChatMessageView);
      return {
        message: toCampaignChatMessageView(checkRequest),
        responses,
        status,
      };
    });
  }

  /**
   * 列出战役日志条目。type 用于按事件类型过滤（system/check_request/roll/
   * archive_published 等），q 用于按 summary 模糊搜索。
   */
  async listJournal(
    actor: AccessTokenPayload,
    campaignId: string,
    query: { type?: string; q?: string } = {},
  ): Promise<CampaignJournalEntryView[]> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canViewCampaign(actor, campaign.context);

    const entries = await this.prismaService.journalEntry.findMany({
      where: {
        campaignId,
        ...(query.type ? { type: query.type } : {}),
        ...(query.q
          ? { summary: { contains: query.q, mode: "insensitive" } }
          : {}),
      },
      orderBy: { createdAt: "asc" },
    });

    return entries.map((entry: any) => toCampaignJournalEntryView(entry));
  }

  async sendMessage(
    actor: AccessTokenPayload,
    campaignId: string,
    input: CreateCampaignChatMessageInput,
  ): Promise<CampaignChatMessageView> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canViewCampaign(actor, campaign.context);

    let content = input.content.trim();
    const kind = normalizeMessageKind(input.kind);

    let displayName = actor.username;
    let avatarUrl: string | null = null;
    let campaignActorId: string | null = null;
    let actionSnapshot: Record<string, unknown> | null = null;
    let delegatedByUserId: string | null = null;
    let speakerAvatarAssetId: string | null = null;
    let publicHealthState: string | null = null;
    let publicHealthFraction: number | null = null;
    const eventData = validateEventData(kind, input.eventData);
    const membership = campaign.members.find(
      (member: any) => member.userId === actor.userId,
    );
    if (!membership) {
      throw new ForbiddenException("Campaign membership not found");
    }
    const capabilities = this.policy.capabilitiesFor(actor, campaign.context);
    const requestedActorId = input.campaignActorId ?? null;

    // Plan 2026-07-23 task 5.3: route the message to a conversation. If the
    // caller did not specify one, default to the campaign's main room
    // (creating it for legacy campaigns predating task 5.3).
    const conversation = await this.resolveMessageConversation(
      actor.userId,
      campaignId,
      input.conversationId,
    );
    const conversationId = conversation.id;

    if (input.speakerSnapshot) {
      return this.sendSpeakerSnapshotMessage(
        actor,
        campaignId,
        {
          kind,
          content,
          eventData,
          speakerSnapshot: input.speakerSnapshot,
          membership,
          capabilities,
          conversationId,
          conversationParticipantIds:
            conversation.kind === "main"
              ? null
              : conversation.participantIds,
        },
      );
    }

    if (MANAGER_MESSAGE_KINDS.has(kind)) {
      this.policy.canManageCampaign(actor, campaign.context);
    }

    if (!capabilities.canManageCampaign && kind !== "ooc") {
      if (
        !membership.boundActorId ||
        membership.speakerMode === "ooc" ||
        !membership.activeSpeakerActorId
      ) {
        throw new ForbiddenException(
          "Bind a character and select it before sending roleplay messages",
        );
      }
      if (
        requestedActorId !== null &&
        requestedActorId !== membership.activeSpeakerActorId
      ) {
        throw new ForbiddenException(
          "Players can only speak as their active campaign character",
        );
      }
    }

    const speakerMode =
      kind === "ooc"
        ? "ooc"
        : membership.speakerMode ?? (requestedActorId ? "actor" : "ooc");
    const effectiveActorId =
      kind === "ooc"
        ? null
        : !capabilities.canManageCampaign
          ? membership.activeSpeakerActorId
          : requestedActorId ??
            (speakerMode === "actor" || speakerMode === "boundActor"
              ? membership.activeSpeakerActorId ?? null
              : null);
    const ooc = speakerMode === "ooc";

    if (input.actionId && !effectiveActorId) {
      throw new BadRequestException("Character action requires an actor");
    }

    if (effectiveActorId) {
      const campaignActor = await this.prismaService.campaignActor.findUnique({
        where: { id: effectiveActorId },
      });
      if (!campaignActor || campaignActor.campaignId !== campaignId) {
        throw new BadRequestException("Actor does not belong to this campaign");
      }
      this.policy.canSpeakAsActor(actor, campaign.context, {
        ownerUserId: campaignActor.ownerUserId,
        actorType: campaignActor.actorType ?? "player",
        status: campaignActor.status ?? "active",
      });
      const sheet = (campaignActor.sheetJson ?? {}) as Record<string, unknown>;
      displayName = typeof sheet.name === "string" ? sheet.name : "";
      avatarUrl = typeof sheet.avatarUrl === "string" ? sheet.avatarUrl : null;
      campaignActorId = effectiveActorId;
      speakerAvatarAssetId = campaignActor.avatarAssetId ?? null;
      publicHealthState = resolvePublicHealthState(sheet);
      publicHealthFraction = resolvePublicHealthFraction(sheet);
      if (
        capabilities.canManageCampaign &&
        campaignActor.actorType === "player" &&
        campaignActor.ownerUserId &&
        campaignActor.ownerUserId !== actor.userId
      ) {
        delegatedByUserId = actor.userId;
      }
      if (input.actionId) {
        actionSnapshot = resolveActionSnapshot(
          sheet,
          input.actionId,
          campaignActor.revision,
        );
        if (!actionSnapshot) {
          throw new BadRequestException(
            "Action does not belong to this campaign actor",
          );
        }
        content = actionSnapshot.name as string;
      }
    }

    if (speakerMode === "narrator") {
      displayName = "旁白 / DM";
    }

    if (kind === "checkRequest") {
      const targetActorId = eventData?.targetActorId as string;
      const targetActor = await this.prismaService.campaignActor.findUnique({
        where: { id: targetActorId },
      });
      if (!targetActor || targetActor.campaignId !== campaignId) {
        throw new BadRequestException(
          "Check target does not belong to this campaign",
        );
      }
    }

    if (kind === "roll" && eventData?.requestId) {
      const requestId = eventData.requestId as string;
      const originalRequest =
        await this.prismaService.campaignChatMessage.findFirst({
          where: { id: requestId, campaignId, kind: "checkRequest" },
        });
      if (!originalRequest) {
        throw new BadRequestException("Check request not found");
      }
      const originalEventData = asRecord(originalRequest.eventData) ?? {};
      const targetActorId = originalEventData.targetActorId;
      if (
        typeof targetActorId === "string" &&
        targetActorId.length > 0 &&
        targetActorId !== effectiveActorId
      ) {
        throw new ForbiddenException(
          "Check request must be answered by its target actor",
        );
      }
      if (originalEventData.status === "closed") {
        throw new BadRequestException("Check request is closed");
      }
      const existingResponse =
        await this.prismaService.campaignChatMessage.findFirst({
          where: {
            campaignId,
            kind: "roll",
            senderId: actor.userId,
            eventData: { path: ["requestId"], equals: requestId },
          },
        });
      if (existingResponse) {
        throw new ConflictException(
          "Already responded to this check request",
        );
      }
    }

    const messageData: Prisma.CampaignChatMessageUncheckedCreateInput = {
      campaignId,
      senderId: actor.userId,
      campaignActorId,
      displayName,
      avatarUrl,
      speakerMode,
      delegatedByUserId,
      speakerAvatarAssetId,
      publicHealthState,
      publicHealthFraction,
      ooc,
      kind,
      content,
      conversationId,
      ...(actionSnapshot
        ? {
            actionSnapshot: actionSnapshot as Prisma.InputJsonValue,
          }
        : {}),
      ...(eventData
        ? { eventData: eventData as Prisma.InputJsonValue }
        : {}),
    };

    // Key events and their journal projection are one consistency boundary.
    // Broadcasting is deliberately deferred until the transaction commits.
    const journalType = toJournalType(kind);
    const created = journalType
      ? await this.prismaService.$transaction(async (tx) => {
          const message = await tx.campaignChatMessage.create({
            data: messageData,
          });
          await tx.journalEntry.create({
            data: {
              campaignId,
              type: journalType,
              summary: content,
              refId: message.id,
            },
          });
          return message;
        })
      : await this.prismaService.campaignChatMessage.create({
          data: messageData,
        });

    const view = toCampaignChatMessageView(created);
    this.broadcastConversationMessage(campaignId, conversation, view);

    return view;
  }

  /**
   * DM-only path: writes a single message under a use-once speaker snapshot.
   * Plan 2026-07-23 task 5.2: no CampaignActor is created and the DM's
   * activeSpeakerActorId is NOT mutated — the snapshot lives only on this one
   * message row. The DM's next message uses whichever actor they had selected
   * before. Replaces the old sendDraftActorMessage which persisted a temporary
   * actor and switched the active speaker.
   */
  private async sendSpeakerSnapshotMessage(
    actor: AccessTokenPayload,
    campaignId: string,
    input: {
      kind: string;
      content: string;
      eventData: Record<string, unknown> | null;
      speakerSnapshot: SpeakerSnapshotInput;
      membership: { id: string };
      capabilities: { canManageCampaign: boolean };
      conversationId: string;
      conversationParticipantIds: string[] | null;
    },
  ): Promise<CampaignChatMessageView> {
    if (!input.capabilities.canManageCampaign) {
      throw new ForbiddenException(
        "Only managers may send speaker snapshot messages",
      );
    }
    if (input.kind === "ooc") {
      throw new BadRequestException(
        "Speaker snapshot cannot be used for out-of-character messages",
      );
    }
    const displayName = input.speakerSnapshot.displayName.trim();
    if (!displayName) {
      throw new BadRequestException("speakerSnapshot.displayName is required");
    }
    const avatarUrl = input.speakerSnapshot.avatarUrl ?? null;

    // No transaction needed: a single row write. No actor creation, no
    // membership mutation — the snapshot is self-contained on the message.
    const created = await this.prismaService.campaignChatMessage.create({
      data: {
        campaignId,
        senderId: actor.userId,
        campaignActorId: null,
        displayName,
        avatarUrl,
        speakerMode: "snapshot",
        delegatedByUserId: null,
        speakerAvatarAssetId: null,
        publicHealthState: null,
        publicHealthFraction: null,
        ooc: false,
        kind: input.kind,
        content: input.content,
        conversationId: input.conversationId,
        ...(input.eventData
          ? { eventData: input.eventData as Prisma.InputJsonValue }
          : {}),
      },
    });

    const view = toCampaignChatMessageView(created);
    if (input.conversationParticipantIds) {
      this.gateway.broadcastToUsers(
        input.conversationParticipantIds,
        "campaign:message:new",
        view,
      );
    } else {
      this.gateway.broadcastToCampaign(
        campaignId,
        "campaign:message:new",
        view,
      );
    }
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
        roleOnJoin: PUBLIC_INVITE_ROLE,
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
          role: PUBLIC_INVITE_ROLE,
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

  private async loadAccessibleConversation(
    userId: string,
    campaignId: string,
    conversationId: string,
  ) {
    const conversation = await this.prismaService.campaignConversation.findFirst({
      where: { id: conversationId, campaignId },
    });
    if (!conversation) {
      throw new NotFoundException("Conversation not found");
    }
    if (conversation.archivedAt) {
      throw new BadRequestException("Conversation is archived");
    }
    // Main is open to all campaign members (membership already verified by
    // canViewCampaign upstream). Direct/group require explicit participation.
    if (
      conversation.kind !== "main" &&
      !conversation.participantIds.includes(userId)
    ) {
      throw new ForbiddenException("You cannot access this conversation");
    }
    return conversation;
  }

  /**
   * Plan 2026-07-23 task 5.3: resolve the conversation a new message is
   * posted to. An explicit conversationId is access-checked; a missing one
   * defaults to the main room, creating it for legacy campaigns that predate
   * the seeded main conversation in createCampaign.
   */
  private async resolveMessageConversation(
    userId: string,
    campaignId: string,
    conversationId: string | null | undefined,
  ): Promise<{ id: string; kind: string; participantIds: string[] }> {
    if (conversationId) {
      const conversation = await this.loadAccessibleConversation(
        userId,
        campaignId,
        conversationId,
      );
      return conversation;
    }
    const main = await this.prismaService.campaignConversation.findFirst({
      where: { campaignId, kind: "main" },
    });
    if (main) return main;
    const created = await this.prismaService.campaignConversation.create({
      data: {
        campaignId,
        kind: "main",
        title: "",
        mainKey: "main",
        participantIds: [],
        createdBy: userId,
      },
    });
    return created;
  }

  private broadcastConversationMessage(
    campaignId: string,
    conversation: { kind: string; participantIds: string[] },
    message: CampaignChatMessageView,
  ): void {
    if (conversation.kind === "main") {
      this.gateway.broadcastToCampaign(
        campaignId,
        "campaign:message:new",
        message,
      );
      return;
    }
    this.gateway.broadcastToUsers(
      conversation.participantIds,
      "campaign:message:new",
      message,
    );
  }

  /**
   * Builds the conversation filter for listMessages. When no conversationId is
   * requested, the main room is shown — including legacy messages that carry a
   * null conversationId from before task 5.3.
   */
  private async resolveConversationFilter(
    userId: string,
    campaignId: string,
    conversationId: string | undefined,
  ): Promise<Prisma.CampaignChatMessageWhereInput> {
    if (conversationId) {
      await this.loadAccessibleConversation(userId, campaignId, conversationId);
      return { conversationId };
    }
    const main = await this.prismaService.campaignConversation.findFirst({
      where: { campaignId, kind: "main" },
    });
    if (main) {
      return { OR: [{ conversationId: main.id }, { conversationId: null }] };
    }
    return { conversationId: null };
  }

  private async fetchCampaignContext(campaignId: string): Promise<{
    view: CampaignView;
    context: CampaignContext;
    members: any[];
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
      members: campaign.members,
    };
  }
}

function toCampaignView(campaign: any, unreadCount = 0): CampaignView {
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
    unreadCount,
    memberPreview,
  };
}

function toCampaignWorkspaceActorView(actor: any) {
  const sheet = asRecord(actor.sheetJson) ?? {};
  return {
    id: actor.id,
    ownerUserId: actor.ownerUserId ?? null,
    actorType: actor.actorType,
    status: actor.status,
    lifecycle: actor.lifecycle ?? "persistent",
    displayName:
      typeof sheet.name === "string" && sheet.name.trim()
        ? sheet.name.trim()
        : "Unnamed actor",
    avatarAssetId: actor.avatarAssetId ?? null,
    publicHealthState: resolvePublicHealthState(sheet),
  };
}

function resolvePublicHealthState(
  sheet: Record<string, unknown>,
): "healthy" | "injured" | "critical" | "down" | "unknown" {
  const currentHp = sheet.currentHp;
  const maxHp = sheet.maxHp;
  if (
    typeof currentHp !== "number" ||
    !Number.isFinite(currentHp) ||
    typeof maxHp !== "number" ||
    !Number.isFinite(maxHp) ||
    maxHp <= 0
  ) {
    return "unknown";
  }
  if (currentHp <= 0) return "down";
  const ratio = currentHp / maxHp;
  if (ratio < 0.25) return "critical";
  if (ratio < 0.5) return "injured";
  return "healthy";
}

function resolvePublicHealthFraction(
  sheet: Record<string, unknown>,
): number | null {
  const currentHp = sheet.currentHp;
  const maxHp = sheet.maxHp;
  if (
    typeof currentHp !== "number" ||
    !Number.isFinite(currentHp) ||
    typeof maxHp !== "number" ||
    !Number.isFinite(maxHp) ||
    maxHp <= 0
  ) {
    return null;
  }
  return Math.min(1, Math.max(0, currentHp / maxHp));
}

function toCampaignChatMessageView(message: any): CampaignChatMessageView {
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

function resolveActionSnapshot(
  sheet: Record<string, unknown>,
  actionId: string,
  actorRevision: number,
): Record<string, unknown> | null {
  const data = asRecord(sheet.data);
  const actions = Array.isArray(data?.actions) ? data.actions : [];
  const action = actions
    .map(asRecord)
    .find((candidate) => candidate?.id === actionId);
  if (!action || typeof action.name !== "string" || !action.name.trim()) {
    return null;
  }

  return {
    id: actionId,
    name: action.name.trim(),
    ...(typeof action.entryId === "string" ? { entryId: action.entryId } : {}),
    ...(typeof action.formula === "string" ? { formula: action.formula } : {}),
    actorRevision,
  };
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

/**
 * 把消息 kind 映射到 journal entry type；返回 null 表示该 kind 不归档
 * (say/action/ooc 等纯对话)。checkRequest→check_request、
 * archivePublished→archive_published。
 */
function toJournalType(kind: string): string | null {
  if (kind === "system" || kind === "roll") return kind;
  if (kind === "checkRequest") return "check_request";
  if (kind === "archivePublished") return "archive_published";
  return null;
}

function toCampaignJournalEntryView(entry: any): CampaignJournalEntryView {
  return {
    id: entry.id,
    campaignId: entry.campaignId,
    type: entry.type,
    summary: entry.summary,
    refId: entry.refId ?? null,
    createdAt:
      entry.createdAt instanceof Date
        ? entry.createdAt.toISOString()
        : entry.createdAt,
  };
}

function normalizeMessageKind(kind: string | undefined): string {
  if (kind == null || kind === "say") return "say";
  if (
    kind === "action" ||
    kind === "roll" ||
    kind === "system" ||
    kind === "checkRequest" ||
    kind === "ooc" ||
    kind === "archivePublished"
  ) {
    return kind;
  }
  throw new BadRequestException("Unsupported campaign message kind");
}

function validateEventData(
  kind: string,
  value: Record<string, unknown> | null | undefined,
): Record<string, unknown> | null {
  if (kind === "say" || kind === "action" || kind === "ooc") {
    return value ?? null;
  }
  if (kind === "roll") {
    if (!value) return null;
    const notation = optionalTrimmedString(value.notation, "Roll notation");
    const label = optionalTrimmedString(value.label, "Roll label");
    const requestId = optionalTrimmedString(value.requestId, "Roll request id");
    const total = value.total;
    if (total != null && (typeof total !== "number" || !Number.isFinite(total))) {
      throw new BadRequestException("Roll total must be a finite number");
    }
    return {
      ...(notation ? { notation } : {}),
      ...(label ? { label } : {}),
      ...(requestId ? { requestId } : {}),
      ...(typeof total === "number" ? { total } : {}),
    };
  }
  if (kind === "system" || kind === "archivePublished") {
    return value ?? null;
  }
  if (!value) {
    throw new BadRequestException("Check request data is required");
  }
  const targetActorId = requiredTrimmedString(
    value.targetActorId,
    "Check target actor",
  );
  const checkType = requiredTrimmedString(value.checkType, "Check type");
  if (!new Set(["ability", "save", "skill"]).has(checkType)) {
    throw new BadRequestException("Unsupported check type");
  }
  const checkKey = requiredTrimmedString(value.checkKey, "Check key");
  const label =
    optionalTrimmedString(value.label, "Check label") ?? checkKey;
  const rollMode =
    optionalTrimmedString(value.rollMode, "Check roll mode") ?? "normal";
  if (!new Set(["normal", "advantage", "disadvantage"]).has(rollMode)) {
    throw new BadRequestException("Unsupported check roll mode");
  }
  const dc = value.dc;
  if (
    dc != null &&
    (typeof dc !== "number" ||
      !Number.isInteger(dc) ||
      dc < 1 ||
      dc > 30)
  ) {
    throw new BadRequestException("Check DC must be an integer from 1 to 30");
  }
  return {
    targetActorId,
    checkType,
    checkKey,
    label,
    rollMode,
    ...(typeof dc === "number" ? { dc } : {}),
  };
}

function requiredTrimmedString(value: unknown, label: string): string {
  const result = optionalTrimmedString(value, label);
  if (!result) {
    throw new BadRequestException(`${label} is required`);
  }
  return result;
}

function optionalTrimmedString(
  value: unknown,
  label: string,
): string | null {
  if (value == null) return null;
  if (typeof value !== "string" || !value.trim()) {
    throw new BadRequestException(`${label} must be a non-empty string`);
  }
  return value.trim();
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
    boundActorId: membership.boundActorId ?? null,
    activeSpeakerActorId: membership.activeSpeakerActorId ?? null,
    speakerMode: membership.speakerMode ?? "boundActor",
    lastReadAt: membership.lastReadAt
      ? membership.lastReadAt instanceof Date
        ? membership.lastReadAt.toISOString()
        : membership.lastReadAt
      : null,
    joinedAt:
      membership.joinedAt instanceof Date
        ? membership.joinedAt.toISOString()
        : membership.joinedAt,
  };
}

function generateInviteCode(): string {
  return randomBytes(INVITE_CODE_BYTES).toString("base64url").toUpperCase();
}
