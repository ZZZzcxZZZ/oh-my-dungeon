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
    user: AccessTokenPayload,
    input: CreateCampaignInput,
  ): Promise<CampaignView> {
    this.policy.canCreateCampaign(user);

    const campaign = await this.prismaService.$transaction(async (tx) => {
      const created = await tx.campaign.create({
        data: {
          name: input.name,
          description: input.description ?? "",
          system: input.system ?? "dnd5e",
          ownerId: user.userId,
        },
      });

      await tx.campaignMember.create({
        data: {
          campaignId: created.id,
          userId: user.userId,
          role: "owner",
          displayName: user.username,
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
          createdBy: user.userId,
        },
      });

      return created;
    });

    return toCampaignView(campaign);
  }

  async listCampaigns(user: AccessTokenPayload): Promise<CampaignView[]> {
    const memberships = await this.prismaService.campaignMember.findMany({
      where: { userId: user.userId },
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
            senderId: { not: user.userId },
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
    user: AccessTokenPayload,
    campaignId: string,
  ): Promise<CampaignView> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canViewCampaign(user, campaign.context);
    return campaign.view;
  }

  async getWorkspaceContext(
    user: AccessTokenPayload,
    campaignId: string,
  ): Promise<CampaignWorkspaceContextView> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canViewCampaign(user, campaign.context);

    const membership = campaign.members.find(
      (member: any) => member.userId === user.userId,
    );
    if (!membership) {
      throw new ForbiddenException("Campaign membership not found");
    }

    const characters = await this.prismaService.campaignCharacter.findMany({
      where: { campaignId },
      orderBy: { createdAt: "asc" },
    });
    const capabilities = this.policy.capabilitiesFor(user, campaign.context);
    const visibleCharacters = characters.filter(
      (character) =>
        capabilities.canManageCampaign ||
        character.characterType === "player" ||
        character.visibleToPlayers === true,
    );

    return {
      campaign: campaign.view,
      membership: toMembershipView(membership),
      members: campaign.view.memberPreview,
      characters: visibleCharacters.map(toCampaignWorkspaceCharacterView),
      capabilities,
    };
  }

  async updateMemberBinding(
    user: AccessTokenPayload,
    campaignId: string,
    targetUserId: string,
    characterId: string | null,
  ): Promise<MembershipView> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canViewCampaign(user, campaign.context);

    const membership = await this.prismaService.campaignMember.findFirst({
      where: { campaignId, userId: targetUserId },
    });
    if (!membership) {
      throw new NotFoundException("Campaign membership not found");
    }

    this.policy.canManageMembershipBinding(
      user,
      campaign.context,
      targetUserId,
      !!membership.boundCharacterId,
    );

    if (characterId === null) {
      const updated = await this.prismaService.campaignMember.update({
        where: { id: membership.id },
        data: {
          boundCharacterId: null,
          activeSpeakerCharacterId: null,
          speakerMode: "ooc",
        },
      });
      return toMembershipView(updated);
    }

    const campaignCharacter = await this.prismaService.campaignCharacter.findUnique({
      where: { id: characterId },
    });
    if (!campaignCharacter || campaignCharacter.campaignId !== campaignId) {
      throw new BadRequestException("Character does not belong to this campaign");
    }
    this.policy.canBindCharacter(user, campaign.context, targetUserId, {
      ownerUserId: campaignCharacter.ownerUserId,
      characterType: campaignCharacter.characterType,
      status: campaignCharacter.status,
    });

    const updated = await this.prismaService.campaignMember.update({
      where: { id: membership.id },
      data: {
        boundCharacterId: characterId,
        activeSpeakerCharacterId: characterId,
        speakerMode: "boundCharacter",
      },
    });
    return toMembershipView(updated);
  }

  async updateSpeaker(
    user: AccessTokenPayload,
    campaignId: string,
    input: { speakerMode: "boundCharacter" | "character" | "narrator" | "ooc"; characterId: string | null },
  ): Promise<MembershipView> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canViewCampaign(user, campaign.context);
    const membership = campaign.members.find(
      (member: any) => member.userId === user.userId,
    );
    if (!membership) {
      throw new ForbiddenException("Campaign membership not found");
    }

    if (input.speakerMode === "ooc") {
      return this.saveSpeaker(membership.id, null, "ooc");
    }
    if (input.speakerMode === "narrator") {
      if (!this.policy.capabilitiesFor(user, campaign.context).canSpeakAsNarrator) {
        throw new ForbiddenException("Only a DM can speak as narrator");
      }
      return this.saveSpeaker(membership.id, null, "narrator");
    }

    const characterId =
      input.speakerMode === "boundCharacter"
        ? membership.boundCharacterId
        : input.characterId;
    if (!characterId) {
      throw new BadRequestException("A bound character is required for this speaker mode");
    }
    const campaignCharacter = await this.prismaService.campaignCharacter.findUnique({
      where: { id: characterId },
    });
    if (!campaignCharacter || campaignCharacter.campaignId !== campaignId) {
      throw new BadRequestException("Character does not belong to this campaign");
    }
    this.policy.canSpeakAsCharacter(user, campaign.context, {
      ownerUserId: campaignCharacter.ownerUserId,
      characterType: campaignCharacter.characterType,
      status: campaignCharacter.status,
    });
    if (
      !this.policy.capabilitiesFor(user, campaign.context).canManageCampaign &&
      membership.boundCharacterId !== characterId
    ) {
      throw new ForbiddenException("Players can only speak as their bound character");
    }
    return this.saveSpeaker(membership.id, characterId, input.speakerMode);
  }

  async markRead(
    user: AccessTokenPayload,
    campaignId: string,
  ): Promise<MembershipView> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canViewCampaign(user, campaign.context);
    const membership = campaign.members.find(
      (member: any) => member.userId === user.userId,
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
    activeSpeakerCharacterId: string | null,
    speakerMode: string,
  ): Promise<MembershipView> {
    const updated = await this.prismaService.campaignMember.update({
      where: { id: membershipId },
      data: { activeSpeakerCharacterId, speakerMode },
    });
    return toMembershipView(updated);
  }

  async listMessages(
    user: AccessTokenPayload,
    campaignId: string,
    query?: string,
    conversationId?: string,
  ): Promise<CampaignChatMessageView[]> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canViewCampaign(user, campaign.context);

    const conversationFilter = await this.resolveConversationFilter(
      user.userId,
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
    user: AccessTokenPayload,
    campaignId: string,
  ): Promise<CampaignCheckRequestView[]> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canViewCampaign(user, campaign.context);

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
    user: AccessTokenPayload,
    campaignId: string,
    query: { type?: string; q?: string } = {},
  ): Promise<CampaignJournalEntryView[]> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canViewCampaign(user, campaign.context);

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
    user: AccessTokenPayload,
    campaignId: string,
    input: CreateCampaignChatMessageInput,
  ): Promise<CampaignChatMessageView> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canViewCampaign(user, campaign.context);

    let content = input.content.trim();
    const kind = normalizeMessageKind(input.kind);

    let displayName = user.username;
    let avatarUrl: string | null = null;
    let campaignCharacterId: string | null = null;
    let actionSnapshot: Record<string, unknown> | null = null;
    let delegatedByUserId: string | null = null;
    let speakerAvatarAssetId: string | null = null;
    let publicHealthState: string | null = null;
    let publicHealthFraction: number | null = null;
    const eventData = validateEventData(kind, input.eventData);
    const membership = campaign.members.find(
      (member: any) => member.userId === user.userId,
    );
    if (!membership) {
      throw new ForbiddenException("Campaign membership not found");
    }
    const capabilities = this.policy.capabilitiesFor(user, campaign.context);
    const explicitSpeaker = input.speaker ?? null;
    const requestedCharacterId =
      explicitSpeaker?.kind === "character"
        ? explicitSpeaker.characterId
        : input.campaignCharacterId ?? null;

    // Plan 2026-07-23 task 5.3: route the message to a conversation. If the
    // caller did not specify one, default to the campaign's main room
    // (creating it for legacy campaigns predating task 5.3).
    const conversation = await this.resolveMessageConversation(
      user.userId,
      campaignId,
      input.conversationId,
    );
    const conversationId = conversation.id;

    if (explicitSpeaker?.kind === "temporary" || input.speakerSnapshot) {
      const snapshot =
        explicitSpeaker?.kind === "temporary"
          ? {
              displayName: explicitSpeaker.displayName,
              avatarUrl: explicitSpeaker.avatarUrl,
            }
          : input.speakerSnapshot!;
      return this.sendSpeakerSnapshotMessage(
        user,
        campaignId,
        {
          kind,
          content,
          eventData,
          speakerSnapshot: snapshot,
          speakerMode:
            explicitSpeaker?.kind === "temporary" ? "temporary" : "snapshot",
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
      this.policy.canManageCampaign(user, campaign.context);
    }

    if (!capabilities.canManageCampaign && kind !== "ooc") {
      if (
        !membership.boundCharacterId ||
        membership.speakerMode === "ooc" ||
        !membership.activeSpeakerCharacterId
      ) {
        throw new ForbiddenException(
          "Bind a character and select it before sending roleplay messages",
        );
      }
      if (
        requestedCharacterId !== null &&
        requestedCharacterId !== membership.activeSpeakerCharacterId
      ) {
        throw new ForbiddenException(
          "Players can only speak as their active campaign character",
        );
      }
    }

    if (
      explicitSpeaker?.kind === "narrator" &&
      !capabilities.canSpeakAsNarrator
    ) {
      throw new ForbiddenException("Only a DM can speak as narrator");
    }
    if (explicitSpeaker?.kind === "ooc" && kind !== "ooc") {
      throw new BadRequestException("OOC speaker requires an ooc message");
    }
    if (explicitSpeaker?.kind !== "ooc" && kind === "ooc" && explicitSpeaker) {
      throw new BadRequestException("OOC messages require the ooc speaker");
    }

    const speakerMode =
      explicitSpeaker?.kind === "character"
        ? "character"
        : explicitSpeaker?.kind === "narrator"
          ? "narrator"
          : explicitSpeaker?.kind === "ooc" || kind === "ooc"
            ? "ooc"
            : membership.speakerMode ?? (requestedCharacterId ? "character" : "ooc");
    const effectiveCharacterId =
      kind === "ooc"
        ? null
        : !capabilities.canManageCampaign
          ? membership.activeSpeakerCharacterId
          : requestedCharacterId ??
            (speakerMode === "character" || speakerMode === "boundCharacter"
              ? membership.activeSpeakerCharacterId ?? null
              : null);
    const ooc = speakerMode === "ooc";

    if (input.actionId && !effectiveCharacterId) {
      throw new BadRequestException("Character action requires an character");
    }

    if (effectiveCharacterId) {
      const campaignCharacter = await this.prismaService.campaignCharacter.findUnique({
        where: { id: effectiveCharacterId },
      });
      if (!campaignCharacter || campaignCharacter.campaignId !== campaignId) {
        throw new BadRequestException("Character does not belong to this campaign");
      }
      this.policy.canSpeakAsCharacter(user, campaign.context, {
        ownerUserId: campaignCharacter.ownerUserId,
        characterType: campaignCharacter.characterType ?? "player",
        status: campaignCharacter.status ?? "active",
      });
      const sheet = (campaignCharacter.sheetJson ?? {}) as Record<string, unknown>;
      displayName = typeof sheet.name === "string" ? sheet.name : "";
      avatarUrl = typeof sheet.avatarUrl === "string" ? sheet.avatarUrl : null;
      campaignCharacterId = effectiveCharacterId;
      speakerAvatarAssetId = campaignCharacter.avatarAssetId ?? null;
      publicHealthState = resolvePublicHealthState(sheet);
      publicHealthFraction = resolvePublicHealthFraction(sheet);
      if (
        capabilities.canManageCampaign &&
        campaignCharacter.characterType !== "player" &&
        campaignCharacter.visibleToPlayers === false
      ) {
        await this.prismaService.campaignCharacter.update({
          where: { id: campaignCharacter.id },
          data: { visibleToPlayers: true },
        });
      }
      if (
        capabilities.canManageCampaign &&
        campaignCharacter.characterType === "player" &&
        campaignCharacter.ownerUserId &&
        campaignCharacter.ownerUserId !== user.userId
      ) {
        delegatedByUserId = user.userId;
      }
      if (input.actionId) {
        actionSnapshot = resolveActionSnapshot(
          sheet,
          input.actionId,
          campaignCharacter.revision,
        );
        if (!actionSnapshot) {
          throw new BadRequestException(
            "Action does not belong to this campaign character",
          );
        }
        content = actionSnapshot.name as string;
      }
    }

    if (speakerMode === "narrator") {
      displayName = "旁白 / DM";
    }

    if (kind === "checkRequest") {
      const targetCharacterId = eventData?.targetCharacterId as string;
      const targetCharacter = await this.prismaService.campaignCharacter.findUnique({
        where: { id: targetCharacterId },
      });
      if (!targetCharacter || targetCharacter.campaignId !== campaignId) {
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
      const targetCharacterId = originalEventData.targetCharacterId;
      if (
        typeof targetCharacterId === "string" &&
        targetCharacterId.length > 0 &&
        targetCharacterId !== effectiveCharacterId
      ) {
        throw new ForbiddenException(
          "Check request must be answered by its target character",
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
            senderId: user.userId,
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
      senderId: user.userId,
      campaignCharacterId,
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
   * Plan 2026-07-23 task 5.2: no CampaignCharacter is created and the DM's
   * activeSpeakerCharacterId is NOT mutated — the snapshot lives only on this one
   * message row. The DM's next message uses whichever character they had selected
   * before. Replaces the old sendDraftCharacterMessage which persisted a temporary
   * character and switched the active speaker.
   */
  private async sendSpeakerSnapshotMessage(
    user: AccessTokenPayload,
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
      speakerMode: "snapshot" | "temporary";
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

    // No transaction needed: a single row write. No character creation, no
    // membership mutation — the snapshot is self-contained on the message.
    const created = await this.prismaService.campaignChatMessage.create({
      data: {
        campaignId,
        senderId: user.userId,
        campaignCharacterId: null,
        displayName,
        avatarUrl,
        speakerMode: input.speakerMode,
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
    user: AccessTokenPayload,
    input: CreateInviteInput,
  ): Promise<InviteView> {
    const campaign = await this.fetchCampaignContext(input.campaignId);
    this.policy.canManageCampaign(user, campaign.context);

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
        createdBy: user.userId,
      },
    });

    return toInviteView(created);
  }

  async listInvites(
    user: AccessTokenPayload,
    campaignId: string,
  ): Promise<InviteView[]> {
    const campaign = await this.fetchCampaignContext(campaignId);
    this.policy.canManageCampaign(user, campaign.context);

    const invites = await this.prismaService.campaignInvite.findMany({
      where: { campaignId },
    });

    return invites.map(toInviteView);
  }

  async joinCampaign(
    user: AccessTokenPayload,
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
          userId: user.userId,
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
          userId: user.userId,
          campaignId: invite!.campaignId,
        },
      });
      return toMembershipView(membership!);
    }

    const membership = await this.prismaService.$transaction(async (tx) => {
      const created = await tx.campaignMember.create({
        data: {
          campaignId: invite!.campaignId,
          userId: user.userId,
          role: PUBLIC_INVITE_ROLE,
          displayName: user.username,
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
    boundCharacterId: member.boundCharacterId ?? null,
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

function toCampaignWorkspaceCharacterView(character: any) {
  const sheet = asRecord(character.sheetJson) ?? {};
  return {
    id: character.id,
    ownerUserId: character.ownerUserId ?? null,
    sourceCharacterId: character.sourceCharacterId ?? null,
    characterType: character.characterType,
    status: character.status,
    lifecycle: character.lifecycle ?? "persistent",
    visibleToPlayers:
      character.characterType === "player" ||
      character.visibleToPlayers === true,
    displayName:
      typeof sheet.name === "string" && sheet.name.trim()
        ? sheet.name.trim()
        : "Unnamed character",
    avatarAssetId: character.avatarAssetId ?? null,
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
    campaignCharacterId: message.campaignCharacterId ?? null,
    displayName: message.displayName,
    avatarUrl: message.avatarUrl ?? null,
    speakerMode: message.speakerMode ?? "character",
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
  characterRevision: number,
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
    characterRevision,
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
  const targetCharacterId = requiredTrimmedString(
    value.targetCharacterId,
    "Check target character",
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
    targetCharacterId,
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
    boundCharacterId: membership.boundCharacterId ?? null,
    activeSpeakerCharacterId: membership.activeSpeakerCharacterId ?? null,
    speakerMode: membership.speakerMode ?? "boundCharacter",
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
