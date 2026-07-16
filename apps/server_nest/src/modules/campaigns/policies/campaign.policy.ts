import {
  ForbiddenException,
  Injectable,
  NotFoundException
} from '@nestjs/common';
import { AccessTokenPayload } from '../../auth/auth.types';

export interface CampaignMemberSummary {
  userId: string;
  role: string;
}

export interface CampaignContext {
  campaignId: string;
  ownerId: string;
  members: CampaignMemberSummary[];
}

export interface InviteContext {
  id: string;
  campaignId: string;
  code: string;
  roleOnJoin: string;
  expiresAt: Date | null;
  maxUses: number;
  usedCount: number;
  requireApproval: boolean;
}

export interface JoinContext {
  invite: InviteContext | null;
  existingMembership: CampaignMemberSummary | null;
}

export interface CampaignActorContext {
  campaignId: string;
  ownerId: string;
  members: CampaignMemberSummary[];
  actorId: string;
  actorOwnerUserId: string | null;
  actorSourceCharacterId: string | null;
  actorRevision: number;
}

export interface CampaignActorIdentity {
  ownerUserId: string | null;
  actorType: string;
  status: string;
}

export interface CampaignCapabilities {
  canManageCampaign: boolean;
  canManageMembers: boolean;
  canCreateActors: boolean;
  canSpeakAsNarrator: boolean;
}

const MANAGE_ROLES = new Set(['owner', 'dm']);
const VIEW_ROLES = new Set(['owner', 'dm', 'player', 'spectator']);

@Injectable()
export class CampaignPolicy {
  canCreateCampaign(actor: AccessTokenPayload): void {
    if (!actor.userId) {
      throw new ForbiddenException('Authenticated user required');
    }
  }

  capabilitiesFor(
    actor: AccessTokenPayload,
    campaign: CampaignContext,
  ): CampaignCapabilities {
    const isManager = this.isManager(actor, campaign);
    return {
      canManageCampaign: isManager,
      canManageMembers: isManager,
      canCreateActors: isManager,
      canSpeakAsNarrator: isManager,
    };
  }

  canViewCampaign(
    actor: AccessTokenPayload,
    campaign: CampaignContext
  ): void {
    if (actor.userId === campaign.ownerId) return;

    const membership = campaign.members.find(
      (member) => member.userId === actor.userId
    );
    if (!membership || !VIEW_ROLES.has(membership.role)) {
      throw new ForbiddenException(
        'You are not a member of this campaign'
      );
    }
  }

  canManageCampaign(
    actor: AccessTokenPayload,
    campaign: CampaignContext
  ): void {
    if (actor.userId === campaign.ownerId) return;

    const membership = campaign.members.find(
      (member) => member.userId === actor.userId
    );
    if (!membership || !MANAGE_ROLES.has(membership.role)) {
      throw new ForbiddenException(
        'Only the owner or a DM can manage this campaign'
      );
    }
  }

  canJoinCampaign(context: JoinContext): void {
    const { invite, existingMembership } = context;

    if (existingMembership) {
      return;
    }

    if (!invite) {
      throw new NotFoundException('Invite not found');
    }

    if (invite.expiresAt && invite.expiresAt.getTime() < Date.now()) {
      throw new ForbiddenException('Invite has expired');
    }

    if (invite.usedCount >= invite.maxUses) {
      throw new ForbiddenException('Invite has reached its usage limit');
    }
  }

  /**
   * Anyone who can view the campaign may list and read its actors, including
   * their sheet JSON. The sheet is the campaign's copy, not the player's
   * private local character, so DM-level visibility is intentional.
   */
  canViewActor(
    actor: AccessTokenPayload,
    ctx: CampaignActorContext
  ): void {
    this.canViewCampaign(actor, ctx);
  }

  /**
   * DMs (owner or dm role) can fully edit any actor: NPCs, unclaimed actors,
   * and the campaign copy of a published player character.
   */
  canManageActor(
    actor: AccessTokenPayload,
    ctx: CampaignActorContext
  ): void {
    this.canManageCampaign(actor, ctx);
  }

  /**
   * A player may edit an actor iff they own it (i.e. they published their
   * local character to the campaign and the actor has not been reassigned).
   * DMs go through `canManageActor` instead.
   */
  canEditOwnedActor(
    actor: AccessTokenPayload,
    ctx: CampaignActorContext
  ): void {
    if (this.isManager(actor, ctx)) return;
    if (ctx.actorOwnerUserId && ctx.actorOwnerUserId === actor.userId) return;
    throw new ForbiddenException(
      'Only the actor owner or a DM can edit this actor'
    );
  }

  /**
   * Publishing a local character only requires campaign membership — players
   * are allowed to introduce their own character into a campaign.
   */
  canPublishActor(
    actor: AccessTokenPayload,
    campaign: CampaignContext
  ): void {
    this.canViewCampaign(actor, campaign);
  }

  /**
   * A membership binding is the player-facing identity for a campaign. A
   * player can only bind their own active player actor; managers can repair
   * bindings for any member.
   */
  canBindActor(
    actor: AccessTokenPayload,
    campaign: CampaignContext,
    targetUserId: string,
    candidate: CampaignActorIdentity,
  ): void {
    this.canViewCampaign(actor, campaign);
    if (candidate.status !== "active" || candidate.actorType !== "player") {
      throw new ForbiddenException(
        "Only active player actors can be bound to a campaign member",
      );
    }
    if (this.isManager(actor, campaign)) return;
    if (actor.userId !== targetUserId || candidate.ownerUserId !== actor.userId) {
      throw new ForbiddenException(
        "Players can only bind their own player actor",
      );
    }
  }

  canManageMembershipBinding(
    actor: AccessTokenPayload,
    campaign: CampaignContext,
    targetUserId: string,
    hasExistingBinding: boolean,
  ): void {
    if (this.isManager(actor, campaign)) return;
    if (actor.userId !== targetUserId || hasExistingBinding) {
      throw new ForbiddenException(
        "Only a DM can replace or clear a campaign character binding",
      );
    }
  }

  /**
   * Chat speakers are server-authorized. Managers may puppeteer any active
   * campaign actor; a player can speak only as their own active player actor.
   */
  canSpeakAsActor(
    actor: AccessTokenPayload,
    campaign: CampaignContext,
    candidate: CampaignActorIdentity,
  ): void {
    this.canViewCampaign(actor, campaign);
    if (candidate.status !== "active") {
      throw new ForbiddenException("Archived actors cannot speak");
    }
    if (this.isManager(actor, campaign)) return;
    if (
      candidate.actorType !== "player" ||
      candidate.ownerUserId !== actor.userId
    ) {
      throw new ForbiddenException("You can only speak as your own actor");
    }
  }

  private isManager(
    actor: AccessTokenPayload,
    campaign: CampaignContext
  ): boolean {
    if (actor.userId === campaign.ownerId) return true;
    const membership = campaign.members.find(
      (member) => member.userId === actor.userId
    );
    return !!membership && MANAGE_ROLES.has(membership.role);
  }
}
