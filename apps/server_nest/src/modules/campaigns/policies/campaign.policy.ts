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

export interface CampaignCharacterContext {
  campaignId: string;
  ownerId: string;
  members: CampaignMemberSummary[];
  characterId: string;
  characterOwnerUserId: string | null;
  characterSourceCharacterId: string | null;
  characterRevision: number;
}

export interface CampaignCharacterIdentity {
  ownerUserId: string | null;
  characterType: string;
  status: string;
}

export interface CampaignCapabilities {
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

const MANAGE_ROLES = new Set(['owner', 'dm']);
const VIEW_ROLES = new Set(['owner', 'dm', 'player', 'spectator']);

@Injectable()
export class CampaignPolicy {
  canCreateCampaign(user: AccessTokenPayload): void {
    if (!user.userId) {
      throw new ForbiddenException('Authenticated user required');
    }
  }

  capabilitiesFor(
    user: AccessTokenPayload,
    campaign: CampaignContext,
  ): CampaignCapabilities {
    const isManager = this.isManager(user, campaign);
    return {
      canManageCampaign: isManager,
      canManageMembers: isManager,
      canInviteMembers: isManager,
      canCreateCharacters: isManager,
      canManageCharacters: isManager,
      canEditAnyCharacter: isManager,
      canSpeakAsNarrator: isManager,
      canCreateArchive: isManager,
      canManageArchive: isManager,
    };
  }

  canViewCampaign(
    user: AccessTokenPayload,
    campaign: CampaignContext
  ): void {
    if (user.userId === campaign.ownerId) return;

    const membership = campaign.members.find(
      (member) => member.userId === user.userId
    );
    if (!membership || !VIEW_ROLES.has(membership.role)) {
      throw new ForbiddenException(
        'You are not a member of this campaign'
      );
    }
  }

  canManageCampaign(
    user: AccessTokenPayload,
    campaign: CampaignContext
  ): void {
    if (user.userId === campaign.ownerId) return;

    const membership = campaign.members.find(
      (member) => member.userId === user.userId
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
   * Anyone who can view the campaign may list and read its characters, including
   * their sheet JSON. The sheet is the campaign's copy, not the player's
   * private local character, so DM-level visibility is intentional.
   */
  canViewCharacter(
    user: AccessTokenPayload,
    ctx: CampaignCharacterContext
  ): void {
    this.canViewCampaign(user, ctx);
  }

  /**
   * DMs (owner or dm role) can fully edit any character: NPCs, unclaimed characters,
   * and the campaign copy of a published player character.
   */
  canManageCharacter(
    user: AccessTokenPayload,
    ctx: CampaignCharacterContext
  ): void {
    this.canManageCampaign(user, ctx);
  }

  /**
   * A player may edit an character iff they own it (i.e. they published their
   * local character to the campaign and the character has not been reassigned).
   * DMs go through `canManageCharacter` instead.
   */
  canEditOwnedCharacter(
    user: AccessTokenPayload,
    ctx: CampaignCharacterContext
  ): void {
    if (this.isManager(user, ctx)) return;
    if (ctx.characterOwnerUserId && ctx.characterOwnerUserId === user.userId) return;
    throw new ForbiddenException(
      'Only the character owner or a DM can edit this character'
    );
  }

  /**
   * Publishing a local character only requires campaign membership — players
   * are allowed to introduce their own character into a campaign.
   */
  canPublishCharacter(
    user: AccessTokenPayload,
    campaign: CampaignContext
  ): void {
    this.canViewCampaign(user, campaign);
  }

  /**
   * A membership binding is the player-facing identity for a campaign. A
   * A player can bind or replace their own active player character; managers
   * can repair bindings for any member.
   */
  canBindCharacter(
    user: AccessTokenPayload,
    campaign: CampaignContext,
    targetUserId: string,
    candidate: CampaignCharacterIdentity,
  ): void {
    this.canViewCampaign(user, campaign);
    if (candidate.status !== "active" || candidate.characterType !== "player") {
      throw new ForbiddenException(
        "只能绑定当前可用的玩家角色；请重新发布或恢复该角色",
      );
    }
    if (this.isManager(user, campaign)) return;
    if (user.userId !== targetUserId || candidate.ownerUserId !== user.userId) {
      throw new ForbiddenException(
        "玩家只能绑定自己的角色",
      );
    }
  }

  canManageMembershipBinding(
    user: AccessTokenPayload,
    campaign: CampaignContext,
    targetUserId: string,
    _hasExistingBinding: boolean,
  ): void {
    if (this.isManager(user, campaign)) return;
    if (user.userId !== targetUserId) {
      throw new ForbiddenException(
        "Only a DM can change another member's character binding",
      );
    }
  }

  /**
   * Chat speakers are server-authorized. Managers may puppeteer any active
   * campaign character; a player can speak only as their own active player character.
   */
  canSpeakAsCharacter(
    user: AccessTokenPayload,
    campaign: CampaignContext,
    candidate: CampaignCharacterIdentity,
  ): void {
    this.canViewCampaign(user, campaign);
    if (candidate.status !== "active") {
      throw new ForbiddenException("Archived characters cannot speak");
    }
    if (this.isManager(user, campaign)) return;
    if (
      candidate.characterType !== "player" ||
      candidate.ownerUserId !== user.userId
    ) {
      throw new ForbiddenException("You can only speak as your own character");
    }
  }

  private isManager(
    user: AccessTokenPayload,
    campaign: CampaignContext
  ): boolean {
    if (user.userId === campaign.ownerId) return true;
    const membership = campaign.members.find(
      (member) => member.userId === user.userId
    );
    return !!membership && MANAGE_ROLES.has(membership.role);
  }
}
