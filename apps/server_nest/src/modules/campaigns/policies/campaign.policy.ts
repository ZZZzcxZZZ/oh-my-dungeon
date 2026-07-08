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

const MANAGE_ROLES = new Set(['owner', 'dm']);
const VIEW_ROLES = new Set(['owner', 'dm', 'player', 'spectator']);

@Injectable()
export class CampaignPolicy {
  canCreateCampaign(actor: AccessTokenPayload): void {
    if (!actor.userId) {
      throw new ForbiddenException('Authenticated user required');
    }
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
}
